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
local U={queue={},dirty=true,full=true,redraw=true}
function U:scheduleIn(seconds,f) self.queue[#self.queue+1]={at=host_time()+seconds,f=f} end
function U:unschedule(f) for i=#self.queue,1,-1 do if self.queue[i].f==f then table.remove(self.queue,i) end end end
function U:setDirty(_,mode,region)
 self.dirty=true
 if mode=='full' or mode=='flashui' then self.full=true end
 if not region or self.full then self.redraw=true;self.region=nil
 elseif not self.redraw then self.region=region end
end
function U:close(v) v:onCloseWidget();self.closed=true end
function U:show(message) if message.text then io.stderr:write(message.text..'\n') end end
package.preload['ui/uimanager']=function() return U end
package.preload['ui/widget/infomessage']=function() return W end
local E=dofile('game/engine.lua')
local S=dofile('game/storage.lua')
local F=dofile('game/filesystem.lua')
local R=dofile('game/reading.lua')
local savepath=assert(S.location('data/pokepal.dat',F))
local backups=dofile('game/backups.lua').new(savepath,E,R,F,host_sync_file,host_sync_directory)
local session,err=S.open(savepath,{'data/pokepal.dat','/mnt/us/koreader/settings/pokepal.dat'},E,F,function() return backups:recover() end)
if not session then error(err) end
local state=session.state or E.new(os.time());local notice=session.notice
local owner={savepath=savepath,backups=backups,native=true}
function owner:onPetClosed() self:cancelReadingScan();if session then session.close();session=nil end end
function owner:save()
 if backups.blocked then return nil,'Reopen PokePal to finish restoring.' end
 local ok,err=S.save(savepath,state,E,host_sync_file,host_sync_directory)
 self.save_error=not ok
 if not ok then
  io.stderr:write('Save failed: '..tostring(err)..'\n')
 end
 return ok,err
end
function owner:syncReading()
 self:cancelReadingScan()
 local counters,status=R.scan('/mnt/us/documents',F)
 return self:finishReadingScan(counters,status)
end
function owner:finishReadingScan(counters,status,visit)
 if counters then R.saveCache() end
 local ko,problem,primary,days=R.counter(savepath..'.reading')
 local f=io.open(savepath..'.reading','rb');if f then f:close() end
 self.reading_status={status,problem and 'KOReader: reading data unavailable'
  or (f and 'KOReader: reading time available' or 'KOReader: open PokePal there once')}
 local message,recap=R.collect(state,E,counters,ko,os.time(),days,visit)
 if recap then self.recap=recap end
 return message
end
function owner:rescanReading() R.clearCache();self:startReadingScan() end
function owner:toggleReading()
 self:syncReading();state.reading.enabled=not state.reading.enabled;return self:save()
end
function owner:cancelReadingScan()
 if self.scan_step then U:unschedule(self.scan_step) end
 self.scan_step=nil;self.reading_busy=false
end
function owner:startReadingScan(visit)
 visit=visit or R.visit(state)
 self:cancelReadingScan();self.reading_busy=true
 local step=R.scanAsync('/mnt/us/documents',F)
 self.scan_step=function()
  if not self.pet_view or self.pet_view.closed then self:cancelReadingScan();return end
  local done,counters,status=step()
  if done then self:cancelReadingScan();self:finishReadingScan(counters,status,visit);self:save();self.pet_view:freeImages();U:setDirty(self.pet_view,'ui')
  else U:scheduleIn(0.01,self.scan_step) end
 end
 U:scheduleIn(0.05,self.scan_step)
end
R.loadCache(savepath..".scan-cache")
local visit=R.visit(state)
R.init(state)
if host_mode~='suspend' then E.companion.resume(state,E,os.time()) end
E.advance(state,os.time())
local saved,problem=owner:save();if not saved then owner:onPetClosed();error(problem) end
if host_mode=='suspend' or host_mode=='resume' then
 if host_mode=='suspend' then E.companion.suspend(state,E,os.time()) end
 if not E.companion.option(state,'auto_rest') then os.remove('data/sleep-enabled') end
 local ok,why=owner:save();owner:onPetClosed();if not ok then error(why) end
 return
end
local V=dofile('game/view.lua')
local view=V:new{state=state,engine=E,owner=owner,path='game'};owner.pet_view=view
if notice then view.message=notice end
local bb={paintRect=function(_,...) host_rect(...) end}
function app_paint()
 local region=not U.redraw and U.region
 if region then view:paintStage(bb) else view:paintTo(bb,0,0) end
 local full=U.full;U.dirty=false;U.full=false;U.redraw=false;U.region=nil
 return full,region and region.x or 0,region and region.y or 0,region and region.w or 600,region and region.h or 800
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
 local delay=-1
 for _,item in ipairs(U.queue) do local wait=math.max(0,math.ceil((item.at-host_time())*1000));delay=delay<0 and wait or math.min(delay,wait) end
 return delay
end
function owner:updateCompanion()
 if E.companion.option(state,'auto_rest') then
  local f=io.open('data/sleep-enabled','w');if f then f:write('1\n');f:close() end
 else os.remove('data/sleep-enabled') end
end
function app_suspend()
 owner:cancelReadingScan();view:onSuspend()
end
function app_close()
 owner:cancelReadingScan();owner:updateCompanion();view:leave()
end
-- Used by the native smoke test, with the same view and save path as the device build.
app={view=view,engine=E,storage=S,ui=U,state=state,owner=owner}
owner:startReadingScan(visit)
if view.screen=='home' and state.species~=0 and E.tripLeft(state,os.time())==0 then view:animate(state.resting and 'ambient_sleep' or 'ambient') end
