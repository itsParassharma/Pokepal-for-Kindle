import sys,pathlib,os,tempfile,json,io,time,datetime
from lupa.luajit21 import LuaRuntime
from PIL import Image,ImageDraw,ImageFont
REPO=pathlib.Path(__file__).resolve().parents[1]
ROOT=REPO/'pokepal.koplugin'
OUT=REPO/'tests'/'rendered';OUT.mkdir(exist_ok=True)
lua=LuaRuntime(unpack_returned_tuples=True)
g=lua.globals();g.BASE=ROOT.as_posix()
temp=tempfile.TemporaryDirectory();g.TESTDIR=pathlib.Path(temp.name).resolve().as_posix()
# Windows CRT rename does not replace files; emulate the Kindle's POSIX rename.
def rename(a,b):
 try:os.replace(a,b);return True
 except OSError as ex:return None,str(ex)
g.host_rename=rename;lua.execute('os.rename=host_rename')
def fs(op,path):
 p=pathlib.Path(path)
 if op=='pid':return os.getpid()
 if op=='mode':
  if path==f'/proc/{os.getpid()}':return 'directory'
  return 'link' if p.is_symlink() else 'directory' if p.is_dir() else 'file' if p.is_file() else None
 if op=='mtime':return p.stat().st_mtime if p.exists() else None
 try:
  if op=='mkdir':p.mkdir()
  elif op=='rmdir':p.rmdir()
  else:return False
  return True
 except OSError:return False
def listdir(path):
 try:return lua.table_from(os.listdir(path))
 except OSError:return None
g.host_fs=fs;g.host_listdir=listdir
lua.execute((REPO/'tests'/'test_engine.lua').read_text())
lua.execute((REPO/'tests'/'test_gen3.lua').read_text())
lua.execute((REPO/'tests'/'test_reading.lua').read_text())
lua.execute((REPO/'tests'/'test_adventures.lua').read_text())
lua.execute((REPO/'tests'/'test_companion.lua').read_text())
lua.execute((REPO/'tests'/'test_backups.lua').read_text())
lua.execute((REPO/'tests'/'test_improvements.lua').read_text())
lua.execute((REPO/'tests'/'test_world.lua').read_text())
lua.execute((REPO/'tests'/'test_town.lua').read_text())

sprite_index=json.loads((ROOT/'assets/sprite-index.json').read_text())
def read_sprite(name):
 species,offset,length=sprite_index[name]
 with (ROOT/'assets'/f'{species:03d}.bin').open('rb') as stream:
  stream.seek(offset);data=stream.read(length)
 assert len(data)==length
 return Image.open(io.BytesIO(data))

canvas=None;draw=None;bounds=[];truncated=[];painted_text=[];painted_sprites=[];painted_text_boxes=[]
def font(size,bold=False):
 choices=(['C:/Windows/Fonts/arialbd.ttf','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'] if bold
          else ['C:/Windows/Fonts/arial.ttf','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'])
 if os.environ.get('POKEPAL_TEST_FONT_DIR'):
  path=pathlib.Path(os.environ['POKEPAL_TEST_FONT_DIR'])/('NotoSans-Bold.ttf' if bold else 'NotoSans-Regular.ttf')
  assert path.is_file(),f'Missing test font: {path}'
  choices.insert(0,str(path))
 for path in choices:
  if pathlib.Path(path).is_file():return ImageFont.truetype(path,int(size))
 return ImageFont.load_default(size=int(size))
def get_text(t,sz,bold,maxw):
 f=font(sz,bold);original=t
 maxw=maxw or 100000
 while draw.textlength(t,font=f)>maxw and t:
  t=t[:-1]
 if t!=original:
  truncated.append(original);t=t[:-2]+'...'
 return t,f
def text_size(t,sz,bold,maxw):
 t,f=get_text(t,sz,bold,maxw);return round(draw.textlength(t,font=f)),sum(f.getmetrics())
def render_text(t,x,y,sz,bold,maxw):
 painted_text.append(t)
 t,f=get_text(t,sz,bold,maxw)
 painted_text_boxes.append((t,x,y,round(draw.textlength(t,font=f)),sum(f.getmetrics()),sz))
 draw.text((round(x),round(y)),t,font=f,fill=0,anchor='la')
def rect(x,y,w,h,col):
 x,y,w,h=map(round,(x,y,w,h))
 if w and h:
  if x<0 or y<0 or x+w>canvas.width or y+h>canvas.height:bounds.append((x,y,w,h))
  draw.rectangle((x,y,x+w-1,y+h-1),fill=int(col))
classic_index=json.loads((ROOT/'assets/classic/index.json').read_text())
for name, (part, offset, length) in classic_index.items():
 with (ROOT/'assets/classic'/f'{part:03d}.bin').open('rb') as stream:
  stream.seek(offset);data=stream.read(length)
 assert len(data)==length, name
 img=Image.open(io.BytesIO(data));img.load()
 assert img.mode=='LA' and img.getchannel('A').getbbox(), name
 assert set(img.getchannel('L').tobytes()) <= {0,85,170,255}, name
for id in range(1,387):
 for pose in ('front','back'):
  assert f'{id}-{pose}.png' in classic_index
 for direction in ('down','up','left','right'):
  for step in (0,1):assert f'{id}-walk-{direction}-{step}.png' in classic_index
print(f'CLASSIC ART: all 386 front/back sprites, four walking directions and {len(classic_index)} packed images decode')

def image(path,x,y,w,h):
 if '/classic/' in path:
  name=pathlib.Path(path).name
  part,offset,length=classic_index[name]
  with (ROOT/'assets/classic'/f'{part:03d}.bin').open('rb') as f:
   f.seek(offset);img=Image.open(io.BytesIO(f.read(length)))
  img=img.convert('LA').resize((int(w),int(h)),Image.Resampling.NEAREST)
  canvas.paste(img.getchannel('L'),(round(x),round(y)),img.getchannel('A'))
  return
 painted_sprites.append(int(pathlib.Path(path).name.split('-')[0]))
 img=read_sprite(pathlib.Path(path).name).convert('LA').resize((int(w),int(h)),Image.Resampling.NEAREST)
 canvas.paste(img.getchannel('L'),(round(x),round(y)),img.getchannel('A'))
