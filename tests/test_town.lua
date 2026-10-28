local E=dofile(BASE..'/engine.lua');local S=dofile(BASE..'/storage.lua')
local W=E.world;local A=W.town;local B=W.battle;local now=1800000000;local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS town: '..name) end
local function pet()
 local s=E.new(now);E.act(s,'choose',25,now);W.enter(s);return s
end
local function copy(s)
 assert(E.valid(s),'invalid town state')
 local data=S.encode(s);local restored=assert(S.decode(data,E),'town save failed to reload')
 assert(S.encode(restored)==data);return restored
end
local function party(s)
 s.world.map='centre';assert(A.party(s,E,2,7));assert(A.party(s,E,3,1));return s
end
local function adjacent(s,index)
 local e=W.encounters[index];s.world.map=e.map
 for _,d in pairs(W.directions) do
  local x,y=e.x+d[1],e.y+d[2]
  if W.walkable(e.map,x,y) and not W.event(e.map,x,y) then s.world.x=x;s.world.y=y;return end
 end
 error('Unreachable encounter')
end
local function win(s)
 s.world.battle.hp=1
 local slot=B.preview(E,s.world.battle,1)>0 and 1 or 2
 assert(W.turn(s,E,slot,now));assert(s.world.battle.status=='won');copy(s)
end

