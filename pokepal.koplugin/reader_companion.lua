-- KOReader integration uses its existing footer and screensaver lifecycle.
local I={}
function I.attach(PokePal,UIManager)
 function PokePal:companionState(callback)
  if self.session then callback(self.state);return self:save() end
  if not self.savepath then return end
  local session=self.storage.open(self.savepath,{},self.engine,self.fs,function() return self.backups:recover() end)
  if not session then return end
  local ok,err
  if session.state then
   self.state=session.state;callback(self.state)
   ok,err=self.storage.save(self.savepath,self.state,self.engine,require("ffi/util").fsyncOpenedFile,require("ffi/util").fsyncDirectory)
  end
  session.close();return ok,err
 end
 function PokePal:bookTitle()
  local settings=self.ui and self.ui.doc_settings
  local props=settings and settings:readSetting("doc_props")
  local title=props and props.title
  if type(title)=="string" and self.engine.companion.text.valid(title,100) then return title end
  return ""
 end
 function PokePal:updateCompanion()
  local footer=self.ui and self.ui.view and self.ui.view.footer
  if self.footer_owner and self.footer_owner~=footer then
   self.footer_owner:removeAdditionalFooterContent(self.footer_content);self.footer_owner=nil
  end
  if footer and footer.addAdditionalFooterContent and footer.removeAdditionalFooterContent then
   local enabled=self.document_open and self.state and self.engine.companion.option(self.state,"footer")
   if enabled and not self.footer_owner then
    self.footer_content=self.footer_content or function()
     local s=self.state;if not s or s.species==0 then return "" end
     local label=self.engine.displayName(s)
     if s.egg then
      local pending=math.max(0,(self.clock.total or s.reading.ko)+(self.clock.pending or 0)-s.reading.ko)
      if not s.reading.enabled then pending=0 end
      local progress=1-math.max(0,self.engine.eggLeft(s)-pending)/self.engine.egg_seconds
      label=label.." / egg "..math.floor(progress*100).."%"
     end
     return label
    end
    footer:addAdditionalFooterContent(self.footer_content);self.footer_owner=footer
   elseif not enabled and self.footer_owner then
    self.footer_owner:removeAdditionalFooterContent(self.footer_content);self.footer_owner=nil
   end
  end
 end
 function PokePal:sleepImage()
  local s=self.session and self.state or self.storage.load(self.savepath,self.engine)
  if not s or s.species==0 or not self.engine.companion.option(s,"sleep_screen") then return end
  local image,preview
  local painted,err=pcall(function()
   local BB=require("ffi/blitbuffer");local Device=require("device")
   image=BB.new(Device.screen:getWidth(),Device.screen:getHeight(),BB.TYPE_BB8)
   preview=self.View:new{owner={save=function() return true end},state=s,engine=self.engine,path=self.path}
   preview:paintSleep(image,false)
  end)
  if preview then preview:stopAnimation();preview:freeImages() end
  if not painted then
   if image then image:free() end
   error(err,0)
  end
  return image
 end
 function PokePal:installSleepScreen()
  if self.sleep_hook and self.sleep_hook.active then return end
  local ok,Screensaver=pcall(require,"ui/screensaver")
  if not ok or not Screensaver.setup then return end
  local previous=Screensaver.setup;self.screensaver=Screensaver;self.previous_setup=previous
  local hook={active=true};self.sleep_hook=hook
  self.sleep_setup=function(screen,event,...)
   local result=previous(screen,event,...)
   if not hook.active or event or screen.ui~=self.ui or not self.savepath then return result end
   -- This callback runs outside KOReader's plugin event error handler.
   local painted,image=pcall(self.sleepImage,self)
   if not painted then
    local logged,logger=pcall(require,"logger")
    if logged then logger.warn("PokePal: could not draw the sleep screen:",image) end
    return result
   end
   if not image then return result end
   if screen.image then screen.image:free() end
   screen.image=image;screen.image_file=nil;screen.screensaver_type="cover"
   screen.show_message=false;screen.overlay_message=nil;screen.screensaver_background="white"
   return result
  end
  Screensaver.setup=self.sleep_setup
 end
 function PokePal:detachCompanion()
  if self.sleep_hook then self.sleep_hook.active=false end
  if self.footer_owner then self.footer_owner:removeAdditionalFooterContent(self.footer_content);self.footer_owner=nil end
  if self.screensaver and self.screensaver.setup==self.sleep_setup then self.screensaver.setup=self.previous_setup end
  self.screensaver=nil;self.previous_setup=nil;self.sleep_setup=nil;self.sleep_hook=nil
 end
end
return I