g.text_size=text_size;g.render_text=render_text;g.render_rect=rect;g.render_image=image
lua.execute(r'''
local W={}
function W:extend(o) o=o or {};setmetatable(o,self);self.__index=self;return o end
function W:new(o) o=self:extend(o);if o._init then o:_init() end;if o.init then o:init() end;return o end
local Input=W:extend{}
function Input:_init() self.key_events={};self.ges_events={} end
package.preload["ui/widget/container/inputcontainer"]=function() return Input end
package.preload["ui/widget/container/widgetcontainer"]=function() return W end
package.preload["ui/geometry"]=function() return W end
package.preload["ui/gesturerange"]=function() return W end
package.preload["ui/font"]=function()
 return {getFace=function(_,name,size) return {size=require('device').screen:scaleBySize(size)} end}
end
local T=W:extend{}
function T:getSize() local w,h=text_size(self.text,self.face.size,self.bold,self.max_width);return {w=w,h=h} end
function T:paintTo(bb,x,y) render_text(self.text,x,y,self.face.size,self.bold,self.max_width) end
function T:free() end
package.preload["ui/widget/textwidget"]=function() return T end
local I=W:extend{}
function I:paintTo(bb,x,y) assert(not self.freed);render_image(self.file or self.image.file,x,y,self.width,self.height) end
function I:free() self.freed=true end
package.preload["ui/widget/imagewidget"]=function() return I end
package.preload["ui/renderimage"]=function()
 local R={}
 local packed=dofile(BASE..'/assets/sprites.lua');local names={}
 for _,directory in ipairs({'assets','assets/classic'}) do
  local pack=dofile(BASE..'/'..directory..'/sprites.lua')
  for name in pairs(pack.index) do names[pack.read(BASE..'/'..directory,name)]=BASE..'/'..directory..'/'..name end
 end
 function R:renderImageData(data)
  local file=assert(names[data]);local raw={file=file,getWidth=function() return 96 end,getHeight=function() return 96 end,scale=function(self,w,h) return {file=self.file,free=function() end} end,free=function() end}
  return raw
 end
 return R
end
package.preload["ffi/blitbuffer"]=function() return {COLOR_WHITE=255,COLOR_BLACK=0,Color8=function(n) return n end} end
D={w=600,h=800}
package.preload["device"]=function()
 local screen={getWidth=function() return D.w end,getHeight=function() return D.h end}
 -- KOReader's Font:getFace calls this, including the user's DPI override.
 -- koreader-base/ffi/framebuffer.lua, scaleBySize (3244ca3f7c36).
 function screen:scaleBySize(px)
  local scale=math.min(self:getWidth(),self:getHeight())/600
  return math.ceil(px*(scale+(D.dpi and D.dpi/160 or scale))/2)
 end
 return {screen_saver_mode=false,screen=screen}
end
U={queue={},dirty={},show_count=0}
function U:scheduleIn(seconds,f) self.queue[#self.queue+1]={seconds=seconds,f=f} end
function U:unschedule(f) for i=#self.queue,1,-1 do if self.queue[i].f==f then table.remove(self.queue,i) end end end
function U:setDirty(widget,mode,region) self.dirty[#self.dirty+1]={mode=mode,region=region} end
function U:show(v) self.show_count=self.show_count+1 end
function U:close(v) v:onCloseWidget() end
function U:drain() local n=0;while #self.queue>0 do n=n+1;assert(n<=100,'unbounded animation or walking');local t=table.remove(self.queue,1);t.f() end;return n end
package.preload["ui/uimanager"]=function() return U end
package.preload["datastorage"]=function() return {getSettingsDir=function() return TESTDIR end} end
package.preload["ffi/util"]=function() return {} end
package.preload["ui/widget/infomessage"]=function() return W end
package.preload["dispatcher"]=function() return {registerAction=function() end} end
G_reader_settings={isTrue=function() return true end}
bb={paintRect=function(_,...) render_rect(...) end}
E=dofile(BASE.."/engine.lua");V=dofile(BASE.."/view.lua")
Device=require("device")
function newView(id)
 local s=E.new(os.time());if id then E.act(s,'choose',id,os.time()) end
 local owner={save=function(self) self.saved=(self.saved or 0)+1;return true end}
 local v=V:new{engine=E,state=s,owner=owner,path=BASE};owner.pet_view=v;return v
end
function tapButton(view,action,arg)
 view:paintTo(bb,0,0)
 for _,button in ipairs(view.buttons) do
  if button.action==action and button.arg==arg then
   local r=view:region(button.x+4,button.y+4,0,0)
   view:onTap(nil,{pos={x=r.x,y=r.y}});return button
  end
 end
 error('Button not found: '..action..' '..tostring(arg))
end
''')
def start(w=600,h=800):
 global canvas,draw,bounds,truncated,painted_text,painted_sprites,painted_text_boxes
 canvas=Image.new('L',(w,h),255);draw=ImageDraw.Draw(canvas);bounds=[];truncated=[];painted_text=[];painted_sprites=[];painted_text_boxes=[]
 g.D.w=w;g.D.h=h
