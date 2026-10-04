import sys,pathlib,os,tempfile
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
lua.execute((REPO/'tests'/'test_engine.lua').read_text())

canvas=None;draw=None;bounds=[];truncated=[]
def font(size,bold=False):
 choices=(['C:/Windows/Fonts/arialbd.ttf','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'] if bold
          else ['C:/Windows/Fonts/arial.ttf','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'])
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
 t,f=get_text(t,sz,bold,maxw);return round(draw.textlength(t,font=f)),int(sz*1.2)
def render_text(t,x,y,sz,bold,maxw):
 t,f=get_text(t,sz,bold,maxw);draw.text((round(x),round(y)),t,font=f,fill=0,anchor='lt')
def rect(x,y,w,h,col):
 x,y,w,h=map(round,(x,y,w,h))
 if w and h:
  if x<0 or y<0 or x+w>canvas.width or y+h>canvas.height:bounds.append((x,y,w,h))
  draw.rectangle((x,y,x+w-1,y+h-1),fill=int(col))
def image(path,x,y,w,h):
 img=Image.open(path).convert('LA').resize((int(w),int(h)),Image.Resampling.NEAREST)
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
package.preload["ui/font"]=function() return {getFace=function(_,name,size) return {size=size} end} end
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
 function R:renderImageFile(file)
  local raw={file=file,getWidth=function() return 96 end,getHeight=function() return 96 end,scale=function(self,w,h) return {file=self.file,free=function() end} end,free=function() end}
  return raw
 end
 return R
