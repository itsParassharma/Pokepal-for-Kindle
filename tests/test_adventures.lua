local E=dofile(BASE..'/engine.lua')
local S=dofile(BASE..'/storage.lua')
local R=dofile(BASE..'/reading.lua')
local now=1800000000
local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS '..name) end
local function pet()
 local s=E.new(now);E.act(s,'choose',25,now);R.init(s);return s
end
test('reading trips ignore old minutes and elapsed wall time',function()
 local s=pet();E.readingReward(s,3600,now);E.act(s,'readingtrip',1,now)
 assert(s.trail==3600 and s.due==0 and s.energy==68)
 E.act(s,'collect',nil,now+86400);assert(s.trip==1 and s.trips==0 and E.tripLeft(s,now+86400)==1800)
 E.readingReward(s,1799,now+86400);assert(E.tripLeft(s,now+86400)==1)
 E.act(s,'collect',nil,now+86400);assert(s.trips==0)
 E.readingReward(s,1,now+86400);assert(E.tripLeft(s,now-3600)==0)
 E.act(s,'collect',nil,now+86400);assert(s.trip==0 and not s.trail and s.trips==1)
 local count,xp,berries=E.count(s.seen),s.xp,s.berries
 E.act(s,'collect',nil,now+86400);assert(E.count(s.seen)==count and s.xp==xp and s.berries==berries)
end)
test('reading and timer routes retain their distinct progress after reload',function()
 for _,action in ipairs({'trip','readingtrip'}) do
  for route,r in ipairs(E.routes) do
   local s=pet();E.act(s,action,route,now);s=S.decode(S.encode(s),E);assert(s)
   E.readingReward(s,r.seconds,now+10)
   assert(E.tripLeft(s,now+10)==(action=='trip' and r.seconds-10 or 0))
   E.act(s,'collect',nil,now+r.seconds);assert(s.trips==1)
  end
 end
end)
test('eggs charge once, save their species, and hatch without replacing the partner',function()
 local s=pet();E.readingReward(s,3600,now);local before=s.berries
 E.act(s,'egg',nil,now);local id,seed=s.egg.id,s.seed
 assert(s.berries==before-3 and E.eggLeft(s)==7200)
 E.act(s,'egg',nil,now);assert(s.egg.id==id and s.seed==seed and s.berries==before-3)
 s=S.decode(S.encode(s),E);assert(s and s.egg.id==id)
 E.act(s,'hatch',nil,now+86400);assert(s.egg and not s.seen[tostring(id)])
 E.readingReward(s,7199,now+86400);E.act(s,'hatch',nil,now+86400);assert(s.egg)
 E.readingReward(s,1,now+86400);assert(E.eggLeft(s)==0)
 local xp,bond=s.xp,s.bond;E.act(s,'hatch',nil,now+86400)
 assert(not s.egg and s.seen[tostring(id)] and s.species==25 and s.xp==xp and s.bond==bond)
 local log=#s.log;E.act(s,'hatch',nil,now+86400);assert(#s.log==log)
 E.act(s,'egg',nil,now+86400);assert(E.eggLeft(s)==7200)
end)
test('both readers advance egg and trail while keeping regular rewards',function()
 local s=pet();R.collect(s,E,{a=50},100,now)
 E.act(s,'egg',nil,now);E.act(s,'readingtrip',2,now)
 R.collect(s,E,{a=950},1000,now+1800)
 assert(s.reading.seconds==1800 and E.tripLeft(s,now+1800)==5400 and E.eggLeft(s)==5400)
 assert(s.xp==6 and s.berries==6)
 R.collect(s,E,{a=950},1000,now+3600);assert(s.reading.seconds==1800)
end)
test('pausing reading freezes both goals and timer trips still work',function()
 local s=pet();R.collect(s,E,{},0,now);E.act(s,'egg',nil,now);E.act(s,'readingtrip',1,now)
 s.reading.enabled=false;R.collect(s,E,{},900,now+900)
 assert(E.eggLeft(s)==7200 and E.tripLeft(s,now+900)==1800)
 s.reading.enabled=true;R.collect(s,E,{},1800,now+1800)
 assert(E.eggLeft(s)==6300 and E.tripLeft(s,now+1800)==900)
 local other=pet();other.reading.enabled=false;E.act(other,'readingtrip',1,now);E.act(other,'egg',nil,now)
 assert(other.trip==0 and not other.egg and other.berries==6)
 E.act(other,'trip',1,now);E.act(other,'collect',nil,now+1800);assert(other.trips==1)
end)
test('eggs work during travel and rest, and do not spend partner progress',function()
 for _,action in ipairs({'trip','rest'}) do
  local s=pet();E.act(s,action,1,now);E.act(s,'egg',nil,now);assert(s.egg)
  E.readingReward(s,7200,now+7200);E.act(s,'hatch',nil,now+7200)
  assert(not s.egg and s.species==25 and (s.trip==1 or s.resting))
 end
 local s=pet();s.berries=2;local seed=s.seed;E.act(s,'egg',nil,now)
 assert(not s.egg and s.berries==2 and s.seed==seed)
end)
test('eggs prefer unseen first forms and still work with a complete journal',function()
 local s=pet();local children={}
 for id=1,160 do for _,child in ipairs(E.evolutionChoices(id)) do children[child]=true end end
 local available=0;for id=1,160 do if not children[id] and not s.seen[tostring(id)] then available=available+1 end end
 for i=1,available do
  s.berries=3;E.act(s,'egg',nil,now);local id=s.egg.id
  assert(not children[id] and not s.seen[tostring(id)])
  E.readingReward(s,7200,now);E.act(s,'hatch',nil,now)
 end
 for id=1,160 do s.seen[tostring(id)]=true end
 s.berries=3;E.act(s,'egg',nil,now);assert(s.egg and not children[s.egg.id])
end)
test('old saves retain timed trips, partners, rewards and defaults',function()
 local s=pet();s.xp=42;s.bond=35;s.partners={['25']={xp=42,bond=35}};E.act(s,'trip',2,now)
 s=S.decode(S.encode(s),E);assert(s and not s.trail and not s.egg and not s.background)
 assert(s.xp==42 and s.bond==35 and s.partners['25'].xp==42 and E.tripLeft(s,now)==7200)
 E.act(s,'background',6,now);E.act(s,'egg',nil,now)
 s=S.decode(S.encode(s),E);R.init(s);assert(s.version==3 and s.background==6 and s.egg and E.valid(s))
 assert(s.xp==42 and s.reading.seconds==0 and E.tripLeft(s,now)==7200)
end)
test('new fields reject corrupt, duplicate and impossible records',function()
 local s=pet();local data=S.encode(s)
 for _,line in ipairs({'background=0','background=7','background=1.5','background=no',
  'background=1\nbackground=2','trail=0','egg=2,0','egg=999,0','egg=1,1',
  'egg=1,-1','egg=1,nan','egg=1,0\negg=4,0'}) do assert(not S.decode(data..line..'\n',E),line) end
 E.act(s,'readingtrip',1,now);s.trail=1;assert(not E.valid(s))
 s.trail=0;s.due=now;assert(not E.valid(s))
 for i=1,#E.backgrounds do s=pet();E.act(s,'background',i,now);assert(S.decode(S.encode(s),E).background==i) end
 local before=S.encode(s);E.act(s,'background',99,now);assert(S.encode(s)==before)
end)
print('READING ADVENTURES: '..checks..' checks passed')