start()
lua.execute((REPO/'tests'/'test_reader_lifecycle.lua').read_text())
lua.execute((REPO/'tests'/'test_koreader_ui.lua').read_text())
lua.execute(r'''
local checks=0
local function check(name,fn) fn();checks=checks+1;print('PASS '..name) end
check('idle creates no animation timer',function() v=newView(25);assert(#U.queue==0) end)
check('gentle animation has finite regional refreshes',function()
 v.state.animation='gentle';v:animate('play');assert(#U.queue==1);assert(U:drain()==4);assert(v.frame==1 and not v.animating)
 for _,d in ipairs(U.dirty) do assert(d.region and d.region.w<D.w and d.region.h<D.h) end
end)
check('eco animation is shorter',function() v.state.animation='eco';v:animate('feed');assert(U:drain()==2) end)
check('eco uses both frames of a two-frame sleep pose',function()
 v.state.resting=true;v:animate('rest');assert(v.sequence[1]==1 and v.sequence[2]==2)
 U:drain();v.state.resting=false
end)
check('animation off queues nothing',function() v.state.animation='off';v:animate('play');assert(#U.queue==0) end)
check('navigation cancels callbacks',function() v.state.animation='gentle';v:animate('play');v:go('journal');assert(#U.queue==0) end)
check('navigation refreshes and saves elapsed trips and weekly goals once',function()
 local real_time=os.time;local clock=1800000000;os.time=function() return clock end
 local v=newView(4);dofile(BASE..'/reading.lua').init(v.state)
 E.act(v.state,'trip',1,clock);E.act(v.state,'goal',3600,clock)
 v.state.week.seconds=120;local week=v.state.week.start
 clock=clock+900;v:go('expeditions')
 assert(v.state.finds==2 and v.state.berries==7 and v.state.xp==3 and v.owner.saved==1)
 v:go('home');assert(v.state.finds==2 and v.owner.saved==1)
 clock=week+8*86400;v:go('weekly')
 assert(v.state.week.seconds==0 and v.state.week.start>week and v.owner.saved==2)
 local last=v.state.last;clock=clock-86400;v:go('home');assert(v.state.last==last and v.owner.saved==2)
 v:leave();os.time=real_time
end)
check('suspend stops callbacks and saves once',function()
 v:animate('train');local before=v.owner.saved or 0;v:onSuspend();v:onSuspend()
 assert(#U.queue==0 and v.suspended and v.owner.saved==before+1)
 v:onResume();assert(not v.suspended and #U.queue==0)
end)
check('screen saver blocks animation and late callbacks',function()
 v=newView(4);v.state.animation='gentle';v:animate('ambient');assert(#U.queue==1)
 Device.screen_saver_mode=true;local late=U.queue[1].f;local dirty=#U.dirty
 late();assert(#U.queue==0 and #U.dirty==dirty and not v.animating)
 v:animate('rest');assert(#U.queue==0);Device.screen_saver_mode=false
end)
check('exit cancels callbacks and detaches view',function()
 v:animate('play');v:leave();assert(#U.queue==0 and v.closed and not v.owner.pet_view)
end)
check('touch controls dispatch at scaled coordinates',function()
 for _,size in ipairs({{600,800},{1072,1448},{800,600}}) do
  D.w=size[1];D.h=size[2];v=newView(25);v.state.animation='off'
  tapButton(v,'feed',nil);assert(v.state.berries==5 and v.screen=='home');v:leave()
 end
 D.w=600;D.h=800
end)
check('home keeps the original pet controls and reading stays under More',function()
 v=newView(4);v:paintTo(bb,0,0);local count=0
 local actions={}
 for _,b in ipairs(v.buttons) do
  if b.y>=596 then count=count+1;actions[b.action=='nav' and b.arg or b.action]=true end
 end
 assert(count==9)
 for _,action in ipairs({'feed','startplay','train','rest','explore','journal','clean','gift','more'}) do assert(actions[action],action) end
 assert(not actions.reading and not actions.egg)
 for _,screen in ipairs({'train','profile','explore','journal','more'}) do
  tapButton(v,'nav',screen);assert(v.screen==screen);tapButton(v,'nav','home')
 end
 v:go('more');v:paintTo(bb,0,0);actions={}
 for _,b in ipairs(v.buttons) do actions[b.action=='nav' and b.arg or b.action]=true end
 for _,action in ipairs({'preferences','memories','help','reading'}) do assert(actions[action],action) end
 tapButton(v,'nav','reading');tapButton(v,'nav','egg');assert(v.screen=='egg')
 v:go('home');v.state.resting=true;tapButton(v,'startplay',nil)
 assert(v.screen=='home' and v.message:find('Wake up',1,true));v:leave()
end)
check('an away partner stays away when the scene or berry basket is tapped',function()
 v=newView(4);dofile(BASE..'/reading.lua').init(v.state);v:act('readingtrip',1);U:drain()
 v:paintTo(bb,0,0);v:onTap(nil,{pos={x=300,y=300}})
 assert(v.screen=='expeditions' and #U.queue==0)
 v:go('home');v:animate('hello');assert(not v.animating and #U.queue==0)
 v.state.gift=os.time()-86400;v:go('home');tapButton(v,'gift',nil)
 assert(v.state.berries==11 and not v.animating and #U.queue==0)
 v:go('entry');v.detail_id=4;v.preview_pose='idle';v:animate('preview')
 assert(U:drain()==2);v:leave()
end)
check('save failures persist across navigation and clear after a successful retry',function()
 local P=dofile(BASE..'/main.lua');local reader=P:new{path=BASE,ui={menu={registerToMainMenu=function() end}}}
 reader.savepath=TESTDIR..'/ui-save-error.dat';reader.counterpath=reader.savepath..'.reading';reader.backups.path=reader.savepath
 reader:openPet();reader:syncReading();reader.pet_view:stopAnimation();if reader.state.species==0 then reader.pet_view:act('choose',4) end
 local save=reader.storage.save;reader.storage.save=function() return nil,'Disk full' end
 reader.pet_view:go('more');tapButton(reader.pet_view,'animation','off');assert(reader.save_error)
 reader.pet_view:go('home');reader.pet_view:onSuspend();reader.pet_view:onResume();assert(reader.save_error)
 reader.storage.save=save;assert(reader:save() and not reader.save_error);reader.pet_view:leave()
end)
check('starter browsing wraps and confirms every available partner',function()
 for index,id in ipairs(E.starters) do
  v=newView();local before=dofile(BASE..'/storage.lua').encode(v.state)
  tapButton(v,'starter',-1);assert(v.starter_index==#E.starters)
  tapButton(v,'starter',1);assert(v.starter_index==1)
  for i=2,index do tapButton(v,'starter',1) end
  assert(dofile(BASE..'/storage.lua').encode(v.state)==before and #U.queue==0 and not v.owner.saved)
  tapButton(v,'choose',id);assert(v.state.species==id and v.owner.saved==1)
  v:leave();assert(#U.queue==0)
 end
end)
check('Profile companion picker previews, cancels and switches without losing progress',function()
 local real_time=os.time;local now=1800000000;os.time=function() return now end
 local S=dofile(BASE..'/storage.lua');local v=newView(4)
 v.state.animation='off';v.state.xp=200;v.state.bond=42;v.state.berries=19
 E.act(v.state,'nickname','Ember',now);v.state.seen['150']=true
 v.journal_query='no match';v.journal_filter='favourites'
 local before=S.encode(v.state)
 v:go('profile');tapButton(v,'nav','companions');assert(v.screen=='companions')
 v:paintTo(bb,0,0);assert(v.journal_count==#E.starters+1 and v.page==1)
 tapButton(v,'entry',1);assert(v.screen=='entry' and v.detail_id==1)
 assert(tapButton(v,'favourite',1).disabled)
 v:onBack();assert(v.screen=='companions');v:onBack();assert(v.screen=='profile')
 assert(S.encode(v.state)==before and not v.owner.saved)
 tapButton(v,'nav','companions');tapButton(v,'page',1);assert(v.page==2)
 tapButton(v,'entry',158);tapButton(v,'nav','companions');assert(v.screen=='companions')
 tapButton(v,'entry',7);tapButton(v,'partner',7)
 assert(v.screen=='home' and v.state.species==7 and v.owner.saved==1)
 assert(v.state.xp==0 and v.state.bond==0 and v.state.berries==19)
 v.state=S.decode(S.encode(v.state),E);assert(v.state and v.state.species==7)
 v:go('profile');tapButton(v,'nav','companions');tapButton(v,'entry',4);tapButton(v,'partner',4)
 assert(v.state.xp==200 and v.state.bond==42 and E.displayName(v.state)=='Ember')
 v:leave();os.time=real_time
end)
check('all 386 are reachable from the welcome screen and Profile without unlocking',function()
 local real_time=os.time;local now=1800000000;os.time=function() return now end
 local S=dofile(BASE..'/storage.lua');local v=newView();v.state.animation='off'
 local before=S.encode(v.state)
 tapButton(v,'nav','allcompanions');assert(v.screen=='allcompanions')
 local found={}
 local pages=math.ceil(E.species_count/6)
 for page=1,pages do
  v:paintTo(bb,0,0);assert(v.journal_count==E.species_count and v.page==page)
  for _,b in ipairs(v.buttons) do
   if b.action=='entry' then assert(not found[b.arg]);found[b.arg]=true end
  end
  if page<pages then tapButton(v,'page',1) end
 end
 for id=1,E.species_count do assert(found[id],id) end
 assert(tapButton(v,'page',1).disabled and v.page==pages)
 tapButton(v,'entry',E.species_count);assert(v.screen=='entry')
 v:onBack();assert(v.screen=='allcompanions');v:onBack();assert(v.screen=='home')
 assert(S.encode(v.state)==before and not v.owner.saved)
 tapButton(v,'nav','allcompanions');tapButton(v,'entry',3);tapButton(v,'choose',3)
 assert(v.state.species==3 and v.state.seen['3'] and E.count(v.state.seen)==1 and v.owner.saved==1)
 v.state.xp=200;v.state.bond=42;E.act(v.state,'nickname','Leaf',now)
 v:go('profile');tapButton(v,'nav','companions');tapButton(v,'nav','allcompanions')
 tapButton(v,'entry',6);tapButton(v,'partner',6)
 assert(v.state.species==6 and v.state.xp==0 and E.count(v.state.seen)==2)
 v.state=S.decode(S.encode(v.state),E);assert(v.state and v.state.species==6)
 v:go('profile');tapButton(v,'nav','companions');tapButton(v,'entry',3);tapButton(v,'partner',3)
 assert(v.state.xp==200 and v.state.bond==42 and E.displayName(v.state)=='Leaf')
 v:leave();os.time=real_time
end)
check('companion confirmation explains blocked switches and respects save locks',function()
 local v=newView(4);v.state.animation='off';v:go('profile')
 tapButton(v,'nav','companions');tapButton(v,'entry',4)
 assert(tapButton(v,'partner',4).disabled)
 tapButton(v,'nav','companions');tapButton(v,'entry',7)
 v.state.resting=true;assert(tapButton(v,'partner',7).disabled and v.state.species==4)
 v.state.resting=false;E.act(v.state,'trip',1,os.time())
 assert(tapButton(v,'partner',7).disabled and v.state.species==4)
 v.state.trip=0;v.state.due=0;v.state.trail=nil;v.state.finds=nil;v.state.companion.journey=nil
 v.owner.reading_busy=true;tapButton(v,'partner',7);assert(v.state.species==4)
 v.owner.reading_busy=false;v.owner.backups={blocked=true}
 tapButton(v,'partner',7);assert(v.state.species==4)
 v.owner.backups=nil;v:leave()
end)
check('region tabs show every regional species and reset the page',function()
 local v=newView();v.state.animation='off';v:go('allcompanions')
 local ranges={{1,386},{1,151},{152,251},{252,386}}
 for region,range in ipairs(ranges) do
  tapButton(v,'chooserregion',region);assert(v.page==1)
  local found={};local count=range[2]-range[1]+1;local pages=math.ceil(count/6)
  for page=1,pages do
   v:paintTo(bb,0,0);assert(v.journal_count==count)
   for _,b in ipairs(v.buttons) do
    if b.action=='entry' then assert(b.arg>=range[1] and b.arg<=range[2] and not found[b.arg]);found[b.arg]=true end
   end
   if page<pages then tapButton(v,'page',1) end
  end
  assert(E.count(found)==count and tapButton(v,'page',1).disabled)
 end
 tapButton(v,'entry',386);tapButton(v,'choose',386);assert(v.state.species==386);v:leave()
end)
check('main plugin persists the picker until a partner is chosen',function()
 local P=dofile(BASE..'/main.lua')
 p=P:new{path=BASE,ui={menu={registerToMainMenu=function() end}}}
 local items={};p:addToMainMenu(items);assert(items.pokepal.callback)
 items.pokepal.callback();p:syncReading();assert(p.pet_view and p.state.species==0 and #U.queue==0);p.pet_view:leave()
 p:openPet();p:syncReading();assert(p.state.species==0 and #U.queue==0)
 for i=1,5 do tapButton(p.pet_view,'starter',1) end
 tapButton(p.pet_view,'choose',152);assert(p.state.species==152 and #U.queue==1)
 p.pet_view:act('feed');p.pet_view:leave()
 p:openPet();p:syncReading();assert(p.state.species==152 and p.state.berries==5 and #U.queue==1);p.pet_view:leave()
end)
check('existing Charmander save keeps progress and bypasses the picker',function()
 local S=dofile(BASE..'/storage.lua');local s=E.new(os.time())
 E.act(s,'choose',4,os.time());s.xp=200;s.bond=42;s.berries=9;s.animation='off'
 assert(S.save(p.savepath,s,E));p:openPet();p:syncReading()
 assert(p.state.species==4 and p.state.xp==200 and p.state.bond==42 and p.state.berries==9)
 assert(#U.queue==0);p.pet_view:leave()
end)
check('Profile gates and dispatches every split evolution',function()
 for _,parent in ipairs({44,61,79,133,236,265,290,366}) do
  for _,id in ipairs(E.evolutionChoices(parent)) do
   v=newView(parent);v.state.animation='off';v:go('profile')
   v.state.xp=E.species[parent][3]-1;v.state.bond=30
   assert(tapButton(v,'evolve',id).disabled and v.state.species==parent)
   v.state.xp=E.species[parent][3];v.state.bond=29
   assert(tapButton(v,'evolve',id).disabled and v.state.species==parent)
   v.state.bond=30;assert(not tapButton(v,'evolve',id).disabled)
   assert(v.state.species==id and v.state.seen[tostring(id)]);v:leave()
  end
 end
end)
check('care actions and training moves play the matching new poses',function()
 for _,id in ipairs({25,184,252,384,386}) do
  local poses={'attack','swing','double','charge'}
  for i,move in ipairs(E.moves({species=id})) do
   v=newView(id);v.state.animation='gentle';v.state.xp=1000;v.state.energy=100
   v:act('train',move.name);assert(v.animating and v:poseFor(v.effect)==poses[i])
   assert(U:drain()<=4);v:leave()
  end
  v=newView(id);v.state.animation='gentle';v.state.dirt=60
  v:act('clean');assert(v.animating and v:poseFor(v.effect)=='rotate');U:drain()
  v:animate('play');assert(v:poseFor(v.effect)=='hop');U:drain();v:leave()
 end
end)
check('all partners use bounded animations across actions',function()
 for id=1,E.species_count do
  v=newView(152);v.state.species=id;v.state.animation='gentle'
  for _,effect in ipairs({'hello','feed','play','train','evolve','rest','clean','explore'}) do
   v.state.resting=effect=='rest';v:animate(effect);assert(U:drain()<=4 and not v.animating)
  end
  v.state.animation='eco';v:animate('play');assert(U:drain()==2)
  v.state.animation='off';v:animate('play');assert(#U.queue==0);v:leave()
 end
end)
check('Charmander idle, sleep and attack use dedicated poses',function()
 v=newView(4);v.state.animation='gentle';v:animate('hello');assert(U:drain()==4 and #U.queue==0)
 v.state.resting=true;v:animate('rest');assert(U:drain()==2 and #U.queue==0)
 v.state.resting=false;v:animate('train');assert(U:drain()==4 and #U.queue==0)
end)
check('activity paging stays within saved history',function()
 v=newView(4)
 for i=1,24 do E.note(v.state,'Moment '..i,os.time()) end
 v:go('history');v:paintTo(bb,0,0)
 local pages=0;for _,b in ipairs(v.buttons) do if b.action=='page' and b.arg==1 then pages=pages+1;v:onTap(nil,{pos={x=b.x+4,y=b.y+4}});break end end
 assert(pages==1 and v.page==2)
end)
check('berry trail rewards a perfect path once',function()
 v=newView(4);v.state.animation='off';v:startPlay();assert(v.screen=='play' and #U.queue==0)
 v.play_phase='pick'
 for i=1,3 do v:pickBush(v.play_sequence[i]) end
 assert(v.state.xp==8 and v.state.energy==70 and v.screen=='home')
 v:pickBush(1);assert(v.state.xp==8)
end)
check('unfinished play and leaving give no reward',function()
 v=newView(4);v:startPlay();v:go('home');assert(v.state.xp==0)
end)
check('wrong answer still gives a kind participation reward',function()
 v=newView(4);v.state.animation='off';v:startPlay();v.play_phase='pick'
 v:pickBush(v.play_sequence[1]%3+1);assert(v.state.xp==5)
end)
check('evolution animation survives sleep without undoing evolution',function()
 v=newView(4);v.state.xp=300;v.state.bond=30;v:act('evolve');assert(v.state.species==5)
 v:onSuspend();assert(#U.queue==0 and v.state.species==5);v:onResume();assert(v.state.species==5)
end)
check('KOReader events persist reading time, exclude sleep and pet visits, and collect once',function()
 local real_time=os.time;local clock=real_time();os.time=function() return clock end
 local P=dofile(BASE..'/main.lua')
 local reader=P:new{path=BASE,ui={menu={registerToMainMenu=function() end}}}
 reader:openPet();reader:syncReading();local xp=reader.state.xp;reader.pet_view:leave()
 reader:onPageUpdate(1);reader:onReaderReady()
 for page=2,16 do clock=clock+60;reader:onPageUpdate(page) end
 reader:onSuspend();clock=clock+7200;reader:onResume();reader:onReadingResumed()
 reader:openPet();reader:syncReading();assert(reader.state.xp==xp+3)
 clock=clock+7200;reader:onPageUpdate(17)
 reader.pet_view:go('reading');tapButton(reader.pet_view,'reading',nil);assert(not reader.state.reading.enabled)
 tapButton(reader.pet_view,'reading',nil);assert(reader.state.reading.enabled)
 reader.pet_view:leave();reader:openPet();reader:syncReading();assert(reader.state.xp==xp+3)
 reader.pet_view:leave();clock=clock+60;reader:onCloseDocument();clock=clock+7200;reader:onClose()
 reader=P:new{path=BASE,ui={menu={registerToMainMenu=function() end}}}
 reader:openPet();reader:syncReading();assert(reader.state.xp==xp+3 and reader.state.reading.carry==60)
 reader.pet_view:leave();os.time=real_time
end)
check('failed KOReader counter promotion retains time for retry without duplicate credit',function()
 local P=dofile(BASE..'/main.lua');local reader=P:new{path=BASE,ui={menu={registerToMainMenu=function() end}}}
 local R=reader.reading;local before=assert(R.counter(reader.counterpath));reader.clock.pending=60
 local real_save=R.saveCounter;R.saveCounter=function() return nil,'disk full' end
 reader:flushReading();assert(reader.clock.pending==60 and reader.reading_error)
 R.saveCounter=real_save;reader:flushReading();assert(reader.clock.pending==0 and R.counter(reader.counterpath)==before+60)
 reader:flushReading();assert(R.counter(reader.counterpath)==before+60)
end)
check('reading trips and timer trips dispatch from the mode picker',function()
 for _,mode in ipairs({'reading','timed'}) do
  v=newView(4);dofile(BASE..'/reading.lua').init(v.state);v.state.animation='off';v:go('expeditions')
  tapButton(v,'tripmode',mode);tapButton(v,mode=='reading' and 'readingtrip' or 'trip',1)
  assert(v.state.trip==1 and (v.state.trail~=nil)==(mode=='reading'))
  v:go('expeditions');tapButton(v,'collect',nil);assert(v.state.trips==0)
  if mode=='reading' then E.readingReward(v.state,1800,os.time()) else v.state.due=os.time() end
  v:go('expeditions');tapButton(v,'nav','trailstory');tapButton(v,'trailchoice',1);tapButton(v,'collect',nil);assert(v.state.trips==1)
  v:leave()
 end
end)
check('expeditions default to timed trips without requiring reading rewards',function()
 v=newView(4);dofile(BASE..'/reading.lua').init(v.state);v.state.reading.enabled=false
 v:go('expeditions');tapButton(v,'trip',1)
 assert(v.state.trip==1 and v.state.trail==nil);v:leave()
end)
check('egg controls hatch into a preview and cannot claim twice',function()
 v=newView(4);dofile(BASE..'/reading.lua').init(v.state);v:go('egg');tapButton(v,'egg',nil)
 local id=v.state.egg.id;v:go('egg');assert(tapButton(v,'hatch',nil).disabled and v.state.egg)
 E.readingReward(v.state,7200,os.time());tapButton(v,'hatch',nil)
 assert(v.screen=='entry' and v.detail_id==id and v.state.species==4 and not v.state.egg)
 assert(U:drain()==2);tapButton(v,'nav','journal');assert(not v.hatched)
 v:go('egg');v:paintTo(bb,0,0)
 for _,b in ipairs(v.buttons) do assert(b.action~='hatch') end
 v:leave()
end)
check('background picker saves immediately without an animation timer',function()
 v=newView(4);v:go('more');tapButton(v,'nav','backgrounds')
 local saved=v.owner.saved or 0
 for i=1,#E.backgrounds do
  tapButton(v,'background',i);assert(v.state.background==i and v.screen=='backgrounds' and #U.queue==0)
 end
 assert(v.owner.saved==saved+6);v:leave()
end)
check('opening shows the pet and keeps reading recaps in their own menu',function()
 local P=dofile(BASE..'/main.lua');local reader=P:new{path=BASE,ui={menu={registerToMainMenu=function() end}}}
 reader:openPet();reader:syncReading();reader.pet_view:leave()
 reader.clock.pending=900;reader:openPet();reader:syncReading();assert(reader.pet_view.screen=='home' and reader.recap.seconds==900)
 assert(not reader.pet_view.message:find('Reading:',1,true))
 tapButton(reader.pet_view,'nav','more');tapButton(reader.pet_view,'nav','reading');tapButton(reader.pet_view,'nav','recap')
 assert(reader.pet_view.screen=='recap' and #U.queue==0);tapButton(reader.pet_view,'nav','home');reader.pet_view:leave()
 reader:openPet();reader:syncReading();assert(reader.pet_view.screen=='home' and not reader.recap);reader.pet_view:leave()
end)
check('weekly picker and decoration shop preserve progress and purchases',function()
 v=newView(4);dofile(BASE..'/reading.lua').init(v.state);v:go('reading');tapButton(v,'nav','weekly')
 tapButton(v,'goal',3600);E.readingReward(v.state,1800,os.time());tapButton(v,'goal',7200);assert(v.state.week.seconds==1800)
 v.state.berries=20;v:go('more');tapButton(v,'nav','decorations');tapButton(v,'decorate',2)
 assert(v.state.decor[2] and v.state.berries==12 and v.screen=='decorations')
 tapButton(v,'decorate',2);tapButton(v,'decorate',2);assert(v.state.berries==12 and v.state.decor[2]);v:leave()
end)
check('nickname keyboard cancels edits, limits input and saves the chosen name',function()
 v=newView(4);v:go('profile');tapButton(v,'nav','nickname');tapButton(v,'nickkey','E')
 tapButton(v,'nickcase',nil);for letter in ('mber'):gmatch('.') do tapButton(v,'nickkey',letter) end
 tapButton(v,'nav','profile');assert(E.displayName(v.state)=='Charmander')
 tapButton(v,'nav','nickname');for i=1,14 do tapButton(v,'nickkey','W') end;assert(#v.nickname_text==12)
 tapButton(v,'nickdelete',nil);assert(#v.nickname_text==11)
 tapButton(v,'nicksave',nil);assert(E.displayName(v.state)==string.rep('W',11) and v.screen=='profile')
 tapButton(v,'nav','nickname');tapButton(v,'nickclear',nil);tapButton(v,'nicksave',nil)
 assert(E.displayName(v.state)=='Charmander');v:leave()
end)
check('home egg is a touch target and keeps its progress through navigation',function()
 v=newView(4);dofile(BASE..'/reading.lua').init(v.state);E.act(v.state,'egg',nil,os.time())
 E.readingReward(v.state,5400,os.time());v:paintTo(bb,0,0)
 v:onTap(nil,{pos={x=440,y=375}});assert(v.screen=='egg' and E.eggLeft(v.state)==1800);v:leave()
end)
check('backup preview can be cancelled and restore preserves a way back',function()
 v=newView(4);dofile(BASE..'/reading.lua').init(v.state)
 local path=TESTDIR..'/ui-backup.dat';local R=dofile(BASE..'/reading.lua');assert(R.saveCounter(path..'.reading',0))
 v.owner.backups=dofile(BASE..'/backups.lua').new(path,E,R,dofile(BASE..'/filesystem.lua'))
 v:go('more');tapButton(v,'nav','backups');assert(tapButton(v,'previewbackup','backup').disabled)
 tapButton(v,'makebackup',nil);v.state.berries=19
 tapButton(v,'previewbackup','backup');assert(v.screen=='restore' and v.state.berries==19)
 tapButton(v,'nav','backups');assert(v.state.berries==19)
 tapButton(v,'previewbackup','backup');tapButton(v,'restorebackup',nil)
 assert(v.screen=='home' and v.state.berries==6 and v.owner.backups:preview('before-restore').state.berries==19);v:leave()
end)
check('unfinished restore blocks gameplay, writes and tracking until recovery',function()
 local P=dofile(BASE..'/main.lua');local reader=P:new{path=BASE,ui={menu={registerToMainMenu=function() end}}}
 reader:openPet();reader:syncReading();reader.pet_view:stopAnimation();reader.backups.blocked=true
 local f=assert(io.open(reader.savepath..'.restore','wb'));f:write('interrupted restore');f:close()
 local R=reader.reading;local before=R.counter(reader.counterpath);reader.clock.pending=60;reader:flushReading()
 assert(reader.clock.pending==60 and R.counter(reader.counterpath)==before and not reader:save())
 reader.pet_view:go('backups');reader.pet_view:paintTo(bb,0,0)
 for _,b in ipairs(reader.pet_view.buttons) do assert(b.action=='exit') end
 local berries=reader.state.berries;reader.pet_view:act('feed');assert(reader.state.berries==berries)
 reader.pet_view:onBack();assert(not reader.pet_view)
 os.remove(reader.savepath..'.restore');reader.backups.blocked=false;reader.clock.pending=0
end)
print('UI LIFECYCLE: '..checks..' checks passed (mock KOReader device APIs)')
''')

