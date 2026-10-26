local Dispatcher=require("dispatcher")
local Device=require("device")
local I={}
local welcome_key="pokepal_welcome_seen"

function I.attach(PokePal,UIManager)
 function PokePal:onDispatcherRegisterActions()
  Dispatcher:registerAction("pokepal_open",{
   category="none",event="PokePalOpen",title="Open PokePal",general=true,
  })
 end
 function PokePal:onPokePalOpen()
  self:openPet()
  return true
 end
 function PokePal:cancelWelcome()
  if self.welcome_task then UIManager:unschedule(self.welcome_task);self.welcome_task=nil end
 end
 function PokePal:markWelcomeSeen()
  self:cancelWelcome()
  if not G_reader_settings:isTrue(welcome_key) then G_reader_settings:saveSetting(welcome_key,true) end
 end
 function PokePal:scheduleWelcome()
  if self.closed or self.welcome_task or self.suspended or Device.screen_saver_mode or G_reader_settings:isTrue(welcome_key) then return end
  self.welcome_task=function()
   self.welcome_task=nil
   if self.closed or self.suspended or Device.screen_saver_mode or G_reader_settings:isTrue(welcome_key) then return end
   -- Both the file browser and a book can have a plugin instance.
   local reader=package.loaded["apps/reader/readerui"]
   local browser=package.loaded["apps/filemanager/filemanager"]
   local active=reader and reader.instance or browser and browser.instance
   if active~=self.ui then return end
   if self.pet_view or self.shortcut_dialog then return end
   local ButtonDialog=require("ui/widget/buttondialog")
   self:showShortcutDialog(ButtonDialog:new{
    modal=true,
    title="Welcome to PokePal\n\nYour partner is under Tools > PokePal. You can also choose a gesture or QuickMenu shortcut.",
    buttons={
     {{text="Open PokePal",callback=function() self:openPet() end}},
     {{text="Shortcut help",callback=function() self:showShortcutHelp() end}},
     {{text="Later",callback=function() self:closeShortcutDialog() end}},
    },
   })
   self:markWelcomeSeen()
  end
  UIManager:nextTick(self.welcome_task)
 end
 function PokePal:showShortcutDialog(dialog)
  self:closeShortcutDialog()
  self:pauseReading()
  self.shortcut_dialog=dialog
  local on_close=dialog.onCloseWidget
  dialog.onCloseWidget=function(widget)
   if self.shortcut_dialog==widget then
    self.shortcut_dialog=nil
    self:resumeReading()
   end
   return on_close(widget)
  end
  UIManager:show(dialog)
 end
 function PokePal:closeShortcutDialog()
  if self.shortcut_dialog then UIManager:close(self.shortcut_dialog) end
 end
 function PokePal:showShortcutHelp()
  if self.closed or self.suspended or Device.screen_saver_mode then return end
  self:markWelcomeSeen()
  local TextViewer=require("ui/widget/textviewer")
  self:showShortcutDialog(TextViewer:new{
   title="PokePal shortcuts",modal=true,show_menu=false,
   text="Open the game from Tools > PokePal.\n\n"..
    "For a gesture, open Settings > Taps and gestures > Gesture manager. Choose a gesture, then General > Open PokePal.\n\n"..
    "For a QuickMenu, add Open PokePal to the gesture's actions and turn on Show as QuickMenu.\n\n"..
    "Book and file-browser gestures are set separately. If Gesture manager is missing, enable Gestures in Plugin management and restart KOReader.\n\n"..
    "Hold the PokePal entry in Tools to see this help again.",
   buttons_table={{
    {text="Open PokePal",callback=function() self:openPet() end},
    {text="Close",callback=function() self:closeShortcutDialog() end},
   }},
  })
 end
end
return I
