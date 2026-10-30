-- Real KOReader widgets, scheduler, image buffers and upstream SimpleUI registry.
io.stdout:setvbuf('line')
require('setupkoenv')
assert(os.getenv('KO_HOME'),'Use a fresh KO_HOME')
local DS=require('datastorage');local settings=DS:getSettingsDir()
G_defaults=require('luadefaults'):open()
G_reader_settings=require('luasettings'):open(DS:getDataDir()..'/settings.reader.lua')
local Device=require('device');require('document/canvascontext'):init(Device);require('ui/bidi').setup()
local plugin,sui=assert(arg[1]),assert(arg[2]);package.path=sui..'/?.lua;'..package.path
local U=require('ui/uimanager');local time=require('ui/time');local BB=require('ffi/blitbuffer')
local Geom=require('ui/geometry');local Event=require('ui/event')
local E=dofile(plugin..'/engine.lua');local S=dofile(plugin..'/storage.lua')
local F=dofile(plugin..'/filesystem.lua');local R=dofile(plugin..'/reading.lua')
assert(F.mkdir(settings..'/simpleui'))
local Model=dofile(plugin..'/simpleui_model.lua');local P=dofile(plugin..'/main.lua')
local Registry=require('modules/moduleregistry');local Store=require('infra/sui_store')
local real_time=os.time;local now=real_time();os.time=function(t) return t and real_time(t) or now end
local state=E.new(now);E.act(state,'choose',25,now);R.init(state);state.reading.ko_ready=true
local p=setmetatable({path=plugin,savepath=settings..'/pokepal.dat',engine=E,storage=S,fs=F,reading=R,state=state}, {__index=P})
local opened=0;p.openPet=function() opened=opened+1 end
assert(S.save(p.savepath,state,E))
local function read(path) local f=assert(io.open(path,'rb'));local b=f:read('*a');f:close();return b end
local function write(path,b) local f=assert(io.open(path,'wb'));assert(f:write(b));assert(f:close()) end
local function pump(dt) U:shiftScheduledTasksBy(-time.s(dt or .1));U:_checkTasks();U:_repaint() end
local function checks(name,fn) fn();print('PASS SimpleUI module: '..name) end
local save=read(p.savepath)
p:registerSimpleUIModule();local M=assert(Registry.get('pokepal_partner'))
Store:set('pokepal_unrelated_test','untouched')
Store:flush()
local prefs=read(settings..'/simpleui/sui_settings.lua')
checks('external registration is idempotent and off by default',function()
 p:registerSimpleUIModule();assert(Registry.get(M.id)==M)
 local n=0;for _,m in ipairs(Registry.list()) do if m.id==M.id then n=n+1 end end
 assert(n==1 and not Registry.isEnabled(M,'simpleui_hs_'))
 assert(read(p.savepath)==save)
end)
checks('care advances without inventing XP or mutating a save',function()
 local c={};local s=Model.snapshot(p,c,now+3600)
 assert(s.care[1][2]<80 and s.xp==state.xp and s.level==E.level(state))
 assert(read(p.savepath)==save and S.encode(state)==save)
 state.trip=1;state.due=now+60;state.finds=0
 assert(S.save(p.savepath,state,E));local before=read(p.savepath)
 s=Model.snapshot(p,c,now+3600);assert(s.xp==state.xp and s.adventure:find('ready to collect'))
 assert(read(p.savepath)==before)
 state.trip=0;state.due=0;state.finds=nil;assert(S.save(p.savepath,state,E))
end)
checks('reading counters update immediately without awarding rewards',function()
 local day=os.date('%Y-%m-%d',now);assert(R.saveCounter(p.savepath..'.reading',900,nil,nil,{[day]=900}))
 local s=Model.snapshot(p,{},now)
 assert(s.pending==900 and s.reading=='Read today: 15 min / 15 min to collect' and s.xp==state.xp)
 state.reading.enabled=false;assert(S.save(p.savepath,state,E));assert(Model.snapshot(p,{},now).pending==0)
 state.reading.enabled=true;assert(S.save(p.savepath,state,E))
end)
checks('restore and corrupt-save states are shown without writes',function()
 assert(F.mkdir(p.savepath..'.restore'));local before=read(p.savepath)
 assert(Model.snapshot(p,{},now).message:find('restoring'));assert(read(p.savepath)==before)
 assert(F.rmdir(p.savepath..'.restore'))
 local old=read(p.savepath..'.old');write(p.savepath,'broken');write(p.savepath..'.old','also broken')
 assert(Model.snapshot(p,{},now).message:find('unreadable'))
 assert(read(p.savepath)=='broken' and read(p.savepath..'.old')=='also broken')
 write(p.savepath,before);write(p.savepath..'.old',old)
end)
local Host=require('ui/widget/container/inputcontainer'):extend{covers_fullscreen=true}
function Host:isActive() return not (self.parked or self.asleep or self.closed) end
function Host:paintTo(bb) bb:fill(BB.COLOR_WHITE);self[1]:paintTo(bb,20,20) end
function Host:onCloseWidget() self.closed=true;self[1]:free() end
local host=Host:new{dimen=Geom:new{w=Device.screen:getWidth(),h=Device.screen:getHeight()}}
local dirty=0
local function card(width,detailed)
 if host[1] then host[1]:free() end
 G_reader_settings:saveSetting('pokepal_simpleui_detail',detailed)
 host[1]=M.build(width,{pfx='simpleui_hs_',_screen_widget=host,
  dirty_region_fn=function(region) dirty=dirty+1;U:setDirty(host,'ui',region) end})
 U:setDirty(host,'ui');U:_repaint();pump()
 return host[1]
