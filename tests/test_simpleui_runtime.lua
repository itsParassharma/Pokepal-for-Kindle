-- Actual upstream Tiny Critter discovery, cache and drawing in KOReader.
-- Pass the absolute plugin path and an extracted SimpleUI *.koplugin path.
io.stdout:setvbuf('line')
require('setupkoenv')
assert(os.getenv('KO_HOME'),'Use a fresh KO_HOME')
local DataStorage=require('datastorage')
local settings=DataStorage:getSettingsDir()
assert(not io.open(settings..'/pokepal.dat','rb'),'Use an empty KO_HOME')
G_defaults=require('luadefaults'):open()
G_reader_settings=require('luasettings'):open(DataStorage:getDataDir()..'/settings.reader.lua')
local Device=require('device')
require('document/canvascontext'):init(Device)
require('ui/bidi').setup()
local plugin,sui=assert(arg[1]),assert(arg[2])
package.path=sui..'/?.lua;'..package.path
local C=dofile(plugin..'/simpleui_critter.lua')
local E=dofile(plugin..'/engine.lua')
local F=dofile(plugin..'/filesystem.lua')
local S=dofile(plugin..'/storage.lua')
local sync=require('ffi/util')
local Assets=require('modules/critter/assets')
local Sprite=require('modules/critter/sprite')
local BB=require('ffi/blitbuffer')
local RenderImage=require('ui/renderimage')
local ffi=require('ffi')
local function bytes(bb) return ffi.string(bb.data,bb.stride*bb.h) end
local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
assert(Assets.userDir()==settings..'/simpleui/sui_critters')
Assets.list() -- prime the listing before installing
local state=E.new(os.time());E.act(state,'choose',25,os.time())
local opts={plugin=plugin,settings=settings,state=state,engine=E,fs=F,syncfile=sync.fsyncOpenedFile,syncdir=sync.fsyncDirectory}
assert(S.save(settings..'/pokepal.dat',state,E,sync.fsyncOpenedFile,sync.fsyncDirectory))
local save=read(settings..'/pokepal.dat')
assert(C.export(opts));C.refreshLoadedAssets(settings)
local Store=require('infra/sui_store')
Store:set('simpleui_hs_critter_pick','pokepal_partner') -- 3.0.1 picker
Store:set('simpleui_critter_cfg_pick','pokepal_partner') -- current main picker
Store:set('simpleui_critter_mood',{score=61,day=os.date('%Y-%m-%d')})
local prefs=read(settings..'/simpleui/sui_settings.lua')
local entry=assert(Assets.get('pokepal_partner'));assert(entry.id=='pokepal_partner')
local painted=0
for id=1,386 do
 local files=assert(C.images(plugin,id))
 for _,mood in ipairs(C.moods) do
  local data=files[mood..'.png'];local bb=assert(RenderImage:renderImageData(data,#data,false))
  assert(bb:getWidth()==64 and bb:getHeight()==64);bb:free();painted=painted+1
 end
end
local function draw(path)
 local widget=Sprite:new{path=path,max_w=128,max_h=128}
 assert(widget.dimen.w==128 and widget.dimen.h==128 and widget.pixel==2)
 local bb=BB.new(128,128,BB.TYPE_BB8);bb:fill(BB.COLOR_WHITE);widget:paintTo(bb,0,0)
 local result=bytes(bb);if widget.free then widget:free() end;bb:free();return result
end
for _,mood in ipairs(C.moods) do assert(draw(Assets.imagePath(entry,mood))) end
local path=Assets.imagePath(entry,'neutral')
local before=draw(path)
-- Force identical mtimes to exercise cache notification, not timestamp luck.
local lfs=require('libs/libkoreader-lfs')
local stamp=lfs.attributes(path,'modification')
state.species=7;assert(C.export(opts))
for _,mood in ipairs(C.moods) do assert(lfs.touch(Assets.imagePath(entry,mood),stamp,stamp)) end
C.refreshLoadedAssets(settings);assert(draw(path)~=before,'same-second update retained the old Pokemon')
opts.follow_mood=true;state.resting=true;assert(C.export(opts));C.refreshLoadedAssets(settings)
local expected=draw(Assets.imagePath(entry,'sleepy'))
for _,mood in ipairs(C.moods) do assert(draw(Assets.imagePath(entry,mood))==expected) end
assert(read(settings..'/pokepal.dat')==save,'export changed the save')
assert(read(settings..'/simpleui/sui_settings.lua')==prefs,'export changed SimpleUI settings or mood')
-- Exercise the actual upstream bubble, sprite and layout together.
local Critter=require('modules/critter/module_critter')
local widget=Critter.build(560,{pfx='simpleui_hs_',stats_stale=true,stats={}})
assert(widget)
local bb=BB.new(600,300,BB.TYPE_BB8);bb:fill(BB.COLOR_WHITE)
widget:paintTo(bb,20,20)
if arg[3] then bb:writePNG(arg[3]) end
widget:free();bb:free()
print('SIMPLEUI UPSTREAM RUNTIME: '..painted..' images decoded; picker, all moods, same-second cache refresh, settings/save preservation and actual critter row passed')
require('ui/uimanager'):quit()
