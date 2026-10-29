-- Party, town services and Tower progress live in the same atomic game save.
local A={cost={recruit=3,lesson=2,advanced=4,potion=2,revive=4,tower=3}}
local function int(n,a,b) return type(n)=="number" and n==n and n%1==0 and n>=a and n<=b end
local function keys(t,allowed)
 if type(t)~="table" then return false end
 for k in pairs(t) do if not allowed[k] then return false end end
 return true
end
function A.has(mask,bit) return math.floor(mask/2^(bit-1))%2==1 end
function A.set(mask,bit) return A.has(mask,bit) and mask or mask+2^(bit-1) end
function A.init(s)
 local w=s.world
 if w.camp then return false end
 w.camp={party={w.partner},health={},training={},quests=0,finds=0,outfits=0,outfit=0,potions=0,rank=0,runs=0,dpad=true}
 s.version=6;return true
end
function A.record(s,id)
 local c=s.world.camp;local key=tostring(id)
 c.training[key]=c.training[key] or {learned=3,slots={1,2}}
 return c.training[key]
end
function A.moves(s,id)
 local r=s.world.camp.training[tostring(id)]
 return r and {r.slots[1],r.slots[2]} or {1,2}
end
function A.hp(w,id) return id==w.partner and w.hp or w.camp.health[tostring(id)] or 40 end
function A.alive(w)
 for _,id in ipairs(w.camp.party) do if A.hp(w,id)>0 then return true end end
 return false
end
function A.heal(w,amount)
 w.hp=math.min(40,w.hp+amount)
 for _,id in ipairs(w.camp.party) do w.camp.health[tostring(id)]=math.min(40,(w.camp.health[tostring(id)] or 40)+amount) end
end
function A.party(s,E,slot,id)
 local w=s.world;local c=w.camp
 if w.map~="centre" or w.battle or c.tower or s.trip>0 or s.resting or not int(slot,1,6) or not int(id,1,E.species_count) then return false end
 if slot>#c.party+1 or not c.box[tostring(id)] then return false,"Befriend this Pokemon first." end
 for _,member in ipairs(c.party) do if member==id then return false,"Already in your party." end end
 c.health[tostring(w.partner)]=w.hp;c.party[slot]=id
 if slot==1 then w.partner=id;w.hp=c.health[tostring(id)] or 40 end
 local present=false;for _,member in ipairs(c.party) do if member==w.partner then present=true end end
 if not present then w.partner=c.party[1];w.hp=c.health[tostring(w.partner)] or 40 end
 s.seen[tostring(id)]=true
 return true,E.name(id).." joined slot "..slot.."."
end
function A.learn(s,E,id,index)
 local w=s.world;local c=w.camp
 if w.map~="dojo" or w.battle or c.tower or s.trip>0 or s.resting or (index~=3 and index~=4) then return false end
 local member=false;for _,v in ipairs(c.party) do if v==id then member=true end end
 if not member then return false end
 local r=c.training[tostring(id)]
 if r and A.has(r.learned,index) then return false,"Already learned. Equip it below." end
 if index==4 and not A.has(c.badges,2) then return false,"Earn the Tide Badge for advanced lessons." end
 local cost=index==4 and A.cost.advanced or A.cost.lesson
 if s.berries<cost then return false,"This lesson costs "..cost.." berries." end
 r=A.record(s,id);r.learned=A.set(r.learned,index);s.berries=s.berries-cost
 return true,E.world.battle.catalog(E,id)[index].name.." learned."
end
function A.equip(s,id,slot,index)
 local w=s.world;local c=w.camp
 if (w.map~="dojo" and w.map~="centre") or w.battle or c.tower or not int(slot,1,2) or not int(index,1,4) then return false end
 local member=false;for _,v in ipairs(c.party) do if v==id then member=true end end
 if not member then return false end
 local r=c.training[tostring(id)] or {learned=3,slots={1,2}}
 if not A.has(r.learned,index) or r.slots[3-slot]==index then return false,"Choose a different learned move." end
 A.record(s,id).slots[slot]=index;return true,"Move equipped."
end
function A.reward(s,id,xp,bond)
 if id==s.species then s.xp=math.min(1e12,s.xp+xp);s.bond=math.min(100,s.bond+bond)
 else
  s.partners=s.partners or {};local key=tostring(id);local p=s.partners[key] or {xp=0,bond=0}
  p.xp=math.min(1e12,p.xp+xp);p.bond=math.min(100,p.bond+bond);s.partners[key]=p
 end
end
function A.settle(s,E)
 local w=s.world;local b=w.battle
 if b.status=="lost" and A.alive(w) then
  b.status=b.turn>100 and "draw" or "active"
  b.log={b.status=="draw" and "Time for a break. Return to town and try again." or "Choose another party member to continue."}
 end
 if b.status=="won" and b.practice then w.camp.quests=A.set(w.camp.quests,5) end
