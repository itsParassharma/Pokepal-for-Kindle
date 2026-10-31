-- Saved story events and navigation. No device calls or timers.
local S={max_potions=5}
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
local data=dofile(dir.."/story_maps.lua")
S.maps=data.maps;S.nodes=dofile(dir.."/story_data.lua")
S.trainers=dofile(dir.."/story_trainers.lua")
local legacy=dofile(dir.."/story_legacy.lua")
-- shortcut: use PokePal's battles until the Crystal battle engine is implemented.
local B=dofile(dir.."/battle.lua");S.battle=B
S.directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local connections={up="north",down="south",left="west",right="east"}
local moves={{0,-1},{1,0},{0,1},{-1,0}}
local people={PlayersHouse1F={{7,4,"mom","mom"}},ElmsLab={{5,2,"elm","elm"}},
 CherrygroveCity={{32,6,"gramps","guide"}},CherrygrovePokecenter1F={{5,1,"nurse","heal"}},
 MrPokemonsHouse={{3,5,"gentleman","mrpokemon"},{6,5,"oak","oak"}},NewBarkTown={{6,8,"teacher","gate"}},
 Route31VioletGate={{5,2,"officer","violet_guide"}},VioletPokecenter1F={{3,1,"nurse","heal"}},
 VioletCity={{17,20,"gramps","violet_guide"}},SproutTower1F={{7,4,"sage","tower_guide"}},
 VioletGym={{7,13,"gym_guide","gym_guide"}}}
local flags={ENGINE_POKEGEAR=true,POKEPAL_ELM_MISSION=true,
 EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON=true,ENGINE_POKEDEX=true,EVENT_BEAT_RIVAL_1=true,EVENT_GAVE_MYSTERY_EGG_TO_ELM=true,
 POKEPAL_REACHED_VIOLET=true,POKEPAL_SPROUT_RIVAL_SEEN=true,EVENT_GOT_HM05_FLASH=true,ENGINE_ZEPHYRBADGE=true}
