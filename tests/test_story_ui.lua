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
test('legacy story waits for reading sync before migrating and displays the companion nickname',function()
 local v=view();local fixtures=dofile(BASE..'/../tests/story_legacy_fixtures.lua')
 v.state=assert(Store.decode(fixtures.choose,E));v.state.nicknames={['25']='Sparky'};v.owner.reading_busy=true
 v:go('story');v:paintTo(bb,0,0);assert(v.state.story.version==1)
 v.owner.reading_busy=false;v:go('story');assert(v.state.story.version==5 and v.state.story.partner==25 and v.state.story.node=='directions')
 v:paintTo(bb,0,0);assert(E.displayName(v.state,v.state.story.partner)=='Sparky');v:leave()
end)
test('Potions use a battle turn and cannot be spent again while a save has failed',function()
 local v=view();dofile(BASE..'/../tests/story_runtime.lua')(v,function(action,arg) tapButton(v,action,arg) end)
 local t=v.state.story;t.hp=10;local turn=t.battle.turn;local potions=t.potions
 local save=v.owner.save;v.owner.save=function(owner) owner.save_error=true;return nil,'Disk full' end
 tapButton(v,'storypanel','bag');tapButton(v,'storyturn','potion');assert(t.potions==potions-1 and t.hp>10 and t.battle.turn==turn+1 and v.world_save_failed)
 local saved=Store.encode(v.state);v:storyTap('storyturn','potion');assert(Store.encode(v.state)==saved)
 v.owner.save=function(owner) owner.save_error=nil;return save(owner) end
 tapButton(v,'worldretry');assert(not v.world_save_failed);v:leave()
end)
test('wild encounters stop walking; failed catch saves block more balls until retry',function()
 local v=view();tapButton(v,'storynext',1);local t=v.state.story;local S=E.story
 t.flags.POKEPAL_ELM_MISSION=true;t.map='Route29';t.grace=0;t.seed=100;v.state.animation='gentle'
 local m=S.maps[t.map]
 for y=1,m.height-2 do for x=1,m.width-2 do
  if S.tile(t.map,x,y)=='G' and S.tile(t.map,x-1,y)=='G' then t.x=x-1;t.y=y end
 end end
 tapButton(v,'storydir','right');assert(t.encounter=='wild' and not v.world_tick and #U.queue==0)
 t.battle.wildid=16;t.battle.hp=1;t.seed=1
 tapButton(v,'storypanel','bag')
 local save=v.owner.save;v.owner.save=function(owner) owner.save_error=true;return nil,'Disk full' end
 local balls=t.balls;tapButton(v,'storycatch');assert(t.box['16'] and #t.party==2 and t.balls==balls-1 and v.world_save_failed)
 local saved=Store.encode(v.state)
 v:storyTap('storycatch');v:storyTap('storyfinish');v:storyTap('storylead',16);assert(Store.encode(v.state)==saved)
 v.owner.save=function(owner) owner.save_error=nil;return save(owner) end
 tapButton(v,'worldretry');v.state=assert(Store.decode(Store.encode(v.state),E));t=v.state.story
 assert(t.box['16'] and #t.party==2 and t.balls==balls-1);tapButton(v,'storyfinish')
 tapButton(v,'storypanel','party');tapButton(v,'storylead',16);assert(t.partner==16 and v.state.species==25);v:leave()
end)

test('a fainted lead opens the party and choosing a healthy replacement is free',function()
 local v=view();dofile(BASE..'/../tests/story_runtime.lua')(v,function(action,arg) tapButton(v,action,arg) end)
 local t=v.state.story;t.hp=1;t.health[tostring(t.party[2])]=30
 tapButton(v,'storyturn',1);assert(t.hp==0 and t.battle.status=='active')
 local turn,hp=t.battle.turn,t.battle.hp;local saved=Store.encode(v.state)
 tapButton(v,'storyback');assert(Store.encode(v.state)==saved)
 tapButton(v,'storylead',t.party[2]);assert(t.hp==30 and t.battle.turn==turn and t.battle.hp==hp)
 assert(E.valid(v.state));v:leave()
end)
test('Azalea Egg, well rescue and Bugsy controls survive sleep and reopen',function()
 local v=view();local t=dofile(BASE..'/../tests/story_azalea_runtime.lua')(v,function(action,arg) tapButton(v,action,arg) end)
 local saved=E.companion.encode(t);v.state=assert(Store.decode(Store.encode(v.state),E));v:go('story')
 assert(E.companion.encode(v.state.story)==saved);v:leave()
end)

test('a failed hatch save blocks movement and cannot duplicate Togepi on retry',function()
 local v=view();local S=E.story
 local fixtures=dofile(BASE..'/../tests/story_collection_fixtures.lua')
 v.state=assert(Store.decode(fixtures.badge,E));v:go('story');tapButton(v,'storynext',1)
 local t=v.state.story;t.map='VioletPokecenter1F';t.x=4;t.y=5
 assert(S.deposit(t,187));t.node='aide';tapButton(v,'storynext',1);tapButton(v,'storynext',1)
 t.togepi_steps=S.egg_steps-1;local save=v.owner.save
 v.owner.save=function(owner) owner.save_error=true;return nil,'Disk full' end
 tapButton(v,'storydir','right');assert(t.node=='hatched' and #t.party==6 and v.world_save_failed)
 local saved=Store.encode(v.state);tapButton(v,'storynext',1);v:storyTap('storydir','left');assert(Store.encode(v.state)==saved)
 v:onSuspend();v:onResume();assert(Store.encode(v.state)==saved)
 v.owner.save=function(owner) owner.save_error=nil;return save(owner) end
 tapButton(v,'worldretry');tapButton(v,'storynext',1);tapButton(v,'storydir','left')
 assert(#t.party==6 and t.flags.EVENT_TOGEPI_HATCHED and not t.togepi_steps);v:leave()
end)
test('Farfetchd, Cut, the quiz and Whitney survive touch, sleep and reopening',function()
 local v=view();local t=dofile(BASE..'/../tests/story_goldenrod_runtime.lua')(v,function(action,arg) tapButton(v,action,arg) end)
 local saved=E.companion.encode(t);v.state=assert(Store.decode(Store.encode(v.state),E));v:go('story')
 assert(E.companion.encode(v.state.story)==saved);v:leave()
end)

test('a failed Cut save blocks progress and retry preserves the opened path',function()
 local v=view();local S=E.story
 v.state=assert(Store.decode(dofile(BASE..'/../tests/story_azalea_fixtures.lua').hive,E));v:go('story');tapButton(v,'storynext',1)
 local t=v.state.story;t.map='IlexForest';t.farfetchd=10;t.flags.EVENT_HERDED_FARFETCHD=true;t.flags.EVENT_GOT_HM01_CUT=true
 local x,y;for yy,row in ipairs(S.maps.IlexForest.walk) do local xx=row:find('T');if xx then x=xx-1;y=yy-1 end end
 t.x=x;t.y=y+1;tapButton(v,'storydir','up');assert(t.node=='cut_tree')
 local save=v.owner.save;v.owner.save=function(owner) owner.save_error=true;return nil,'Disk full' end
 tapButton(v,'storynext',1);assert(t.node=='cut_done' and v.world_save_failed)
 local saved=Store.encode(v.state);tapButton(v,'storynext',1);v:storyTap('storydir','up');assert(Store.encode(v.state)==saved)
 v:onSuspend();v:onResume();assert(Store.encode(v.state)==saved)
 v.owner.save=function(owner) owner.save_error=nil;return save(owner) end
 tapButton(v,'worldretry');tapButton(v,'storynext',1);tapButton(v,'storydir','up')
 assert(t.x==x and t.y==y and t.flags.POKEPAL_ILEX_TREE_CUT and E.valid(v.state));v:leave()
end)
os.time=original_time
print('STORY UI: '..checks..' checks passed')
