local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local Device = require("device")
local DataStorage = require("datastorage")
local ffiUtil = require("ffi/util")
local InfoMessage = require("ui/widget/infomessage")
-- watchers: callbacks run when the game closes, for views of the partner elsewhere
-- (the Bookshelf module) to redraw from the new save. Shared by every instance.
local PokePal = WidgetContainer:extend{name="pokepal",is_doc_only=false,watchers={}}

function PokePal:init()
 -- KOReader supplies self.view for the book. The game uses self.pet_view.
 self.engine=dofile(self.path.."/engine.lua")
 self.storage=dofile(self.path.."/storage.lua")
 self.fs=dofile(self.path.."/filesystem.lua")
 self.reading=dofile(self.path.."/reading.lua")
 self.timer=dofile(self.path.."/reading_timer.lua")
 self.clock=self.timer.new()
 if not Device:isKindle() then self.reading_status={"KOReader: tracks while you read"} end
 self.savepath,self.path_error=self.storage.location(DataStorage:getSettingsDir().."/pokepal.dat",self.fs)
 if self.savepath then self.counterpath=self.savepath..".reading";self.reading.loadCache(self.savepath..".scan-cache") end
 if self.savepath then
  self.backups=dofile(self.path.."/backups.lua").new(self.savepath,self.engine,self.reading,self.fs,ffiUtil.fsyncOpenedFile,ffiUtil.fsyncDirectory)
 end
 self:refreshCompanion()
 self.View=dofile(self.path.."/view.lua")
 self.ui.menu:registerToMainMenu(self)
 self:installSleepScreen()
 self:onDispatcherRegisterActions()
 self:scheduleWelcome()
 self:syncSimpleUI()
 self:registerSimpleUIModule()
end
function PokePal:addToMainMenu(items)
 items.pokepal={text="PokePal",sorting_hint="tools",callback=function() self:openPet() end,
  hold_callback=function() self:showShortcutHelp() end}
 self:addSimpleUIMenu(items)
end
function PokePal:openPet()
 if self.closed or self.suspended or Device.screen_saver_mode then return end
 self:closeShortcutDialog()
 if self.pet_view then return end
 if not self.savepath then UIManager:show(InfoMessage:new{text=self.path_error});return end
 self:markWelcomeSeen()
 self:pauseReading()
 local notice
 self.session,notice=self.storage.open(self.savepath,{DataStorage:getSettingsDir().."/pokepal.dat",
  "/mnt/us/extensions/pokepal/data/pokepal.dat"},self.engine,self.fs,function() return self.backups:recover() end)
 if not self.session then
  UIManager:show(InfoMessage:new{text="PokePal: "..notice});self:resumeReading()
  return
 end
 self.state=self.session.state or self.engine.new(os.time());notice=self.session.notice
 self:flushReading()
 self.recap=nil
 local visit=self.reading.visit(self.state)
 self.reading.init(self.state)
 self.engine.companion.resume(self.state,self.engine,os.time())
 self.engine.advance(self.state,os.time())
 if not self:save() then
  UIManager:show(InfoMessage:new{text="PokePal could not save. Check free space on the device."})
  self:onPetClosed();return
 end
 self.pet_view=self.View:new{owner=self,engine=self.engine,state=self.state,path=self.path}
 if notice then self.pet_view.message=notice end
 UIManager:show(self.pet_view,"full")
 self:startReadingScan(visit)
 if self.pet_view.screen=="home" and self.state.species~=0 and self.engine.tripLeft(self.state,os.time())==0 then
  self.pet_view:animate(self.state.resting and "ambient_sleep" or "ambient")
 end