end
function A.switch(s,E,id)
 local w=s.world;local c=w.camp;local b=w.battle
 if not b or b.status~="active" or id==w.partner or s.resting or s.trip>0 or A.hp(w,id)<=0 then return false end
 local present=false;for _,v in ipairs(c.party) do if v==id then present=true end end
 if not present then return false end
 local forced=w.hp==0
 c.health[tostring(w.partner)]=w.hp;w.partner=id;w.hp=A.hp({partner=0,camp=c},id)
 b.ally=id;b.moves=A.moves(s,id);b.boost=false
 if forced then b.log={E.name(id).." is ready. Choose a move."};return true end
 if c.tower then w.hp=math.min(40,w.hp+c.tower.switch*3) end
 w.hp=E.world.battle.step(E,b,w.hp,0);E.world.resolve(s,E,os.time());return true
end
function A.switchPreview(s,E,id)
 local w=s.world;local b={}
 if w.hp==0 then return 0,A.hp(w,id) end
 for k,v in pairs(w.battle) do b[k]=v end
 b.ally=id;b.moves=A.moves(s,id);b.boost=false
 local hp=math.min(40,A.hp(w,id)+(w.camp.tower and w.camp.tower.switch*3 or 0))
 local taken=E.world.battle.intent(b)=="attack" and E.world.battle.incoming(E,b) or 0
 local after=E.world.battle.step(E,b,hp,0)
 return taken,after
end
function A.potion(s,E)
 local w=s.world;local c=w.camp;local b=w.battle
 if c.potions==0 or w.hp==0 or w.hp==40 or s.resting or s.trip>0 or (b and b.status~="active") then return false end
 if c.tower then return false,"Tower runs use only the benefits earned inside." end
 c.potions=c.potions-1;w.hp=math.min(40,w.hp+16)
 if b then w.hp=E.world.battle.step(E,b,w.hp,-1);E.world.resolve(s,E,os.time()) end
 return true,"Restored up to 16 HP."
end
function A.buy(s,kind)
 local w=s.world;local c=w.camp
 if w.map~="shop" or w.battle or c.tower then return false end
 if kind=="potion" or kind=="revive" then
  if kind=="revive" and not A.has(c.badges,1) then return false,"Earn the Leaf Badge to buy revives." end
  local key=kind=="potion" and "potions" or "revives";local cost=A.cost[kind]
  if c[key]>=9 or s.berries<cost then return false,"Costs "..cost.." berries; carry up to 9." end
  s.berries=s.berries-cost;c[key]=c[key]+1;return true,kind=="potion" and "Potion packed." or "Revive packed."
 end
 if not int(kind,0,2) then return false end
 if kind>0 and not A.has(c.outfits,kind) then
  local cost=kind==1 and 5 or 8
  if s.berries<cost then return false,"Not enough berries for this outfit." end
  s.berries=s.berries-cost;c.outfits=A.set(c.outfits,kind)
 end
 c.outfit=kind;return true,"Outfit changed."
end
function A.quest(s,index)
 local w=s.world;local c=w.camp
 if w.map~="town" or w.battle then return false end
 if index==1 then
  if not A.has(c.quests,1) then return false,"Mira: My lost Pikachu was last seen in Fern Woods." end
  if A.has(c.quests,2) then return false,"Mira: Thank you! The Coast path and woods shortcut are open." end
  c.quests=A.set(c.quests,2);c.outfits=A.set(c.outfits,1);s.berries=math.min(999,s.berries+4)
  return true,"Pikachu is home! Coast unlocked, 4 berries and a ranger outfit."
 elseif index==2 then
  if not A.has(c.quests,3) then return false,"Theo: Inspect the tracks deep inside Moon Cave." end
  if A.has(c.quests,4) then return false,"Theo: The cave shortcut is open. Your plant is ready at home." end
  c.quests=A.set(c.quests,4);s.decor=s.decor or {};s.decor[2]=s.decor[2]~=false
  return true,"Tracks reported! Cave shortcut and a plant for your room."
 elseif index==3 then
  if not A.has(c.quests,5) then return false,"Ari: Win a dojo practice battle to help me prepare." end
  if A.has(c.quests,6) then return false,"Ari: See you at the Tower!" end
  c.quests=A.set(c.quests,6);s.berries=math.min(999,s.berries+3)
  return true,"Ari is ready! 3 berries for helping with practice."
 end
 return false
