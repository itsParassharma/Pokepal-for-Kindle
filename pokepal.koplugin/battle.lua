-- Turn-based practice battles. No clock, callbacks or device code.
local B={max_hp=40}
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
local types=dofile(dir.."/battle_types.lua")
local rng=dofile(dir.."/random.lua")
local teams={
 [2]={19,56,66,106,107,115,236,237,287,288,296,307},
 [21]={1,43,69,102,114,152,187,252,270,285,315,331},
 [22]={7,54,60,72,79,90,98,116,120,170,183,222,258,278},
 [23]={74,95,111,138,140,142,185,213,246,299,304,345},
 [6]={10,12,13,14,15,43,46,48,114,165,167,193},
 [9]={7,54,60,72,79,90,98,116,120,170,183,222,258,278},
 [12]={27,50,74,95,104,111,194,213,246,299,304,328},
}
function B.rollTeam(s,foe,count)
 local pool=teams[foe];local result={};local used={}
 while #result<count do
  local id=pool and pool[rng(s,#pool)] or rng(s,386)
  if not used[id] then result[#result+1]=id;used[id]=true end
 end
 return result
end
function B.opponent(b) return b.team and b.team[b.opponent] or b.wildid or B.foes[b.foe].id end
function B.validTeam(team,E,count)
 if type(team)~="table" or #team~=count then return false end
 local seen={};local size=0
 for k,id in pairs(team) do
  if type(k)~="number" or k%1~=0 or k<1 or k>count or type(id)~="number" or not E.species[id] or seen[id] then return false end
  seen[id]=true;size=size+1
 end
 return size==count
end
B.foes={
 {id=10,hp=24,power=5,type="Normal"},
 {id=19,hp=28,power=6,type="Normal"},
 {id=74,hp=34,power=7,type="Rock"},
 {id=43,hp=28,power=6,type="Grass"},
 {id=163,hp=30,power=6,type="Flying"},
 {id=14,hp=36,power=7,type="Bug"},
 {id=278,hp=30,power=7,type="Flying"},
 {id=98,hp=34,power=8,type="Water"},
 {id=120,hp=38,power=8,type="Water"},
 {id=41,hp=32,power=7,type="Poison"},
 {id=304,hp=38,power=8,type="Steel"},
 {id=95,hp=42,power=9,type="Rock"},
 {id=280,hp=26,power=4,type="Psychic"},
 {id=66,hp=28,power=4,type="Fighting"},
 {id=81,hp=26,power=4,type="Electric"},
 {id=259,hp=28,power=4,type="Water"},
 {id=253,hp=26,power=4,type="Grass"},
 {id=6,hp=36,power=5,type="Fire"},
 {id=282,hp=36,power=5,type="Psychic"},
 {id=376,hp=36,power=5,type="Steel"},
}
B.foes[21]={id=1,hp=30,power=5,type="Grass"}
B.foes[22]={id=7,hp=34,power=6,type="Water"}
B.foes[23]={id=74,hp=38,power=7,type="Rock"}
local wildTypes={meadow="Normal Grass Bug Fairy Flying",woods="Bug Grass Poison Psychic Ghost",
 coast="Water Flying Electric Dragon",cave="Rock Ground Steel Ghost Dark Ice Fire Fighting"}
local wildPools={}
local species=dofile(dir.."/species.lua")
for foe=13,20 do
 teams[foe]={}
 for id,p in ipairs(species) do if p.types:find(B.foes[foe].type,1,true) then teams[foe][#teams[foe]+1]=id end end
end
for map,kinds in pairs(wildTypes) do
 wildPools[map]={}
 for id,p in ipairs(species) do
  if kinds:find(p.types:match("^%a+"),1,true) then wildPools[map][#wildPools[map]+1]=id end
 end
end
B.wildPools=wildPools
function B.rollWild(s,map) local pool=wildPools[map];return pool[rng(s,#pool)] end
local kits={
 [25]={{name="Quick Attack",kind="damage",type="Normal",power=6},
       {name="Thunder Shock",kind="damage",type="Electric",power=8}},
 [7]={{name="Water Gun",kind="damage",type="Water",power=6},
      {name="Bite",kind="damage",type="Dark",power=8}},
 [1]={{name="Vine Whip",kind="damage",type="Grass",power=6},
      {name="Leech Seed",kind="seed",type="Grass",power=2}},
 [4]={{name="Ember",kind="damage",type="Fire",power=8},
      {name="Scratch",kind="damage",type="Normal",power=6}},
 [27]={{name="Scratch",kind="damage",type="Normal",power=6},
       {name="Poison Sting",kind="damage",type="Poison",power=5}},
 [41]={{name="Wing Attack",kind="damage",type="Flying",power=6},
       {name="Leech Life",kind="drain",type="Bug",power=5}},
 [43]={{name="Absorb",kind="drain",type="Grass",power=5},
       {name="Acid",kind="damage",type="Poison",power=8}},
 [63]={{name="Confusion",kind="damage",type="Psychic",power=8},
       {name="Psybeam",kind="damage",type="Psychic",power=6}},
 [66]={{name="Karate Chop",kind="damage",type="Fighting",power=6},
       {name="Low Kick",kind="damage",type="Fighting",power=8}},
 [74]={{name="Rock Throw",kind="damage",type="Rock",power=8},
       {name="Tackle",kind="damage",type="Normal",power=6}},
 [92]={{name="Lick",kind="damage",type="Ghost",power=6},
       {name="Night Shade",kind="damage",type="Ghost",power=8}},
 [134]={{name="Water Gun",kind="damage",type="Water",power=6},
        {name="Bite",kind="damage",type="Dark",power=8}},
 [135]={{name="Pin Missile",kind="damage",type="Bug",power=6},
        {name="Thunder Shock",kind="damage",type="Electric",power=8}},
 [143]={{name="Body Slam",kind="damage",type="Normal",power=8},
        {name="Lick",kind="damage",type="Ghost",power=6}},
 [152]={{name="Razor Leaf",kind="damage",type="Grass",power=6},
        {name="Tackle",kind="damage",type="Normal",power=6}},
 [158]={{name="Bite",kind="damage",type="Dark",power=6},
        {name="Water Gun",kind="damage",type="Water",power=8}},
 [252]={{name="Quick Attack",kind="damage",type="Normal",power=6},
        {name="Mega Drain",kind="drain",type="Grass",power=5}},
 [255]={{name="Peck",kind="damage",type="Flying",power=6},
        {name="Ember",kind="damage",type="Fire",power=8}},
 [258]={{name="Water Gun",kind="damage",type="Water",power=6},
        {name="Mud Slap",kind="damage",type="Ground",power=8}},
 [270]={{name="Water Gun",kind="damage",type="Water",power=6},
        {name="Mega Drain",kind="drain",type="Grass",power=5}},
 [285]={{name="Mega Drain",kind="drain",type="Grass",power=5},
        {name="Leech Seed",kind="seed",type="Grass",power=2}},
 [304]={{name="Metal Claw",kind="damage",type="Steel",power=8},
        {name="Headbutt",kind="damage",type="Normal",power=8}},
 [363]={{name="Powder Snow",kind="damage",type="Ice",power=6},
        {name="Water Gun",kind="damage",type="Water",power=6}},
}
kits[172]=kits[25]
local typeMoves={Normal="Headbutt",Fire="Ember",Water="Water Gun",Electric="Thunder Shock",
 Grass="Vine Whip",Ice="Powder Snow",Fighting="Low Kick",Poison="Acid",Ground="Mud Slap",
 Flying="Wing Attack",Psychic="Confusion",Bug="Bug Bite",Rock="Rock Throw",Ghost="Lick",
 Dragon="Dragon Breath",Dark="Bite",Steel="Metal Claw",Fairy="Fairy Wind"}
function B.moves(E,id)
 local ancestor=id
 while ancestor do
  if kits[ancestor] then return kits[ancestor] end
  ancestor=E.parents[ancestor]
 end
 local kind=E.species[id].types:match("^%a+")
 return {{name="Tackle",kind="damage",type="Normal",power=6},
  {name=typeMoves[kind],kind="damage",type=kind,power=8}}
end
function B.catalog(E,id)
 local pair=B.moves(E,id)
 return {pair[1],pair[2],{name="Swift",kind="damage",type="Normal",power=8},
  {name="Drain strike",kind="drain",type=E.species[id].types:match("^%a+"),power=5}}
end
function B.equipped(E,b)
 if not b.moves then return B.moves(E,b.ally) end
 local all=B.catalog(E,b.ally);return {all[b.moves[1]],all[b.moves[2]]}
end
function B.maxFoeHP(b) return B.foes[b.foe].hp+(b.floor or 0)*2 end
function B.multiplier(E,kind,id)
 local n=1
 for target in E.species[id].types:gmatch("%a+") do n=n*((types[kind] or {})[target] or 100)/100 end
 return n
end
local function damage(power,multiplier)
 return multiplier==0 and 0 or math.max(1,math.floor(power*multiplier))
end
function B.incoming(E,b)
 local foe=B.foes[b.foe]
 local kind=(b.team or b.wildid) and E.species[B.opponent(b)].types:match("^%a+") or foe.type
 -- Opponents now attack every turn instead of spending half their turns waiting.
 local taken=damage(math.ceil((foe.power+(b.floor or 0))/2),B.multiplier(E,kind,b.ally))
 return taken==0 and 0 or math.max(1,taken-(b.defense or 0))
end
function B.description(move)
 return move.kind=="seed" and "Drains up to 3 HP for three turns"
  or move.kind=="drain" and "Restores up to 3 HP when it hits" or move.type.."-type attack"
end
function B.preview(E,b,slot)
 local move=B.equipped(E,b)[slot]
 if not move then return end
 local mult=B.multiplier(E,move.type,B.opponent(b))
 local dealt=move.power==0 and 0 or damage(move.power,mult)
 return dealt,move,mult
end
function B.hint(E,b,slot)
 local dealt,move,mult=B.preview(E,b,slot)
 if move.power>0 and mult==0 then return "Opponent is immune." end
 if dealt>=b.hp then return b.team and b.opponent<#b.team and "Knocks out this Pokemon." or "Finishes this battle." end
 if move.kind=="drain" or move.kind=="seed" then return B.description(move) end
 if mult>1 then return "Super effective." end
 if mult<1 then return "Not very effective." end
 return B.description(move)
end
function B.resume(b)
 -- Keep the legacy flags readable so existing in-progress saves still load.
 local changed=b.charged or b.boost
 for _,line in ipairs(b.log) do
  local old=line:lower()
  if old:find("guard",1,true) or old:find("charg",1,true) or old:find("block",1,true)
   or old:find("next hit",1,true) then changed=true end
 end
 if changed then
  b.charged=false;b.boost=false
  b.log={b.status=="active" and "Choose a move. Your partner acts first." or "Encounter finished."}
 end
 return changed
end
function B.new(ally,foe,moves,floor,defense,team)
 return {ally=ally,foe=foe,hp=B.foes[foe].hp+(floor or 0)*2,turn=1,charged=false,boost=false,moves=moves,floor=floor,defense=defense,
  team=team,opponent=team and 1 or nil,
  seed=0,status="active",last_move=0,log=team and {"The trainer brought "..#team.." Pokemon.","Your party is ready. Choose a move."} or {"Choose a move. Your partner acts first."}}
end
function B.step(E,b,hp,slot)
 if b.status~="active" or hp<=0 then return hp,false end
 local dealt,move,mult=B.preview(E,b,slot)
 if slot==0 then dealt,move,mult=0,{name="Changed partner",kind="switch",power=0},1 end
 if slot==-1 then dealt,move,mult=0,{name="Used a berry supply",kind="item",power=0},1 end
 if not move then return hp,false end
 local lines={}
 local function say(line) lines[#lines+1]=line end
 b.charged=false;b.boost=false
 b.last_move=math.max(0,slot)
 if move.power>0 then
  b.hp=math.max(0,b.hp-dealt)
  say(move.name..": "..dealt.." damage"..(mult==0 and " (immune)." or mult>1 and " (super effective)." or "."))
 else say(move.name..". The opponent takes its turn.") end
 if move.kind=="drain" and dealt>0 then
  local healed=math.min(3,B.max_hp-hp);hp=hp+healed;say(move.name.." restored "..healed.." HP.")
 end
 if move.kind=="seed" and mult>0 then b.seed=3 end
 if b.hp>0 then
  local taken=B.incoming(E,b)
  say(E.name(B.opponent(b)).." hit back for "..taken.." HP.")
  hp=math.max(0,hp-taken)
  if hp>0 and b.seed>0 then
   local drain=math.min(3,b.hp);b.hp=b.hp-drain;hp=math.min(B.max_hp,hp+drain);b.seed=b.seed-1
   say("Leech Seed drained "..drain.." HP.")
  end
 end
 if hp==0 then b.status="lost"
 elseif b.hp==0 then
  if b.team and b.opponent<#b.team then
   say(E.name(B.opponent(b)).." fainted!")
   b.opponent=b.opponent+1;b.hp=B.maxFoeHP(b);b.charged=false;b.seed=0
   say("The trainer sent out "..E.name(B.opponent(b)).."!")
   if b.turn>=100 then b.status="draw";say("Time for a break. Return to town and try again.") end
  else b.status="won" end
 elseif b.turn>=100 then b.status="draw";say("Time for a break. Return to town and try again.") end
 while #lines>4 do table.remove(lines,1) end
 b.turn=b.turn+1;b.log=lines
 return hp,true
end
function B.valid(b,E)
 if type(b)~="table" then return false end
 local allowed={ally=true,foe=true,hp=true,turn=true,charged=true,boost=true,seed=true,status=true,last_move=true,log=true,moves=true,floor=true,defense=true,practice=true,team=true,opponent=true,party_size=true,wildid=true,recruited=true,gym=true}
 for k in pairs(b) do if not allowed[k] then return false end end
 local function int(n,min,max) return type(n)=="number" and n==n and n>=min and n<=max and n%1==0 end
 if not int(b.ally,1,E.species_count) or not int(b.foe,1,#B.foes)
  or (b.floor~=nil and not int(b.floor,1,6)) or (b.defense~=nil and not int(b.defense,0,5))
  or (b.practice~=nil and b.practice~=true)
  or not int(b.hp,0,B.maxFoeHP(b)) or not int(b.turn,1,101)
  or not int(b.seed,0,3) or not int(b.last_move,0,2)
  or type(b.charged)~="boolean" or type(b.boost)~="boolean" then return false end
 if b.status~="active" and b.status~="won" and b.status~="lost" and b.status~="fled" and b.status~="draw" and b.status~="befriended" then return false end
 if b.team~=nil then
  if not B.validTeam(b.team,E,b.party_size or (b.floor and 3 or 2)) or not int(b.opponent,1,#b.team)
   or not (b.floor or b.practice or teams[b.foe]) or (b.status=="won" and b.opponent~=#b.team) then return false end
 elseif b.opponent~=nil or b.party_size~=nil then return false end
 if b.party_size~=nil and not int(b.party_size,1,6) then return false end
 if b.gym~=nil and (not int(b.gym,1,3) or b.foe~=20+b.gym or not b.team or b.floor or b.practice) then return false end
 if b.wildid~=nil and (not int(b.wildid,1,E.species_count) or b.team or b.floor or b.practice or b.gym) then return false end
 if b.recruited~=nil and (b.recruited~=true or b.status~="befriended" or not b.wildid) then return false end
 if b.status=="befriended" and not b.recruited then return false end
 if (b.status~="befriended" and (b.status=="won")~=(b.hp==0)) or (b.status=="active" and b.turn>100) then return false end
 if b.moves~=nil then
  if type(b.moves)~="table" or not int(b.moves[1],1,4) or not int(b.moves[2],1,4) or b.moves[1]==b.moves[2] then return false end
  for k in pairs(b.moves) do if k~=1 and k~=2 then return false end end
 end
 if type(b.log)~="table" then return false end
 local count=0
 for k,v in pairs(b.log) do
  count=count+1
  if not int(k,1,4) or type(v)~="string" or #v>120 or v:find("[%c]") then return false end
 end
 return count==#b.log
end
return B