end
host[1]=M.build(560,{pfx='simpleui_hs_',_screen_widget=host})
U:show(host);U:_repaint();pump()
checks('foreground paint loads real sprites asynchronously and follows saved partner',function()
 local v=host[1];assert(v.snapshot.species==25 and #v.images==2 and v.animating)
 state.species=7;state.seen['7']=true;state.xp=125
 assert(p:save());assert(v.snapshot.species==25,'save callback did blocking card work')
 pump();assert(v.snapshot.species==7 and v.snapshot.level==7)
 assert(read(p.savepath)==S.encode(state))
end)
checks('only one deferred refresh is queued for repeated notifications',function()
 local v=card(560,false);pump(1);pump(1)
 local calls=0;local snapshot=M.snapshot;M.snapshot=function() calls=calls+1;return snapshot() end
 for _=1,20 do p:notifySimpleUIModule() end
 pump();assert(calls==1);M.snapshot=snapshot
end)
checks('bounded animations stop at rest and Off queues no frame timer',function()
 local v=card(560,true)
 local function shot(n)
  if not arg[3] then return end
  local bb=BB.new(v.dimen.w,v.dimen.h,BB.TYPE_BB8);bb:fill(BB.COLOR_WHITE);v:paintTo(bb,0,0)
  bb:writePNG(arg[3]..'-animation-'..n..'.png');bb:free()
 end
 assert(v.animating);shot(1);pump(.9);assert(v.frame==2);shot(2);pump(.9);shot(3)
 assert(v.frame==1 and not v.animating)
 local before=dirty;pump(1);assert(dirty==before)
 G_reader_settings:saveSetting('pokepal_simpleui_animation','off');M.changed();pump()
 assert(not v.animating and #v.images==1)
 G_reader_settings:saveSetting('pokepal_simpleui_animation','gentle');M.changed();pump()
 assert(#v.images>=2 and #v.images<=4)
end)
checks('hidden, suspended, parked and freed cards stop all work',function()
 local v=card(560,true);local before=dirty
 local overlay=require('ui/widget/infomessage'):new{text='Reading another screen'}
 U:show(overlay);pump(1);assert(not v.animating and not v.poll_pending and not v.refresh_pending)
 p:notifySimpleUIModule();pump();assert(dirty==before)
 U:close(overlay);U:_repaint();pump();assert(v.poll_pending)
 Device.screen_saver_mode=true;p.suspended=true;p:pauseSimpleUIModule()
 assert(not v.animating and not v.poll_pending and not v.refresh_pending)
 p:notifySimpleUIModule();pump();assert(not v.refresh_pending)
 Device.screen_saver_mode=false;p.suspended=false;U:setDirty(host,'ui');U:_repaint();pump()
 assert(v.poll_pending)
 host.parked=true;host:handleEvent(Event:new('ShowingReader'));assert(not v.poll_pending)
 pump(65);assert(not v.refresh_pending)
 host.parked=false;U:setDirty(host,'ui');U:_repaint();pump();assert(v.poll_pending)
 v:free();assert(not v.poll_pending and not v.animating);pump(65);assert(v.dead)
end)
checks('narrow and detailed cards render; taps open the game',function()
 for _,width in ipairs({180,280,560}) do
  for _,detail in ipairs({false,true}) do
   local v=card(width,detail);assert(v.snapshot.species==7)
   local bb=BB.new(width,v.dimen.h,BB.TYPE_BB8);bb:fill(BB.COLOR_WHITE);v:paintTo(bb,0,0)
   if arg[3] then bb:writePNG(arg[3]..'-'..width..'-'..tostring(detail)..'.png') end
   bb:free()
  end
 end
 assert(host[1]:onTapPokePal() and opened==1)
end)
checks('module settings and D-pad activation use the same card',function()
 local refreshed=0;local menu=M.getMenuItems{refresh=function() refreshed=refreshed+1 end}
 local before=M.detailed();menu[1].callback();assert(M.detailed()~=before and refreshed==1)
 menu[2].sub_item_table[1].callback();assert(M.animation()=='off' and refreshed==2)
 local focus
 host[1]:free();host[1]=M.build(560,{pfx='simpleui_hs_',_screen_widget=host,
  kbStops=function(id,stops) assert(id==M.id);focus=stops[1].widget end})
 U:setDirty(host,'ui');U:_repaint();pump()
 assert(focus==host[1]);focus:onTapSelect();assert(opened==2)
end)
U:close(host)
assert(read(settings..'/simpleui/sui_settings.lua')==prefs,'card changed SimpleUI settings')
checks('all partners decode every frame used by the card',function()
 local v=M.build(560,{pfx='simpleui_hs_'})
 v.mode='gentle'
 for species=1,386 do
  for _,pose in ipairs({'idle','walk','sleep','charge'}) do
   v:freeContent();v.snapshot={species=species,pose=pose};v:loadImages()
   assert(#v.images>=2 and #v.images<=4,'missing frames for '..species..'/'..pose)
   for _,img in ipairs(v.images) do assert(img.image:getWidth()==v.sprite_size) end
  end
 end
 v:free()
end)
checks('actual SimpleUI home screen discovers, renders and frees the module',function()
 Store:set('simpleui_onboarding_done',true)
 Store:set('simpleui_hs_pokepal_partner_enabled',true)
 Store:set('simpleui_layout',{pages={{modules={'pokepal_partner'}}}})
 G_reader_settings:saveSetting('pokepal_simpleui_detail',true)
 G_reader_settings:saveSetting('pokepal_simpleui_animation','eco')
 G_reader_settings:saveSetting('pokepal_welcome_seen',true)
 local Loader=require('pluginloader')
 Loader._discover=function()
  return {{name='pokepal',path=plugin,main=plugin..'/main.lua',meta=plugin..'/_meta.lua'},
   {name='simpleui',path=sui,main=sui..'/main.lua',meta=sui..'/_meta.lua'},
   {name='coverbrowser',path='plugins/coverbrowser.koplugin',main='plugins/coverbrowser.koplugin/main.lua',meta='plugins/coverbrowser.koplugin/_meta.lua'}}
 end
 local FM=require('apps/filemanager/filemanager')
 FM:showFiles(DS:getDataDir());pump()
 assert(FM.instance.pokepal and FM.instance.simpleui)
 local HS=require('screens/sui_homescreen')
 local h=assert(HS.show());pump();pump()
 local top=U:getTopmostVisibleWidget()
 if top~=h and top.text=='Book info cache database updated.' then U:close(top);U:_repaint();pump() end
 local slot=assert(h._stats_mod_slots.pokepal_partner,'module not mounted by SimpleUI')
 local v=slot.content;assert(v.snapshot.species==7 and v.host==h,
  tostring(v.snapshot.message or v.snapshot.species)..' / '..tostring(v:visible())..' / '..tostring(U:getTopmostVisibleWidget().name))
 if arg[3] then Device.screen.bb:writePNG(arg[3]..'-homescreen.png') end
 local live=FM.instance.pokepal
 assert(v:onTapPokePal());pump();assert(live.pet_view,'card did not open PokePal')
 live:syncReading();assert(live:save());local earned=live.state.xp
 live.pet_view:leave();pump();pump()
 local returned=assert(HS.getInstance('hs'),'home screen was lost when opening the game')
 local updated=returned._stats_mod_slots.pokepal_partner.content
 assert(updated.snapshot.xp==earned,'home card did not follow collected rewards')
 for _=1,8 do
  Device.screen_saver_mode=true;U:broadcastEvent(Event:new('Suspend'));pump()
  assert(not updated.animating and not updated.poll_pending and not updated.refresh_pending)
  Device.screen_saver_mode=false;U:broadcastEvent(Event:new('Resume'));pump();pump()
  returned=assert(HS.getInstance('hs'));updated=returned._stats_mod_slots.pokepal_partner.content
  assert(updated.snapshot.xp==earned and updated.poll_pending)
 end
 HS.close();assert(v.dead and not v.poll_pending)
 FM.instance.pokepal:onTeardown();FM.instance:onClose()
end)
checks('teardown unregisters only PokePal and preserves the game',function()
 local before=read(p.savepath);p:onTeardown();assert(not Registry.get(M.id))
 assert(Registry.get('critter'));assert(read(p.savepath)==before)
end)
os.time=real_time
print('SIMPLEUI MODULE RUNTIME: all checks passed')
U:quit()
