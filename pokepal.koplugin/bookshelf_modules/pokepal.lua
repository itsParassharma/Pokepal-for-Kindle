-- Your partner on the Bookshelf home screen, with no card behind it.
-- Bookshelf loads this file from every plugin's bookshelf_modules folder.
-- Read only: the game keeps the save lock, so this never writes the save.
local dir=(...):match("^(.*)/bookshelf_modules$") or ((...).."/..")
local E,S,F
local cache={}
local views=setmetatable({},{__mode="k"})
local function load()
 if not E then
  E=dofile(dir.."/engine.lua");S=dofile(dir.."/storage.lua");F=dofile(dir.."/filesystem.lua")
 end
 if not cache.path then
  cache.path=S.location(require("datastorage"):getSettingsDir().."/pokepal.dat",F)
 end
 if not cache.path then return nil end
 return S.load(cache.path,E,cache)
end
-- Stats as the game would show them now. The copy keeps the cached save as read.
local function current(s)
 local function copy(t) local o={};for k,v in pairs(t) do o[k]=type(v)=="table" and copy(v) or v end;return o end
 local now=copy(s);E.advance(now,os.time());return now
end
local function pose(s)
 if s.trip>0 then return "walk" end
 return s.resting and "sleep" or "idle"
end
-- The packed PNG for this partner. The index is large, so it is not kept.
local function sprite(id,want)
 local key=id.."-"..want
 if cache.png_key==key then return cache.png end
 local sprites=dofile(dir.."/assets/sprites.lua")
 for _,name in ipairs({id.."-"..want.."-1.png",id.."-idle-1.png",id.."-1.png"}) do
  if sprites.index[name] then
   cache.png_key,cache.png=key,sprites.read(dir.."/assets",name);return cache.png
  end
 end
