local Store=dofile(BASE..'/storage.lua');local checks=0
local original_time=os.time;local now=original_time();os.time=function(t) return t and original_time(t) or now end
local function test(name,fn) fn();checks=checks+1;print('PASS story UI: '..name) end
local function view()
 local v=newView(25);v.state.animation='off'
 v.owner.save=function(owner) assert(E.valid(v.state));owner.saved=(owner.saved or 0)+1;return true end
 v:go('explore');tapButton(v,'nav','story');return v
end
test('Explore opens the story, and dialogue resumes after leaving and reloading',function()
 local v=view();assert(v.state.story.node=='welcome')
 tapButton(v,'nav','home');v.state=assert(Store.decode(Store.encode(v.state),E));v:go('explore');tapButton(v,'nav','story')
 assert(v.state.story.node=='welcome');tapButton(v,'storynext',1)
 assert(not v.state.story.node and #U.queue==0)
 local p=E.story.maps.PlayersHouse2F.warps[1]
 tapButton(v,'storytile',p[2]*E.story.maps.PlayersHouse2F.width+p[1])
 assert(v.state.story.map=='PlayersHouse1F' and v.state.story.node=='mom')
 tapButton(v,'storynext',1);tapButton(v,'storynext',1)
 assert(v.state.story.flags.ENGINE_POKEGEAR);v:leave()
end)
test('sleep cancels queued story walks and stale callbacks cannot move the player',function()
 local v=view();tapButton(v,'storynext',1);v.state.animation='gentle'
 local m=E.story.maps.PlayersHouse2F;local p=m.warps[1]
 tapButton(v,'storytile',p[2]*m.width+p[1]);assert(v.world_tick and #U.queue==1)
 local late=v.world_tick;v:onSuspend();local saved=Store.encode(v.state)
 late();v:onResume();assert(Store.encode(v.state)==saved and #U.queue==0 and not v.world_tick)
 v:leave();late();assert(Store.encode(v.state)==saved)
end)
test('disk errors block dialogue, walking and battle turns until retry',function()
 local v=view();local save=v.owner.save
 v.owner.save=function(owner) owner.save_error=true;return nil,'Disk full' end
 tapButton(v,'storynext',1);assert(v.world_save_failed)
 local saved=Store.encode(v.state);tapButton(v,'storydir','right');assert(Store.encode(v.state)==saved)
 v.owner.save=function(owner) owner.save_error=nil;return save(owner) end
 tapButton(v,'worldretry');assert(not v.world_save_failed)
 tapButton(v,'storyhelp');assert(v.state.story.node=='sign')
 dofile(BASE..'/../tests/story_runtime.lua')(v,function(action,arg) tapButton(v,action,arg) end)
 v.owner.save=function(owner) owner.save_error=true;return nil,'Disk full' end
 tapButton(v,'storyturn',1);assert(v.world_save_failed and v.state.story.battle.turn==3)
 saved=Store.encode(v.state);tapButton(v,'storyturn',2);assert(Store.encode(v.state)==saved)
 v.owner.save=function(owner) owner.save_error=nil;return save(owner) end
 tapButton(v,'worldretry');assert(not v.world_save_failed);v:leave()
end)
test('restore, reading sync and screen-saver locks block story mutation',function()
 local v=view();local saved=Store.encode(v.state)
 for _,lock in ipairs({'reading','restore','sleep'}) do
  v.owner.reading_busy=lock=='reading';v.owner.backups=lock=='restore' and {blocked=true} or nil;Device.screen_saver_mode=lock=='sleep'
  tapButton(v,'storynext',1);assert(Store.encode(v.state)==saved)
 end
 v.owner.reading_busy=false;v.owner.backups=nil;Device.screen_saver_mode=false;v:leave()
end)
test('direction controls dispatch correctly in portrait and landscape',function()
 for _,size in ipairs({{600,800},{1072,1448},{800,600}}) do
  D.w=size[1];D.h=size[2];local v=view();tapButton(v,'storynext',1)
  local x=v.state.story.x;tapButton(v,'storydir','right');assert(v.state.story.x==x+1)
  local saved=Store.encode(v.state);U:drain();assert(Store.encode(v.state)==saved and #U.queue==0);v:leave()
 end
 D.w=600;D.h=800
end)
os.time=original_time
print('STORY UI: '..checks..' checks passed')