end
function PokePal:flushReading()
 if not self.counterpath then return end
 -- Do not create or lock a counter when no reading needs saving.
 if self.clock.pending==0 and not self.reading_unsynced and not self.reading_error then return end
 if self.fs.mode(self.savepath..".restore") then self.reading_error="Reopen PokePal to finish restoring.";return end
 local pending=self.clock.pending
 local unlock,err=self.fs.lock(self.counterpath..".session")
 if not unlock then self.reading_error=err;return end
 local total,primary,days;total,err,primary,days=self.reading.counter(self.counterpath)
 if total then
  days=days or {};for day,n in pairs(self.clock.days or {}) do days[day]=(days[day] or 0)+n end
  local keys={};for day in pairs(days) do keys[#keys+1]=day end;table.sort(keys);while #keys>62 do days[table.remove(keys,1)]=nil end
  local saved,committed=primary and pending==0 and not self.reading_unsynced,false
  if not saved then
   saved,err,committed=self.reading.saveCounter(self.counterpath,total+pending,ffiUtil.fsyncOpenedFile,ffiUtil.fsyncDirectory,days)
   -- A renamed counter still needs a retry if its directory could not be synced.
   if saved then self.reading_unsynced=nil elseif committed then self.reading_unsynced=true end
  end
  if saved or committed then self.clock.pending=self.clock.pending-pending;self.clock.days={};self.clock.total=total+pending end
 end
 unlock();self.reading_error=err
 self:notifySimpleUIModule()
end
function PokePal:pauseReading()
 self.timer.pause(self.clock,os.time());self:flushReading()
end
function PokePal:resumeReading()
 if self.closed then return end
 self:scheduleWelcome()
 if self.document_open and not self.suspended and not Device.screen_saver_mode and not self.reading_paused and not self.pet_view and not self.shortcut_dialog then
  self.timer.resume(self.clock,self.clock.page,os.time())
 end
end
function PokePal:onReaderReady()
 self.document_open=true
 self:refreshCompanion()
 self:updateCompanion();self:resumeReading()
end
function PokePal:onPageUpdate(page)
 if not self.document_open then self.clock.page=page;return end
 if self.pet_view or self.shortcut_dialog or self.suspended or Device.screen_saver_mode or self.reading_paused then self.clock.page=page;return end
 self.timer.page(self.clock,page,os.time())
 if self.clock.pending>=60 then self:flushReading() end
end
function PokePal:onPosUpdate(_,page)
 -- Reflowable books emit PosUpdate instead of PageUpdate in scroll mode.
 self:onPageUpdate(page)
end
function PokePal:onReadingPaused()
 self.reading_paused=true;self:pauseReading()
end
function PokePal:onReadingResumed()
 self.reading_paused=false;self:resumeReading()
end
function PokePal:onCloseDocument()
 self.document_open=false;self:pauseReading()
 if self.footer_owner then self.footer_owner:removeAdditionalFooterContent(self.footer_content);self.footer_owner=nil end
end
function PokePal:onFlushSettings() self:flushReading() end
function PokePal:finishReadingScan(counters,status,visit)
 if counters then self.reading.saveCache() end
 local ko,err,primary,days=self.reading.counter(self.counterpath)
 self.reading_status={(err or self.reading_error) and "KOReader: could not save reading time" or "KOReader: automatic tracking on"}
 if status then table.insert(self.reading_status,1,status) end
 local message,recap=self.reading.collect(self.state,self.engine,counters,ko,os.time(),days,visit)
 if recap then self.recap=recap end
 return message
end
function PokePal:cancelReadingScan()
 if self.scan_step then UIManager:unschedule(self.scan_step) end
 self.scan_step=nil;self.reading_busy=false
end
function PokePal:startReadingScan(visit)
 visit=visit or self.reading.visit(self.state)
 self:cancelReadingScan();self.reading_busy=true
 -- Native reading records only exist on Kindle. Keep KOReader collection on
 -- every host; nil counters leave a migrated save's Kindle baseline intact.
 local step=Device:isKindle() and self.reading.scanAsync("/mnt/us/documents",self.fs) or function() return true end
 self.scan_step=function()
  if not self.pet_view or self.suspended then self:cancelReadingScan();return end
  local done,counters,status=step()
  if done then
   self:cancelReadingScan();self:finishReadingScan(counters,status,visit);self:save()
   self.pet_view:freeImages();UIManager:setDirty(self.pet_view,"ui")
  else UIManager:scheduleIn(0.01,self.scan_step) end
 end
 UIManager:scheduleIn(0.05,self.scan_step)
end
function PokePal:syncReading()
 self:cancelReadingScan()
 if not Device:isKindle() then return self:finishReadingScan() end
 return self:finishReadingScan(self.reading.scan("/mnt/us/documents",self.fs))
end
function PokePal:rescanReading() self.reading.clearCache();self:startReadingScan() end
function PokePal:toggleReading()
 self:syncReading();self.state.reading.enabled=not self.state.reading.enabled
 return self:save()
end
function PokePal:onPetClosed()
 self:cancelReadingScan();self:updateCompanion()
 if self.session then self.session.close();self.session=nil end
 self:resumeReading()
 self:notifySimpleUIModule()
 if not self.closed and next(self.watchers) then
  UIManager:nextTick(function()
   if self.closed or self.suspended or Device.screen_saver_mode then return end
   for _,fn in pairs(self.watchers) do pcall(fn) end
  end)
 end
end
function PokePal:save()
 if self.backups and self.backups.blocked then return nil,"Reopen PokePal to finish restoring." end
 if self.savepath and self.state then
  local ok,err=self.storage.save(self.savepath,self.state,self.engine,ffiUtil.fsyncOpenedFile,ffiUtil.fsyncDirectory)
  self.save_error=not ok
  if not ok then return nil,err end
  self:syncSimpleUI()
  self:notifySimpleUIModule()
 end
 return true
end
function PokePal:onSuspend()
 self.suspended=true;self:pauseReading();self:cancelReadingScan()
 self:pauseSimpleUIModule()
 if self.pet_view then self.pet_view:onSuspend()
 elseif self.state and self.engine.companion.option(self.state,"auto_rest") then
  self:companionState(function(s) self.engine.companion.suspend(s,self.engine,os.time()) end)
 end
end
function PokePal:onResume()
 local visit=self.state and self.reading.visit(self.state)
 if not self.pet_view then
  -- Pick up changes from KUAL, but only write when a partner needs waking.
  self:refreshCompanion()
  if self.state and self.state.companion and self.state.companion.sleep then
   self:companionState(function(s) self.engine.companion.resume(s,self.engine,os.time()) end)
  end
 end
 self.suspended=false;self:updateCompanion();self:resumeReading()
 if self.pet_view then self.pet_view:onResume();self:startReadingScan(visit) end
 self:syncSimpleUI()
 self:notifySimpleUIModule()
end
function PokePal:onClose()
 self.closed=true;self:cancelWelcome();self:closeShortcutDialog()
 self:pauseSimpleUIModule()
 self:detachCompanion();self:cancelReadingScan()
 self.document_open=false;self:pauseReading()
 if self.pet_view then self.pet_view:leave() end
 self:onPetClosed()
end
function PokePal:onCloseWidget()
 -- Closing a book or the file browser sends CloseWidget, not Close.
 self:onClose()
end
dofile(debug.getinfo(1,"S").source:sub(2):match("^(.*)/").."/reader_companion.lua").attach(PokePal,UIManager)
dofile(debug.getinfo(1,"S").source:sub(2):match("^(.*)/").."/shortcuts.lua").attach(PokePal,UIManager)
dofile(debug.getinfo(1,"S").source:sub(2):match("^(.*)/").."/simpleui_menu.lua").attach(PokePal,UIManager)
dofile(debug.getinfo(1,"S").source:sub(2):match("^(.*)/").."/simpleui_link.lua").attach(PokePal,UIManager)
return PokePal