lua.execute((REPO/'tests'/'test_new_ui.lua').read_text())
lua.execute((REPO/'tests'/'test_world_ui.lua').read_text())

# Check the displayed dates and totals using real daylight-saving transitions.
if hasattr(time,'tzset'):
 render_history=lua.eval('''function(now,week,days)
  local clock=os.time;os.time=function(t) if t then return clock(t) end;return now end
  local v=newView(4);v.engine.companion.get(v.state).days=days
  v.screen='readinghistory';v.history_week=week;v:paintTo(bb,0,0)
  os.time=clock
 end''')
 original_tz=os.environ.get('TZ')
 try:
  for zone,today,week,monday in [
   ('Australia/Hobart','2026-10-25',3,'2026-09-28'),
   ('Australia/Hobart','2026-04-19',2,'2026-03-30'),
   ('America/New_York','2026-03-22',2,'2026-03-02'),
   ('America/New_York','2026-11-15',2,'2026-10-26'),
   ('UTC','2026-10-25',3,'2026-09-28'),
  ]:
   os.environ['TZ']=zone;time.tzset();start()
   today=datetime.date.fromisoformat(today);monday=datetime.date.fromisoformat(monday)
   days=lua.table()
   for i in range(-1,8):
    day=monday+datetime.timedelta(days=i)
    days[day.isoformat()]=lua.table_from({'ko':(i+1)*60 if 0<=i<=6 else 60000,'kindle':0})
   now=lua.eval('os.time')(lua.table_from({'year':today.year,'month':today.month,'day':today.day,'hour':12}))
   render_history(now,week,days)
   assert 'Week of '+monday.strftime('%d %b %Y') in painted_text,(zone,painted_text)
   labels=[text for text,x,y,*_ in painted_text_boxes if x==32 and 243<=y<=501]
   expected=[(monday+datetime.timedelta(days=i)).strftime('%a %d') for i in range(7)]
   assert labels==expected,(zone,labels,expected)
   assert '28 minutes recorded' in painted_text,(zone,painted_text)
 finally:
  if original_tz is None:os.environ.pop('TZ',None)
  else:os.environ['TZ']=original_tz
  time.tzset()
 print('READING HISTORY: dates and totals pass across both DST changes in Hobart and New York, and in UTC')
