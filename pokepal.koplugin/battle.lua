-- Turn-based practice battles. No clock, callbacks or device code.
local B={max_hp=40}
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
local types=dofile(dir.."/battle_types.lua")
B.foes={
 {id=10,hp=24,power=5,type="Normal",pattern={"charge","attack","guard","attack"}},
 {id=19,hp=28,power=6,type="Normal",pattern={"attack","guard","charge","attack"}},
 {id=74,hp=34,power=7,type="Rock",pattern={"charge","attack","guard","attack"}},
}
local kits={
 [25]={{name="Quick Attack",kind="quick",type="Normal",power=6},
       {name="Thunder Shock",kind="break",type="Electric",power=8}},
 [7]={{name="Water Gun",kind="quick",type="Water",power=6},
      {name="Withdraw",kind="guard",type="Water",power=0}},
 [1]={{name="Vine Whip",kind="quick",type="Grass",power=6},
      {name="Leech Seed",kind="seed",type="Grass",power=2}},
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
 return damage(foe.power*(b.charged and 2 or 1),B.multiplier(E,foe.type,b.ally))
end
function B.preview(E,b,slot)
 local move=B.moves(E,b.ally)[slot]
 if not move then return end
 local intent=B.intent(b)
 local power=move.power+(b.boost and move.power>0 and 4 or 0)
 if move.kind=="quick" and intent=="charge" then power=power+2 end
 if move.kind=="break" and intent=="guard" then power=power+6 end
 local mult=B.multiplier(E,move.type,B.foes[b.foe].id)
 local dealt=move.power==0 and 0 or damage(power,mult)
 if intent=="guard" and move.kind~="break" then dealt=math.floor(dealt/2) end
 return dealt,move,mult
end
function B.new(ally,foe)
 return {ally=ally,foe=foe,hp=B.foes[foe].hp,turn=1,charged=false,boost=false,
  seed=0,status="active",last_move=0,log={"Choose a move. Your partner acts first."}}
end
function B.step(E,b,hp,slot)
 if b.status~="active" or hp<=0 then return hp,false end
 local dealt,move,mult=B.preview(E,b,slot)
 if not move then return hp,false end
 local intent=B.intent(b);local lines={}
 local function say(line) lines[#lines+1]=line end
 b.last_move=slot
 if move.power>0 then
  b.hp=math.max(0,b.hp-dealt);b.boost=false
  say(move.name..": "..dealt.." damage"..(mult==0 and " (immune)." or mult>1 and " (strong match)." or "."))
 else say("Withdraw: ready to block this turn.") end
 if move.kind=="seed" and mult>0 then b.seed=3 end
 if b.hp>0 then
  if intent=="charge" then
   b.charged=move.kind~="quick" or mult==0
   say(b.charged and "The wild Pokemon charged its next attack." or "Charge interrupted!")
  elseif intent=="guard" then
   say(move.kind=="break" and "You broke through its guard!" or "The wild Pokemon held its guard.")
  else
   local taken=B.incoming(E,b);b.charged=false
   if move.kind=="guard" then
    taken=math.ceil(taken/4);b.boost=taken>0
    say("Blocked! Lost "..taken.." HP. Next hit: +4 power.")
   else say("The wild Pokemon hit back for "..taken.." HP.") end
   hp=math.max(0,hp-taken)
  end
  if hp>0 and b.seed>0 then
   local drain=math.min(3,b.hp);b.hp=b.hp-drain;hp=math.min(B.max_hp,hp+drain);b.seed=b.seed-1
   say("Leech Seed drained "..drain.." HP.")
  end
 end
 if hp==0 then b.status="lost"
 elseif b.hp==0 then b.status="won"
 elseif b.turn>=100 then b.status="draw";say("Time for a break. Return to town and try again.") end
 b.turn=b.turn+1;b.log=lines
 return hp,true
end
function B.valid(b,E)
 if type(b)~="table" then return false end
 local allowed={ally=true,foe=true,hp=true,turn=true,charged=true,boost=true,seed=true,status=true,last_move=true,log=true}
 for k in pairs(b) do if not allowed[k] then return false end end
 local function int(n,min,max) return type(n)=="number" and n==n and n>=min and n<=max and n%1==0 end
 if not int(b.ally,1,E.species_count) or not int(b.foe,1,#B.foes)
  or not int(b.hp,0,B.foes[b.foe].hp) or not int(b.turn,1,101)
  or not int(b.seed,0,3) or not int(b.last_move,0,2)
  or type(b.charged)~="boolean" or type(b.boost)~="boolean" then return false end
 if b.status~="active" and b.status~="won" and b.status~="lost" and b.status~="fled" and b.status~="draw" then return false end
 if (b.status=="won")~=(b.hp==0) or (b.status=="active" and b.turn>100) then return false end
 if type(b.log)~="table" then return false end
 local count=0
 for k,v in pairs(b.log) do
  count=count+1
  if not int(k,1,4) or type(v)~="string" or #v>120 or v:find("[%c]") then return false end
 end
 return count==#b.log
end
return B
