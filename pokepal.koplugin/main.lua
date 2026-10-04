local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local DataStorage = require("datastorage")
local ffiUtil = require("ffi/util")
local InfoMessage = require("ui/widget/infomessage")
local PokePal = WidgetContainer:extend{name="pokepal",is_doc_only=false}

function PokePal:init()
 self.engine=dofile(self.path.."/engine.lua")
 self.storage=dofile(self.path.."/storage.lua")
 self.View=dofile(self.path.."/view.lua")
 self.ui.menu:registerToMainMenu(self)
end
function PokePal:addToMainMenu(items)
 items.pokepal={text="PokePal - Pokemon companion",sorting_hint="more_tools",callback=function() self:openPet() end}
end
function PokePal:openPet()
 if self.view then return end
 self.savepath=DataStorage:getSettingsDir().."/pokepal.dat"
 local notice
 self.state,notice=self.storage.load(self.savepath,self.engine)
 if not self.state and notice then
  UIManager:show(InfoMessage:new{text="PokePal: "..notice.." See the troubleshooting guide."})
  return
 end
 if not self.state then
  self.state=self.engine.new(os.time())
  self.engine.act(self.state,"choose",4,os.time())
  local ok=self:save()
  if not ok then
   UIManager:show(InfoMessage:new{text="PokePal could not create its save. Check free space on the Kindle."})
   return
  end
 end
 self.engine.advance(self.state,os.time())
 self.view=self.View:new{owner=self,engine=self.engine,state=self.state,path=self.path}
 if notice then self.view.message=notice end
 UIManager:show(self.view,"full")
 if self.state.species~=0 and (self.state.trip==0 or os.time()>=self.state.due) then
  self.view:animate(self.state.resting and "ambient_sleep" or "ambient")
 end
end
function PokePal:save()
 if self.savepath and self.state then
  local ok,err=self.storage.save(self.savepath,self.state,self.engine,ffiUtil.fsyncOpenedFile,ffiUtil.fsyncDirectory)
  if not ok then
   if self.view then self.view.message="Save failed. Exit and check free storage." end
   return nil,err
  end
 end
 return true
end
function PokePal:onSuspend()
 if self.view then self.view:onSuspend() end
end
function PokePal:onResume()
 if self.view then self.view:onResume() end
end
function PokePal:onClose()
 if self.view then self.view:leave() end
end
return PokePal
