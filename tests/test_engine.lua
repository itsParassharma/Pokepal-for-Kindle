local E=dofile(BASE.."/engine.lua")
local S=dofile(BASE.."/storage.lua")
local now=1800000000
local passed=0
local function test(name,fn) fn();passed=passed+1;print("PASS "..name) end
local function pet(id)
 local s=E.new(now);E.act(s,"choose",id or 25,now);return s
end
test("all eight starter choices round-trip without changing progress",function()
 local expected={1,4,7,25,133,152,155,158};assert(#E.starters==#expected)
 for i,id in ipairs(expected) do
  assert(E.starters[i]==id);local s=pet(id);assert(s.species==id and E.valid(s))
  assert(S.encode(S.decode(S.encode(s),E))==S.encode(s))
 end
end)
test("an unchosen save survives reopening and starts its clock on selection",function()
 local s=S.decode(S.encode(E.new(now)),E);assert(s and s.species==0 and E.count(s.seen)==0)
 E.act(s,"choose",152,now+86400)
 assert(s.started==now+86400 and s.gift==now+86400 and s.last==now+86400)
 assert(s.food==80 and s.energy==80 and s.berries==6)
end)
test("invalid starter and repeat choice do not replace pet",function()
 local s=E.new(now);E.act(s,"choose",999,now);assert(s.species==0)
 E.act(s,"choose",1,now);E.act(s,"choose",4,now);assert(s.species==1)
end)
test("elapsed care independent of number of check-ins",function()
 local a,b=pet(),pet()
 E.advance(a,now+3600)
 for i=1,3600 do E.advance(b,now+i) end
 assert(math.abs(a.food-b.food)<0.00001);assert(math.abs(a.energy-b.energy)<0.00001)
end)
test("absence is forgiving and never kills pet",function()
 local s=pet();E.advance(s,now+86400*90)
 assert(s.food>=15 and s.joy>=20 and s.energy==100 and s.species==25)
end)
test("clock rollback does not reverse care or duplicate gift",function()
 local s=pet();local before=S.encode(s);E.advance(s,now-3600);assert(S.encode(s)==before)
 E.act(s,"gift",nil,now-86400);assert(s.berries==6)
end)
test("feeding spends one berry and caps fullness",function()
 local s=pet();s.food=90;E.act(s,"feed",nil,now)
 assert(s.food==100 and s.berries==5);E.act(s,"feed",nil,now);assert(s.berries==5)
end)
test("empty inventory cannot go negative",function()
 local s=pet();s.food=30;s.berries=0;E.act(s,"feed",nil,now);assert(s.food==30 and s.berries==0)
end)
test("play and training cannot be spammed",function()
 local s=pet();E.act(s,"play",nil,now);local xp=s.xp
 E.act(s,"play",nil,now);assert(s.xp==xp)
 E.act(s,"train",nil,now);xp=s.xp;E.act(s,"train",nil,now);assert(s.xp==xp)
 E.act(s,"play",nil,now+1800);assert(s.xp==xp+5)
end)
test("rest recovers energy and blocks active care",function()
 local s=pet();s.energy=10;E.act(s,"rest",nil,now);E.advance(s,now+7200)
 assert(s.energy==34);local xp=s.xp;E.act(s,"train",nil,now+7200);assert(s.xp==xp)
 E.act(s,"rest",nil,now+7200);assert(not s.resting)
end)
test("expedition costs once and cannot finish early",function()
 local s=pet();E.act(s,"trip",1,now);assert(s.energy==68 and s.trip==1)
 E.act(s,"collect",nil,now+1799);assert(s.trips==0 and s.berries==6)
 E.act(s,"trip",2,now+1799);assert(s.trip==1)
 E.act(s,"feed",nil,now+1799);assert(s.berries==6)
end)
test("expedition reward is collectible exactly once",function()
 local s=pet();E.act(s,"trip",1,now);E.act(s,"collect",nil,now+1800)
 assert(s.trip==0 and s.trips==1 and s.berries==9 and s.xp==12 and E.count(s.seen)==2)
 E.act(s,"collect",nil,now+1800);assert(s.berries==9 and s.trips==1)
end)
test("all routes have valid sprite-backed encounters",function()
 for i,r in ipairs(E.routes) do
  local s=pet();E.act(s,"trip",i,now);E.act(s,"collect",nil,now+r.seconds)
  assert(s.trips==1);for id in pairs(s.seen) do assert(E.species[tonumber(id)]) end
 end
end)
test("berry basket has a rolling 24-hour cooldown",function()
 local s=pet();E.act(s,"gift",nil,now+86399);assert(s.berries==6)
 E.act(s,"gift",nil,now+86400);assert(s.berries==11)
 E.act(s,"gift",nil,now+86401);assert(s.berries==11)
end)
test("evolution requires XP and bond",function()
 local s=pet(1);s.xp=60;s.bond=29;E.act(s,"evolve",nil,now);assert(s.species==1)
 s.bond=30;E.act(s,"evolve",nil,now);assert(s.species==2)
 s.xp=180;E.act(s,"evolve",nil,now);assert(s.species==3)
end)
test("Eevee has three explicit evolution branches",function()
 for _,id in ipairs({134,135,136}) do
  local s=pet(133);s.xp=120;s.bond=30;E.act(s,"evolve",nil,now);assert(s.species==133)
  E.act(s,"evolve",id,now);assert(s.species==id)
 end
end)
test("Charmander grows through the full evolution line",function()
 local s=pet(4);s.xp=299;s.bond=30;assert(E.level(s)==15 and not E.ready(s))
 s.xp=300;assert(E.level(s)==16 and E.ready(s));E.act(s,"evolve",nil,now);assert(s.species==5)
 s.xp=699;assert(not E.ready(s));s.xp=700;assert(E.level(s)==36 and E.ready(s))
 E.act(s,"evolve",nil,now);assert(s.species==6 and not E.ready(s))
 assert(s.seen['4'] and s.seen['5'] and s.seen['6'])
end)
test("Johto evolution boundaries preserve care and record every stage",function()
 for _,line in ipairs({{152,153,154,300,620},{155,156,157,260,700},{158,159,160,340,580}}) do
  local s=pet(line[1]);s.food=61;s.joy=62;s.energy=63;s.berries=4
  for stage=1,2 do
   local threshold=line[stage+3];s.xp=threshold-1;s.bond=30
   E.act(s,"evolve",nil,now);assert(s.species==line[stage] and not E.ready(s))
   s.xp=threshold;s.bond=29;E.act(s,"evolve",nil,now);assert(s.species==line[stage])
   s.bond=30;assert(E.ready(s));E.act(s,"evolve",nil,now)
   assert(s.species==line[stage+1] and s.xp==threshold and s.bond==30)
   assert(s.food==61 and s.joy==62 and s.energy==63 and s.berries==4)
   assert(s.seen[tostring(line[stage+1])] and S.decode(S.encode(s),E))
  end
  assert(not E.ready(s));E.act(s,"evolve",nil,now);assert(s.species==line[3])
 end
end)
test("profiles retain ancestry and only show the selected Eevee branch",function()
 local families={{1,2,3},{4,5,6},{7,8,9},{25,26},{152,153,154},{155,156,157},{158,159,160}}
 for _,family in ipairs(families) do
  for _,id in ipairs(family) do assert(table.concat(E.evolutionLine(id),",")==table.concat(family,",")) end
 end
 assert(table.concat(E.evolutionLine(133),",")=="133")
 for _,id in ipairs({134,135,136}) do
  assert(table.concat(E.evolutionLine(id),",")=="133,"..id)
  assert(#E.evolutionChoices(id)==0)
 end
end)
test("evolution cannot jump into an unrelated family",function()
 local s=pet(152);s.xp=700;s.bond=50
 E.act(s,"evolve",6,now);assert(s.species==152)
 s=pet(133);s.xp=700;s.bond=50
 E.act(s,"evolve",153,now);assert(s.species==133)
end)
test("starter families have usable moves with enforced unlocks",function()
 for _,id in ipairs(E.starters) do
  local s=pet(id);local moves=E.moves(s)
  assert(#moves==4 and moves[1].level==1 and moves[2].level==7 and moves[4].level==36)
  E.act(s,"train",moves[2].name,now);assert(s.xp==0 and s.trained==0)
  E.act(s,"train",nil,now);assert(s.xp==12 and s.trained==now)
  s.xp=120;E.act(s,"train",moves[2].name,now+3600);assert(s.xp==132)
  for _,member in ipairs(E.evolutionLine(id)) do
   s.species=member;assert(E.moves(s)[2].name==moves[2].name)
  end
 end
 assert(E.moves({species=152})[2].name=="Razor Leaf")
 assert(E.moves({species=155})[2].name=="Ember")
 assert(E.moves({species=158})[2].name=="Water Gun")
end)
test("move training honors level unlocks",function()
 local s=pet(4);E.act(s,"train","Ember",now);assert(s.xp==0 and s.trained==0)
 s.xp=120;E.act(s,"train","Ember",now);assert(s.xp==132)
 local xp=s.xp;E.act(s,"train","Flamethrower",now+3600);assert(s.xp==xp)
end)
test("cleaning has no unlimited bond reward",function()
 local s=pet();s.dirt=30;E.act(s,"clean",nil,now);local b=s.bond
 E.act(s,"clean",nil,now);assert(s.bond==b and s.dirt==0)
end)
test("badges are awarded once and log is bounded",function()
 local s=pet();s.care=20;s.trips=5;s.bond=80;s.xp=300
 E.badges(s);local n=E.count(s.badges);local logs=#s.log;E.badges(s)
 assert(E.count(s.badges)==n and #s.log==logs)
 for i=1,30 do E.note(s,"entry "..i) end;assert(#s.log==24)
end)
test("new pets default to Eco and activities include timestamps",function()
 local s=pet(4);assert(s.animation=="eco")
 assert(s.log[1]:find(" | ",1,true))
 E.act(s,"rest",nil,now+60);assert(s.log[1]:find(" | ",1,true))
end)
test("save round-trip retains trip, cooldowns and discoveries",function()
 local s=pet();E.act(s,"train",nil,now);E.act(s,"trip",2,now)
 local data=S.encode(s);local restored=S.decode(data,E);assert(restored and S.encode(restored)==data)
end)
test("version 0.1 saves remain readable and expanded history persists",function()
 local s=pet(4);s.animation="gentle"
 for i=1,8 do E.note(s,"old entry "..i) end
 local upgraded=S.decode(S.encode(s),E);assert(upgraded and upgraded.animation=="gentle")
 for i=1,24 do E.note(upgraded,"new entry "..i,now) end
 local saved=S.decode(S.encode(upgraded),E)
 assert(saved and #saved.log==24 and saved.log[1]:find(" | ",1,true))
end)
test("bad saves and code-like input are rejected",function()
 assert(not S.decode('os.execute("bad")',E));assert(not S.decode("version=999\n",E))
 local s=pet();assert(not S.decode(S.encode(s).."species=4\n",E))
 s.food=101;assert(not E.valid(s))
end)
test("atomic save and damaged-primary recovery",function()
 local p=TESTDIR.."/save.dat";local s=pet()
 assert(S.save(p,s,E));s.berries=8;assert(S.save(p,s,E))
 local loaded=S.load(p,E);assert(loaded.berries==8)
 local f=assert(io.open(p,"wb"));f:write("broken");f:close()
 local recovered,notice=S.load(p,E);assert(recovered.berries==6 and notice)
 assert(S.save(p,recovered,E));assert(S.load(p,E).berries==6)
end)
test("both corrupted copies are preserved, not reset",function()
 local p=TESTDIR.."/bad.dat"
 for _,suffix in ipairs({"",".old"}) do local f=assert(io.open(p..suffix,"wb"));f:write("broken");f:close() end
 local s,err=S.load(p,E);assert(not s and err)
end)
test("unwritable destination reports failure",function()
 local ok,err=S.save(TESTDIR.."/absent/save.dat",pet(),E);assert(not ok and err)
end)
print("ENGINE AND STORAGE: "..passed.." checks passed")
