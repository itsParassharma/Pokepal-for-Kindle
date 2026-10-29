-- Collection and berry services use the existing per-species progress records.
return function(A)
 local function int(n,a,b) return type(n)=="number" and n%1==0 and n>=a and n<=b end
 A.leaders={
  {name="Lea",theme="Grass",badge="Leaf",opens="Coast and shop revives"},
  {name="Finn",theme="Water",badge="Tide",opens="Moon Cave and advanced lessons"},
  {name="Petra",theme="Rock",badge="Stone",opens="Battle Tower"},
 }
 A.trainers={[6]={"Kit","Let's see how your team handles bugs!","Back for another round? My bugs are ready."},
  [9]={"Marin","The Coast is a good place to train.","Welcome back! I've brought a different team."},
  [12]={"Flint","My team knows every rock in this cave.","You beat us before. Let's try again!"}}
 function A.migrate(s,W)
  local c=s.world.camp
  if c.box then return false end
  c.box={};c.badges=0;c.revives=0;c.wild={}
  local function own(id) if id and id>0 then c.box[tostring(id)]=true;s.seen[tostring(id)]=true end end
  own(s.species);own(s.world.partner)
  for _,id in ipairs(c.party) do own(id) end
  for _,records in ipairs({s.partners or {},c.health,c.training}) do for id in pairs(records) do own(tonumber(id)) end end
  for i,e in ipairs(W.encounters) do if not e.trainer then c.wild[tostring(i)]=W.battle.foes[i].id end end
  -- Existing Tower players keep access. Route quest unlocks also remain valid.
  if c.runs>0 then c.badges=7 end
  return true
 end
 function A.member(c,id)
  for i,member in ipairs(c.party) do if member==id then return i end end
 end
 function A.canManage(s)
  local w=s.world
  return w.map=="centre" and not w.battle and not w.camp.tower and s.trip==0 and not s.resting
 end
 function A.deposit(s,id)
  local w=s.world;local c=w.camp;local slot=A.member(c,id)
  if not A.canManage(s) or not slot then return false,"Use the PC at the Centre." end
  if #c.party==1 then return false,"Keep at least one Pokemon in your party." end
  c.health[tostring(w.partner)]=w.hp;table.remove(c.party,slot)
  if w.partner==id then w.partner=c.party[1];w.hp=c.health[tostring(w.partner)] or 40 end
  return true,"Moved to the box. Its progress is saved."
 end
 function A.lead(s,id)
  local w=s.world;local c=w.camp;local slot=A.member(c,id)
  if not A.canManage(s) or not slot then return false end
  c.health[tostring(w.partner)]=w.hp
  table.remove(c.party,slot);table.insert(c.party,1,id);w.partner=id;w.hp=c.health[tostring(id)] or 40
  return true,"This Pokemon will lead your party."
 end
 function A.boxList(s,E,query,kind,favourites)
  local result={};query=(query or ""):lower();local c=s.world.camp
  for id=1,E.species_count do
   local key=tostring(id);local p=E.species[id]
   if c.box[key] and (not kind or kind=="All" or p.types:find(kind,1,true))
    and (not favourites or s.companion and s.companion.favourites[key])
    and (query=="" or E.name(id):lower():find(query,1,true) or E.displayName(s,id):lower():find(query,1,true) or query==key) then result[#result+1]=id end
  end
  return result
 end
 function A.rename(s,E,id,name)
  if not s.world.camp.box[tostring(id)] or type(name)~="string" then return false end
  name=name:gsub("^%s+",""):gsub("%s+$","")
  if name~="" and not E.validNickname(name) then return false,"Use up to 12 characters." end
  s.nicknames=s.nicknames or {};s.nicknames[tostring(id)]=name~="" and name or nil
  return true,"Name saved."
 end
 function A.canRecruit(s,E)
  local w=s.world;local b=w.battle;local e=b and E.world.encounters[b.foe]
  if not b or not e or e.trainer or b.team or b.floor or b.practice or b.gym or b.recruited
   or (b.status~="active" and b.status~="won") then return false,"Only wild Pokemon can join you." end
  local id=E.world.battle.opponent(b)
  if w.camp.box[tostring(id)] then return false,"Already in your collection." end
  if s.resting or s.trip>0 or w.hp==0 then return false,"Choose a healthy Pokemon first." end
  if b.status=="active" and b.hp>math.floor(E.world.battle.maxFoeHP(b)/2) then return false,"Lower its HP to half, then offer berries." end
  if s.berries<A.cost.recruit then return false,"Befriending costs 3 berries." end
  return true
 end
 function A.recruit(s,E)
  local ok,message=A.canRecruit(s,E);if not ok then return false,message end
  local w=s.world;local b=w.battle;local B=E.world.battle;local id=B.opponent(b);local key=tostring(id)
  s.berries=s.berries-A.cost.recruit;w.camp.box[key]=true;s.seen[key]=true
  w.camp.health[key]=math.max(1,math.floor(b.hp/B.maxFoeHP(b)*40))
  E.companion.mark(s,id,os.time());b.wildid=id;b.recruited=true;b.status="befriended"
  b.log={E.name(id).." accepted your berries!","Saved in your box. Your party stays as it was."}
  E.world.resolve(s,E,os.time())
  return true
 end
 function A.addRecruit(s,E)
  local w=s.world;local b=w.battle;local c=w.camp
  if not b or not b.recruited or b.status~="befriended" or #c.party>=6 or s.resting or s.trip>0 then return false end
  local id=E.world.battle.opponent(b)
  if A.member(c,id) then return false end
  c.party[#c.party+1]=id;return true,E.name(id).." joined your party."
 end
 function A.revive(s,E,id)
  local w=s.world;local c=w.camp;local b=w.battle
  if c.revives==0 or not A.member(c,id) or A.hp(w,id)~=0 or s.resting or s.trip>0
   or c.tower or (b and (b.status~="active" or w.hp==0)) then return false end
  c.revives=c.revives-1;c.health[tostring(id)]=20;if w.partner==id then w.hp=20 end
  if b then w.hp=E.world.battle.step(E,b,w.hp,-1);E.world.resolve(s,E,os.time()) end
  return true,"Revived with 20 HP."
 end
 function A.gym(s,E,index)
  local w=s.world;local c=w.camp
  if w.map~="gym" or w.battle or c.tower or not int(index,1,3) or s.trip>0 or s.resting or w.hp==0 then return false end
  if index>1 and not A.has(c.badges,index-1) then return false,"Earn the previous badge first." end
  local B=E.world.battle;local leader=A.leaders[index];local again=A.has(c.badges,index)
  w.battle=B.new(w.partner,20+index,A.moves(s,w.partner),nil,nil,B.rollTeam(s,20+index,#c.party))
  w.battle.gym=index;w.battle.party_size=#c.party
  w.battle.log={leader.name..(again and ": Good to see you again!" or ": Ready to earn your "..leader.badge.." Badge?"),
   "A "..#c.party.." against "..#c.party.." battle. Choose a move."}
  return true
 end
 function A.validCollection(c,s,E)
  if type(c.box)~="table" or type(c.wild)~="table" or not int(c.revives,0,9)
   or (c.badges~=0 and c.badges~=1 and c.badges~=3 and c.badges~=7) then return false end
  local function id(key) return type(key)=="string" and tostring(tonumber(key))==key and E.species[tonumber(key)] end
  for key,value in pairs(c.box) do if not id(key) or value~=true or not s.seen[key] then return false end end
  if not c.box[tostring(s.species)] then return false end
  for _,records in ipairs({c.health,c.training}) do for key in pairs(records) do if not c.box[key] then return false end end end
  for key,value in pairs(c.wild) do
   local e=type(key)=="string" and E.world.encounters[tonumber(key)]
   if not e or e.trainer or tostring(tonumber(key))~=key or not int(value,1,E.species_count) then return false end
  end
  for i,e in ipairs(E.world.encounters) do if not e.trainer and not c.wild[tostring(i)] then return false end end
  return true
 end
end
