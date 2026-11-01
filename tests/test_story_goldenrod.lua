return function(c)
local E,S,Store=c.E,c.S,c.Store
local copy,advance,dismiss,walk,warp,connect,battle,fight=c.roundtrip,c.advance,c.dismiss,c.walk,c.warp,c.connect,c.battle,c.fight
local dir=debug.getinfo(1,'S').source:match('^@(.*/)')
local fixtures=dofile(dir..'story_azalea_fixtures.lua');local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS Goldenrod: '..name) end
local function ready()
 local s=assert(Store.decode(fixtures.hive,E));assert(S.enter(s,E));dismiss(s);copy(s);return s
end
local tree={}
for y,row in ipairs(S.maps.IlexForest.walk) do for x=1,#row do if row:sub(x,x)=='T' then tree={x-1,y-1} end end end
assert(#tree==2)
local function unlocked(s)
 local t=s.story;t.farfetchd=10;t.flags.EVENT_HERDED_FARFETCHD=true;t.flags.EVENT_GOT_HM01_CUT=true;t.flags.POKEPAL_ILEX_TREE_CUT=true
end
local function herd(s,direction,expected)
 local t=s.story;local p=S.farfetchd_positions[t.farfetchd];local d=S.directions[direction]
 walk(s,p[1]-d[1],p[2]-d[2]);assert(not t.node);assert(S.step(t,d[1],d[2],E,12));copy(s)
 assert(t.farfetchd==expected,tostring(t.farfetchd));dismiss(s)
end
local goldenrod

test('five Azalea saves preserve Egg progress, catches, battles and care data on migration',function()
 for name,data in pairs(fixtures) do
  local s=assert(Store.decode(data,E));assert(Store.encode(s)==data)
  local old=E.companion.encode(s.story);local care=Store.encode(s):gsub('story=[^\n]+\n',''):gsub('version=12\n','version=13\n')
  assert(S.enter(s,E) and s.version==13 and s.story.version==5)
  s.story.version=4;assert(E.companion.encode(s.story)==old,name);s.story.version=5
  assert(Store.encode(s):gsub('story=[^\n]+\n','')==care);copy(s)
  local saved=Store.encode(s);assert(not S.enter(s,E) and Store.encode(s)==saved)
 end
end)

test('walk the Farfetchd puzzle, Cut, Route 34 and Whitney badge handoff',function()
 local s=ready();local t=s.story;local care=Store.encode(s):gsub('story=[^\n]+\n','')
 warp(s,'ILEX_FOREST');assert(t.node=='ilex' and t.farfetchd==1);dismiss(s)
 walk(s,7,28);assert(t.node=='apprentice');dismiss(s)
 walk(s,tree[1],tree[2]);assert(t.node=='need_cut');dismiss(s)
 assert(not S.path(t,1,5),'forest exit accessible before Cut')
 walk(s,14,31);assert(t.farfetchd==2);dismiss(s)
 herd(s,'down',8);herd(s,'down',9);herd(s,'left',10)
 assert(t.flags.EVENT_HERDED_FARFETCHD and not t.flags.EVENT_GOT_HM01_CUT)
 walk(s,5,28);assert(t.node=='cut_owner');advance(s);assert(t.node=='cut_received');dismiss(s)
 walk(s,tree[1],tree[2]);assert(t.node=='cut_tree');advance(s,2);dismiss(s);assert(not t.flags.POKEPAL_ILEX_TREE_CUT)
 local before=S.tileImage(t,tree[1],tree[2]);walk(s,tree[1],tree[2]);advance(s)
 assert(t.node=='cut_done' and t.flags.POKEPAL_ILEX_TREE_CUT and before~=S.tileImage(t,tree[1],tree[2]));dismiss(s)
 walk(s,tree[1],tree[2]);assert(t.x==tree[1] and t.y==tree[2] and S.wildTerrain(t));copy(s)
 fight(s,'wayne');warp(s,'ROUTE_34_ILEX_FOREST_GATE');warp(s,'ROUTE_34')
 for _,key in ipairs({'samuel','brandon','gina','ian','todd'}) do fight(s,key) end
 connect(s,'up');assert(t.map=='GoldenrodCity' and t.node=='goldenrod');dismiss(s)
 warp(s,'GOLDENROD_POKECENTER_1F');walk(s,3,1);dismiss(s)
 assert(t.hp==40 and t.balls==10 and t.potions==5 and S.canManage(t));goldenrod=Store.encode(s)
 warp(s,'GOLDENROD_CITY');warp(s,'GOLDENROD_GYM')
 for _,key in ipairs({'carrie','samantha','victoria','bridget','whitney'}) do fight(s,key) end
 assert(t.flags.EVENT_BEAT_WHITNEY and not t.flags.ENGINE_PLAINBADGE and S.stage(t)==19)
 walk(s,8,3);assert(t.node=='won_whitney');dismiss(s)
 walk(s,8,5);assert(t.node=='whitney_calm');dismiss(s);assert(t.flags.POKEPAL_WHITNEY_CALMED)
 walk(s,8,3);assert(t.node=='plain_received' and S.stage(t)==21);dismiss(s)
 local flags=E.companion.encode(t.flags);walk(s,8,3);assert(t.node=='plain_again');dismiss(s)
 assert(E.companion.encode(t.flags)==flags and Store.encode(s):gsub('story=[^\n]+\n','')==care)
 warp(s,'GOLDENROD_CITY');warp(s,'ROUTE_35_GOLDENROD_GATE');assert(t.node=='closed');dismiss(s)
 connect(s,'down');warp(s,'ROUTE_34_ILEX_FOREST_GATE');warp(s,'ILEX_FOREST')
 assert(S.path(t,3,42),'cut path did not stay open on return');warp(s,'ILEX_FOREST_AZALEA_GATE');copy(s)
end)

test('Farfetchd direction branches persist and the puzzle can recover from every position',function()
 local expected={{2,2,2,2},{3,3,8,3},{4,4,4,2},{3,5,5,5},{4,4,6,7},{7,5,7,7},{8,8,5,6},{2,7,9,2},{10,8,8,10}}
 local directions={'up','right','down','left'};local count=0
 for position=1,9 do
  local paths={};local queue={{position}};local head=1
  while head<=#queue do
   local path=queue[head];head=head+1;local pos=path[#path]
   if pos==10 then paths=path;break end
   for _,next in ipairs(expected[pos]) do
    local seen=false;for _,v in ipairs(path) do if v==next then seen=true end end
    if not seen then local q={};for _,v in ipairs(path) do q[#q+1]=v end;q[#q+1]=next;queue[#queue+1]=q end
   end
  end
  assert(#paths>0,'stranded position '..position)
  for i,direction in ipairs(directions) do
   local s=ready();local t=s.story;t.map='IlexForest';t.farfetchd=position
   local p=S.farfetchd_positions[position];local d=S.directions[direction];t.x=p[1]-d[1];t.y=p[2]-d[2]
   if S.tile(t.map,t.x,t.y)=='.' then
    copy(s);assert(S.step(t,d[1],d[2],E,12));assert(t.farfetchd==expected[position][i]);copy(s);count=count+1
   end
  end
 end
 assert(count>=24)
end)

test('Radio Card quiz saves each answer, restarts after mistakes and grants once',function()
 local s=assert(Store.decode(goldenrod,E));local t=s.story
 warp(s,'GOLDENROD_CITY');warp(s,'RADIO_TOWER_1F');walk(s,12,6);assert(t.node=='radio_quiz')
 advance(s,2);dismiss(s);walk(s,12,6);advance(s);advance(s,2)
 assert(t.node=='radio_wrong' and not t.flags.ENGINE_RADIO_CARD);dismiss(s)
 walk(s,12,6);advance(s)
 for i,answer in ipairs({1,1,2,1,2}) do assert(t.node=='radio_q'..i);advance(s,answer) end
 assert(t.node=='radio_card' and t.flags.ENGINE_RADIO_CARD);dismiss(s)
 local flags=E.companion.encode(t.flags);walk(s,12,6);assert(t.node=='radio_card');dismiss(s);assert(E.companion.encode(t.flags)==flags)
end)

test('twelve source trainer rosters, night patrol and defeat checkpoints work',function()
 local count=0
 for key,p in pairs(S.trainers) do if p.chapter==4 then
  local s=assert(Store.decode(goldenrod,E));local t=s.story;t.map=p.map;t.x=p.x;t.y=p.y;t.node='challenge_'..key
  t.flags[p.flag]=nil;S.heal(t);copy(s);advance(s);battle(s);assert(t.flags[p.flag]);count=count+1
 end end
 assert(count==12 and S.trainers.whitney.team[1]==35 and S.trainers.whitney.team[2]==241 and #S.trainers.bridget.team==3)
 local s=assert(Store.decode(goldenrod,E));local t=s.story;t.map='Route34';t.x=9;t.y=12
 assert(S.step(t,0,-1,E,12) and t.node=='keith_day');dismiss(s)
 assert(S.step(t,0,-1,E,22) and t.node=='challenge_keith');advance(s)
 assert(S.retreat(t));S.finishBattle(t);assert(t.map=='GoldenrodPokecenter1F' and not t.flags.EVENT_BEAT_OFFICER_KEITH);copy(s)
 s=ready();t=s.story;unlocked(s);t.map='IlexForest';t.x=12;t.y=1;t.node='challenge_wayne';advance(s)
 assert(S.retreat(t));S.finishBattle(t);assert(t.map=='AzaleaPokecenter1F' and t.flags.POKEPAL_ILEX_TREE_CUT);copy(s)
end)

test('forest and Route 34 encounters use their source pools and captures reach the city box',function()
 local s=assert(Store.decode(goldenrod,E));local t=s.story
 for _,map in ipairs({'IlexForest','Route34'}) do
  t.map=map;local m=S.maps[map]
  for y=1,m.height-2 do for x=1,m.width-2 do
   t.x=x;t.y=y;if S.wildTerrain(t) and not S.warpAt(map,x,y) then break end
  end;if S.wildTerrain(t) and not S.warpAt(map,t.x,t.y) then break end end
  local seen={}
  for _,hour in ipairs({6,12,22}) do for seed=1,50 do
   t.node=nil;t.battle=nil;t.encounter=nil;t.opponent=nil;t.grace=0;t.seed=seed*100
   if S.maybeWild(t,E,hour) then seen[t.battle.wildid]=true;copy(s);S.flee(t);S.finishBattle(t) end
  end end
  assert(next(seen))
 end
 assert(S.wildSpecies('Route34',132) and S.wildSpecies('Route34',63) and S.wildSpecies('IlexForest',46))
 t.map='Route34';local m=S.maps[t.map]
 for y,row in ipairs(m.walk) do local x=row:find('G');if x then t.x=x-1;t.y=y-1;break end end
 t.node='wild';t.encounter='wild';t.opponent=1;t.battle=S.battle.new(t.partner,1);t.battle.wildid=132;t.battle.hp=1;t.seed=7
 assert(S.catch(t,E) and t.box['132'] and not S.member(t,132));copy(s);S.finishBattle(t)
 t.map='GoldenrodPokecenter1F';t.x=4;t.y=5;assert(S.deposit(t,16) and S.withdraw(t,132));copy(s)
end)

test('corrupt puzzle, badge, quiz and premature map saves fail without throwing',function()
 local s=ready();local encoded=Store.encode(s)
 for i,change in ipairs({
  function(t) t.farfetchd=0 end,function(t) t.farfetchd=1.5 end,function(t) t.farfetchd=11 end,
  function(t) t.farfetchd=10 end,function(t) t.flags.EVENT_HERDED_FARFETCHD=true end,
  function(t) t.flags.EVENT_GOT_HM01_CUT=true end,function(t) t.flags.POKEPAL_ILEX_TREE_CUT=true end,
  function(t) t.flags.POKEPAL_REACHED_GOLDENROD=true end,function(t) t.flags.ENGINE_PLAINBADGE=true end,
  function(t) t.flags.POKEPAL_WHITNEY_CALMED=true end,function(t) t.flags.ENGINE_RADIO_CARD=true end,
  function(t) t.map='GoldenrodPokecenter1F';t.x=4;t.y=5 end,
  function(t) t.map='IlexForest';t.x=3;t.y=42 end,
 }) do local bad=assert(Store.decode(encoded,E));change(bad.story);local ok,valid=pcall(E.valid,bad);assert(ok and not valid,'bad chapter 4 '..i) end
 s=assert(Store.decode(goldenrod,E));s.story.version=4;assert(not E.valid(s))
end)
print('GOLDENROD: '..checks..' checks passed')
end