else:
 print('READING HISTORY: timezone checks need time.tzset; run this suite on Linux')

def paint(v,w=600,h=800):
 start(w,h);v.geometry(v);v.paintTo(v,g.bb,0,0);assert not bounds,bounds;return canvas.copy()

import runpy
runpy.run_path(str(REPO/'tests'/'world_layouts.py'))['run'](globals())

# The reported Pikachu screen must fit at Kindle resolutions and custom DPI.
text_layouts=0
for w,h in [(1072,1448),(600,800),(758,1024),(1264,1680),(1440,1920),(800,600)]:
 for dpi in (None,160,300,450):
  for large in (False,True):
   g.D.dpi=dpi;v=g.newView(25)
   if large:
    g.E.act(v.state,'preference','large_text',int(v.state.last))
    g.E.act(v.state,'preference','high_contrast',int(v.state.last))
   im=paint(v,w,h)
   if (w,h,dpi,large)==(1072,1448,None,False):im.save(OUT/'text-scaling-pikachu.png')
   assert not truncated,(w,h,dpi,large,truncated)
   for text,x,y,tw,th,sz in painted_text_boxes:
    if text=='Pikachu':assert sz==max(9,int(27*v.scale+0.5)),(w,h,dpi,sz)
   for _,button in v.buttons.items():
    if button.action in ('hello','nav') and button.arg in (None,'egg'):continue
    r=v.region(v,button.x,button.y,button.w,button.h)
    labels=[box for box in painted_text_boxes if r.x<=box[1]+box[3]/2<r.x+r.w and r.y<=box[2]+box[4]/2<r.y+r.h]
    assert len(labels)==1,(w,h,dpi,large,button.action,button.arg,labels)
    _,x,y,tw,th,_=labels[0]
    assert r.x<=x and x+tw<=r.x+r.w and r.y<=y and y+th<=r.y+r.h,(w,h,dpi,large,labels[0])
    assert abs(y+th/2-(r.y+r.h/2))<=1,(w,h,dpi,large,labels[0])
   text_layouts+=1;v.freeImages(v)
