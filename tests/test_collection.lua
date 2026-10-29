local E=dofile(BASE..'/engine.lua');local S=dofile(BASE..'/storage.lua')
local W=E.world;local A=W.town;local B=W.battle;local now=1800000000;local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS collection: '..name) end
local function pet()
 local s=E.new(now);E.act(s,'choose',25,now);W.enter(s);return s
end
local function reload(s)
 assert(E.valid(s),'invalid collection state');local data=S.encode(s);local copy=assert(S.decode(data,E))
 assert(S.encode(copy)==data);return copy
end
local function own(s,id) s.seen[tostring(id)]=true;s.world.camp.box[tostring(id)]=true end
local function wild(s)
 s.world.map='meadow';s.world.x=3;s.world.y=3;assert(W.startBattle(s,1));return s.world.battle
end
local function win(s)
 local b=s.world.battle
 while b.status=='active' do
  b.hp=1
  local slot=B.preview(E,b,1)>0 and 1 or 2
  assert(W.turn(s,E,slot,now));reload(s)
 end
 assert(b.status=='won')
end

test('one chosen starter, six explicit slots and a persistent box',function()
 local s=pet();local w=s.world;local c=w.camp
 assert(#c.party==1 and c.party[1]==25 and E.count(c.box)==1)
 w.map='centre';assert(not A.party(s,E,2,7));assert(not A.deposit(s,25))
 for i,id in ipairs({1,7,133,252,255}) do own(s,id);assert(A.party(s,E,i+1,id)) end
 own(s,92);assert(not A.party(s,E,7,92));assert(#c.party==6)
 w.hp=13;A.record(s,25).learned=15;A.record(s,25).slots={3,4};assert(A.rename(s,E,25,'Sparky'))
 s.xp=120;s.bond=47;assert(A.deposit(s,25));assert(c.health['25']==13 and c.box['25'] and #c.party==5)
 s=reload(s);w=s.world;c=w.camp;assert(A.party(s,E,6,25));assert(A.lead(s,25))
 assert(w.hp==13 and A.moves(s,25)[2]==4 and E.displayName(s,25)=='Sparky' and s.xp==120 and s.bond==47)
 reload(s)
end)

test('berries recruit once into the box, with an explicit party choice',function()
 for _,finish in ipairs({false,true}) do
  local s=pet();local b=wild(s);local c=s.world.camp;local before=S.encode(s)
  assert(not A.recruit(s,E) and S.encode(s)==before)
  if finish then win(s) else b.hp=math.floor(B.maxFoeHP(b)/2) end
  local berries=s.berries;local party=E.companion.encode(c.party)
  assert(A.recruit(s,E));assert(c.box['10'] and E.companion.encode(c.party)==party)
  assert(s.berries==berries-3+(finish and 0 or 1));assert(b.status=='befriended')
  before=S.encode(s);assert(not A.recruit(s,E) and S.encode(s)==before);s=reload(s)
  assert(A.addRecruit(s,E) and #s.world.camp.party==2);assert(not A.addRecruit(s,E));reload(s)
  assert(W.finish(s));assert(s.world.camp.wild['1']);reload(s)
 end
 local s=pet();own(s,10);local b=wild(s);b.hp=1;assert(not A.recruit(s,E))
 s=pet();b=wild(s);b.hp=1;s.berries=2;local before=S.encode(s);assert(not A.recruit(s,E) and S.encode(s)==before)
end)

test('each area repopulates from its pool and all 386 species are reachable',function()
 local found={}
 for map,pool in pairs(B.wildPools) do
  local allowed={};for _,id in ipairs(pool) do found[id]=true;allowed[id]=true end
  local s=pet();for i=1,100 do assert(allowed[B.rollWild(s,map)]) end
 end
 assert(E.count(found)==386)
 local s=pet();local b=wild(s);local id=B.opponent(b);s=reload(s);assert(B.opponent(s.world.battle)==id)
 local seed=s.seed;s.world.battle.status='fled';assert(W.finish(s));assert(s.seed~=seed);reload(s)
end)

test('all trainer battles match one to six party members and remember wins',function()
 for count=1,6 do
  local s=pet();s.world.map='centre'
  for i=2,count do local id=({25,7,1,133,252,255})[i];own(s,id);assert(A.party(s,E,i,id)) end
  local w=s.world;local party=E.companion.encode(w.camp.party)
  for _,index in ipairs({6,9,12}) do
   local e=W.encounters[index];w.map=e.map;w.x=e.x-1;w.y=e.y
   assert(W.startBattle(s,index));assert(#w.battle.team==count and w.battle.party_size==count)
   assert(not A.recruit(s,E));reload(s);w.battle.status='fled';W.finish(s)
   w.cleared=A.set(w.cleared,index);assert(W.startBattle(s,index))
   assert(w.battle.log[1]==A.trainers[index][1]..': '..A.trainers[index][3])
   w.battle.status='fled';W.finish(s)
  end
  w.map='dojo';assert(A.practice(s,E) and #w.battle.team==count);reload(s);w.battle.status='fled';W.finish(s)
  w.map='gym';assert(A.gym(s,E,1) and #w.battle.team==count);reload(s);w.battle.status='fled';W.finish(s)
  w.map='tower';w.camp.badges=7;assert(A.startTower(s,E) and #w.battle.team==count);reload(s)
  assert(E.companion.encode(w.camp.party)==party)
 end
end)

test('a fainted replacement gets a free entrance; voluntary switching spends a turn',function()
 local s=pet();own(s,7);s.world.map='centre';assert(A.party(s,E,2,7));local b=wild(s);local w=s.world
 b.turn=2;w.hp=1;assert(W.turn(s,E,2,now));assert(w.hp==0 and b.status=='active')
 b.charged=true;b.seed=2;local turn=b.turn;local _,forecast=A.switchPreview(s,E,7)
 assert(A.switch(s,E,7) and w.hp==40 and forecast==40 and b.turn==turn and b.seed==2 and b.charged)
 assert(w.camp.health['25']==0);reload(s)
 w.camp.health['25']=40;assert(A.switch(s,E,25) and b.turn==turn+1);reload(s)
end)

test('badges unlock routes, lessons, revives and Tower without repeat rewards',function()
 local s=pet();local w=s.world;local c=w.camp;s.berries=0
 w.map='tower';assert(not A.startTower(s,E));w.map='shop';assert(not A.buy(s,'revive'))
 w.map='dojo';assert(not A.learn(s,E,25,4));assert(not W.unlocked(w,'coast') and not W.unlocked(w,'cave'))
 for i=1,3 do
  w.map='gym';A.heal(w,40)
  if i<3 then assert(not A.gym(s,E,i+1)) end
  assert(A.gym(s,E,i));w.battle.team={10};win(s)
  assert(A.has(c.badges,i) and s.berries==i*5);W.finish(s);reload(s)
 end
 assert(W.unlocked(w,'coast') and W.unlocked(w,'cave'))
 w.map='gym';A.heal(w,40);assert(A.gym(s,E,1));w.battle.team={10};win(s);assert(s.berries==15);W.finish(s)
 w.map='dojo';assert(A.learn(s,E,25,4) and s.berries==11);assert(not A.learn(s,E,25,4))
 w.map='shop';assert(A.buy(s,'revive') and s.berries==7 and c.revives==1)
 w.map='tower';assert(A.startTower(s,E) and s.berries==4);assert(not A.startTower(s,E) and s.berries==4);reload(s)
end)

test('revives restore the chosen fainted member and consume a battle turn once',function()
 local s=pet();local w=s.world;own(s,7);w.map='centre';assert(A.party(s,E,2,7))
 w.camp.revives=2;w.camp.health['7']=0;wild(s);local turn=w.battle.turn
 assert(A.revive(s,E,7) and A.hp(w,7)==20 and w.battle.turn==turn+1 and w.camp.revives==1)
 local before=S.encode(s);assert(not A.revive(s,E,7) and S.encode(s)==before);reload(s)
 w.battle.status='fled';W.finish(s);w.hp=0;assert(A.revive(s,E,25) and w.hp==20);reload(s)
end)

test('box filters combine search, types, favourites and saved nicknames',function()
 local s=pet();for id=1,386 do own(s,id) end
 assert(A.rename(s,E,7,'Shell'));E.act(s,'favourite',7,now)
 assert(#A.boxList(s,E,'','All',false)==386)
 assert(A.boxList(s,E,'shell','Water',true)[1]==7)
 assert(#A.boxList(s,E,'shell','Fire',true)==0)
 assert(A.boxList(s,E,'25','All',false)[1]==25)
 local copy=reload(s);assert(A.boxList(copy,E,'shell','Water',true)[1]==7)
end)

test('old owned companions migrate without granting encountered species or rerolling a fight',function()
 local s=pet();own(s,7);s.world.map='centre';assert(A.party(s,E,2,7));s.partners={['133']={xp=42,bond=30}};s.seen['133']=true;s.seen['150']=true
 s.version=7;local c=s.world.camp;c.box=nil;c.badges=nil;c.revives=nil;c.wild=nil
 s.world.map='woods';s.world.x=7;s.world.y=6
 s.world.battle=B.new(25,6,{1,2},nil,nil,{10,43});s=reload(s)
 local before=E.companion.encode(s.world.battle);W.enter(s);c=s.world.camp
 assert(c.box['25'] and c.box['7'] and c.box['133'] and not c.box['150'])
 assert(E.companion.encode(s.world.battle)==before and #s.world.battle.team==2);reload(s)
 local seed=s.seed;E.act(s,'partner',150,now);assert(s.species==25 and s.seed==seed)
end)

test('malformed ownership, badges, encounters and team sizes fail closed',function()
 local data=S.encode(pet())
 for _,mutate in ipairs({function(c) c.box['25']=nil end,function(c) c.box['999']=true end,
  function(c) c.box['7']=true end,function(c) c.box['25']='yes' end,function(c) c.badges=2 end,
  function(c) c.revives=10 end,function(c) c.wild['1']=nil end,function(c) c.wild['6']=10 end,
  function(c) c.wild['1']=999 end,function(c) c.party={25,7} end}) do
  local s=assert(S.decode(data,E));mutate(s.world.camp);assert(not E.valid(s))
 end
 local s=pet();s.world.map='gym';assert(A.gym(s,E,1));s.world.battle.party_size=2;assert(not E.valid(s))
end)
test('home changes require ownership, while eggs and evolution join the box',function()
 local s=pet();local w=s.world;local party=E.companion.encode(w.camp.party)
 assert(E.act(s,'partner',7,now)=='Befriend this Pokemon in Explore first.' and s.species==25)
 own(s,7);E.act(s,'partner',7,now);assert(s.species==7 and E.companion.encode(w.camp.party)==party)
 E.act(s,'partner',25,now);s.xp=E.species[25][3];s.bond=40
 E.act(s,'evolve',26,now);assert(s.species==26 and w.camp.box['26']);reload(s)
 dofile(BASE..'/reading.lua').init(s);s.reading.seconds=7200;s.egg={id=1,start=0}
 E.act(s,'hatch',nil,now);assert(not s.egg and w.camp.box['1'])
 assert(E.companion.encode(w.camp.party)==party);reload(s)
end)
test('holes inside a saved six-member roster cannot pass Lua length checks',function()
 local s=pet();s.world.map='centre'
 for i,id in ipairs({7,1,133,252,255}) do own(s,id);assert(A.party(s,E,i+1,id)) end
 reload(s);s.world.camp.party[3]=nil;assert(not E.valid(s))
 local team={25,7,1,133,252,255};assert(B.validTeam(team,E,6))
 team[3]=nil;assert(not B.validTeam(team,E,6))
end)
print('COLLECTION: '..checks..' party, recruitment, berry, badge and migration checks passed')
