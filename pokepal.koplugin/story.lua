-- A saved, bounded event graph for Crystal's opening. No device calls or timers.
local S={}
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
local data=dofile(dir.."/story_maps.lua")
S.maps=data.maps;S.nodes=dofile(dir.."/story_data.lua")
-- shortcut: use PokePal's battles until the Crystal battle engine is implemented.
local B=dofile(dir.."/battle.lua")
S.battle=B
S.directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local starters={[152]=155,[155]=158,[158]=152}
local connections={up="north",down="south",left="west",right="east"}
local moves={{0,-1},{1,0},{0,1},{-1,0}}
local people={PlayersHouse1F={{7,4,"mom","mom"}},ElmsLab={{5,2,"elm","elm"}},
 CherrygroveCity={{32,6,"gramps","guide"}},CherrygrovePokecenter1F={{5,1,"nurse","heal"}},
 MrPokemonsHouse={{3,5,"gentleman","mrpokemon"},{6,5,"oak","oak"}},NewBarkTown={{6,8,"teacher","gate"}}}
local rival={{32,6,"rival","rival"}}
local flags={ENGINE_POKEGEAR=true,POKEPAL_ELM_MISSION=true,EVENT_GOT_A_POKEMON_FROM_ELM=true,
 EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON=true,ENGINE_POKEDEX=true,EVENT_BEAT_RIVAL_1=true,EVENT_GAVE_MYSTERY_EGG_TO_ELM=true}
local operations={text=true,choice=true,flag=true,heal=true,starter=true,egg=true,battle=true,deliver=true}
for key,n in pairs(S.nodes) do
 assert(operations[n.op],"Unsupported story command: "..tostring(n.op))
 assert(not n.next or S.nodes[n.next],key)
 if n.op=="flag" then assert(flags[n.key]) end
 for _,choice in ipairs(n.choices or {}) do assert(S.nodes[choice[2]],key) end
end
function S.stage(t)
 local f=t.flags
 return f.EVENT_GAVE_MYSTERY_EGG_TO_ELM and 5 or f.EVENT_BEAT_RIVAL_1 and 4
  or f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON and 3 or t.starter~=0 and 2 or f.POKEPAL_ELM_MISSION and 1 or 0
end
function S.objective(t)
 return ({[0]="Visit Professor Elm in New Bark Town.",[1]="Choose a story starter at Elm's lab.",
 [2]="Visit Mr. Pokemon on Route 30.",[3]="Bring the Mystery Egg back to Elm.",[4]="Return to Professor Elm's lab.",[5]="Chapter complete. Explore or return home."})[S.stage(t)]
end
local function run(t,key)
 for _=1,16 do
  t.node=key;if not key then return end
  local n=assert(S.nodes[key],"Unknown story node")
  if n.op=="text" or n.op=="choice" then return end
  if n.op=="flag" then t.flags[n.key]=true
  elseif n.op=="heal" then t.hp=40
  elseif n.op=="starter" then
   if t.starter==0 then t.starter=n.id;t.hp=40;t.flags.EVENT_GOT_A_POKEMON_FROM_ELM=true end
  elseif n.op=="egg" then
   if not t.flags.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON then t.egg=true;t.flags.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON=true end
  elseif n.op=="deliver" then
   if t.egg then t.egg=false;t.flags.EVENT_GAVE_MYSTERY_EGG_TO_ELM=true end
  elseif n.op=="battle" then
   if not t.battle then t.battle=B.new(t.starter,1);t.battle.wildid=starters[t.starter] end
   return
  else error("Unsupported story command: "..tostring(n.op)) end
  key=n.next
 end
 error("Story event exceeded its step limit")
end
function S.enter(s,E)
 if s.species==0 or s.story then return false end
 if s.world then E.world.enter(s) end
 s.story={version=1,map="PlayersHouse2F",x=3,y=3,facing="down",step=0,starter=0,hp=40,egg=false,flags={}}
 s.version=math.max(s.version,9);run(s.story,"welcome");return true
end
function S.advance(t,index)
 local n=t.node and S.nodes[t.node]
 if not n then return false end
 if n.op=="text" and index==1 then run(t,n.next);return true end
 if n.op=="choice" and type(index)=="number" and n.choices[index] then run(t,n.choices[index][2]);return true end
 return false
end
function S.turn(t,E,slot)
 if t.node~="fight" or not t.battle or (slot~=1 and slot~=2) then return false end
 local changed;t.hp,changed=B.step(E,t.battle,t.hp,slot);return changed
end
function S.finishBattle(t)
 if t.node~="fight" or not t.battle or t.battle.status=="active" then return false end
 t.battle=nil;run(t,"rivalleft");return true
end
function S.tile(map,x,y)
 local m=S.maps[map]
 if not m or x<0 or y<0 or x>=m.width or y>=m.height then return "#" end
 return m.walk[y+1]:sub(x+1,x+1)