g.D.dpi=None
print(f'TEXT SCALING: {text_layouts} Kindle size, DPI and accessibility combinations passed')

# Companion selection must fit large text, region tabs and Eevee's five evolutions.
for w,h in [(600,800),(1072,1448),(800,600)]:
 for large in (False,True):
  v=g.newView(133);v.state.xp=120;v.state.bond=30
  if large:
   g.E.act(v.state,'preference','large_text',int(v.state.last))
   g.E.act(v.state,'preference','high_contrast',int(v.state.last))
  for screen in ('profile','companions','allcompanions','entry'):
   v.go(v,screen);v.detail_id=158;v.entry_from='companions'
   im=paint(v,w,h);assert not truncated,(screen,w,h,large,truncated)
   buttons=list(v.buttons.values())
   for i,a in enumerate(buttons):
    for b in buttons[i+1:]:
     assert a.x+a.w<=b.x or b.x+b.w<=a.x or a.y+a.h<=b.y or b.y+b.h<=a.y,(screen,a.action,b.action)
   if (w,h)==(600,800):im.save(OUT/f'change-companion-{screen}-{"large" if large else "normal"}.png')
  v.freeImages(v)
print('COMPANION PICKER: 24 profile, selection and confirmation layouts checked')

# Layout smoke tests execute every actual view at representative portrait/landscape sizes.
for w,h in [(600,800),(1072,1448),(1264,1680),(800,600)]:
 for screen in ['welcome','home','sleep','explore','journal','history','more','profile','badges','play','train','help','reading','egg','backgrounds','weekly','recap','decorations','nickname','backups']:
  v=g.newView(None if screen=='welcome' else 4)
  v.screen='home' if screen in ('welcome','sleep') else screen
  if screen=='nickname':v.go(v,'nickname')
  if screen=='sleep':v.state.resting=True
  if screen=='play':v.startPlay(v)
  if screen=='journal':
   for id in g.E.species.keys():v.state.seen[str(id)]=True
  if screen=='history':
   for i in range(24):g.E.note(v.state,f'Moment {i+1}',int(v.state.last))
  im=paint(v,w,h)
  if screen=='home':
   for label in ('Food ','Joy ','Energy ','Hygiene ','Bond '):assert any(text.startswith(label) for text in painted_text),label
   assert not any('min read' in text or 'next berry' in text for text in painted_text)
  if (w,h)==(600,800):im.save(OUT/f'layout-{screen}.png')
  v.freeImages(v)
