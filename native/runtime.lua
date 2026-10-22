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
local V=dofile('game/view.lua')
local state,notice=S.load('data/pokepal.dat',E)
if not state and notice then error(notice) end
state=state or E.new(os.time())
local owner={}
function owner:save()
 local ok,err=S.save('data/pokepal.dat',state,E,host_sync_file,host_sync_directory)
 if not ok then
  io.stderr:write('Save failed: '..tostring(err)..'\n')
  if self.view then self.view.message='Save failed. Check the free space on your Kindle.' end
 end
 return ok,err
end
assert(owner:save())
E.advance(state,os.time())
local view=V:new{state=state,engine=E,owner=owner,path='game'};owner.view=view
if notice then view.message=notice end
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
