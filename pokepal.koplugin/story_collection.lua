-- The story starts with one care companion, then keeps its own caught party.
return function(S,B,data,equip)
 local rng=dofile(debug.getinfo(1,"S").source:sub(2):match("^(.*)/").."/random.lua")
 S.max_balls=10;S.wild=data.wild
 -- shortcut: use 256 walking steps for this preview until Crystal egg cycles are implemented.
 S.egg_steps=256
 local function int(n,a,b) return type(n)=="number" and n==n and n%1==0 and n>=a and n<=b end
 function S.initParty(t,seed)
  t.version=5;t.origin=t.partner;t.party={t.partner};t.box={[tostring(t.partner)]=true};t.health={}
  t.seed=seed;t.balls=S.max_balls;t.grace=3
 end
 function S.member(t,id) for i,mon in ipairs(t.party) do if mon==id then return i end end end
 function S.partySize(t) return #t.party+(t.togepi_steps~=nil and 1 or 0) end
 function S.growEgg(t)
  if t.togepi_steps==nil then return false end
  t.togepi_steps=t.togepi_steps+1
  if t.togepi_steps<S.egg_steps then return false end
  t.togepi_steps=nil;t.flags.EVENT_TOGEPI_HATCHED=true
  if t.box['175'] then t.node="hatched_owned"
  else t.box['175']=true;t.health['175']=40;t.party[#t.party+1]=175;t.node="hatched" end
  return true
 end
 function S.hp(t,id) return id==t.partner and t.hp or t.health[tostring(id)] or 40 end
 function S.alive(t) for _,id in ipairs(t.party) do if S.hp(t,id)>0 then return true end end;return false end
 function S.heal(t)
  t.hp=40;t.potions=S.max_potions
  if t.version>=3 then t.health={};t.balls=S.max_balls end
 end
 function S.atCentre(t) return t.map=="CherrygrovePokecenter1F" or t.map=="VioletPokecenter1F" or t.map=="Route32Pokecenter1F" or t.map=="AzaleaPokecenter1F" or t.map=="GoldenrodPokecenter1F" end
 function S.canManage(t) return S.atCentre(t) and not t.node and not t.battle end
 function S.lead(t,E,id)
  if not S.member(t,id) or id==t.partner or S.hp(t,id)==0 then return false end
  local b=t.battle
  if b and b.status~="active" or not b and t.node then return false end
  local forced=t.hp==0
  t.health[tostring(t.partner)]=t.hp;t.partner=id;t.hp=t.health[tostring(id)] or 40
  if b then
   b.ally=id;b.moves=nil;b.boost=false;equip(b,E)
   if forced then b.log={E.name(id).." is ready. Choose a move."}
   else S.takeTurn(t,E,0) end
  end
  return true
 end
 function S.deposit(t,id)
  local slot=S.member(t,id)
  if not S.canManage(t) or not slot or #t.party==1 then return false end
  t.health[tostring(t.partner)]=t.hp;table.remove(t.party,slot)
  if t.partner==id then t.partner=t.party[1];t.hp=t.health[tostring(t.partner)] or 40 end
  return true
 end
 function S.withdraw(t,id)
  if not S.canManage(t) or not int(id,1,386) or not t.box[tostring(id)] or S.member(t,id) or S.partySize(t)==6 then return false end
  t.party[#t.party+1]=id;return true
 end
 function S.boxList(t)
  local result={};for id=1,386 do if t.box[tostring(id)] then result[#result+1]=id end end;return result
 end
 function S.wildTerrain(t)
  local tile=S.tile(t.map,t.x,t.y,t)
  return S.wild[t.map] and (tile=="G" or S.wild[t.map].terrain=="floor" and tile==".")
 end
 function S.wildSpecies(map,id)
  local wild=S.wild[map];if not wild then return false end
  for _,period in ipairs(wild.mons) do for _,mon in ipairs(period) do if mon==id then return true end end end
  return false
 end
 function S.maybeWild(t,E,hour)
  if t.grace>0 then t.grace=t.grace-1;return false end
  if not S.wildTerrain(t) or not t.flags.POKEPAL_ELM_MISSION or t.hp==0 then return false end
  local wild=S.wild[t.map];hour=hour or 12
  local period=hour>=4 and hour<10 and 1 or hour>=10 and hour<18 and 2 or 3
  if rng(t,100)>wild.rates[period] then return false end
  local roll=rng(t,100);local index=7
  for i,limit in ipairs(data.wild_slots) do if roll<=limit then index=i;break end end
  t.node="wild";t.encounter="wild";t.opponent=1;t.battle=B.new(t.partner,1)
  t.battle.wildid=wild.mons[period][index];equip(t.battle,E)
  t.battle.log={"A wild "..E.name(t.battle.wildid).." appeared!","Lower its HP, then throw a Poke Ball."}
  return true
 end
 function S.catchChance(t)
  local b=t.battle
  if not b or t.encounter~="wild" or b.status~="active" or b.hp<=0 then return 0 end
  -- shortcut: HP/rate catches omit status bonuses until the full battle engine.
  return math.max(1,math.min(255,math.floor((3*B.maxFoeHP(b)-2*b.hp)*data.catch_rates[b.wildid]/(3*B.maxFoeHP(b)))))
 end
 function S.canCatch(t)
  local b=t.battle
  return b and t.encounter=="wild" and b.status=="active" and b.hp>0 and t.hp>0 and t.balls>0 and not t.box[tostring(b.wildid)] or false
 end
 function S.catch(t,E)
  if not S.canCatch(t) then return false end
  local b=t.battle;local id=b.wildid;t.balls=t.balls-1
  if rng(t,255)<=S.catchChance(t) then
   t.box[tostring(id)]=true;t.health[tostring(id)]=math.max(1,math.floor(b.hp/B.maxFoeHP(b)*40))
   local joined=S.partySize(t)<6;if joined then t.party[#t.party+1]=id end
   b.recruited=true;b.status="befriended"
   b.log={"Gotcha! "..E.name(id).." was caught!",joined and "It joined your party." or "Sent to your box at the Pokemon Centre."}
  else
   S.takeTurn(t,E,-1);b.log[1]="The Poke Ball broke open!"
  end
  return true
 end
 function S.flee(t)
  local b=t.battle
  if not b or t.encounter~="wild" or b.status~="active" or t.hp==0 then return false end
  b.status="fled";b.log={"Got away safely."};return true
 end
 function S.retreat(t)
  local b=t.battle
  if not b or t.encounter=="wild" or b.status~="active" then return false end
  b.status="draw";b.log={"You ended the battle to rest.","Try another team at the Pokemon Centre."};return true
 end
 function S.validParty(t,E)
  if not int(t.origin,1,E.species_count) or not int(t.seed,1,2147483646) or not int(t.balls,0,S.max_balls) or not int(t.grace,0,3)
   or type(t.party)~="table" or #t.party<1 or #t.party>6 or type(t.box)~="table" or type(t.health)~="table" then return false end
  local function key(id) return type(id)=="string" and tostring(tonumber(id))==id and int(tonumber(id),1,E.species_count) end
  for id,owned in pairs(t.box) do if not key(id) or owned~=true then return false end end
  for id,hp in pairs(t.health) do if not key(id) or not t.box[id] or not int(hp,0,40) then return false end end
  local seen,count={},0
  for slot,id in pairs(t.party) do
   if not int(slot,1,#t.party) or not int(id,1,E.species_count) or seen[id] or not t.box[tostring(id)] then return false end
   seen[id]=true;count=count+1
  end
  return count==#t.party and seen[t.partner]==true and t.box[tostring(t.origin)]==true
 end
end