print('LAYOUT: 80 screen/size combinations painted within bounds (desktop renderer)')

# New screens also have to fit with both accessibility preferences enabled.
for large in (False,True):
 for w,h in [(600,800),(1072,1448),(800,600)]:
  v=g.newView(4);lua.execute("return dofile(BASE..'/reading.lua')").init(v.state)
  now=int(v.state.last);v.state.berries=80
  g.E.act(v.state,'nickname','Évoli',now);g.E.act(v.state,'egg',None,now)
  g.E.act(v.state,'memory','The Hobbit',now);g.E.act(v.state,'trip',1,now);v.state.due=now
  if large:
   g.E.act(v.state,'preference','large_text',now);g.E.act(v.state,'preference','high_contrast',now)
  for screen in ('preferences','sleeppreview','filters','snacks','memories','bookconfirm','readinghistory','trailstory','textentry','journal'):
   v.go(v,screen);v.input_text='The Hobbit';v.input_kind='memory';v.input_limit=100
   im=paint(v,w,h);assert not truncated,(screen,large,w,truncated)
   if (w,h)==(600,800):im.save(OUT/f'new-{screen}-{"large" if large else "normal"}.png')
  v.freeImages(v)
v=g.newView(4);v.owner.native=True;v.go(v,'preferences');paint(v);assert not truncated,truncated
large_failures=[]
for screen in ('home','more','profile','reading','egg','weekly','decorations','backgrounds','badges','train','help','explore','nickname','backups'):
 v=g.newView(4);g.E.act(v.state,'preference','large_text',int(v.state.last));g.E.act(v.state,'preference','high_contrast',int(v.state.last));v.go(v,screen)
 paint(v)
 if truncated:large_failures.append((screen,list(truncated)))
assert not large_failures,large_failures
print('NEW LAYOUTS: 75 screen/size/text-mode combinations checked')

# A save failure remains visible on every page, including pages with their own messages.
for w,h in [(600,800),(1072,1448),(1264,1680),(800,600)]:
 v=g.newView(4);v.owner.save_error=True
 for screen in ('home','reading','profile','more','decorations','backgrounds','weekly','backups'):
  v.go(v,screen);paint(v,w,h)
  assert any(text.startswith('Not saved.') for text in painted_text),screen
  assert not truncated,(screen,truncated)
 v.freeImages(v)
print('SAVE WARNINGS: visible without clipped text on 32 page/size combinations')

# Reading goals at empty, growing, paused and ready states, including old timed trips.
init_reading=lua.eval("function(s) return dofile(BASE..'/reading.lua').init(s) end")
for w,h in [(600,800),(1072,1448),(1264,1680),(800,600)]:
 for scenario in ('egg-empty','egg-growing','egg-ready','egg-paused','trip-reading','trip-ready','trip-paused','trip-timed'):
  v=g.newView(4);init_reading(v.state);now=int(v.state.last)
  if scenario.startswith('egg'):
   if scenario!='egg-empty':
    g.E.act(v.state,'egg',None,now);g.E.readingReward(v.state,7200 if scenario=='egg-ready' else 3600,now)
   v.screen='egg'
  else:
   g.E.act(v.state,'trip' if scenario=='trip-timed' else 'readingtrip',1,now)
   g.E.readingReward(v.state,1800 if scenario=='trip-ready' else 900,now);v.screen='expeditions'
  if scenario.endswith('paused'):v.state.reading.enabled=False
  im=paint(v,w,h);assert not truncated,(scenario,truncated)
  if (w,h)==(600,800):im.save(OUT/f'{scenario}.png')
  v.screen='home';paint(v,w,h);assert not truncated,(scenario,'home',truncated);v.freeImages(v)
 for background in range(1,7):
  for night in (False,True):
   v=g.newView(4);v.state.background=background
   lua.execute("real_date=os.date;os.date=function(format,t) if format=='%H' then return '"+('22' if night else '12')+"' end;return real_date(format,t) end")
   im=paint(v,w,h);assert not truncated,(background,night,truncated)
   if (w,h)==(600,800):im.save(OUT/f"background-{background}-{'night' if night else 'day'}.png")
   lua.execute('os.date=real_date');v.freeImages(v)
print('ADVENTURE LAYOUTS: 64 goal/home states and 48 day/night backgrounds checked')

for w,h in [(600,800),(1072,1448),(1264,1680),(800,600)]:
 v=g.newView(4);init_reading(v.state);now=int(v.state.last);v.state.berries=80
 for item in range(1,5):g.E.act(v.state,'decorate',item,now)
 g.E.act(v.state,'egg',None,now);g.E.act(v.state,'readingtrip',3,now);g.E.act(v.state,'goal',3600,now)
 _,v.owner.recap=g.E.readingReward(v.state,3600,now)
 for screen in ('recap','weekly','decorations'):
  v.go(v,screen);im=paint(v,w,h);assert not truncated,(screen,truncated)
  if (w,h)==(600,800):im.save(OUT/f'companion-{screen}.png')
 v.go(v,'nickname');v.nickname_text='W'*12;im=paint(v,w,h);assert not truncated,('nickname',truncated)
 if (w,h)==(600,800):
  v.nickname_text='Ember';paint(v,w,h).save(OUT/'companion-nickname.png')
 v.restore_preview=lua.table_from({'state':v.state,'at':now,'ko':0,'slot':'backup'});v.go(v,'restore')
 im=paint(v,w,h);assert not truncated,('restore',truncated)
 if (w,h)==(600,800):im.save(OUT/'companion-restore.png')
 v.state.trip=0;v.state.trail=None;v.state.finds=None;v.state.companion.journey=None;v.state.background=6;v.go(v,'home')
 im=paint(v,w,h);assert not truncated,('decorated home',truncated)
 if (w,h)==(600,800):im.save(OUT/'companion-home.png')
 v.state.xp=270;v.state.bond=24;v.go(v,'profile');im=paint(v,w,h);assert not truncated,('evolution',truncated)
 if (w,h)==(600,800):im.save(OUT/'companion-evolution.png')
 R=lua.execute("return dofile(BASE..'/reading.lua')");F=lua.execute("return dofile(BASE..'/filesystem.lua')")
 B=lua.execute("return dofile(BASE..'/backups.lua')")
 v.owner.backups=B.new(g.TESTDIR+f'/render-backup-{w}.dat',g.E,R,F)
 ok,error=v.owner.backups.create(v.owner.backups,v.state);assert ok,error
 preview=v.owner.backups.preview(v.owner.backups,'backup');v.state.xp+=1
 ok,error=v.owner.backups.restore(v.owner.backups,v.state,preview);assert ok,error
 v.go(v,'backups');im=paint(v,w,h);assert not truncated,('backups',truncated)
 if (w,h)==(600,800):im.save(OUT/'companion-backups.png')
 v.freeImages(v)
