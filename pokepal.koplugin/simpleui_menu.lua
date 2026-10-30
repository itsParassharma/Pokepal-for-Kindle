-- KOReader-only controls for the optional Tiny Critter image export.
local M={}
local SYNC="pokepal_simpleui_sync"
local MOOD="pokepal_simpleui_mood"
function M.attach(PokePal,UIManager)
 local function enabled(key) return G_reader_settings:isTrue(key) end
 function PokePal:exportSimpleUI(follow_mood)
  if not self.savepath or self.fs.mode(self.savepath..".restore") then
   return nil,"Reopen PokePal to finish loading your save."
  end
  self.simpleui_critter=self.simpleui_critter or dofile(self.path.."/simpleui_critter.lua")
  local export=self.simpleui_critter
  local settings=require("datastorage"):getSettingsDir()
  local sync=require("ffi/util")
  -- Read the committed save, including changes made by the standalone game.
  local state,notice=self.storage.load(self.savepath,self.engine)
  if not state then return nil,notice or "Choose a PokePal partner first." end
  local ok,changed,published=export.export{plugin=self.path,settings=settings,state=state,
   engine=self.engine,fs=self.fs,follow_mood=follow_mood,
   syncfile=sync.fsyncOpenedFile,syncdir=sync.fsyncDirectory}
  -- A directory-sync error can follow a completed promotion. Refresh those
  -- images too, while still reporting the durability error to the user.
  if changed==true or published then export.refreshLoadedAssets(settings) end
  if ok then self.simpleui_error=nil end
  return ok,changed
 end
 function PokePal:syncSimpleUI(manual,follow_mood)
  if not manual and (not enabled(SYNC) or self.closed or self.suspended or require("device").screen_saver_mode) then return end
  if follow_mood==nil then follow_mood=enabled(MOOD) end
  -- An optional export failure must never turn a successful game save into a failure.
  local called,ok,detail=pcall(self.exportSimpleUI,self,follow_mood)
  if not called then detail=ok;ok=nil end
  if not ok then self.simpleui_error=tostring(detail or "Could not export the critter.") end
  return ok,detail
 end
 function PokePal:addSimpleUIMenu(items)
  local function show(text)
   UIManager:show(require("ui/widget/infomessage"):new{text=text})
  end
  local function export(follow_mood)
   local ok=self:syncSimpleUI(true,follow_mood)
   if ok then show("Exported PokePal partner. In SimpleUI, add Tiny Critter and choose Pokepal partner in its Critter picker. Reopen the home screen to see changes.")
   else show("PokePal: "..self.simpleui_error) end
   return ok
  end
  items.pokepal_simpleui={text="PokePal: SimpleUI Tiny Critter",sorting_hint="tools",sub_item_table={
   {text="Export selected Pokémon",callback=function() export() end},
   {text="Keep Pokémon in sync",checked_func=function() return enabled(SYNC) end,callback=function()
    if enabled(SYNC) then G_reader_settings:saveSetting(SYNC,false)
    elseif export() then G_reader_settings:saveSetting(SYNC,true) end
   end},
   {text="Use PokePal mood image",checked_func=function() return enabled(MOOD) end,callback=function()
    local value=not enabled(MOOD)
    if export(value) then G_reader_settings:saveSetting(MOOD,value) end
   end},
   {text="About this integration",callback=function()
    show("Requires a SimpleUI build with Tiny Critter (tested against 3.0.1). Sync updates images after PokePal saves and when KOReader starts or resumes. Mood image uses PokePal's pose for every SimpleUI expression. Dialogue, mood score, XP and reading progress stay separate. No animations or background polling. Turning sync off keeps the last export."..(self.simpleui_error and "\n\nLast export error: "..self.simpleui_error or ""))
   end},
  }}
 end
end
return M
