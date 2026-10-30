-- Register once per KOReader process; plugin instances come and go with books.
local I={}
function I.attach(PokePal)
 local module,registry
 function PokePal:registerSimpleUIModule()
  local ok,r=pcall(require,"modules/moduleregistry")
  if not ok or type(r)~="table" or type(r.register)~="function" then return end
  local called,err=pcall(function()
   if not module then module=dofile(self.path.."/simpleui_module.lua") end
   module.player=self
   if registry~=r then r.register(module);registry=r end
  end)
  if not called then require("logger").warn("PokePal SimpleUI registration:",err) end
 end
 function PokePal:notifySimpleUIModule()
  if module then
   local ok,err=pcall(module.changed)
   if not ok then require("logger").warn("PokePal SimpleUI notification:",err) end
  end
 end
 function PokePal:pauseSimpleUIModule()
  if module then pcall(module.pause) end
 end
 function PokePal:onTeardown()
  self:pauseSimpleUIModule()
  if registry and module and registry.get(module.id)==module then registry.unregister(module.id) end
  registry=nil;module=nil
 end
end
return I
