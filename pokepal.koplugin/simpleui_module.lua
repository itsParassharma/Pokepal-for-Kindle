-- A SimpleUI external module. No changes to SimpleUI code or game save format.
local M={id="pokepal_partner",name="PokePal",category="extras",
 enabled_key="pokepal_partner_enabled",default_on=false}
local source=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
local Model=dofile(source.."/simpleui_model.lua")
local U=require("ui/uimanager")
local Device=require("device")
local views=setmetatable({},{__mode="k"})
local cache={}
local Card
local function setting(key,default)
 local value=G_reader_settings:readSetting("pokepal_simpleui_"..key)
 return value==nil and default or value
end
function M.detailed() return setting("detail",false)==true end
function M.animation(snapshot)
 local value=setting("animation",snapshot and snapshot.animation or "eco")
 return (value=="off" or value=="gentle") and value or "eco"
end
function M.owner()
 for _,key in ipairs({"apps/reader/readerui","apps/filemanager/filemanager"}) do
  local ui=package.loaded[key];local p=ui and ui.instance and ui.instance.pokepal
  if p and not p.closed then return p end
 end
 return M.player and not M.player.closed and M.player or nil
end
function M.snapshot()
 local p=M.owner()
 if cache.path~=(p and p.savepath) then cache={path=p and p.savepath} end
 local ok,s=pcall(Model.snapshot,p,cache)
 if not ok then
  require("logger").warn("PokePal SimpleUI snapshot:",s)
  return {message="Could not read PokePal. Tap to open."}
 end
 return s
end
function M.changed()
 for v in pairs(views) do v:queueUpdate() end
end
function M.pause()
 for v in pairs(views) do v:pause() end
end
function M.open()
 local p=M.owner()
 if p and not p.suspended and not Device.screen_saver_mode then p:openPet() end
end
function M.build(w,ctx)
 Card=Card or dofile(source.."/simpleui_card.lua")
 local v=Card:new{module=M,path=source,width=w,host=ctx._screen_widget,
  dirty=ctx.dirty_region_fn,detailed=M.detailed()}
 views[v]=true
 if ctx.kbStops then
  require("infra/sui_core").makeFocusable(v,function() v:onTapPokePal() end)
  ctx.kbStops(M.id,{{id="partner",widget=v}})
 end
 return v
end
function M.updateStats(widget)
 widget:queueUpdate();return false -- our deferred callback requests its own region
end
function M.getHeight() return Device.screen:scaleBySize(M.detailed() and 290 or 120) end
function M.getMenuItems(ctx)
 local function refresh() M.changed();if ctx.refresh then ctx.refresh() end end
 local animation={}
 for _,row in ipairs({{"Off","off"},{"Eco (2 frames)","eco"},{"Gentle (up to 4 frames)","gentle"}}) do
  local label,value=row[1],row[2]
  animation[#animation+1]={text=label,checked_func=function() return M.animation(M.snapshot())==value end,
   callback=function() G_reader_settings:saveSetting("pokepal_simpleui_animation",value);M.pause();refresh() end}
 end
 return {
  {text="Show care and progress",checked_func=M.detailed,callback=function()
   G_reader_settings:saveSetting("pokepal_simpleui_detail",not M.detailed());refresh()
  end},
  {text="Animation",sub_item_table=animation},
  {text="Open PokePal",callback=M.open},
  {text="About this card",callback=function()
   U:show(require("ui/widget/infomessage"):new{text="Follows your saved partner, XP and level. Care is calculated for now. Reading time waiting for rewards is labelled separately; open PokePal to collect it. Updates after saves and every minute while visible. Animations play once on arrival or a partner/mood change and stop while hidden or asleep."})
  end},
 }
end
return M
