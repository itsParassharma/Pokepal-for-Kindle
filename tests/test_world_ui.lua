local S=dofile(BASE..'/storage.lua');local checks=0
local original_time=os.time;local now=original_time()
os.time=function(t) return t and original_time(t) or now end
local function test(name,fn) fn();checks=checks+1;print('PASS world UI: '..name) end
local function view(id)
 local v=newView(id or 25);v.state.animation='off'
 v.owner.save=function(owner) assert(E.valid(v.state));owner.saved=(owner.saved or 0)+1;return true end
 v:go('explore');return v
end
local function encounter(v,index)
 tapButton(v,'worldtile',6)
 assert(v.state.world.map=='meadow')
 local p=E.world.encounters[index or 1]
 tapButton(v,'worldtile',(p.y-1)*11+p.x)
 assert(v.screen=='battle' and v.state.world.battle)
end
test('home opens the map and the trail board opens existing expeditions',function()
 local v=newView(25);v.state.animation='off'
 tapButton(v,'nav','explore');assert(v.state.world and v.screen=='explore')
 tapButton(v,'worldtile',31);assert(v.screen=='expeditions')
 tapButton(v,'tripmode','reading');assert(v.trip_mode=='reading')
 v:go('home');v:go('reading');tapButton(v,'nav','expeditions');assert(v.screen=='expeditions');v:leave()
end)
test('tap-to-walk and arrows work in portrait and landscape',function()
 for _,size in ipairs({{600,800},{1072,1448},{800,600}}) do
  D.w=size[1];D.h=size[2];local v=view()
  tapButton(v,'worlddir','up');assert(v.state.world.y==5)
  tapButton(v,'worldtile',25);assert(v.state.world.map=='centre')
  v.state.world.hp=1;tapButton(v,'worldtile',39);assert(v.state.world.hp==40)
  tapButton(v,'worldtile',83);assert(v.state.world.map=='town');v:leave()
 end
 D.w=600;D.h=800
end)
test('animated walks stop on sleep and stale callbacks stay cancelled after waking',function()
 local v=view();v.state.animation='gentle';tapButton(v,'worldtile',6)
 assert(v.world_tick and #U.queue==1);local late=v.world_tick
 v:onSuspend();local saved=S.encode(v.state);assert(#U.queue==0 and not v.world_tick)
 late();assert(S.encode(v.state)==saved)
 v:onResume();saved=S.encode(v.state);late();assert(S.encode(v.state)==saved and #U.queue==0)
 v:leave()
end)
test('a new destination and navigation invalidate earlier walks',function()
 local v=view();v.state.animation='eco';tapButton(v,'worldtile',6);local late=v.world_tick
 tapButton(v,'worlddir','left');local saved=S.encode(v.state);late();assert(S.encode(v.state)==saved)
 tapButton(v,'worldtile',6);late=v.world_tick;v:go('worldhelp');saved=S.encode(v.state)
 late();assert(S.encode(v.state)==saved and #U.queue==0);v:leave()
end)
test('map transitions have finite callbacks and Off walks without a timer',function()
 for _,mode in ipairs({'gentle','eco','off'}) do
  local v=view();v.state.animation=mode;tapButton(v,'worldtile',6)
  if mode=='off' then assert(#U.queue==0) else assert(U:drain()<88) end
  assert(v.state.world.map=='meadow' and #U.queue==0 and not v.world_path);v:leave()
 end
end)
test('battle survives pause, save reload, sleep and orientation changes',function()
 local v=view();encounter(v);tapButton(v,'battleturn',1)
 local saved=S.encode(v.state);tapButton(v,'nav','home');tapButton(v,'nav','explore')
 assert(v.screen=='battle' and S.encode(v.state)==saved)
 v.state=assert(S.decode(saved,E));v:onSuspend();D.w=800;D.h=600;v:onResume()
 assert(v.screen=='battle' and S.encode(v.state)==saved and #U.queue==0)
 v:paintTo(bb,0,0);tapButton(v,'battleflee');assert(v.state.world.battle.status=='fled')
 tapButton(v,'battlefinish');assert(v.screen=='explore' and not v.state.world.battle);v:leave()
 D.w=600;D.h=800
end)
test('a failed turn save blocks further turns until the same state saves',function()
 local v=view();encounter(v);local save=v.owner.save
 v.owner.save=function(owner) owner.save_error=true;return nil,'Disk full' end
 tapButton(v,'battleturn',1);assert(v.world_save_failed and v.state.world.battle.turn==2)
 local saved=S.encode(v.state);tapButton(v,'battleturn',2);assert(S.encode(v.state)==saved)
 v.owner.save=function(owner) owner.save_error=nil;return save(owner) end
 tapButton(v,'worldretry');assert(not v.world_save_failed and S.encode(v.state)==saved)
 tapButton(v,'battleturn',1);assert(v.state.world.battle.turn==3);v:leave()
end)
test('battle animations do not advance turns and stop when the view closes',function()
 local v=view();encounter(v);v.state.animation='gentle'
 tapButton(v,'battleturn',1);assert(#U.queue==1)
 local saved=S.encode(v.state);U:drain();assert(S.encode(v.state)==saved)
 tapButton(v,'battleturn',2);assert(#U.queue==1);local late=v.tick
 v:leave();saved=S.encode(v.state);late();assert(S.encode(v.state)==saved and #U.queue==0)
end)
test('screensaver and restore locks block taps and queued walking',function()
 local v=view();local saved=S.encode(v.state);Device.screen_saver_mode=true
 tapButton(v,'worlddir','up');assert(S.encode(v.state)==saved);Device.screen_saver_mode=false
 v.state.animation='gentle';tapButton(v,'worldtile',6);local late=v.world_tick
 v.owner.backups={blocked=true};saved=S.encode(v.state);late();assert(S.encode(v.state)==saved and #U.queue==0)
 v.owner.backups=nil;v:leave()
end)
print('WORLD UI: '..checks..' movement, lifecycle, save failure and touch checks passed')
os.time=original_time