for key,trainer in pairs(S.trainers) do
 trainer.team=assert(data.teams[key]);flags[trainer.flag]=true
 S.nodes["challenge_"..key]={op="text",who=trainer.name,lines=trainer.lines or {"Let's see how you work together.","I have "..#trainer.team.." Pokemon ready."},next="battle_"..key}
 S.nodes["battle_"..key]={op="battle",id=key}
 S.nodes["won_"..key]={op="text",who=trainer.name,lines=trainer.reward or {"Well fought! You and your partner won.","I'll step aside so you can continue."}}
end
local operations={text=true,choice=true,flag=true,heal=true,egg=true,battle=true,deliver=true}
for key,n in pairs(S.nodes) do
 assert(operations[n.op],"Unsupported story command: "..tostring(n.op))
 assert(not n.next or S.nodes[n.next],key)
 if n.op=="flag" then assert(flags[n.key]) end
 for _,choice in ipairs(n.choices or {}) do assert(S.nodes[choice[2]],key) end
end
function S.stage(t)
 local f=t.flags
 return f.ENGINE_ZEPHYRBADGE and 8 or f.EVENT_GOT_HM05_FLASH and 7 or f.POKEPAL_REACHED_VIOLET and 6
  or f.EVENT_GAVE_MYSTERY_EGG_TO_ELM and 5 or f.EVENT_BEAT_RIVAL_1 and 4
  or f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON and 3 or f.POKEPAL_ELM_MISSION and 2 or 0
end
function S.objective(t)
 return ({[0]="Visit Professor Elm in New Bark Town.",[2]="Visit Mr. Pokemon on Route 30.",
 [3]="Bring the Mystery Egg back to Elm.",[4]="Return to Professor Elm's lab.",
 [5]="Take Route 30 north to Violet City.",[6]="Meet the elder at the top of Sprout Tower.",
 [7]="Challenge Falkner at Violet Gym.",[8]="Chapter 2 complete. Zephyr Badge earned."})[S.stage(t)]
end
local function roster(t) return t.encounter=="rival" and {t.rival} or S.trainers[t.encounter].team end
function S.hasNext(t) return t.battle and t.opponent<#roster(t) end
function S.battleTitle(t) return t.encounter=="rival" and "Rival battle" or S.trainers[t.encounter].name end
function S.teamSize(t) return #roster(t) end
local function equip(b,E)
 local first=B.preview(E,b,1);local second=B.preview(E,b,2)
 -- Use the existing Swift option when both usual moves meet an immunity.
 if first==0 and second==0 then b.moves={1,3} end
end
local function startBattle(t,key,E)
 t.encounter=key;t.opponent=1;t.battle=B.new(t.partner,1)
 t.battle.wildid=roster(t)[1];equip(t.battle,E)
end
local function run(t,key,E)
 for _=1,16 do
  t.node=key;if not key then return end
  local n=assert(S.nodes[key],"Unknown story node")
  if n.op=="text" or n.op=="choice" then return end
  if n.op=="flag" then t.flags[n.key]=true
  elseif n.op=="heal" then t.hp=40;t.potions=S.max_potions
  elseif n.op=="egg" then
   if not t.flags.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON then t.egg=true;t.flags.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON=true end
  elseif n.op=="deliver" then
   if t.egg then t.egg=false;t.flags.EVENT_GAVE_MYSTERY_EGG_TO_ELM=true end
  elseif n.op=="battle" then
   if not t.battle then startBattle(t,n.id or "rival",E) end
   return
  else error("Unsupported story command: "..tostring(n.op)) end
  key=n.next
 end
 error("Story event exceeded its step limit")
end
local function rivalFor(id,E)
 local chosen,score=155,-1
 for _,candidate in ipairs({155,158,152}) do
  local strength=B.multiplier(E,E.species[candidate].types:match("^%a+"),id)
  if strength>score then chosen=candidate;score=strength end
 end
 return chosen
end
function S.sync(s)
 local t=s.story
 if t and not t.battle and t.partner~=s.species then t.partner=s.species;return true end
 return false
end
function S.enter(s,E)
 if s.species==0 then return false end
 local t=s.story
 if t then
  if t.version==1 then
   t.version=2;t.partner=s.species;t.starter=nil;t.potions=S.max_potions
   t.rival=t.battle and t.battle.wildid or rivalFor(s.species,E)
   t.flags.EVENT_GOT_A_POKEMON_FROM_ELM=nil
   if t.node=="choose" then t.node="directions" end
   if t.battle then
    t.encounter="rival";t.opponent=1;t.battle.ally=t.partner;equip(t.battle,E)
   end
   s.version=math.max(s.version,10);return true
  end
  return S.sync(s)
 end
 if s.world then E.world.enter(s) end
 s.story={version=2,map="PlayersHouse2F",x=3,y=3,facing="down",step=0,partner=s.species,rival=rivalFor(s.species,E),hp=40,potions=S.max_potions,egg=false,flags={}}
 s.version=math.max(s.version,10);run(s.story,"welcome");return true
end
function S.advance(t,index,E)
 local n=t.node and S.nodes[t.node]
 if not n then return false end
 if n.op=="text" and index==1 then run(t,n.next,E);return true end
 if n.op=="choice" and type(index)=="number" and n.choices[index] then run(t,n.choices[index][2],E);return true end
 return false
end
function S.turn(t,E,slot)
 local b=t.battle
 if not b or b.status~="active" or (slot~=1 and slot~=2 and slot~="potion") then return false end
 local healed
 if slot=="potion" then
  if t.potions==0 or t.hp==40 then return false end
  healed=math.min(50,40-t.hp);t.hp=t.hp+healed;t.potions=t.potions-1;slot=-1
 end
 local changed;t.hp,changed=B.step(E,b,t.hp,slot)
 if healed then b.log[1]="Super Potion restored "..healed.." HP." end
 if changed and b.status=="won" and S.hasNext(t) then
  t.opponent=t.opponent+1
  local next=B.new(t.partner,1);next.wildid=roster(t)[t.opponent];next.turn=b.turn;next.moves=b.moves;equip(next,E)
  next.log={E.name(B.opponent(b)).." fainted!","The trainer sent out "..E.name(next.wildid).."!"}
  if next.turn>100 then next.status="draw" end
  t.battle=next
 end
 return changed
end
function S.finishBattle(t)
 local b=t.battle;if not b or b.status=="active" then return false end
 local key=t.encounter;t.battle=nil;t.encounter=nil;t.opponent=nil
 if key=="rival" then run(t,"rivalleft")
 elseif b.status=="won" then
  t.flags[S.trainers[key].flag]=true
  if key=="li" then t.flags.EVENT_GOT_HM05_FLASH=true
  elseif key=="falkner" then
   t.flags.ENGINE_ZEPHYRBADGE=true;t.flags.EVENT_BEAT_BIRD_KEEPER_ROD=true;t.flags.EVENT_BEAT_BIRD_KEEPER_ABE=true
  end
  run(t,"won_"..key)
 else
  t.hp=40;t.potions=S.max_potions;t.map=t.flags.POKEPAL_REACHED_VIOLET and "VioletPokecenter1F" or "CherrygrovePokecenter1F"
  t.x=4;t.y=5;t.facing="down";run(t,"defeat")
 end
 return true
end
function S.tile(map,x,y)
 local m=S.maps[map]
 if not m or x<0 or y<0 or x>=m.width or y>=m.height then return "#" end
 return m.walk[y+1]:sub(x+1,x+1)
end
function S.npcs(t)
 if t.map=="CherrygroveCity" and S.stage(t)==3 then return {{32,6,"rival","rival"}} end
 local result={}
 for _,p in ipairs(people[t.map] or {}) do result[#result+1]=p end
 if S.stage(t)>=5 then
  for key,p in pairs(S.trainers) do
   if p.map==t.map and (p.stay or not t.flags[p.flag]) then result[#result+1]={p.x,p.y,p.sprite,key} end
  end
 end
 if t.map=="SproutTower3F" and not t.flags.POKEPAL_SPROUT_RIVAL_SEEN then result[#result+1]={10,4,"rival","tower_rival"} end
 return result
end
local function npc(t,x,y)
 for _,p in ipairs(S.npcs(t)) do if p[1]==x and p[2]==y then return p end end
end
local function facingNpc(t,x,y,dx,dy)
 local p=npc(t,x+dx,y+dy)
 if not p and S.tile(t.map,x+dx,y+dy)=="C" then p=npc(t,x+2*dx,y+2*dy) end
 return p
end
local function talk(t,key)
 local stage=S.stage(t);local trainer=S.trainers[key]
 if trainer then
  if t.flags[trainer.flag] then key="won_"..key
  elseif key=="li" and not t.flags.POKEPAL_SPROUT_RIVAL_SEEN then key="tower_rival"
  elseif t.hp==0 then key="needheal"
  else key="challenge_"..key end
 elseif key=="mom" then key=t.flags.ENGINE_POKEGEAR and "rest" or "mom"
 elseif key=="elm" then key=stage==0 and "elm" or stage==4 and "delivery" or stage>=5 and "complete" or "directions"
 elseif key=="mrpokemon" or key=="oak" then key=stage<2 and "gate" or stage==2 and "mrpokemon" or stage>=5 and "rest" or "remind"
 elseif key=="heal" then key="rest"
 elseif key=="gate" then key=stage<2 and "gate" or "sign" end
 run(t,key)
end
function S.warpAt(map,x,y)
 for _,p in ipairs(S.maps[map].warps) do if p[1]==x and p[2]==y then return p end end
end
local function ground(tile) return tile=="." or tile=="U" or tile=="D" or tile=="L" or tile=="R" or tile=="b" or tile=="c" end
local function landing(t,x,y,dx,dy)
 local nx,ny=x+dx,y+dy;local tile=S.tile(t.map,nx,ny)
 -- An upper wall blocks crossing its top edge, but allows walking beside it.
 if dy==1 and tile=="U" or dy==-1 and S.tile(t.map,x,y)=="U" then return end
 if ground(tile) then return nx,ny end
 -- Crystal ledges are standing tiles; the jump crosses the wall beside them.
 tile=S.tile(t.map,x,y)
 if dy==1 and (tile=="D" or tile=="b" or tile=="c") or dx==1 and (tile=="R" or tile=="b") or dx==-1 and (tile=="L" or tile=="c") then
  nx,ny=nx+dx,ny+dy
  if ground(S.tile(t.map,nx,ny)) and not npc(t,nx,ny) then return nx,ny end
 end
end
local function arrived(t)
 if t.map=="PlayersHouse1F" and not t.flags.ENGINE_POKEGEAR then run(t,"mom")
 elseif t.map=="ElmsLab" and S.stage(t)==4 then run(t,"delivery")
 elseif t.map=="VioletCity" and not t.flags.POKEPAL_REACHED_VIOLET then
  t.flags.POKEPAL_REACHED_VIOLET=true;run(t,"violet")
 end
end
function S.step(t,dx,dy)
 if t.node or math.abs(dx)+math.abs(dy)~=1 then return false end
 local m=S.maps[t.map];local nx,ny=t.x+dx,t.y+dy
 t.facing=dx==1 and "right" or dx==-1 and "left" or dy==1 and "down" or "up"
 if nx<0 or ny<0 or nx>=m.width or ny>=m.height then
  for _,link in ipairs(m.links) do if link[1]==connections[t.facing] then
   if t.map=="NewBarkTown" and not t.flags.POKEPAL_ELM_MISSION then run(t,"gate");return true end
   if t.map=="CherrygroveCity" and link[1]=="east" and S.stage(t)==3 then run(t,"rival");return true end
   if t.map=="Route30" and link[1]=="north" and not t.flags.EVENT_GAVE_MYSTERY_EGG_TO_ELM then run(t,"errand_first");return true end
   local dest=S.maps[link[2]]
   if dest then
    local x=dx==1 and 0 or dx==-1 and dest.width-1 or t.x-link[3]*2
    local y=dy==1 and 0 or dy==-1 and dest.height-1 or t.y-link[3]*2
    if S.tile(link[2],x,y)=="." then t.map=link[2];t.x=x;t.y=y;arrived(t);return true end
   end
  end end
  run(t,"closed");return true
 end
 local person=facingNpc(t,t.x,t.y,dx,dy)
 if person then talk(t,person[4]);return true end
 nx,ny=landing(t,t.x,t.y,dx,dy);if not nx then return true end
 if t.map=="CherrygroveCity" and nx==33 and (ny==6 or ny==7) and S.stage(t)==3 then run(t,"rival");return true end
 if t.map=="SproutTower3F" and nx==11 and ny==9 and not t.flags.POKEPAL_SPROUT_RIVAL_SEEN then run(t,"tower_rival");return true end
 local warp=S.warpAt(t.map,nx,ny)
 if warp then
  local dest=data.constants[warp[3]];local target=dest and S.maps[dest].warps[warp[4]]
  if not target then run(t,"closed");return true end
  t.map=dest;t.x=target[1];t.y=target[2];arrived(t);return true
 end
 t.x=nx;t.y=ny;t.step=(t.step+1)%2;return true
end
function S.path(t,x,y)
 local m=S.maps[t.map]
 if t.node or x<0 or y<0 or x>=m.width or y>=m.height then return end
 local queue={{x=t.x,y=t.y}};local seen={[t.y*m.width+t.x]=true};local head=1
 while head<=#queue do
  local p=queue[head];head=head+1
  if p.x==x and p.y==y then
   local result={};while p.parent do table.insert(result,1,{p.dx,p.dy});p=p.parent end;return result
  end
  for _,d in ipairs(moves) do
   local nx,ny=landing(t,p.x,p.y,d[1],d[2])
   local person=facingNpc(t,p.x,p.y,d[1],d[2])
   if person and person[1]==x and person[2]==y then nx,ny=x,y elseif person then nx=nil end
   if nx and not seen[ny*m.width+nx] then
    seen[ny*m.width+nx]=true
    if nx==x and ny==y or not S.warpAt(t.map,nx,ny) then queue[#queue+1]={x=nx,y=ny,dx=d[1],dy=d[2],parent=p} end
   end
  end
 end
end
function S.valid(t,s,E)
 if t==nil then return true end
 if type(t)~="table" then return false end
 if t.version==1 then return legacy(t,s,E,S) end
 if s.version<10 or s.species==0 or t.version~=2 then return false end
 local allowed={version=true,map=true,x=true,y=true,facing=true,step=true,partner=true,rival=true,hp=true,potions=true,egg=true,flags=true,node=true,battle=true,encounter=true,opponent=true}
 for k in pairs(t) do if not allowed[k] then return false end end
 local function integer(n,a,b) return type(n)=="number" and n==n and n%1==0 and n>=a and n<=b end
 local m=S.maps[t.map]
 if not m or not integer(t.x,0,m.width-1) or not integer(t.y,0,m.height-1) or not ground(S.tile(t.map,t.x,t.y))
  or not S.directions[t.facing] or not integer(t.step,0,1) or not integer(t.partner,1,E.species_count)
  or (t.rival~=152 and t.rival~=155 and t.rival~=158) or not integer(t.hp,0,40) or not integer(t.potions,0,S.max_potions) or type(t.egg)~="boolean" or type(t.flags)~="table" then return false end
 local f=t.flags
 for k,v in pairs(f) do if not flags[k] or v~=true then return false end end
 if f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON and not f.POKEPAL_ELM_MISSION or f.ENGINE_POKEDEX and not f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON
  or f.EVENT_BEAT_RIVAL_1 and not f.ENGINE_POKEDEX or f.EVENT_GAVE_MYSTERY_EGG_TO_ELM and not f.EVENT_BEAT_RIVAL_1
  or f.POKEPAL_REACHED_VIOLET and not f.EVENT_GAVE_MYSTERY_EGG_TO_ELM then return false end
 if f.POKEPAL_SPROUT_RIVAL_SEEN and not f.POKEPAL_REACHED_VIOLET then return false end
 for key,trainer in pairs(S.trainers) do
  if f[trainer.flag] and not f.EVENT_GAVE_MYSTERY_EGG_TO_ELM then return false end
  if f[trainer.flag] and trainer.map~="Route30" and trainer.map~="Route31" and not f.POKEPAL_REACHED_VIOLET then return false end
 end
 if (f.EVENT_BEAT_SAGE_LI==true)~=(f.EVENT_GOT_HM05_FLASH==true) or (f.EVENT_BEAT_FALKNER==true)~=(f.ENGINE_ZEPHYRBADGE==true)
  or f.EVENT_BEAT_SAGE_LI and not f.POKEPAL_SPROUT_RIVAL_SEEN then return false end
 if f.EVENT_BEAT_FALKNER and (not f.EVENT_BEAT_BIRD_KEEPER_ABE or not f.EVENT_BEAT_BIRD_KEEPER_ROD) then return false end
 if (t.map=="Route31" or t.map=="Route31VioletGate") and not f.EVENT_GAVE_MYSTERY_EGG_TO_ELM then return false end
 if (t.map:match("^Violet") or t.map:match("^Sprout")) and not f.POKEPAL_REACHED_VIOLET then return false end
 if t.egg~=(f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON==true and not f.EVENT_GAVE_MYSTERY_EGG_TO_ELM) then return false end
 local n=t.node and S.nodes[t.node]
 if t.node~=nil and (type(t.node)~="string" or not n or n.op~="text" and n.op~="choice" and n.op~="battle") then return false end
 local event_stage={welcome=0,mom=0,elm=0,request=0,refuse=0,mrpokemon=2,oak=3,phone=3,rival=3,fight=3,rivalleft=3,delivery=4}
 if event_stage[t.node] and S.stage(t)~=event_stage[t.node] then return false end
 local event_map={welcome="PlayersHouse2F",mom="PlayersHouse1F",elm="ElmsLab",request="ElmsLab",refuse="ElmsLab",directions="ElmsLab",delivery="ElmsLab",complete="ElmsLab",
  mrpokemon="MrPokemonsHouse",oak="MrPokemonsHouse",phone="MrPokemonsHouse",remind="MrPokemonsHouse",rival="CherrygroveCity",fight="CherrygroveCity",rivalleft="CherrygroveCity",tower_rival="SproutTower3F",violet="VioletCity"}
 if event_map[t.node] and t.map~=event_map[t.node] or t.node=="complete" and not f.EVENT_GAVE_MYSTERY_EGG_TO_ELM
  or S.stage(t)==3 and not f.ENGINE_POKEDEX and t.node~="oak" then return false end
 local trainer_key=t.node and t.node:match("^challenge_(.+)$") or t.node and t.node:match("^won_(.+)$")
 if trainer_key then
  local trainer=S.trainers[trainer_key]
  if t.map~=trainer.map or not f.EVENT_GAVE_MYSTERY_EGG_TO_ELM or t.node:match("^won_") and not f[trainer.flag] then return false end
  if t.node:match("^challenge_") and (f[trainer.flag] or trainer_key=="li" and not f.POKEPAL_SPROUT_RIVAL_SEEN) then return false end
 end
 if (n~=nil and n.op=="battle")~=(t.battle~=nil) then return false end
 if not t.battle then return t.encounter==nil and t.opponent==nil end
 local b=t.battle;local trainer=S.trainers[t.encounter]
 if t.encounter~="rival" and not trainer then return false end
 local expected=t.encounter=="rival" and "fight" or "battle_"..t.encounter
 if t.node~=expected or not integer(t.opponent,1,#roster(t)) or not B.valid(b,E) or b.ally~=t.partner or b.foe~=1 or b.wildid~=roster(t)[t.opponent]
  or b.team or b.floor or b.gym or b.practice or b.recruited or b.defense
  or b.moves and (b.moves[1]~=1 or b.moves[2]~=3)
  or b.status~="active" and b.status~="won" and b.status~="lost" and b.status~="draw"
  or (b.status=="lost")~=(t.hp==0) or b.status=="won" and S.hasNext(t) then return false end
 if trainer then
  if t.map~=trainer.map or not f.EVENT_GAVE_MYSTERY_EGG_TO_ELM or f[trainer.flag] then return false end
  if trainer.map~="Route30" and trainer.map~="Route31" and not f.POKEPAL_REACHED_VIOLET then return false end
  if t.encounter=="li" and not f.POKEPAL_SPROUT_RIVAL_SEEN then return false end
 else if S.stage(t)~=3 or not f.ENGINE_POKEDEX then return false end end
 return true
end
return S