end
function S.npcs(t)
 if t.map=="CherrygroveCity" and S.stage(t)==3 then return rival end
 return people[t.map] or {}
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
 local stage=S.stage(t)
 if key=="mom" then key=t.flags.ENGINE_POKEGEAR and "rest" or "mom"
 elseif key=="elm" then key=stage==0 and "elm" or stage==1 and "choose" or stage==4 and "delivery" or stage==5 and "complete" or "directions"
 elseif key=="mrpokemon" or key=="oak" then key=stage<2 and "gate" or stage==2 and "mrpokemon" or stage==5 and "rest" or "remind"
 elseif key=="heal" then key="rest"
 elseif key=="gate" then key=stage<2 and "gate" or "sign" end
 run(t,key)
end
function S.warpAt(map,x,y)
 for _,p in ipairs(S.maps[map].warps) do if p[1]==x and p[2]==y then return p end end
end
local function ground(tile) return tile=="." or tile=="D" or tile=="L" or tile=="R" or tile=="b" or tile=="c" end
local function landing(t,x,y,dx,dy)
 local nx,ny=x+dx,y+dy;local tile=S.tile(t.map,nx,ny)
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
 elseif t.map=="ElmsLab" and S.stage(t)==4 then run(t,"delivery") end
end
function S.step(t,dx,dy)
 if t.node or math.abs(dx)+math.abs(dy)~=1 then return false end
 local m=S.maps[t.map];local nx,ny=t.x+dx,t.y+dy
 t.facing=dx==1 and "right" or dx==-1 and "left" or dy==1 and "down" or "up"
 if nx<0 or ny<0 or nx>=m.width or ny>=m.height then
  for _,link in ipairs(m.links) do if link[1]==connections[t.facing] then
   if t.map=="NewBarkTown" and t.starter==0 then run(t,"gate");return true end
   if t.map=="CherrygroveCity" and link[1]=="east" and S.stage(t)==3 then run(t,"rival");return true end
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
 if s.version<9 or s.species==0 or type(t)~="table" then return false end
 local allowed={version=true,map=true,x=true,y=true,facing=true,step=true,starter=true,hp=true,egg=true,flags=true,node=true,battle=true}
 for k in pairs(t) do if not allowed[k] then return false end end
 local function integer(n,a,b) return type(n)=="number" and n==n and n%1==0 and n>=a and n<=b end
 local m=S.maps[t.map]
 if t.version~=1 or not m or not integer(t.x,0,m.width-1) or not integer(t.y,0,m.height-1)
  or not ground(S.tile(t.map,t.x,t.y)) or not S.directions[t.facing] or not integer(t.step,0,1)
  or (t.starter~=0 and not starters[t.starter]) or not integer(t.hp,0,40) or type(t.egg)~="boolean" or type(t.flags)~="table" then return false end
 for k,v in pairs(t.flags) do if not flags[k] or v~=true then return false end end
 local f=t.flags
 if (t.starter~=0)~=(f.EVENT_GOT_A_POKEMON_FROM_ELM==true) or t.starter~=0 and not f.POKEPAL_ELM_MISSION then return false end
 if f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON and t.starter==0 or f.ENGINE_POKEDEX and not f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON
  or f.EVENT_BEAT_RIVAL_1 and not f.ENGINE_POKEDEX or f.EVENT_GAVE_MYSTERY_EGG_TO_ELM and not f.EVENT_BEAT_RIVAL_1 then return false end
 if t.egg~=(f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON==true and not f.EVENT_GAVE_MYSTERY_EGG_TO_ELM) then return false end
 local n=t.node and S.nodes[t.node]
 if t.node~=nil and (type(t.node)~="string" or not n or n.op~="text" and n.op~="choice" and n.op~="battle") then return false end
 local event_stage={welcome=0,mom=0,elm=0,request=0,refuse=0,choose=1,mrpokemon=2,oak=3,phone=3,rival=3,fight=3,rivalleft=3,delivery=4,complete=5}
 if event_stage[t.node] and S.stage(t)~=event_stage[t.node] then return false end
 local event_map={welcome="PlayersHouse2F",mom="PlayersHouse1F",elm="ElmsLab",request="ElmsLab",refuse="ElmsLab",choose="ElmsLab",directions="ElmsLab",delivery="ElmsLab",complete="ElmsLab",
  mrpokemon="MrPokemonsHouse",oak="MrPokemonsHouse",phone="MrPokemonsHouse",remind="MrPokemonsHouse",rival="CherrygroveCity",fight="CherrygroveCity",rivalleft="CherrygroveCity"}
 if event_map[t.node] and t.map~=event_map[t.node] or S.stage(t)==1 and t.node~="choose"
  or S.stage(t)==3 and not f.ENGINE_POKEDEX and t.node~="oak" then return false end
 if (t.node=="fight")~=(t.battle~=nil) then return false end
 if t.battle then
  local b=t.battle
  if S.stage(t)~=3 or not f.ENGINE_POKEDEX or not B.valid(b,E) or b.ally~=t.starter or b.wildid~=starters[t.starter] or b.foe~=1
   or b.team or b.floor or b.gym or b.practice or b.recruited or b.moves or b.defense
   or (b.status~="active" and b.status~="won" and b.status~="lost" and b.status~="draw")
   or (b.status=="lost")~=(t.hp==0) then return false end
 end
 return true
end
return S
