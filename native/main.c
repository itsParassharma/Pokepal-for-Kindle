/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <signal.h>
#include <sys/stat.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
#define STBI_ONLY_PNG
#define STB_TRUETYPE_IMPLEMENTATION
#define STBTT_STATIC
#include "stb_image.h"
#include "stb_truetype.h"
#if defined(HEADLESS) && defined(_WIN32)
#include <windows.h>
#endif
#ifndef _WIN32
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <dirent.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <linux/input.h>
#endif
#ifndef HEADLESS
#include "fbink.h"
#endif

enum { WIDTH=600, HEIGHT=800 };
static unsigned char pixels[WIDTH*HEIGHT];
static stbtt_fontinfo fonts[2];
static unsigned char *font_data[2];
static lua_State *L;
static int runtime_error;
static volatile sig_atomic_t stopping;
static void interrupted(int sig) { (void)sig; stopping=1; }
static double monotime(void) {
#ifdef _WIN32
 return (double)clock()/CLOCKS_PER_SEC;
#else
 struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9;
#endif
}
static int host_time(lua_State *s) { lua_pushnumber(s,monotime());return 1; }
static int number(lua_State *s,int i) { return (int)floor(luaL_checknumber(s,i)+0.5); }
static void blend(int x,int y,int gray,int alpha) {
 if(x>=0 && x<WIDTH && y>=0 && y<HEIGHT) {
  unsigned char *p=&pixels[y*WIDTH+x];*p=(unsigned char)((gray*alpha+*p*(255-alpha))/255);
 }
}
static int host_rect(lua_State *s) {
 int x=number(s,1),y=number(s,2),w=number(s,3),h=number(s,4),gray=number(s,5);
 for(int j=y<0?0:y;j<y+h && j<HEIGHT;j++)
  for(int i=x<0?0:x;i<x+w && i<WIDTH;i++) pixels[j*WIDTH+i]=(unsigned char)gray;
 return 0;
}
/* Small bounded LRU caches retain decoded pixels across paints. */
#define SPRITE_SLOTS 32
#define SPRITE_BYTES (4*1024*1024)
#define GLYPH_SLOTS 512
typedef struct { unsigned char *key,*data;size_t length,bytes;int w,h;unsigned long age; } Sprite;
typedef struct { unsigned char *data;int code,size,bold,w,h,x,y,advance;unsigned long age; } Glyph;
static Sprite sprites[SPRITE_SLOTS];static Glyph glyphs[GLYPH_SLOTS];
static unsigned long cache_clock,sprite_decodes,glyph_rasters;static size_t sprite_bytes;
static void free_sprite(Sprite *p) { sprite_bytes-=p->bytes;free(p->key);stbi_image_free(p->data);memset(p,0,sizeof(*p)); }
static Sprite *oldest_sprite(void) { Sprite *p=&sprites[0];for(int i=1;i<SPRITE_SLOTS;i++)if(sprites[i].age<p->age)p=&sprites[i];return p; }
static int host_image(lua_State *s) {
 size_t length;const unsigned char *png=(const unsigned char*)luaL_checklstring(s,1,&length);
 int x=number(s,2),y=number(s,3),w=number(s,4),h=number(s,5),iw,ih,n;
 if(length>1048576)return luaL_error(s,"Sprite is too large");
 Sprite *p=NULL;
 for(int i=0;i<SPRITE_SLOTS;i++)if(sprites[i].key && sprites[i].length==length && !memcmp(sprites[i].key,png,length)){p=&sprites[i];break;}
 if(!p) {
  if(!stbi_info_from_memory(png,(int)length,&iw,&ih,&n) || iw<1 || ih<1 || iw>512 || ih>512)return luaL_error(s,"Invalid sprite dimensions");
  size_t bytes=length+(size_t)iw*ih*2;
  while(sprite_bytes+bytes>SPRITE_BYTES){Sprite *old=NULL;for(int i=0;i<SPRITE_SLOTS;i++)if(sprites[i].key && (!old || sprites[i].age<old->age))old=&sprites[i];if(!old)break;free_sprite(old);}
  p=oldest_sprite();free_sprite(p);
  p->key=malloc(length);p->data=stbi_load_from_memory(png,(int)length,&iw,&ih,&n,2);
  if(!p->key || !p->data){free(p->key);stbi_image_free(p->data);memset(p,0,sizeof(*p));return luaL_error(s,"Cannot decode packed sprite");}
  memcpy(p->key,png,length);p->length=length;p->w=iw;p->h=ih;p->bytes=bytes;sprite_bytes+=bytes;sprite_decodes++;
 }
 p->age=++cache_clock;
 if(w>0 && h>0 && w<=4000 && h<=4000)for(int j=0;j<h;j++)for(int i=0;i<w;i++) {
  int k=((j*p->h/h)*p->w+i*p->w/w)*2;blend(x+i,y+j,p->data[k],p->data[k+1]);
 }
 return 0;
}
static int utf8_next(const unsigned char **input) {
 const unsigned char *p=*input;int a=*p++,n,cp;
 if(a<128){*input=p;return a;}
 if(a>=194 && a<=223){n=1;cp=a-192;}
 else if(a>=224 && a<=239){n=2;cp=a-224;}
 else if(a>=240 && a<=244){n=3;cp=a-240;}
 else { *input=p;return 0xfffd; }
 for(int i=0;i<n;i++){if(*p<128 || *p>191){*input=p;return 0xfffd;}cp=cp*64+(*p++-128);}
 *input=p;
 if((n==1 && cp<128)||(n==2 && cp<2048)||(n==3 && cp<65536)||cp>0x10ffff||(cp>=0xd800 && cp<=0xdfff))return 0xfffd;
 return cp;
}
static Glyph *glyph(int code,int size,int bold) {
 Glyph *old=&glyphs[0];
 for(int i=0;i<GLYPH_SLOTS;i++) {
  Glyph *g=&glyphs[i];if(g->age && g->code==code && g->size==size && g->bold==bold){g->age=++cache_clock;return g;}
  if(g->age<old->age)old=g;
 }
 stbtt_FreeBitmap(old->data,NULL);memset(old,0,sizeof(*old));
 stbtt_fontinfo *font=&fonts[bold];float scale=stbtt_ScaleForMappingEmToPixels(font,(float)size);
 int advance,lsb;stbtt_GetCodepointHMetrics(font,code,&advance,&lsb);
 old->data=stbtt_GetCodepointBitmap(font,0,scale,code,&old->w,&old->h,&old->x,&old->y);
 old->advance=(int)roundf(advance*scale*64);old->size=size;old->bold=bold;old->code=code;old->age=++cache_clock;glyph_rasters++;return old;
}
static int text(lua_State *s,int paint) {
 const unsigned char *str=(const unsigned char*)luaL_checkstring(s,1);
 int x=paint?number(s,2):0,y=paint?number(s,3):0;
 int size=number(s,paint?4:2),bold=lua_toboolean(s,paint?5:3)?1:0;
 int maxw=(int)luaL_optnumber(s,paint?6:4,100000);
 if(size<1 || size>96)return luaL_error(s,"Invalid font size");
 float cursor=0;stbtt_fontinfo *font=&fonts[bold];float scale=stbtt_ScaleForMappingEmToPixels(font,(float)size);
 while(*str) {
  int c=utf8_next(&str);if(!stbtt_FindGlyphIndex(font,c))c=0xfffd;
  Glyph *g=glyph(c,size,bold);float advance=g->advance/64.0f;
  if(cursor+advance>maxw)break;
  if(paint && g->data)for(int j=0;j<g->h;j++)for(int k=0;k<g->w;k++)blend(x+(int)roundf(cursor)+g->x+k,y+size+g->y+j,0,g->data[j*g->w+k]);
  cursor+=advance;
  if(*str){const unsigned char *next=str;cursor+=stbtt_GetCodepointKernAdvance(font,c,utf8_next(&next))*scale;}
 }
 lua_pushinteger(s,(int)roundf(cursor));return 1;
}
static unsigned char stage_pixels[WIDTH*HEIGHT];static int stage_x,stage_y,stage_w,stage_h;
static int host_stage_save(lua_State *s) {
 stage_x=number(s,1);stage_y=number(s,2);stage_w=number(s,3);stage_h=number(s,4);
 if(stage_x<0 || stage_y<0 || stage_x+stage_w>WIDTH || stage_y+stage_h>HEIGHT)return luaL_error(s,"Invalid stage");
 for(int y=stage_y;y<stage_y+stage_h;y++)memcpy(stage_pixels+y*WIDTH+stage_x,pixels+y*WIDTH+stage_x,(size_t)stage_w);
 return 0;
}
static int host_stage_restore(lua_State *s) {
 (void)s;for(int y=stage_y;y<stage_y+stage_h;y++)memcpy(pixels+y*WIDTH+stage_x,stage_pixels+y*WIDTH+stage_x,(size_t)stage_w);return 0;
}
static int host_cache_stats(lua_State *s) {
 lua_pushinteger(s,(lua_Integer)sprite_decodes);lua_pushinteger(s,(lua_Integer)glyph_rasters);lua_pushinteger(s,(lua_Integer)sprite_bytes);return 3;
}
static int host_text(lua_State *s) { return text(s,1); }
static int host_text_width(lua_State *s) { return text(s,0); }
static int host_sync_file(lua_State *s) {
#ifndef _WIN32
 luaL_Stream *stream=luaL_checkudata(s,1,LUA_FILEHANDLE);
 if(!stream->f || fsync(fileno(stream->f))<0) return luaL_error(s,"fsync failed");
#endif
 return 0;
}
static int host_sync_directory(lua_State *s) {
#ifndef _WIN32
 char path[4096];const char *file=luaL_checkstring(s,1);
 if(strlen(file)>=sizeof(path))return luaL_error(s,"Save path too long");
 strcpy(path,file);char *slash=strrchr(path,'/');if(slash)*slash=0;else strcpy(path,".");
 int fd=open(path,O_RDONLY|O_DIRECTORY);
 if(fd<0)return luaL_error(s,"Cannot open save directory");
 int rc=fsync(fd);close(fd);if(rc<0)return luaL_error(s,"Directory sync failed");
#else
 (void)s;
#endif
 return 0;
}
static int host_fs(lua_State *s) {
 const char *op=luaL_checkstring(s,1),*path=luaL_checkstring(s,2);
 if(!strcmp(op,"pid")) {
#ifdef _WIN32
  lua_pushinteger(s,GetCurrentProcessId());
#else
  lua_pushinteger(s,getpid());
#endif
  return 1;
 }
 if(!strcmp(op,"mode")) {
#ifdef _WIN32
  if(!strncmp(path,"/proc/",6)) {
   DWORD pid=(DWORD)strtoul(path+6,NULL,10);
   HANDLE process=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,FALSE,pid);
   DWORD status=0;int alive=process && GetExitCodeProcess(process,&status) && status==STILL_ACTIVE;
   if(process)CloseHandle(process);if(!alive)return 0;lua_pushliteral(s,"directory");return 1;
  }
  DWORD a=GetFileAttributesA(path);if(a==INVALID_FILE_ATTRIBUTES)return 0;
  lua_pushstring(s,(a&FILE_ATTRIBUTE_REPARSE_POINT)?"link":(a&FILE_ATTRIBUTE_DIRECTORY)?"directory":"file");
#else
  struct stat st;if(lstat(path,&st)<0)return 0;
  lua_pushstring(s,S_ISLNK(st.st_mode)?"link":S_ISDIR(st.st_mode)?"directory":S_ISREG(st.st_mode)?"file":"other");
#endif
  return 1;
 }
 if(!strcmp(op,"size")) {
  struct stat st;if(stat(path,&st)<0)return 0;lua_pushnumber(s,(lua_Number)st.st_size);return 1;
 }
 if(!strcmp(op,"mtime")) {
  struct stat st;if(stat(path,&st)<0)return 0;lua_pushnumber(s,(lua_Number)st.st_mtime);return 1;
 }
 int result=0;