end
package.preload["ffi/blitbuffer"]=function() return {COLOR_WHITE=255,COLOR_BLACK=0,Color8=function(n) return n end} end
D={w=600,h=800}
package.preload["device"]=function() return {screen_saver_mode=false,screen={getWidth=function() return D.w end,getHeight=function() return D.h end}} end
U={queue={},dirty={},show_count=0}
function U:scheduleIn(seconds,f) self.queue[#self.queue+1]={seconds=seconds,f=f} end
function U:unschedule(f) for i=#self.queue,1,-1 do if self.queue[i].f==f then table.remove(self.queue,i) end end end
function U:setDirty(widget,mode,region) self.dirty[#self.dirty+1]={mode=mode,region=region} end
function U:show(v) self.show_count=self.show_count+1 end
function U:close(v) v:onCloseWidget() end
function U:drain() local n=0;while #self.queue>0 do n=n+1;assert(n<=10,'unbounded animation');local t=table.remove(self.queue,1);t.f() end;return n end
package.preload["ui/uimanager"]=function() return U end
package.preload["datastorage"]=function() return {getSettingsDir=function() return TESTDIR end} end
package.preload["ffi/util"]=function() return {} end
package.preload["ui/widget/infomessage"]=function() return W end
bb={paintRect=function(_,...) render_rect(...) end}
E=dofile(BASE.."/engine.lua");V=dofile(BASE.."/view.lua")
Device=require("device")
function newView(id)
 local s=E.new(os.time());if id then E.act(s,'choose',id,os.time()) end
 local owner={save=function(self) self.saved=(self.saved or 0)+1;return true end}
 local v=V:new{engine=E,state=s,owner=owner,path=BASE};owner.view=v;return v
end
''')
def start(w=600,h=800):
 global canvas,draw,bounds,truncated
 canvas=Image.new('L',(w,h),255);draw=ImageDraw.Draw(canvas);bounds=[];truncated=[]
 g.D.w=w;g.D.h=h
start()
lua.execute(r'''
local checks=0
local function check(name,fn) fn();checks=checks+1;print('PASS '..name) end
check('idle creates no animation timer',function() v=newView(25);assert(#U.queue==0) end)
check('gentle animation has finite regional refreshes',function()
 v.state.animation='gentle';v:animate('play');assert(#U.queue==1);assert(U:drain()==4);assert(v.frame==1 and not v.animating)
 for _,d in ipairs(U.dirty) do assert(d.region and d.region.w<D.w and d.region.h<D.h) end
end)
check('eco animation is shorter',function() v.state.animation='eco';v:animate('feed');assert(U:drain()==2) end)
check('animation off queues nothing',function() v.state.animation='off';v:animate('play');assert(#U.queue==0) end)
check('navigation cancels callbacks',function() v.state.animation='gentle';v:animate('play');v:go('journal');assert(#U.queue==0) end)
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
 v:animate('play');v:leave();assert(#U.queue==0 and v.closed and not v.owner.view)
end)
check('touch controls dispatch at scaled coordinates',function()
 v=newView(25);v.state.animation='off';v:paintTo(bb,0,0)
 v:onTap(nil,{pos={x=70,y=612}});assert(v.state.berries==5)
end)
check('main plugin starts with Charmander and persists it',function()
 local P=dofile(BASE..'/main.lua')
 p=P:new{path=BASE,ui={menu={registerToMainMenu=function() end}}}
 local items={};p:addToMainMenu(items);assert(items.pokepal.callback)
 items.pokepal.callback();assert(p.view and p.state.species==4 and #U.queue==1);p.view:act('feed');p.view:leave()
 p:openPet();assert(p.state.species==4 and p.state.berries==5 and #U.queue==1);p.view:leave()
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
print('UI LIFECYCLE: '..checks..' checks passed (mock KOReader device APIs)')
''')

def paint(v,w=600,h=800):
 start(w,h);v.geometry(v);v.paintTo(v,g.bb,0,0);assert not bounds,bounds;return canvas.copy()

# Layout smoke tests execute every actual view at representative portrait/landscape sizes.
for w,h in [(600,800),(1072,1448),(1264,1680),(800,600)]:
 for screen in ['welcome','home','sleep','explore','journal','history','more','profile','badges','play','train','help']:
  v=g.newView(None if screen=='welcome' else 4)
  v.screen='home' if screen in ('welcome','sleep') else screen
  if screen=='sleep':v.state.resting=True
  if screen=='play':v.startPlay(v)
  if screen=='journal':
   for id in g.E.species.keys():v.state.seen[str(id)]=True
  if screen=='history':
   for i in range(24):g.E.note(v.state,f'Moment {i+1}',int(v.state.last))
  im=paint(v,w,h)
  if (w,h)==(600,800):im.save(OUT/f'layout-{screen}.png')
  v.freeImages(v)
print('LAYOUT: 48 screen/size combinations painted within bounds (desktop renderer)')

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
print('PREVIEW: rendered directly from game view; fonts approximated with Arial, not a Kindle capture')

# Every species, every frame is present, grayscale and correctly sized.
count=0
manifest=lua.execute((ROOT/'assets'/'frames.lua').read_text())
for id in g.E.species.keys():
 hashes=[]
 for fr in range(1,manifest[id]+1):
  img=Image.open(ROOT/'assets'/f'{id}-{fr}.png');assert img.size==(96,96) and img.mode=='LA'
  assert set(img.getchannel('L').get_flattened_data()).issubset({0,85,170,255});hashes.append(img.tobytes());count+=1
 assert len(set(hashes))>=2,f'{id}: no motion'
print(f'ASSETS: {count} valid transparent frames; all 27 species have changing animation frames')
poses=lua.execute((ROOT/'assets'/'poses.lua').read_text())
pose_count=0
for id in (4,5,6):
 for pose,frames in poses[id].items():
  hashes=[]
  for fr in range(1,frames+1):
   img=Image.open(ROOT/'assets'/f'{id}-{pose}-{fr}.png')
   assert img.size==(96,96) and img.mode=='LA'
   assert set(img.getchannel('L').get_flattened_data()).issubset({0,85,170,255})
   hashes.append(img.tobytes());pose_count+=1
  assert len(set(hashes))>=2,f'{id} {pose}: no motion'
print(f'POSES: {pose_count} valid grayscale alpha frames; every pose moves')
compile_lua=lua.eval('function(path) assert(loadfile(path)) end')
sources=list(ROOT.rglob('*.lua'))
for path in sources:compile_lua(path.as_posix())
print(f'SYNTAX: {len(sources)} shipped Lua files compile')
temp.cleanup()
