local E=dofile(BASE..'/engine.lua')
local S=dofile(BASE..'/storage.lua')
local R=dofile(BASE..'/reading.lua')
local now=1800000000
local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS '..name) end
local function pet(id)
 local s=E.new(now);E.act(s,'choose',id or 25,now);R.init(s);return s
end

test('the roster covers the first three generations exactly once',function()
 assert(E.species_count==386 and E.count(E.species)==386)
 assert(E.name(151)=='Mew' and E.name(251)=='Celebi' and E.name(386)=='Deoxys')
 assert(E.name(184)=='Azumarill' and E.name(252)=='Treecko' and E.name(384)=='Rayquaza')
 assert(E.moves({species=196})[4].name=='Psychic')
 assert(E.moves({species=197})[4].name=='Dark Pulse')
 assert(E.moves({species=198})[3].name=='Crunch')
 local seen={}
 for _,route in ipairs(E.routes) do
  for _,id in ipairs(route.pool) do assert(not seen[id] and E.species[id]);seen[id]=true end
 end
 assert(E.count(seen)==386)
 for id=1,386 do
  local line=E.evolutionLine(id);local ancestors={}
  for _,member in ipairs(line) do assert(E.species[member] and not ancestors[member]);ancestors[member]=true end
  assert(ancestors[id] and #line<=3)
  assert(#E.moves({species=id})==4)
 end
end)

test('every split evolution can be chosen and survives a save',function()
 local branches={
  [44]={45,182},[61]={62,186},[79]={80,199},[133]={134,135,136,196,197},
  [236]={106,107,237},[265]={266,268},[290]={291,292},[366]={367,368},
 }
 for parent,children in pairs(branches) do
  assert(table.concat(E.evolutionChoices(parent),',')==table.concat(children,','),parent)
  for _,child in ipairs(children) do
   local s=pet(parent);s.xp=E.species[parent][3];s.bond=30
   E.act(s,'evolve',nil,now);assert(s.species==parent,'split evolution chose a branch without asking')
   E.act(s,'evolve',child,now);assert(s.species==child and s.seen[tostring(child)])
   assert(S.decode(S.encode(s),E).species==child)
   local line=E.evolutionLine(child);local found={}
   for _,id in ipairs(line) do found[id]=true end
   assert(found[parent] and found[child])
   for _,sibling in ipairs(children) do assert(sibling==child or not found[sibling]) end
  end
 end
end)

test('Hoenn starters use their level thresholds and keep family moves',function()
 for _,family in ipairs({{252,253,254},{255,256,257},{258,259,260}}) do
  local s=pet(family[1]);s.bond=30
  assert(E.species[family[1]][3]==300 and E.species[family[2]][3]==700)
  local moves=E.moves(s)
  for stage=1,2 do
   local threshold=E.species[s.species][3]
   s.xp=threshold-1;E.act(s,'evolve',nil,now);assert(s.species==family[stage])
   s.xp=threshold;E.act(s,'evolve',nil,now);assert(s.species==family[stage+1])
   assert(E.moves(s)[2].name==moves[2].name and E.valid(s))
  end
 end
end)

test('new eggs use baby forms while existing eggs can still hatch',function()
 local s=pet()
 for id=1,386 do s.seen[tostring(id)]=true end
 s.seen['172']=nil;s.berries=3;E.act(s,'egg',nil,now)
 assert(s.egg.id==172)
 for _,id in ipairs({25,35,39,106,107,124,125,126}) do
  s=pet(4);s.egg={id=id,start=0}
  s=assert(S.decode(S.encode(s),E));E.readingReward(s,7200,now);E.act(s,'hatch',nil,now)
  assert(not s.egg and s.seen[tostring(id)] and s.species==4)
 end
 s=pet();s.egg={id=386,start=0};assert(E.valid(s))
 s.egg.id=387;assert(not E.valid(s))
 s.egg.id=254;assert(not E.valid(s),'an evolved Hoenn species was accepted as an egg')
end)

test('a complete 386-species journal with full companion data saves and restores',function()
 local s=pet(386);local c=E.companion.get(s);s.partners={};s.nicknames={}
 for id=1,386 do
  local key=tostring(id);s.seen[key]=true;s.partners[key]={xp=id*20,bond=100};s.nicknames[key]='Pal '..id
  c.favourites[key]=true;c.tastes[key]=true;c.met[key]=1e12
 end
 for i=1,100 do c.memories[i]={title=string.rep('📚',96)..' '..i,id=i,at=1e12} end
 for i=1,62 do
  local day=os.date('%Y-%m-%d',now-i*86400)
  c.days[day]={ko=1e12,kindle=1e12};c.ko_days[day]=1e12
 end
 for _,key in ipairs(E.companion.preferences) do c.prefs[key]=true end
 c.hatches=1e9;c.goals=1e9;c.routes={['1']=true,['2']=true,['3']=true}
 assert(E.valid(s));local encoded=S.encode(s)
 local copy=assert(S.decode(encoded,E));assert(S.encode(copy)==encoded)
 assert(#E.companion.journal(copy,E,'','favourites')==386)
 local path=TESTDIR..'/gen3-complete.dat'
 assert(S.save(path,s,E));local saved=assert(S.load(path,E))
 assert(saved.species==386 and saved.partners['384'].xp==7680 and saved.nicknames['386']=='Pal 386')
 local F=dofile(BASE..'/filesystem.lua')
 local backup=dofile(BASE..'/backups.lua').new(path,E,R,F)
 local snapshot=backup:encode(s,0,now,{})
 assert(backup:decode(snapshot).state.species==386)
end)

test('new families keep the same favourite berry through evolution',function()
 for _,family in ipairs({{172,25,26},{298,183,184},{252,253,254},{255,256,257},{258,259,260}}) do
  local s=pet(family[1]);local trait,berry=E.companion.profile(s,family[1],E)
  for _,id in ipairs(family) do
   local next_trait,next_berry=E.companion.profile(s,id,E)
   assert(next_trait==trait and next_berry==berry)
  end
 end
end)
print('GEN 3: '..checks..' roster, evolution, egg and complete-save checks passed')