print('COMPANION LAYOUTS: 32 recap, goal, decor, keyboard, backup, restore, home and evolution layouts checked')

# Assert visible species, lineage and text, not just that drawing does not crash.
families=[(1,2,3),(4,5,6),(7,8,9),(172,25,26),(133,),
          (133,134),(133,135),(133,136),(133,196),(133,197),(152,153,154),(155,156,157),(158,159,160),
          (252,253,254),(255,256,257),(258,259,260),(298,183,184),(374,375,376)]
profile_cases={species:family for family in families for species in family if species!=133}
profile_cases[133]=(133,)
species_layouts=0
for w,h in [(600,800),(1072,1448),(1264,1680),(800,600)]:
 for index,species in g.E.starters.items():
  v=g.newView(None);v.starter_index=index;paint(v,w,h)
  assert painted_sprites==[species] and not truncated,(species,truncated)
  assert f'Start with {g.E.name(species)}' in painted_text
  if (w,h)==(600,800) and species==152:canvas.save(OUT/'PokePal-starter-picker.png')
  g.tapButton(v,'choose',species);assert v.state.species==species;v.leave(v);species_layouts+=1
 for species,family in profile_cases.items():
  v=g.newView(family[0]);v.state.species=species;v.screen='profile';paint(v,w,h)
  assert painted_sprites==list(family),(species,painted_sprites,family)
  assert not truncated,(species,truncated)
  if not g.E.species[species][2]:
   assert any(f'{g.E.name(species)} is fully evolved.' in text for text in painted_text)
  if (w,h)==(600,800) and species in (152,133,160):canvas.save(OUT/f'PokePal-profile-{species}.png')
  species_layouts+=1
  for screen in ('home','train','sleep'):
   v.screen='home' if screen=='sleep' else screen;v.state.resting=screen=='sleep';paint(v,w,h)
   assert not truncated,(species,screen,truncated)
   species_layouts+=1
  v.freeImages(v)
print(f'PARTNERS: {species_layouts} starter/profile/home/training/sleep layouts verified')

# New journal entries use the actual touch dispatcher and every core pose.
for species in range(1,g.E.species_count+1):
 v=g.newView(4);v.state.seen[str(species)]=True
 v.go(v,'entry');v.detail_id=species;v.preview_pose='idle';paint(v)
 assert not truncated,(species,'entry',truncated)
 for pose in ('idle','sleep','walk','attack','eat','hop','rotate','charge','swing','double'):
  g.tapButton(v,'preview',pose);assert v.preview_pose==pose
  assert g.U.drain(g.U)<=4
 v.freeImages(v)
print(f'JOURNAL: all {g.E.species_count} entries and {g.E.species_count*10} pose buttons rendered and dispatched')

v=g.newView(4);v.state.bond=28;v.state.xp=48;v.state.food=76;v.state.joy=84;v.state.energy=72;v.state.dirt=22
v.message='Charmander is happy to see you.'
v.state.animation='gentle';v.animating=False;v.effect=None
paint(v).save(OUT/'PokePal-preview.png')
frames=[]
for n in [1,2,3,4,1]:
 v.frame=n;v.animating=n!=1;v.effect='ambient' if n!=1 else None
 frames.append(paint(v))
frames[0].save(OUT/'PokePal-idle-preview.gif',save_all=True,append_images=frames[1:],duration=[450]*4+[2500],disposal=2)
frames=[]
for n in [1,2,3,4,1]:
 v.frame=n;v.animating=n!=1;v.effect='play' if n!=1 else None
 frames.append(paint(v))
frames[0].save(OUT/'PokePal-animation.gif',save_all=True,append_images=frames[1:],duration=[450]*4+[2500],disposal=2)
v.state.resting=True;v.message='Resting peacefully. Energy recovers while you read.';v.animating=False;v.effect=None
paint(v).save(OUT/'PokePal-sleep-preview.png')
sleep_frames=[]
for n in [1,2,1]:
 v.frame=n;v.animating=n!=1;v.effect='ambient_sleep' if n!=1 else None
 sleep_frames.append(paint(v))
sleep_frames[0].save(OUT/'PokePal-sleep-preview.gif',save_all=True,append_images=sleep_frames[1:],duration=[800,800,2500],disposal=2)
v.state.resting=False;v.message='Charmander is happy to see you.'
v.screen='profile';paint(v).save(OUT/'PokePal-evolution.png')
print(f'PREVIEW: rendered from game view with {font(18).getname()[0]}; desktop rendering, not a Kindle capture')

# Every species, every frame is present, grayscale and correctly sized.
count=0
manifest=lua.execute((ROOT/'assets'/'frames.lua').read_text())
for id in g.E.species.keys():
 hashes=[]
 for fr in range(1,manifest[id]+1):
  img=read_sprite(f'{id}-{fr}.png');assert img.size==(96,96) and img.mode=='LA'
  assert set(img.getchannel('L').tobytes()).issubset({0,85,170,255});hashes.append(img.tobytes());count+=1
 assert len(set(hashes))>=2,f'{id}: idle must move'
species_ids=set(g.E.species.keys())
assert set(manifest.keys())==species_ids
sources=json.loads((ROOT/'assets'/'sources.json').read_text())
assert len(sources)==len(species_ids) and {record['id'] for record in sources}==species_ids
for record in sources:
 assert record['count']==manifest[record['id']]
 if not record.get('generated'):assert len(record['sampled'])==record['count']
 assert len(set(record['sampled']))==len(record['sampled'])
 assert all(0<=index<record['original_frames'] for index in record['sampled'])
print(f'ASSETS: {count} valid transparent frames; all {len(species_ids)} species have frames and source records')
poses=lua.execute((ROOT/'assets'/'poses.lua').read_text())
pose_sources={(r['species'],r['pose'].lower()):r for r in json.loads((ROOT/'assets'/'pose-sources.json').read_text())}
walk_sources=json.loads((ROOT/'assets'/'walk-sources.json').read_text())
assert {r['species'] for r in walk_sources}==species_ids and len(walk_sources)==len(species_ids)
for record in walk_sources:
 assert record['rows']=={'down':0,'left':2,'up':4,'right':6}
 assert len(record['source_sha256'])==64
 for direction in record['rows']:
  pose_sources[record['species'],'walk_'+direction]={**record,'motion':True}
assert set(pose_sources)=={(id,pose) for id in species_ids for pose in poses[id].keys()}
pose_count=0
for id in poses.keys():
 assert set(poses[id].keys())=={'idle','sleep','walk','attack','eat','hop','rotate','charge','swing','double','walk_up','walk_down','walk_left','walk_right'}
 for pose,frames in poses[id].items():
  hashes=[]
  for fr in range(1,frames+1):
   img=read_sprite(f'{id}-{pose}-{fr}.png')
   assert img.size==(96,96) and img.mode=='LA'
   assert set(img.getchannel('L').tobytes()).issubset({0,85,170,255})
   hashes.append(img.tobytes());pose_count+=1
  record=pose_sources[id,pose]
  assert len(set(hashes))>=2 and record['motion'],(id,pose)
print(f'POSES: {pose_count} valid grayscale alpha frames; every species has ten action poses and four walking directions')
compile_lua=lua.eval('function(path) assert(loadfile(path)) end')
sources=list(ROOT.rglob('*.lua'))
for path in sources:compile_lua(path.as_posix())
print(f'SYNTAX: {len(sources)} shipped Lua files compile')
temp.cleanup()