end
-- Every partner is fitted into the same 80px box, feet on its bottom edge
-- (tools/import_kanto.py), so drawing that box keeps them all to one scale.
local BOX={8,10,80,80}
-- Room left above the largest partner, so it stands among the books rather than filling its space.
local SHARE=0.8
local function picture(data,size)
 local RenderImage=require("ui/renderimage");local BB=require("ffi/blitbuffer")
 local raw=RenderImage:renderImageData(data,#data,false)
 if not raw then return nil end
 local part=BB.new(BOX[3],BOX[4],raw:getType());part:blitFrom(raw,0,0,BOX[1],BOX[2],BOX[3],BOX[4]);raw:free()
 size=math.max(1,math.floor(size))
 local image=part
 if size~=BOX[3] then image=part:scale(size,size);part:free() end
 return require("ui/widget/imagewidget"):new{image=image,image_disposable=true,alpha=true,width=size,height=size,scale_for_dpi=false}
end
-- Before a partner is chosen: a line saying what a tap does, over the game's egg.
-- No text box behind it, as the partner has no card; above the egg, so it clears a plank.
local function placeholder(w,h,scale,Container)
 local BB=require("ffi/blitbuffer");local Kit=require("lib/bookshelf_module_kit")
 local rows=dofile(dir.."/art.lua").icons.egg
 local p=math.max(1,math.floor(math.min(w,h)*0.4/#rows))
 local egg=BB.new(#rows[1]*p,#rows*p,BB.TYPE_BB8A)
 for y,row in ipairs(rows) do for x=1,#row do
  if row:sub(x,x)=="#" then egg:paintRect((x-1)*p,(y-1)*p,p,p,BB.Color8A(0,255)) end
 end end
 local VerticalGroup=require("ui/widget/verticalgroup");local Geom=require("ui/geometry")
 local col=VerticalGroup:new{align="center",
  require("ui/widget/textwidget"):new{text="Tap to choose a partner",face=Kit.face(14,scale),fgcolor=Kit.COLOR_MUTED,max_width=w,padding=0},
  require("ui/widget/verticalspan"):new{width=p*2},
  require("ui/widget/imagewidget"):new{image=egg,image_disposable=true,alpha=true,width=egg:getWidth(),height=egg:getHeight(),scale_for_dpi=false}}
 return Container:new{dimen=Geom:new{w=w,h=h},col}
end
-- Name, level, mood and the four care bars, for a card with room beside the partner.
local function stats(s,width,scale)
 local Kit=require("lib/bookshelf_module_kit")
 local TextWidget=require("ui/widget/textwidget")
 local VerticalGroup=require("ui/widget/verticalgroup")
 local HorizontalGroup=require("ui/widget/horizontalgroup")
 local VerticalSpan=require("ui/widget/verticalspan")
 local HorizontalSpan=require("ui/widget/horizontalspan")
 local CenterContainer=require("ui/widget/container/centercontainer")
 local LeftContainer=require("ui/widget/container/leftcontainer")
 local Geom=require("ui/geometry")
 local sc=Kit.sc(scale);local now=current(s)
 local function text(t,size,bold,color,w)
  return TextWidget:new{text=t,face=Kit.face(size,scale),bold=bold,fgcolor=color or Kit.COLOR_PRIMARY,max_width=w or width,padding=0}
 end
 local col=VerticalGroup:new{align="left",
  text(E.displayName(now),22,true),
  text("Lv "..E.level(now).." / "..E.mood(now,os.time()),15,false,Kit.COLOR_MUTED),
  VerticalSpan:new{width=sc(10)}}
 local label_w=0;local labels={}
 for i,row in ipairs({{"Food",now.food},{"Joy",now.joy},{"Energy",now.energy},{"Hygiene",100-now.dirt}}) do
  labels[i]={text(row[1],14,false,Kit.COLOR_MUTED),row[2]};label_w=math.max(label_w,labels[i][1]:getSize().w)
 end
 local gap=sc(16);local bar_w=math.max(sc(20),width-label_w-gap);local bar_h=math.max(2,sc(7))
 for _,l in ipairs(labels) do
  local h=l[1]:getSize().h
  col[#col+1]=HorizontalGroup:new{align="center",
   LeftContainer:new{dimen=Geom:new{w=label_w,h=h},l[1]},HorizontalSpan:new{width=gap},
   CenterContainer:new{dimen=Geom:new{w=bar_w,h=h},Kit.progressBar{width=bar_w,height=bar_h,fraction=math.max(0,math.min(1,l[2]/100))}}}
 end
 return col
end
local function game()
 local reader=package.loaded["apps/reader/readerui"]
 local browser=package.loaded["apps/filemanager/filemanager"]
 local ui=reader and reader.instance or browser and browser.instance
 return ui and ui.pokepal
end
local function open()
 local p=game()
 if p then p:openPet() end
end
local function refresh()
 if not next(views) then return end
 local p=game()
 if require("device").screen_saver_mode or p and (p.closed or p.suspended) then return end
 if not pcall(load) then return end
 local U=require("ui/uimanager")
 -- A refresh may replace several widgets. Visit only those present at the start.
 local pending={};for widget in pairs(views) do pending[#pending+1]=widget end
 for _,widget in ipairs(pending) do
  local watch=widget._pokepal_watch
  if watch then
   if watch.bw._closed then views[widget]=nil;widget._pokepal_watch=nil
   elseif watch.revision~=cache.revision and U:getTopmostVisibleWidget()==(watch.bw._micro_fullscreen or watch.bw) then
    if pcall(watch.refresh) then watch.revision=cache.revision end
   end
  end
 end
end
-- The widget owns its callback; the shared watcher keeps only weak widget keys.
local function watch(ctx,widget)
 local p=game()
 if p and type(p.watchers)=="table" and ctx.bw and ctx.refresh and not ctx.preview then
  widget._pokepal_watch={bw=ctx.bw,refresh=ctx.refresh,revision=cache.revision}
  views[widget]=true;p.watchers["bookshelf:partner"]=refresh
  local free=widget.free
  function widget:free(...)
   views[self]=nil;self._pokepal_watch=nil
   if free then return free(self,...) end
  end
 end
 return widget
end
return {
 key="pokepal_partner",
 title="PokePal",
 summary="Your PokePal partner, with no card. Works offline.",
 hero_only=true,
 bare=true,
 aspect="square",
 start_w=1,
 start_h=1,
 render=function(ctx)
  local w=math.max(50,ctx.width)
  local h=(ctx.height and ctx.height>0) and ctx.height or w
  local ok,s=pcall(load)
  s=ok and s or nil
  local id=s and s.species~=0 and s.species or (ctx.preview and 25)
  local Kit=require("lib/bookshelf_module_kit")
  local Geom=require("ui/geometry")
  -- On a spine shelf the partner stands on the plank, like the books beside it.
  -- Bookshelf before ctx.shelf_view does not say which shelf, so it stands on any shelf.
  local plank=ctx.shelf_view=="spines" or (ctx.surface=="shelf" and ctx.shelf_view==nil)
  local Container=require(plank and "ui/widget/container/bottomcontainer" or "ui/widget/container/centercontainer")
  if not id then return watch(ctx,placeholder(w,h,ctx.scale,Container)) end
  local data=sprite(id,s and s.species==id and pose(s) or "idle")
  if not data then return nil end
  -- A wide space has room for the partner's stats beside it.
  local side=s and s.species==id and not ctx.preview and Kit.shape(w,h)=="wide" and math.floor(math.min(h*SHARE,w*0.45))
  if side then
   -- Margins follow the partner's size, so the text keeps its room at any cell size.
   local pad=math.floor(side*0.08);local gap=math.floor(pad*1.5);local text_w=w-side-gap-pad
   local img=picture(data,side)
   if not img then return nil end
   local HorizontalGroup=require("ui/widget/horizontalgroup")
   local HorizontalSpan=require("ui/widget/horizontalspan")
   -- The partner's space fills the height, so the host never grows the text: size it to that space.
   local col=stats(s,text_w,ctx.scale)
   -- Standing on a plank, the text ends above it: the partner's feet are on the plank's front.
   local target=plank and side*0.8-pad or side*0.85
   local k=math.max(0.6,math.min(3,target/math.max(1,col:getSize().h)))
   if k<0.95 or k>1.05 then col=stats(s,text_w,math.floor(ctx.scale*k)) end
   -- On a spine shelf the text hangs from the top, clear of the plank the partner stands on.
   if plank then
    col=require("ui/widget/verticalgroup"):new{align="left",require("ui/widget/verticalspan"):new{width=pad},col}
   end
   local row=HorizontalGroup:new{align=plank and "top" or "center",
    Container:new{dimen=Geom:new{w=side,h=side},img},HorizontalSpan:new{width=gap},col,HorizontalSpan:new{width=pad}}
   return watch(ctx,Container:new{dimen=Geom:new{w=w,h=math.max(h,row:getSize().h)},row})
  end
  -- In the module picker the partner gets a little more room round it, as other pieces do.
  -- Sized by the height (a shelf's row), so a partner is the same size in a narrow space or a wide one.
  local img=picture(data,ctx.preview and math.min(w,h)*0.65 or math.min(w,h*SHARE))
  if not img then return nil end
  return watch(ctx,Container:new{dimen=Geom:new{w=w,h=h},img})
 end,
 -- Pick up a new partner or a nap after the game saves, without redrawing otherwise.
 on_minute=refresh,
 on_tap=function() open() end,
}