#ifdef _WIN32
 if(!strcmp(op,"mkdir"))result=CreateDirectoryA(path,NULL);
 else if(!strcmp(op,"rmdir"))result=RemoveDirectoryA(path);
#else
 if(!strcmp(op,"mkdir"))result=mkdir(path,0700)==0;
 else if(!strcmp(op,"rmdir"))result=rmdir(path)==0;
#endif
 lua_pushboolean(s,result);return 1;
}
static int host_listdir(lua_State *s) {
 const char *path=luaL_checkstring(s,1);int count=0;
#ifdef _WIN32
 char pattern[4096];if(snprintf(pattern,sizeof(pattern),"%s/*",path)>=(int)sizeof(pattern))return 0;
 WIN32_FIND_DATAA entry;HANDLE dir=FindFirstFileA(pattern,&entry);
 if(dir==INVALID_HANDLE_VALUE)return 0;lua_newtable(s);
 do {const char *name=entry.cFileName;
  if(strcmp(name,".") && strcmp(name,"..")){lua_pushstring(s,name);lua_rawseti(s,-2,++count);}
  if(count>20000){FindClose(dir);lua_pop(s,1);return 0;}
 } while(FindNextFileA(dir,&entry));FindClose(dir);
#else
 DIR *dir=opendir(path);if(!dir)return 0;lua_newtable(s);struct dirent *entry;
 while((entry=readdir(dir))) {const char *name=entry->d_name;
  if(strcmp(name,".") && strcmp(name,"..")){lua_pushstring(s,name);lua_rawseti(s,-2,++count);}
  if(count>20000){closedir(dir);lua_pop(s,1);return 0;}
 }closedir(dir);
#endif
 return 1;
}
#ifdef _WIN32
static int host_rename(lua_State *s) {
 if(MoveFileExA(luaL_checkstring(s,1),luaL_checkstring(s,2),MOVEFILE_REPLACE_EXISTING)) {lua_pushboolean(s,1);return 1;}
 lua_pushnil(s);lua_pushliteral(s,"Rename failed");return 2;
}
#endif
static int call(const char *fn,int args,int results) {
 lua_getglobal(L,fn);if(args)lua_insert(L,-args-1);
 if(lua_pcall(L,args,results,0)!=LUA_OK) { fprintf(stderr,"%s: %s\n",fn,lua_tostring(L,-1));lua_pop(L,1);runtime_error=1;stopping=1;return 0; }
 return 1;
}
static int load_font(int index,const char *path) {
 FILE *f=fopen(path,"rb");if(!f)return 0;
 fseek(f,0,SEEK_END);long n=ftell(f);rewind(f);
 if(n<1 || n>2000000){fclose(f);return 0;}
 font_data[index]=malloc((size_t)n);if(!font_data[index]){fclose(f);return 0;}
 int ok=fread(font_data[index],1,(size_t)n,f)==(size_t)n;fclose(f);
 return ok && stbtt_InitFont(&fonts[index],font_data[index],0);
}
#ifndef HEADLESS
static int fb=-1,input=-1,watchfd=-1,lockfd=-1;
static pid_t watcher=-1;
static FBInkConfig config={.is_quiet=true,.ignore_alpha=true,.wfm_mode=WFM_AUTO};
static FBInkState screen;
static struct input_absinfo ax,ay;
static int code_x,code_y,display_w,display_h,offset_x,offset_y;
static unsigned char *output;
static int find_touch(void) {
 for(int i=0;i<32;i++) {
  char path[64];snprintf(path,sizeof(path),"/dev/input/event%d",i);int fd=open(path,O_RDONLY|O_NONBLOCK|O_CLOEXEC);if(fd<0)continue;
  int x=ABS_MT_POSITION_X,y=ABS_MT_POSITION_Y;
  if(ioctl(fd,EVIOCGABS(x),&ax)<0 || ioctl(fd,EVIOCGABS(y),&ay)<0){x=ABS_X;y=ABS_Y;}
  if(ioctl(fd,EVIOCGABS(x),&ax)==0 && ioctl(fd,EVIOCGABS(y),&ay)==0 && ax.maximum>ax.minimum && ay.maximum>ay.minimum) {
   if(ioctl(fd,EVIOCGRAB,1)==0) {code_x=x;code_y=y;return fd;}
  }
  close(fd);
 }
 return -1;
}
static int watch_sleep(void) {
 int p[2];if(pipe(p)<0)return 0;
 watcher=fork();
 if(watcher==0){close(p[0]);dup2(p[1],STDOUT_FILENO);close(p[1]);execlp("lipc-wait-event","lipc-wait-event","-m","com.lab126.powerd","goingToScreenSaver",(char*)NULL);_exit(127);}
 close(p[1]);if(watcher<0){close(p[0]);return 0;}watchfd=p[0];return 1;
}
static int present(int flashing,int rx,int ry,int rw,int rh) {
 int x0=offset_x+rx*display_w/WIDTH,y0=offset_y+ry*display_h/HEIGHT;
 int x1=offset_x+(int)ceil((rx+rw)*display_w/(double)WIDTH),y1=offset_y+(int)ceil((ry+rh)*display_h/(double)HEIGHT);
 if(rx==0 && ry==0 && rw==WIDTH && rh==HEIGHT){x0=0;y0=0;x1=screen.screen_width;y1=screen.screen_height;}
 int w=x1-x0,h=y1-y0;
 if(w<=0 || h<=0 || x0<0 || y0<0 || x1>(int)screen.screen_width || y1>(int)screen.screen_height)return -1;
 for(int y=0;y<h;y++)for(int x=0;x<w;x++) {
  int px=x+x0-offset_x,py=y+y0-offset_y;
  output[y*w+x]=(px<0 || py<0 || px>=display_w || py>=display_h)?255:pixels[(py*HEIGHT/display_h)*WIDTH+px*WIDTH/display_w];
 }
 config.no_refresh=true;
 int rc=fbink_print_raw_data(fb,output,w,h,(size_t)w*h,(short)x0,(short)y0,&config);
 config.no_refresh=false;config.is_flashing=flashing;
 if(rc<0)return rc;
 return fbink_refresh(fb,(uint32_t)y0,(uint32_t)x0,(uint32_t)w,(uint32_t)h,&config);
}
static int paint_screen(void) {
 if(!call("app_paint",0,5))return 0;
 int flash=lua_toboolean(L,-5),x=(int)lua_tointeger(L,-4),y=(int)lua_tointeger(L,-3),w=(int)lua_tointeger(L,-2),h=(int)lua_tointeger(L,-1);lua_pop(L,5);
 return present(flash,x,y,w,h)>=0;
}
static void cleanup(void) {
 if(input>=0){ioctl(input,EVIOCGRAB,0);close(input);}
 if(watcher>0){kill(watcher,SIGTERM);waitpid(watcher,NULL,0);}
 if(watchfd>=0)close(watchfd);
 if(fb>=0)fbink_close(fb);
 if(lockfd>=0)close(lockfd);
 free(output);
}
#endif
int main(int argc,char **argv) {
 int result=1;const char *mode=argc>1 && !strcmp(argv[1],"--suspend")?"suspend":argc>1 && !strcmp(argv[1],"--resume")?"resume":"normal";
 int background=strcmp(mode,"normal")!=0;
 signal(SIGINT,interrupted);signal(SIGTERM,interrupted);
#ifndef HEADLESS
 signal(SIGHUP,interrupted);signal(SIGUSR1,interrupted);atexit(cleanup);
 if(!background) {
 lockfd=open("data/pokepal.lock",O_CREAT|O_RDWR,0600);
 if(lockfd<0 || flock(lockfd,LOCK_EX|LOCK_NB)<0){fprintf(stderr,"PokePal is already open or data is not writable.\n");return 1;}
 fb=fbink_open();if(fb<0 || fbink_init(fb,&config)<0){fprintf(stderr,"Cannot open Kindle screen.\n");return 1;}
 fbink_get_state(&config,&screen);
 if(screen.screen_width<300 || screen.screen_height<400 || screen.screen_width>3000 || screen.screen_height>4000){fprintf(stderr,"Unsupported screen size.\n");return 1;}
 double scale=fmin(screen.screen_width/(double)WIDTH,screen.screen_height/(double)HEIGHT);
 display_w=(int)(WIDTH*scale);display_h=(int)(HEIGHT*scale);
 offset_x=(screen.screen_width-display_w)/2;offset_y=(screen.screen_height-display_h)/2;
 output=malloc((size_t)screen.screen_width*screen.screen_height);if(!output)return 1;
 input=find_touch();if(input<0){fprintf(stderr,"No available touchscreen.\n");return 1;}
 if(!watch_sleep()){fprintf(stderr,"Cannot start sleep watcher.\n");return 1;}
 }
#endif
 if(!background && (!load_font(0,"fonts/DejaVuSans.ttf") || !load_font(1,"fonts/DejaVuSans-Bold.ttf"))){fprintf(stderr,"Missing fonts.\n");return 1;}
 L=luaL_newstate();if(!L)return 1;luaL_openlibs(L);
 lua_pushstring(L,mode);lua_setglobal(L,"host_mode");
#ifdef _WIN32
 lua_getglobal(L,"os");lua_pushcfunction(L,host_rename);lua_setfield(L,-2,"rename");lua_pop(L,1);
#endif
 const luaL_Reg functions[]={{"host_stage_save",host_stage_save},{"host_stage_restore",host_stage_restore},{"host_cache_stats",host_cache_stats},{"host_rect",host_rect},{"host_image",host_image},{"host_text",host_text},{"host_text_width",host_text_width},{"host_time",host_time},{"host_sync_file",host_sync_file},{"host_sync_directory",host_sync_directory},{"host_fs",host_fs},{"host_listdir",host_listdir},{NULL,NULL}};
 for(const luaL_Reg *f=functions;f->name;f++){lua_pushcfunction(L,f->func);lua_setglobal(L,f->name);}
 if(luaL_dofile(L,"runtime.lua")!=LUA_OK){fprintf(stderr,"%s\n",lua_tostring(L,-1));goto done;}
 if(background){result=0;goto done;}
#ifdef HEADLESS
 if(argc>1 && luaL_dofile(L,argv[1])!=LUA_OK){fprintf(stderr,"%s\n",lua_tostring(L,-1));goto done;}
 if(!call("app_paint",0,1))goto done;lua_pop(L,1);
 FILE *f=fopen(argc>2?argv[2]:"preview.pgm","wb");if(!f)goto done;
 fprintf(f,"P5\n600 800\n255\n");fwrite(pixels,1,sizeof(pixels),f);fclose(f);result=0;
#else
 (void)argc;(void)argv;
 int x=ax.minimum,y=ay.minimum,down=0,was_down=0,slot=0,dropped=0;
 if(!paint_screen())goto done;
 while(!stopping) {
  if(!call("app_delay",0,1))break;int delay=(int)lua_tointeger(L,-1);lua_pop(L,1);
  struct pollfd p[2]={{input,POLLIN,0},{watchfd,POLLIN,0}};
  int n=poll(p,2,delay);
  if(n<0){if(errno==EINTR)continue;break;}
  if(p[1].revents){char b[256];ssize_t count=read(watchfd,b,sizeof(b));
   if(count>0){if(!call("app_suspend",0,0))break;result=10;}
   else fprintf(stderr,"Power event listener ended; closing PokePal.\n");
   break;
  }
  if(p[0].revents&(POLLERR|POLLHUP|POLLNVAL))break;
  if(p[0].revents&POLLIN) {
   struct input_event ev;
   while(read(input,&ev,sizeof(ev))==sizeof(ev)) {
    if(ev.type==EV_SYN && ev.code==SYN_DROPPED){dropped=1;down=was_down=0;continue;}
    if(dropped){if(ev.type==EV_SYN && ev.code==SYN_REPORT)dropped=0;continue;}
    if(ev.type==EV_ABS && ev.code==ABS_MT_SLOT)slot=ev.value;
    if(ev.type==EV_ABS && slot==0) {
     if(ev.code==code_x)x=ev.value;
     else if(ev.code==code_y)y=ev.value;
     else if(ev.code==ABS_MT_TRACKING_ID)down=ev.value>=0;
     else if(ev.code==ABS_MT_PRESSURE || ev.code==ABS_PRESSURE)down=ev.value>0;
    }
    if(ev.type==EV_KEY && ev.code==BTN_TOUCH)down=ev.value>0;
    if(ev.type==EV_SYN && ev.code==SYN_REPORT) {
     if(was_down && !down) {
      double tx=(x-ax.minimum)/(double)(ax.maximum-ax.minimum),ty=(y-ay.minimum)/(double)(ay.maximum-ay.minimum);
      if(screen.touch_swap_axes){double t=tx;tx=ty;ty=t;}
      if(screen.touch_mirror_x)tx=1-tx;if(screen.touch_mirror_y)ty=1-ty;
      lua_pushnumber(L,(tx*(screen.screen_width-1)-offset_x)*WIDTH/display_w);
      lua_pushnumber(L,(ty*(screen.screen_height-1)-offset_y)*HEIGHT/display_h);
      if(!call("app_tap",2,0))break;
     }
     was_down=down;
    }
   }
  }
  if(!call("app_tick",0,2))break;
  int dirty=lua_toboolean(L,-2),closed=lua_toboolean(L,-1);lua_pop(L,2);
  if(closed){result=0;break;}
  if(dirty && !paint_screen())break;
 }
 if(stopping && !runtime_error)result=0;
#endif
 if(!call("app_close",0,0))result=1;
done:
 lua_close(L);for(int i=0;i<SPRITE_SLOTS;i++)free_sprite(&sprites[i]);for(int i=0;i<GLYPH_SLOTS;i++)stbtt_FreeBitmap(glyphs[i].data,NULL);free(font_data[0]);free(font_data[1]);return result;
}
