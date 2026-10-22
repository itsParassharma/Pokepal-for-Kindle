-- SPDX-License-Identifier: GPL-3.0-or-later
-- The standalone host supplies drawing and input; the game and view are shared.
local W={}
function W:extend(o) o=o or {};setmetatable(o,self);self.__index=self;return o end
function W:new(o) o=self:extend(o);if o._init then o:_init() end;if o.init then o:init() end;return o end
local Input=W:extend{}
function Input:_init() self.key_events={};self.ges_events={} end
package.preload['ui/widget/container/inputcontainer']=function() return Input end
package.preload['ui/geometry']=function() return W end
package.preload['ui/gesturerange']=function() return W end
package.preload['ui/font']=function() return {getFace=function(_,name,size) return {size=size} end} end
package.preload['ffi/blitbuffer']=function() return {COLOR_WHITE=255,COLOR_BLACK=0,Color8=function(n) return n end} end
local T=W:extend{}
function T:getSize() return {w=host_text_width(self.text,self.face.size,self.bold,self.max_width),h=self.face.size*1.2} end
function T:paintTo(_,x,y) host_text(self.text,x,y,self.face.size,self.bold,self.max_width) end
function T:free() end
package.preload['ui/widget/textwidget']=function() return T end
local I=W:extend{}
function I:paintTo(_,x,y) host_image(self.image.data,x,y,self.width,self.height) end
function I:free() end
package.preload['ui/widget/imagewidget']=function() return I end
package.preload['ui/renderimage']=function()
 return {renderImageData=function(_,data)
  return {data=data,getWidth=function() return 96 end,getHeight=function() return 96 end,free=function() end,
   scale=function(self) return self end}
 end}
end
local Device={screen_saver_mode=false,screen={getWidth=function() return 600 end,getHeight=function() return 800 end}}
package.preload['device']=function() return Device end
local U={queue={},dirty=true,full=true}
function U:scheduleIn(seconds,f) self.queue[#self.queue+1]={at=host_time()+seconds,f=f} end
function U:unschedule(f) for i=#self.queue,1,-1 do if self.queue[i].f==f then table.remove(self.queue,i) end end end
function U:setDirty(_,mode,region)
 self.dirty=true
 if not region or mode=='full' or mode=='flashui' then self.full=true end
end
function U:close(v) v:onCloseWidget();self.closed=true end
function U:show(message) if message.text then io.stderr:write(message.text..'\n') end end
package.preload['ui/uimanager']=function() return U end
package.preload['ui/widget/infomessage']=function() return W end
local E=dofile('game/engine.lua')
local S=dofile('game/storage.lua')
local F=dofile('game/filesystem.lua')
local R=dofile('game/reading.lua')
local V=dofile('game/view.lua')
local savepath=assert(S.location('data/pokepal.dat',F))
local session,err=S.open(savepath,{'data/pokepal.dat','/mnt/us/koreader/settings/pokepal.dat'},E,F)
if not session then error(err) end
local state=session.state or E.new(os.time());local notice=session.notice
local owner={savepath=savepath}
function owner:onPetClosed() if session then session.close();session=nil end end
function owner:save()
 local ok,err=S.save(savepath,state,E,host_sync_file,host_sync_directory)
 if not ok then
  io.stderr:write('Save failed: '..tostring(err)..'\n')
  if self.view then self.view.message='Save failed. Check the free space on your Kindle.' end
 end
 return ok,err
end
function owner:syncReading()
 local counters,status=R.scan('/mnt/us/documents',F)
 local ko,problem=R.counter(savepath..'.reading')
 local f=io.open(savepath..'.reading','rb');if f then f:close() end
 self.reading_status={status,problem and 'KOReader: reading data unavailable'
  or (f and 'KOReader: reading time available' or 'KOReader: open PokePal there once')}
 return R.collect(state,E,counters,ko,os.time())
end
function owner:toggleReading()
 self:syncReading();state.reading.enabled=not state.reading.enabled;return self:save()
end
local reward=owner:syncReading()
local saved,problem=owner:save();if not saved then owner:onPetClosed();error(problem) end
E.advance(state,os.time())
local view=V:new{state=state,engine=E,owner=owner,path='game'};owner.view=view
if reward or notice then view.message=reward or notice end
local bb={paintRect=function(_,...) host_rect(...) end}
function app_paint()
 view:paintTo(bb,0,0)
 local full=U.full;U.dirty=false;U.full=false
 return full
end
function app_tap(x,y) view:onTap(nil,{pos={x=x,y=y}}) end
function app_tick()
 local now=host_time()
 for i=#U.queue,1,-1 do local item=U.queue[i]
  if item.at<=now then table.remove(U.queue,i);item.f() end
 end
 return U.dirty, U.closed or false
end
function app_delay()
 local delay=60000
 for _,item in ipairs(U.queue) do delay=math.min(delay,math.max(0,math.ceil((item.at-host_time())*1000))) end
 return delay
end
function app_close() view:onSuspend();view:leave() end
-- Used by the native smoke test, with the same view and save path as the device build.
app={view=view,engine=E,storage=S,ui=U,state=state,owner=owner}
if state.species~=0 then view:animate(state.resting and 'ambient_sleep' or 'ambient') end
