local E=dofile(BASE..'/engine.lua')
local S=dofile(BASE..'/storage.lua')
local W=E.world;local B=W.battle
local now=1800000000;local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS world: '..name) end
local function pet(id)
 local s=E.new(now);E.act(s,'choose',id or 25,now);W.enter(s);return s
end
local function roundtrip(s)
 assert(E.valid(s),'invalid world state')
 local data=S.encode(s);local copy=assert(S.decode(data,E),'world did not reload')
 assert(S.encode(copy)==data);return copy
end
local function walk(s,x,y)
 local path=assert(W.path(s.world,x,y),'unreachable target')
 local event
 for _,p in ipairs(path) do local changed;changed,event=W.step(s,p.x,p.y);assert(changed);roundtrip(s) end
 return event
end
local function battle(id,index)
 local s=pet(id);assert(walk(s,6,1)=='meadow')
 local e=W.encounters[index or 1];assert(walk(s,e.x,e.y)=='battle')
 return s
end
test('old saves remain byte-identical until entering Explore',function()
 local s=E.new(now);E.act(s,'choose',25,now)
 local data=S.encode(s);assert(not s.world and S.encode(assert(S.decode(data,E)))==data)
 assert(W.enter(s) and s.version==5 and s.world.map=='town');roundtrip(s)
 local saved=S.encode(s);assert(not W.enter(s) and S.encode(s)==saved)
end)
test('town, meadow and centre connect without putting the player inside an event',function()
 local s=pet();assert(walk(s,3,3)=='centre');assert(s.world.map=='centre')
 s.world.hp=1;assert(walk(s,6,4)=='message' and s.world.hp==40)
 assert(walk(s,6,8)=='outside' and s.world.map=='town')
 assert(walk(s,9,3)=='expeditions');assert(walk(s,4,6)=='guide')
 assert(walk(s,6,1)=='meadow');assert(walk(s,6,8)=='town');roundtrip(s)
end)
test('pathfinding is bounded, avoids walls, water and intermediate encounters',function()
 for name,map in pairs(W.maps) do
  assert(#map.rows==8);for _,row in ipairs(map.rows) do assert(#row==11) end
  local w=pet().world;w.map=name;w.x=6;w.y=6
  for y=0,9 do for x=0,12 do
   local path=W.path(w,x,y)
   if path then
    assert(#path<=88);local px,py=w.x,w.y
    for i,p in ipairs(path) do
     assert(W.walkable(name,p.x,p.y) and math.abs(p.x-px)+math.abs(p.y-py)==1)
     assert(i==#path or not W.event(name,p.x,p.y));px=p.x;py=p.y
    end
   elseif not W.walkable(name,x,y) then assert(not path) end
  end end
 end
 local s=pet();local before=S.encode(s)
 assert(not W.step(s,1,1) and S.encode(s)==before)
end)
test('encounters require an adjacent, awake partner with battle HP',function()
 local s=pet();assert(not W.startBattle(s,1));walk(s,6,1)
 local e=W.encounters[1];s.resting=true;assert(walk(s,e.x,e.y)=='message' and not s.world.battle)
 s.resting=false;s.world.hp=0;assert(not W.startBattle(s,1))
 s.world.hp=40;E.act(s,'trip',1,now);assert(s.trip==1 and not W.startBattle(s,1));roundtrip(s)
end)
test('quick moves interrupt charging and bursts break guards',function()
 local b=B.new(25,1);local hp,changed=B.step(E,b,40,1)
 assert(changed and hp==40 and b.hp==16 and not b.charged)
 b=B.new(25,2);b.turn=2;assert(B.intent(b)=='guard')
 assert(B.preview(E,b,1)==3 and B.preview(E,b,2)==14)
 hp=B.step(E,b,40,2);assert(hp==40 and b.hp==14)
 b=B.new(25,3);b.turn=3;assert(B.preview(E,b,2)==0,'Electric must not damage Ground')
end)
test('Withdraw only earns a boost by blocking a hit and consumes it once',function()
 local b=B.new(7,2);local hp=B.step(E,b,40,2)
 assert(hp==38 and b.boost)
 hp=B.step(E,b,hp,1);assert(not b.boost and b.hp==23)
 b=B.new(7,1);hp=B.step(E,b,40,2)
 assert(hp==40 and not b.boost and b.charged)
 hp=B.step(E,b,hp,2);assert(hp==37 and b.boost and not b.charged)
end)
test('Leech Seed heals in bounded ticks and survives saving',function()
 local s=battle(1,2);s.world.hp=30
 assert(W.turn(s,E,2,now));assert(s.world.battle.seed==2 and s.world.hp==27)
 s=roundtrip(s);assert(W.turn(s,E,1,now));assert(s.world.battle.seed==1 and s.world.hp<=40)
 s=roundtrip(s);assert(W.turn(s,E,2,now));assert(s.world.battle.seed==2);roundtrip(s)
end)
test('invalid actions leave a battle unchanged',function()
 local s=battle(25);local before=S.encode(s)
 for _,slot in ipairs({0,3,-1,'1'}) do assert(not W.turn(s,E,slot,now));assert(S.encode(s)==before) end
 for _,action in ipairs({'partner','evolve','trip','readingtrip'}) do
  E.act(s,action,7,now);assert(S.encode(s)==before,action)
 end
 assert(not W.finish(s))
end)
test('first-win rewards commit once across reloads and rematches',function()
 local s=battle(25);s.world.battle.hp=1
 local berries,xp,bond=s.berries,s.xp,s.bond
 assert(W.turn(s,E,1,now));assert(s.world.battle.status=='won')
 assert(s.berries==berries+1 and s.xp==xp+3 and s.bond==bond+1 and s.seen['10'])
 s=roundtrip(s);assert(not W.turn(s,E,1,now));assert(s.berries==berries+1)
 assert(W.finish(s));assert(W.startBattle(s,1));s.world.battle.hp=1
 assert(W.turn(s,E,1,now));assert(s.berries==berries+1 and s.xp==xp+3);roundtrip(s)
end)
test('losing returns to the centre, fleeing preserves HP, neither awards a win',function()
 local s=battle(7,2);s.world.hp=1
 assert(W.turn(s,E,1,now));assert(s.world.battle.status=='lost' and s.world.hp==0)
 s=roundtrip(s);assert(W.finish(s) and s.world.map=='centre' and s.world.cleared==0)
 walk(s,6,4);assert(s.world.hp==40)
 s=battle(25);local berries=s.berries;s.world.battle.status='fled'
 s=roundtrip(s);assert(W.finish(s) and s.world.hp==40 and s.berries==berries)
end)
test('battle and map validation reject malformed or inconsistent state',function()
 local original=S.encode(battle(25))
 local cases={
  function(s) s.version=4 end,function(s) s.world.map='missing' end,
  function(s) s.world.x=0 end,function(s) s.world.x=1 end,
  function(s) s.world.facing='north' end,function(s) s.world.hp=-1 end,
  function(s) s.world.partner=999 end,function(s) s.world.battle.hp=999 end,
  function(s) s.world.battle.foe=99 end,function(s) s.world.battle.charged=1 end,
  function(s) s.world.battle.status='won' end,function(s) s.world.battle.ally=7 end,
  function(s) s.world.battle.turn=0 end,function(s) s.world.extra=true end,
  function(s) s.world.battle.log={[2]='gap'} end,function(s) s.world.cleared=8 end,
 }
 for _,mutate in ipairs(cases) do local s=assert(S.decode(original,E));mutate(s);assert(not E.valid(s)) end
 assert(not S.decode(original..original:match('(world=[^\n]+)')..'\n',E))
end)
test('all 386 partners have legal moves and finish encounters without invalid saves',function()
 for id=1,E.species_count do for foe=1,#B.foes do
  local s=battle(id,foe);local b=s.world.battle;local count=0
  assert(#B.moves(E,id)==2)
  while b.status=='active' do
   local a,ma=B.preview(E,b,1);local z,mz=B.preview(E,b,2)
   local slot=z>a and 2 or 1
   if mz.kind=='seed' and b.seed==0 and b.turn==1 then slot=2 end
   if mz.kind=='guard' and B.intent(b)=='attack' and b.charged then slot=2 end
   assert(W.turn(s,E,slot,now));s=roundtrip(s);b=s.world.battle;count=count+1;assert(count<=100)
  end
  assert(W.finish(s));roundtrip(s)
 end end
end)
print('WORLD: '..checks..' rule, navigation, reward and save checks passed')
