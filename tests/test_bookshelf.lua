-- The real module and save files, with a small Bookshelf host. The runtime
-- suite also runs these cases with KOReader's real widgets and image buffers.
local E=dofile(BASE..'/engine.lua');local S=dofile(BASE..'/storage.lua')
local F=dofile(BASE..'/filesystem.lua')
local now=1800000000
local real_ui=BOOKSHELF_REAL_UI
local original_host_fs=host_fs
local passed,failed,serial=0,0,0
local function read(path) local f=assert(io.open(path,'rb'));local data=f:read('*a');f:close();return data end
local function write(path,data) local f=assert(io.open(path,'wb'));assert(f:write(data));f:close() end
local function text(widget,want)
 if widget.text==want then return true end
 for _,child in ipairs(widget) do if text(child,want) then return true end end
 return false
end
local function test(name,fn)
 local saved={}
 local function mock(name,value)
  if saved[name]==nil then saved[name]={package.loaded[name]} end
  package.loaded[name]=value
 end
 local Widget={}
 function Widget:extend(o) o=o or {};self.__index=self;return setmetatable(o,self) end
 function Widget:new(o) return self:extend(o) end
 function Widget:getSize() return self.dimen or {w=self.width or 80,h=self.height or 20} end
 function Widget:free() for _,child in ipairs(self) do if child.free then child:free() end end end
 if real_ui then Widget=require('ui/widget/widget') end
 local U={queue={}}
 function U:nextTick(fn) self.queue[#self.queue+1]=fn end
 function U:getTopmostVisibleWidget() return self.top end
 function U:drain()
  local n=0
  while #self.queue>0 do n=n+1;assert(n<20,'refresh loop');table.remove(self.queue,1)() end
 end
 local D={screen_saver_mode=false}
 if real_ui then setmetatable(D,{__index=require('device')}) end
 serial=serial+1
 local directory=TESTDIR..'/bookshelf-'..serial
 assert(F.mkdir(directory))
 local path=directory..'/pokepal.dat'
 mock('ui/uimanager',U);mock('device',D)
 mock('datastorage',{getSettingsDir=function() return directory end})
 mock('ffi/util',{});mock('dispatcher',{})
 if not real_ui then
  for _,name in ipairs({'container/widgetcontainer','container/centercontainer','container/bottomcontainer',
   'container/leftcontainer','textwidget','imagewidget','verticalgroup','horizontalgroup','verticalspan','horizontalspan','infomessage'}) do
   mock('ui/widget/'..name,Widget)
  end
  mock('ui/geometry',{new=function(self,o) return o end})
  local buffer={getType=function() return 1 end,free=function() end,blitFrom=function() end,paintRect=function() end,
   getWidth=function(self) return self.w end,getHeight=function(self) return self.h end}
  function buffer:scale(w,h) return setmetatable({w=w,h=h},{__index=buffer}) end
  mock('ffi/blitbuffer',{TYPE_BB8A=1,Color8A=function() return 0 end,new=function(w,h) return buffer:scale(w,h) end})
  mock('ui/renderimage',{renderImageData=function() return buffer:scale(96,96) end})
 end
 local Kit={COLOR_PRIMARY=require('ffi/blitbuffer').COLOR_BLACK,COLOR_MUTED=require('ffi/blitbuffer').COLOR_BLACK}
 function Kit.sc(scale) return function(n) return math.max(1,math.floor(n*(scale or 100)/100+0.5)) end end
 function Kit.face(size,scale)
  size=Kit.sc(scale)(size)
  return real_ui and require('ui/font'):getFace('cfont',size) or {size=size}
 end
 function Kit.shape(w,h) return w/h>=1.6 and 'wide' or 'square' end
 function Kit.progressBar(o) return Widget:new{dimen={w=o.width,h=o.height}} end
 mock('lib/bookshelf_module_kit',Kit)
 local P=dofile(BASE..'/main.lua')
 local p=setmetatable({cancelReadingScan=function() end,updateCompanion=function() end,resumeReading=function() end}, {__index=P})
 mock('apps/filemanager/filemanager',{instance={pokepal=p}})
 mock('apps/reader/readerui',{})
 local module=assert(loadfile(BASE..'/bookshelf_modules/pokepal.lua'))(BASE..'/bookshelf_modules')
 local s=E.new(now);E.act(s,'choose',25,now);E.world.enter(s)
 for i=1,24 do E.act(s,'nickname','Bolt',now) end
 assert(S.save(path,s,E))
 local cards={}
 local function card(id,bw,preview)
  bw=bw or {};U.top=bw._micro_fullscreen or bw
  local c={count=0,bw=bw}
  c.ctx={width=400,height=200,scale=100,entry={id=id},bw=bw,preview=preview}
  c.ctx.refresh=function()
   c.count=c.count+1;c.widget:free();c.widget=assert(module.render(c.ctx));c.widget:getSize()
  end
  c.widget=assert(module.render(c.ctx));c.widget:getSize()
  cards[#cards+1]=c
  return c
 end
 local function change(name) E.act(s,'nickname',name,now);assert(S.save(path,s,E)) end
 local ok,err=pcall(fn,{p=p,U=U,D=D,module=module,card=card,cards=cards,change=change,path=path,state=s,mock=mock})
 for _,c in ipairs(cards) do if c.widget then c.widget:free() end end
 host_fs=original_host_fs
 for name,old in pairs(saved) do package.loaded[name]=old[1] end
 if ok then passed=passed+1;print('PASS bookshelf: '..name)
 else failed=failed+1;print('FAIL bookshelf: '..name..': '..tostring(err)) end
end

test('same-size saves with identical timestamps refresh every visible card',function(t)
 host_fs=function(op,path)
  if op=='mtime' then return 42 end
  if op=='size' then local f=io.open(path,'rb');if not f then return nil end;local n=f:seek('end');f:close();return n end
  if original_host_fs then return original_host_fs(op,path) end
  local lfs=require('libs/libkoreader-lfs')
  if op=='mode' then return lfs.symlinkattributes(path,'mode') end
 end
 local bw={};local a,b=t.card('a',bw),t.card('b',bw)
 local before=read(t.path);t.change('Volt');assert(#read(t.path)==#before)
 t.module.on_minute(a.ctx);t.module.on_minute(b.ctx)
 assert(a.count==1 and b.count==1,'not all cards refreshed')
 assert(text(a.widget,'Volt') and text(b.widget,'Volt'),'a card still displays the old save')
 t.module.on_minute(a.ctx);assert(a.count==1 and b.count==1,'unchanged save repainted')
end)

test('rendering a new card does not consume an older card update',function(t)
 local bw={};local a=t.card('a',bw);t.change('New name')
 local b=t.card('b',bw);assert(text(b.widget,'New name'))
 t.module.on_minute(b.ctx)
 assert(a.count==1 and text(a.widget,'New name'),'older card missed a cached revision')
 assert(b.count==0,'fresh card repainted unnecessarily')
end)

test('closing PokePal refreshes all live cards after the final save',function(t)
 local bw={};local a,b=t.card('a',bw),t.card('b',bw)
 t.change('New name');t.p:onPetClosed();assert(a.count==0);t.U:drain()
 assert(a.count==1 and b.count==1 and text(a.widget,'New name') and text(b.widget,'New name'))
 t.p:onPetClosed();t.U:drain();assert(a.count==1 and b.count==1)
end)

test('freed cards are unsubscribed before queued callbacks run',function(t)
 local a=t.card('a');t.change('New name');t.p:onPetClosed();a.widget:free();t.U:drain()
 assert(a.count==0,'freed card refreshed')
end)

test('a closed Bookshelf never refreshes',function(t)
 local a=t.card('a');a.bw._closed=true;t.change('New name');t.p:onPetClosed();t.U:drain()
 assert(a.count==0,'closed Bookshelf refreshed')
end)

test('subscriptions do not keep discarded screens alive',function(t)
 local a=t.card('a');local weak=setmetatable({a.bw,a.widget},{__mode='v'})
 t.cards[1]=nil;t.U.top=nil;a=nil;collectgarbage();collectgarbage()
 assert(weak[1]==nil and weak[2]==nil,'watchers retained a discarded Bookshelf')
end)

test('background cards wait until their host is visible',function(t)
 local a=t.card('a');t.U.top={};t.change('New name');t.p:onPetClosed();t.U:drain()
 assert(a.count==0,'background card requested a repaint')
 t.U.top=a.bw;t.module.on_minute(a.ctx);assert(a.count==1 and text(a.widget,'New name'))
end)

test('full-screen cards refresh through the visible overlay',function(t)
 local a=t.card('a',{_micro_fullscreen={}});t.change('New name');t.p:onPetClosed();t.U:drain()
 assert(a.count==1)
end)

test('sleep and plugin teardown block queued refreshes',function(t)
 local a=t.card('a');t.change('New name');t.p:onPetClosed()
 t.D.screen_saver_mode=true;t.U:drain();t.module.on_minute(a.ctx);assert(a.count==0)
 t.D.screen_saver_mode=false;t.p.suspended=true;t.module.on_minute(a.ctx);assert(a.count==0)
 t.p.suspended=false;t.module.on_minute(a.ctx);assert(a.count==1)
 t.change('Next name');t.p:onPetClosed();t.p.closed=true;t.U:drain();assert(a.count==1)
end)

test('backup changes are detected while the primary stays unreadable',function(t)
 local good=read(t.path);write(t.path..'.old',good);write(t.path,'broken')
 local a=t.card('a');assert(text(a.widget,'Bolt'))
 E.act(t.state,'nickname','Volt',now);write(t.path..'.old',S.encode(t.state))
 t.module.on_minute(a.ctx);assert(a.count==1 and text(a.widget,'Volt'))
end)

test('a failed callback does not block another card and can retry',function(t)
 local bw={};local a,b=t.card('a',bw),t.card('b',bw)
 local original,attempts=a.ctx.refresh,0;a.widget:free()
 a.ctx.refresh=function() attempts=attempts+1;if attempts==1 then error('temporary host failure') end;original() end
 a.widget=assert(t.module.render(a.ctx));t.change('New name');t.p:onPetClosed();t.U:drain()
 assert(b.count==1,'a failed callback blocked another card')
 t.module.on_minute(a.ctx);assert(a.count==1 and text(a.widget,'New name'))
end)

test('choosing the first partner replaces the egg on returning from the game',function(t)
 local state=E.new(now);assert(S.save(t.path,state,E))
 local a=t.card('a');assert(text(a.widget,'Tap to choose a partner'))
 E.act(state,'choose',25,now);assert(S.save(t.path,state,E))
 t.p:onPetClosed();t.U:drain()
 assert(a.count==1 and text(a.widget,'Pikachu') and not text(a.widget,'Tap to choose a partner'))
end)

test('preview widgets do not subscribe or write saves',function(t)
 local before=read(t.path);local a=t.card('preview',nil,true)
 t.p:onPetClosed();t.U:drain();assert(a.count==0 and read(t.path)==before)
end)

test('read cache skips decoding unchanged primary and backup bytes',function(t)
 local cache={};local first=assert(S.load(t.path,E,cache));local revision=cache.revision
 assert(S.load(t.path,E,cache)==first,'unchanged data was decoded again')
 assert(cache.revision==revision)
 t.change('Volt');local next_state=assert(S.load(t.path,E,cache))
 assert(E.displayName(next_state)=='Volt' and cache.revision>revision)
 assert(read(t.path)==S.encode(t.state),'loading modified the save')
end)

assert(failed==0,tostring(failed)..' Bookshelf checks failed')
print('BOOKSHELF: '..passed..' save, refresh and lifecycle checks passed'..(real_ui and ' (real KOReader widgets)' or ' (mock display)'))
