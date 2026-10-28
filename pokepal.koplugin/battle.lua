-- Turn-based practice battles. No clock, callbacks or device code.
local B={max_hp=40}
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
local types=dofile(dir.."/battle_types.lua")
local rng=dofile(dir.."/random.lua")
local teams={
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
function B.opponent(b) return b.team and b.team[b.opponent] or B.foes[b.foe].id end
function B.validTeam(team,E,count)
 if type(team)~="table" or #team~=count then return false end
 local seen={}
 for k,id in pairs(team) do
  if type(k)~="number" or k%1~=0 or k<1 or k>count or type(id)~="number" or not E.species[id] or seen[id] then return false end
  seen[id]=true
 end
 return true
end
B.foes={
 {id=10,hp=24,power=5,type="Normal",pattern={"charge","attack","guard","attack"}},
 {id=19,hp=28,power=6,type="Normal",pattern={"attack","guard","charge","attack"}},
 {id=74,hp=34,power=7,type="Rock",pattern={"charge","attack","guard","attack"}},
 {id=43,hp=28,power=6,type="Grass",pattern={"guard","attack","charge","attack"}},
 {id=163,hp=30,power=6,type="Flying",pattern={"charge","attack","guard","attack"}},
 {id=14,hp=36,power=7,type="Bug",pattern={"guard","charge","attack","attack"}},
 {id=278,hp=30,power=7,type="Flying",pattern={"charge","attack","guard","attack"}},
 {id=98,hp=34,power=8,type="Water",pattern={"guard","attack","charge","attack"}},
 {id=120,hp=38,power=8,type="Water",pattern={"attack","guard","charge","attack"}},
 {id=41,hp=32,power=7,type="Poison",pattern={"charge","attack","attack","guard"}},
 {id=304,hp=38,power=8,type="Steel",pattern={"guard","charge","attack","attack"}},
 {id=95,hp=42,power=9,type="Rock",pattern={"charge","attack","guard","attack"}},
 {id=280,hp=26,power=4,type="Psychic",pattern={"charge","attack","guard","attack"}},
 {id=66,hp=28,power=4,type="Fighting",pattern={"attack","guard","charge","attack"}},
 {id=81,hp=26,power=4,type="Electric",pattern={"guard","attack","charge","attack"}},
 {id=259,hp=28,power=4,type="Water",pattern={"charge","attack","attack","guard"}},
 {id=253,hp=26,power=4,type="Grass",pattern={"attack","charge","attack","guard"}},
 {id=6,hp=36,power=5,type="Fire",pattern={"guard","charge","attack","attack"}},
 {id=282,hp=36,power=5,type="Psychic",pattern={"charge","attack","guard","attack"}},
 {id=376,hp=36,power=5,type="Steel",pattern={"guard","attack","charge","attack"}},
}
local kits={
 [25]={{name="Quick Attack",kind="quick",type="Normal",power=6},
       {name="Thunder Shock",kind="break",type="Electric",power=8}},
 [7]={{name="Water Gun",kind="quick",type="Water",power=6},
      {name="Withdraw",kind="guard",type="Water",power=0}},
 [1]={{name="Vine Whip",kind="quick",type="Grass",power=6},
      {name="Leech Seed",kind="seed",type="Grass",power=2}},
 [4]={{name="Ember",kind="break",type="Fire",power=8},
      {name="Smokescreen",kind="guard",type="Normal",power=0}},
 [27]={{name="Scratch",kind="quick",type="Normal",power=6},
       {name="Defense Curl",kind="guard",type="Normal",power=0}},
 [41]={{name="Wing Attack",kind="quick",type="Flying",power=6},
       {name="Leech Life",kind="drain",type="Bug",power=5}},
 [43]={{name="Absorb",kind="drain",type="Grass",power=5},
       {name="Acid",kind="break",type="Poison",power=8}},
 [63]={{name="Confusion",kind="break",type="Psychic",power=8},
       {name="Reflect",kind="guard",type="Psychic",power=0}},
 [66]={{name="Karate Chop",kind="quick",type="Fighting",power=6},
       {name="Bulk Up",kind="guard",type="Fighting",power=0}},
 [74]={{name="Rock Throw",kind="break",type="Rock",power=8},
       {name="Defense Curl",kind="guard",type="Normal",power=0}},
 [92]={{name="Lick",kind="quick",type="Ghost",power=6},
       {name="Night Shade",kind="break",type="Ghost",power=8}},
 [134]={{name="Water Gun",kind="quick",type="Water",power=6},
        {name="Acid Armor",kind="guard",type="Poison",power=0}},
 [135]={{name="Pin Missile",kind="quick",type="Bug",power=6},
        {name="Thunder Shock",kind="break",type="Electric",power=8}},
 [143]={{name="Body Slam",kind="break",type="Normal",power=8},
        {name="Amnesia",kind="guard",type="Psychic",power=0}},
 [152]={{name="Razor Leaf",kind="quick",type="Grass",power=6},
        {name="Reflect",kind="guard",type="Psychic",power=0}},
 [158]={{name="Bite",kind="quick",type="Dark",power=6},
        {name="Water Gun",kind="break",type="Water",power=8}},
 [252]={{name="Quick Attack",kind="quick",type="Normal",power=6},
        {name="Mega Drain",kind="drain",type="Grass",power=5}},
 [255]={{name="Peck",kind="quick",type="Flying",power=6},
        {name="Ember",kind="break",type="Fire",power=8}},
 [258]={{name="Water Gun",kind="quick",type="Water",power=6},
        {name="Mud Slap",kind="break",type="Ground",power=8}},
 [270]={{name="Water Gun",kind="quick",type="Water",power=6},
        {name="Mega Drain",kind="drain",type="Grass",power=5}},
 [285]={{name="Mega Drain",kind="drain",type="Grass",power=5},
        {name="Leech Seed",kind="seed",type="Grass",power=2}},
 [304]={{name="Metal Claw",kind="break",type="Steel",power=8},
        {name="Iron Defense",kind="guard",type="Steel",power=0}},
 [363]={{name="Powder Snow",kind="quick",type="Ice",power=6},
        {name="Defense Curl",kind="guard",type="Normal",power=0}},
}
kits[172]=kits[25]
function B.moves(E,id)
 local ancestor=id
 while ancestor do
  if kits[ancestor] then return kits[ancestor] end
  ancestor=E.parents[ancestor]
 end
 local kind=E.species[id].types:match("^%a+")
 return {{name="Quick strike",kind="quick",type="Normal",power=6},
  {name=kind.." burst",kind="break",type=kind,power=8}}
end
function B.catalog(E,id)
 local pair=B.moves(E,id)
 return {pair[1],pair[2],{name="Protect",kind="guard",type="Normal",power=0},
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
function B.intent(b)
 local pattern=B.foes[b.foe].pattern
 return pattern[(b.turn-1)%#pattern+1]
end
function B.intentText(E,b)
 local intent=B.intent(b)
 if intent=="charge" then return "Charging: interrupt it with a quick move." end
 if intent=="guard" then return "Guarding: a burst breaks through." end
 return (b.charged and "Strong attack" or "Attack")..": "..B.incoming(E,b).." damage before blocking."
end
function B.incoming(E,b)
 local foe=B.foes[b.foe]
 local kind=b.team and E.species[B.opponent(b)].types:match("^%a+") or foe.type
 return damage((foe.power+(b.floor or 0))*(b.charged and 2 or 1),B.multiplier(E,kind,b.ally))
end
function B.blockedDamage(E,b)
 return math.ceil(B.incoming(E,b)*math.max(0.1,0.25-(b.defense or 0)*0.03))
end
function B.description(move)
 return move.kind=="quick" and "Interrupts a charge" or move.kind=="break" and "Breaks a guard"
  or move.kind=="guard" and "Blocks a hit and strengthens your next attack"
  or move.kind=="seed" and "Drains up to 3 HP for three turns" or "Restores up to 3 HP when it hits"
end
function B.preview(E,b,slot)
 local move=B.equipped(E,b)[slot]
 if not move then return end
 local intent=B.intent(b)
 local power=move.power+(b.boost and move.power>0 and 4 or 0)
 if move.kind=="quick" and intent=="charge" then power=power+2 end
 if move.kind=="break" and intent=="guard" then power=power+6 end
 local mult=B.multiplier(E,move.type,B.opponent(b))
 local dealt=move.power==0 and 0 or damage(power,mult)
 if intent=="guard" and move.kind~="break" then dealt=math.floor(dealt/2) end
 return dealt,move,mult
end
function B.hint(E,b,slot)
 local dealt,move,mult=B.preview(E,b,slot);local intent=B.intent(b)
 if move.power>0 and mult==0 then return "Opponent is immune." end
 if move.kind=="guard" then
  if intent~="attack" then return "No attack to block this turn." end
  local taken=B.blockedDamage(E,b)
  return taken==0 and "This attack cannot hurt you." or "Take "..taken.." damage. Next hit: +4 power."
 end
 if dealt>=b.hp then return b.team and b.opponent<#b.team and "Knocks out this Pokemon." or "Finishes this battle." end
 if move.kind=="quick" and intent=="charge" then return "Interrupts this charge." end
 if move.kind=="break" and intent=="guard" then return "Breaks this guard." end
 if move.kind=="drain" or move.kind=="seed" then return B.description(move) end
 if intent=="guard" then return "Their guard reduces this hit." end
 if mult>1 then return "Strong type match." end
 if mult<1 then return "This type deals less damage." end
 return B.description(move)
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
 if slot==-1 then dealt,move,mult=0,{name="Used a potion",kind="item",power=0},1 end
 if not move then return hp,false end
 local intent=B.intent(b);local lines={}
 local function say(line) lines[#lines+1]=line end
 b.last_move=math.max(0,slot)
 if move.power>0 then
  b.hp=math.max(0,b.hp-dealt);b.boost=false
  say(move.name..": "..dealt.." damage"..(mult==0 and " (immune)." or mult>1 and " (strong match)." or "."))
 elseif move.kind=="guard" then say(move.name..": ready to block this turn.")
 else say(move.name..". The opponent takes its turn.") end
 if move.kind=="drain" and dealt>0 then
  local healed=math.min(3,B.max_hp-hp);hp=hp+healed;say(move.name.." restored "..healed.." HP.")
 end
 if move.kind=="seed" and mult>0 then b.seed=3 end
 if b.hp>0 then
  if intent=="charge" then
   b.charged=move.kind~="quick" or mult==0
   say(b.charged and "The opponent charged its next attack." or "Charge interrupted!")
  elseif intent=="guard" then
   say(move.kind=="break" and "You broke through its guard!" or "The opponent held its guard.")
  else
   local taken=move.kind=="guard" and B.blockedDamage(E,b) or B.incoming(E,b);b.charged=false
   if move.kind=="guard" then
    b.boost=taken>0
    say(taken==0 and "The attack could not hurt you." or "Blocked! Lost "..taken.." HP. Next hit: +4 power.")
   else say("The opponent hit back for "..taken.." HP.") end
   hp=math.max(0,hp-taken)
  end
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
 local allowed={ally=true,foe=true,hp=true,turn=true,charged=true,boost=true,seed=true,status=true,last_move=true,log=true,moves=true,floor=true,defense=true,practice=true,team=true,opponent=true}
 for k in pairs(b) do if not allowed[k] then return false end end
 local function int(n,min,max) return type(n)=="number" and n==n and n>=min and n<=max and n%1==0 end
 if not int(b.ally,1,E.species_count) or not int(b.foe,1,#B.foes)
  or (b.floor~=nil and not int(b.floor,1,6)) or (b.defense~=nil and not int(b.defense,0,5))
  or (b.practice~=nil and b.practice~=true)
  or not int(b.hp,0,B.maxFoeHP(b)) or not int(b.turn,1,101)
  or not int(b.seed,0,3) or not int(b.last_move,0,2)
  or type(b.charged)~="boolean" or type(b.boost)~="boolean" then return false end
 if b.status~="active" and b.status~="won" and b.status~="lost" and b.status~="fled" and b.status~="draw" then return false end
 if b.team~=nil then
  if not B.validTeam(b.team,E,b.floor and 3 or 2) or not int(b.opponent,1,#b.team)
   or not (b.floor or b.practice or teams[b.foe]) or (b.status=="won" and b.opponent~=#b.team) then return false end
 elseif b.opponent~=nil then return false end
 if (b.status=="won")~=(b.hp==0) or (b.status=="active" and b.turn>100) then return false end
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
