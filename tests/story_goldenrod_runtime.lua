-- Shared real controls for the renderer, native host and KOReader.
return function(v,tap)
 local E=v.engine;local S=E.story;local Store=dofile(v.path..'/storage.lua')
 local dir=debug.getinfo(1,'S').source:match('^@(.*/)')
 local restored=assert(Store.decode(dofile(dir..'story_azalea_fixtures.lua').hive,E))
 v.state.story=restored.story;v.state.version=math.max(v.state.version,restored.version)
 v.story_panel=nil;v.state.animation='off';v:go('story');tap('storynext',1)
 local t=v.state.story
 local function tile(x,y) tap('storytile',y*S.maps[t.map].width+x) end
 local function sleep()
  assert(E.valid(v.state));local saved=E.companion.encode(t)
  v:onSuspend();v:onResume();assert(E.companion.encode(t)==saved)
 end
 t.map='IlexForest';t.x=14;t.y=30;t.farfetchd=1
 tile(14,31);assert(t.farfetchd==2 and t.node=='bird_moved' and not v.world_tick);sleep();tap('storynext',1)
 t.farfetchd=10;t.flags.EVENT_HERDED_FARFETCHD=true;t.flags.EVENT_GOT_HM01_CUT=true
 local x,y
 for yy,row in ipairs(S.maps.IlexForest.walk) do local xx=row:find('T');if xx then x=xx-1;y=yy-1 end end
 t.x=x;t.y=y+1;tile(x,y);assert(t.node=='cut_tree');sleep();tap('storynext',1)
 assert(t.node=='cut_done' and t.flags.POKEPAL_ILEX_TREE_CUT);sleep();tap('storynext',1)
 tile(x,y);assert(t.x==x and t.y==y);sleep()
 t.flags.POKEPAL_REACHED_GOLDENROD=true;t.map='RadioTower1F';t.x=11;t.y=6
 tile(12,6);tap('storynext',1);tap('storynext',1);assert(t.node=='radio_q2');sleep()
 tap('nav','home');v:go('story');assert(t.node=='radio_q2')
 for _,answer in ipairs({1,2,1,2}) do tap('storynext',answer) end
 assert(t.flags.ENGINE_RADIO_CARD and t.node=='radio_card');tap('storynext',1)
 t.map='GoldenrodGym';t.x=8;t.y=4;S.heal(t);tile(8,3);tap('storynext',1)
 t.battle.hp=1;tap('storyturn',2);assert(t.opponent==2 and t.battle.wildid==241 and t.battle.turn==2);sleep()
 t.battle.hp=1;tap('storyturn',2);tap('storyfinish');assert(t.node=='won_whitney' and not t.flags.ENGINE_PLAINBADGE)
 sleep();tap('storynext',1);tap('storydir','down');assert(t.node=='whitney_calm');tap('storynext',1)
 tap('storydir','up');tap('storydir','up');assert(t.node=='plain_received' and t.flags.ENGINE_PLAINBADGE);sleep()
 assert(v.owner:save());return t
end