end
function A.practice(s,E)
 local w=s.world
 if w.map~="dojo" or w.battle or w.camp.tower or s.trip>0 or s.resting or w.hp==0 then return false end
 local B=E.world.battle
 w.battle=B.new(w.partner,2,A.moves(s,w.partner),nil,nil,B.rollTeam(s,2,#w.camp.party));w.battle.party_size=#w.camp.party;w.battle.practice=true
 w.battle.log={A.has(w.camp.quests,5) and "Coach: Ready for another practice?" or "Coach: Let's try your moves in a practice battle.","Each trainer brings "..#w.camp.party.." Pokemon."}
 return true
end
function A.towerFoe(run,floor)
 return floor==6 and 18+(run-1)%3 or 13+(run+floor-2)%5
end
function A.towerBattle(s,E)
 local w=s.world;local c=w.camp;local t=c.tower
 local foe=A.towerFoe(t.run,t.floor)
 local B=E.world.battle
 w.battle=B.new(w.partner,foe,A.moves(s,w.partner),t.floor,t.defense,B.rollTeam(s,foe,#c.party));w.battle.party_size=#c.party
end
function A.startTower(s,E)
 local w=s.world;local c=w.camp
 if w.map~="tower" or w.battle or c.tower or s.trip>0 or s.resting or c.runs>=1000000 then return false,"Finish your current activity first." end
 if not A.has(c.badges,3) then return false,"Earn the Stone Badge to enter the Tower." end
 if s.berries<A.cost.tower then return false,"Tower entry costs 3 berries." end
 s.berries=s.berries-A.cost.tower
 c.runs=c.runs+1;c.tower={floor=1,run=c.runs,defense=0,switch=0,choice=false}
 A.heal(w,40);A.towerBattle(s,E);return true
end
function A.benefit(s,E,index)
 local w=s.world;local t=w.camp.tower
 if not t or not t.choice or w.battle or not int(index,1,3) then return false end
 if index==1 then A.heal(w,16) elseif index==2 then t.defense=t.defense+1 else t.switch=t.switch+1 end
 t.floor=t.floor+1;t.choice=false
 if w.hp==0 then for _,id in ipairs(w.camp.party) do if A.hp(w,id)>0 then w.partner=id;w.hp=w.camp.health[tostring(id)] or 40;break end end end
 A.towerBattle(s,E);return true
end
function A.valid(c,s,E)
 if not keys(c,{party=true,health=true,training=true,quests=true,finds=true,outfits=true,outfit=true,potions=true,rank=true,runs=true,dpad=true,tower=true,box=true,badges=true,revives=true,wild=true}) or s.version<6 then return false end
 if type(c.party)~="table" or #c.party<1 or #c.party>(s.version>=8 and 6 or 3) or type(c.health)~="table" or type(c.training)~="table" then return false end
 if s.version<8 and (c.box~=nil or c.badges~=nil or c.revives~=nil or c.wild~=nil) then return false end
 if s.version>=8 and not A.validCollection(c,s,E) then return false end
 local members={};local size=0
 for k,id in pairs(c.party) do
  if not int(k,1,#c.party) or not int(id,1,E.species_count) or members[id] or not s.seen[tostring(id)] then return false end
  if s.version>=8 and not c.box[tostring(id)] then return false end
  members[id]=true;size=size+1
 end
 if size~=#c.party or not members[s.world.partner] then return false end
 for id,hp in pairs(c.health) do if type(id)~="string" or not E.species[tonumber(id)] or tostring(tonumber(id))~=id or not s.seen[id] or not int(hp,0,40) then return false end end
 for id,r in pairs(c.training) do
  if type(id)~="string" or not E.species[tonumber(id)] or tostring(tonumber(id))~=id or not s.seen[id] or not keys(r,{learned=true,slots=true}) or not int(r.learned,3,15) or r.learned%4~=3 then return false end
  if not keys(r.slots,{[1]=true,[2]=true}) or not int(r.slots[1],1,4) or not int(r.slots[2],1,4) or r.slots[1]==r.slots[2] then return false end
  if not A.has(r.learned,r.slots[1]) or not A.has(r.learned,r.slots[2]) then return false end
 end
 if not int(c.quests,0,63) or not int(c.finds,0,15) or not int(c.outfits,0,3) or not int(c.outfit,0,2) or (c.outfit>0 and not A.has(c.outfits,c.outfit))
  or not int(c.potions,0,9) or not int(c.rank,0,999) or not int(c.runs,0,1000000) or c.rank>c.runs or type(c.dpad)~="boolean" then return false end
 if A.has(c.quests,2) and not A.has(c.quests,1) or A.has(c.quests,4) and not A.has(c.quests,3) or A.has(c.quests,6) and not A.has(c.quests,5) then return false end
 if c.tower then
  local t=c.tower
  if not keys(t,{floor=true,run=true,defense=true,switch=true,choice=true}) or not int(t.floor,1,6) or t.run~=c.runs or not int(t.run,1,1000000)
   or not int(t.defense,0,5) or not int(t.switch,0,5) or t.defense+t.switch>t.floor-1 or type(t.choice)~="boolean"
   or s.world.map~="tower" or (s.version<8 and #c.party~=3) or s.trip>0 or (t.choice and (t.floor==6 or s.world.battle~=nil)) or (not t.choice and not s.world.battle) then return false end
 end
 return true
end
dofile(debug.getinfo(1,"S").source:sub(2):match("^(.*)/").."/collection.lua")(A)
return A