test('version 5 battles migrate without changing their turn, health or rewards',function()
 local s=pet();adjacent(s,1);assert(W.startBattle(s,1));W.turn(s,E,1,now)
 s.world.camp=nil;s.world.battle.moves=nil;s.version=5
 s=copy(s);local turn,hp,foe=s.world.battle.turn,s.world.hp,s.world.battle.hp
 assert(W.enter(s) and s.version==6 and s.world.battle.turn==turn and s.world.hp==hp and s.world.battle.hp==foe)
 copy(s)
end)
test('party selection preserves individual HP and rejects duplicates or gaps',function()
 local s=party(pet());local before=S.encode(s)
 assert(not A.party(s,E,2,25) and not A.party(s,E,4,133));assert(S.encode(s)==before)
 s.world.hp=9;assert(A.party(s,E,1,133));assert(s.world.hp==40 and s.world.camp.health['25']==9)
 assert(A.party(s,E,1,25));assert(s.world.hp==9);copy(s)
end)
test('lessons charge once, loadouts require distinct learned moves',function()
 local s=pet();s.world.map='dojo';local before=S.encode(s)
 assert(not A.learn(s,E,25,4));assert(S.encode(s)==before)
 assert(A.learn(s,E,25,3));local berries,energy=s.berries,s.energy
 assert(not A.learn(s,E,25,3) and s.berries==berries and s.energy==energy)
 assert(A.equip(s,25,2,3));assert(not A.equip(s,25,1,3));assert(not A.equip(s,25,1,4))
 assert(A.practice(s,E));assert(s.world.battle.moves[2]==3);copy(s)
end)
test('switching uses a turn, preserves HP, and prevents returning to a fainted member',function()
 local s=party(pet());adjacent(s,2);assert(W.startBattle(s,2))
 assert(A.switch(s,E,7));assert(s.world.battle.turn==2 and s.world.partner==7 and s.world.hp==34)
 assert(s.world.camp.health['25']==40);s=copy(s)
 s.world.hp=1;s.world.battle.turn=4;assert(W.turn(s,E,1,now))
 assert(s.world.hp==0 and s.world.battle.status=='active');assert(not W.turn(s,E,1,now))
 assert(A.switch(s,E,1));assert(s.world.camp.health['7']==0 and not A.switch(s,E,7));copy(s)
 local berries=s.berries;win(s);assert(s.species==25 and s.berries==berries+1 and s.partners['1'].xp==3)
end)
test('every route encounter saves and only rewards its first win',function()
 local s=pet()
 for i=1,#W.encounters do
  local e=W.encounters[i];assert(W.walkable(e.map,e.x,e.y),'encounter on blocked tile')
  local path=assert(W.path({map=e.map,x=6,y=6},e.x,e.y),'unreachable encounter');assert(#path>0)
  A.heal(s.world,40);adjacent(s,i);assert(W.startBattle(s,i));local berries=s.berries
  win(s);assert(s.berries==berries+1);assert(W.finish(s));s=copy(s)
  assert(W.startBattle(s,i));win(s);assert(s.berries==berries+1);assert(W.finish(s))
 end
 assert(s.world.cleared==4095);copy(s)
end)
test('town buildings and the complete quest route are reachable by walking',function()
 local s=pet()
 local function walk(x,y)
  for _,p in ipairs(assert(W.path(s.world,x,y),'route unreachable')) do assert(W.step(s,p.x,p.y));copy(s) end
 end
 for _,door in ipairs({{2,6,'dojo'},{8,6,'shop'},{10,6,'tower'}}) do
  walk(door[1],door[2]);assert(s.world.map==door[3]);walk(6,8);assert(s.world.map=='town')
 end
 walk(6,1);walk(6,1);assert(s.world.map=='woods');walk(4,4);walk(1,5);assert(s.world.map=='woods')
 walk(6,8);walk(6,8);assert(s.world.map=='town');assert(A.quest(s,1))
 walk(1,5);assert(s.world.map=='woods');walk(11,5);assert(s.world.map=='coast')
 walk(6,1);assert(s.world.map=='coast');local e=W.encounters[9];walk(e.x,e.y);win(s);W.finish(s)
 walk(6,1);assert(s.world.map=='cave');walk(4,4);walk(6,8);walk(1,5);walk(1,5)
 assert(s.world.map=='town');assert(A.quest(s,2));assert(W.unlocked(s.world,'cave-shortcut'));copy(s)
end)
test('quests, discoveries, route gates and shop rewards cannot be replayed',function()
 local s=pet();local c=s.world.camp;local before=S.encode(s)
 assert(not A.quest(s,1));assert(S.encode(s)==before)
 assert(not W.unlocked(s.world,'coast'))
 s.world.map='woods';s.world.x=4;s.world.y=5;assert(W.step(s,4,4))
 s.world.map='town';s.world.x=6;s.world.y=6;assert(A.quest(s,1));assert(W.unlocked(s.world,'coast'))
 local berries=s.berries;assert(not A.quest(s,1));assert(s.berries==berries)
 s.world.map='woods';s.world.x=3;s.world.y=6;assert(W.step(s,3,7));berries=s.berries;W.step(s,3,7);assert(s.berries==berries)
 s.world.map='shop';s.world.x=6;s.world.y=6;assert(A.buy(s,1));berries=s.berries;assert(A.buy(s,1) and s.berries==berries)
 assert(A.buy(s,'potion'));s.world.hp=20;assert(A.potion(s,E) and s.world.hp==36 and c.potions==0);assert(not A.potion(s,E));copy(s)
end)
test('Tower runs persist six battles, one benefit per win and one completion reward',function()
 local s=party(pet());s.world.map='tower';local c=s.world.camp
 assert(A.startTower(s,E));local first=s.world.battle.foe;local berries=s.berries
 for floor=1,6 do
  assert(s.world.battle.floor==floor);s=copy(s);c=s.world.camp
  local original=S.encode(s);assert(not A.startTower(s,E));assert(not A.party(s,E,1,133));assert(S.encode(s)==original)
  win(s);assert(s.berries==berries);assert(W.finish(s));s=copy(s);c=s.world.camp
  if floor<6 then assert(c.tower.choice);assert(A.benefit(s,E,({1,2,3,1,2})[floor]));assert(not A.benefit(s,E,1)) end
 end
 assert(c.rank==1 and not c.tower and s.berries==berries+6 and A.has(c.outfits,2));assert(not W.finish(s))
 assert(A.startTower(s,E) and s.world.battle.foe~=first)
 s.world.battle.status='fled';assert(W.finish(s) and not c.tower and c.rank==1 and s.world.map=='centre');copy(s)
end)
test('full-party defeat ends the run and common Tower stats ignore care levels',function()
 local s=party(pet());s.world.map='tower';s.xp=1e6;assert(A.startTower(s,E))
 local b=s.world.battle;local power=B.preview(E,b,1);s.xp=0;assert(B.preview(E,b,1)==power)
 s.world.camp.health['7']=0;s.world.camp.health['1']=0;s.world.hp=1;b.turn=4
 assert(W.turn(s,E,1,now));assert(b.status=='lost');copy(s);assert(W.finish(s));assert(not s.world.camp.tower and s.world.camp.rank==0);copy(s)
end)
test('all 386 trained parties fit the bounded save codec',function()
 local s=pet();local c=s.world.camp
 for id=1,E.species_count do s.seen[tostring(id)]=true;c.health[tostring(id)]=id%41;c.training[tostring(id)]={learned=15,slots={3,4}} end
 copy(s)
end)

test('fainting on the last turn ends a saveable battle even with reserves',function()
 for _,tower in ipairs({false,true}) do for _,action in ipairs({'move','switch','defeat'}) do
  local s=party(pet());local w=s.world
  if tower then w.map='tower';assert(A.startTower(s,E)) else adjacent(s,2);assert(W.startBattle(s,2)) end
  local b=w.battle;b.turn=100;w.hp=1
  if action=='switch' then w.camp.health['7']=1;assert(A.switch(s,E,7))
  else
   if action=='defeat' then w.camp.health['7']=0;w.camp.health['1']=0 end
   assert(W.turn(s,E,1,now))
  end
  assert(w.hp==0 and b.status==(action=='defeat' and 'lost' or 'draw'),'final-turn faint left an active battle')
  copy(s);assert(not W.turn(s,E,1,now) and not A.switch(s,E,1))
  assert(W.finish(s));assert(not w.camp.tower and w.camp.rank==0);copy(s)
 end end
end)
test('a turn-limit draw keeps the bounded battle log saveable after drain effects',function()
 local s=pet();s.world.camp.training['25']={learned=15,slots={4,2}}
 adjacent(s,2);assert(W.startBattle(s,2));local b=s.world.battle
 b.turn=100;b.seed=2;assert(W.turn(s,E,1,now))
 assert(b.status=='draw' and #b.log==4 and b.log[4]:find('Time for a break',1,true));copy(s)
end)
test('malformed party, learned moves, inventory and Tower state are rejected',function()
 local original=S.encode(party(pet()))
 local cases={function(c) c.party={25,25} end,function(c) c.party={[1]=25,[3]=1} end,
  function(c) c.health['7']=-1 end,function(c) c.health['007']=4 end,function(c) c.potions=10 end,
  function(c) c.training['25']={learned=3,slots={1,4}} end,function(c) c.training['25']={learned=15,slots={3,3}} end,
  function(c) c.training['25']={learned=3,slots={1,2},extra=true} end,
  function(c) c.quests=2 end,function(c) c.outfit=2 end,function(c) c.extra=true end,
  function(c) c.tower={floor=6,run=1,defense=0,switch=0,choice=true} end}
 for _,bad in ipairs(cases) do local s=assert(S.decode(original,E));bad(s.world.camp);assert(not E.valid(s)) end
end)
print('TOWN: '..checks..' party, training, quest, Tower and save checks passed')
