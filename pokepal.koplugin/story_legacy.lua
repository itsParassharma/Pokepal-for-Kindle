-- Validate version 1 snapshots before the one-way story migration.
local starters={[152]=155,[155]=158,[158]=152}
local maps={PlayersHouse2F=true,PlayersHouse1F=true,NewBarkTown=true,ElmsLab=true,Route29=true,CherrygroveCity=true,CherrygrovePokecenter1F=true,Route30=true,MrPokemonsHouse=true}
local function ground(tile) return tile:match('^[.GDLRbc]$')~=nil end
local nodes={}
for _,key in ipairs({'welcome','mom','rested','elm','refuse','directions','mrpokemon','oak','phone','remind','rival','rivalleft','delivery','complete','gate','closed','sign'}) do nodes[key]={op='text'} end
nodes.choose={op='choice'};nodes.request={op='choice'};nodes.fight={op='battle'}
local flags={ENGINE_POKEGEAR=true,POKEPAL_ELM_MISSION=true,EVENT_GOT_A_POKEMON_FROM_ELM=true,
 EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON=true,ENGINE_POKEDEX=true,EVENT_BEAT_RIVAL_1=true,EVENT_GAVE_MYSTERY_EGG_TO_ELM=true}
local function stage(t)
 local f=t.flags
 return f.EVENT_GAVE_MYSTERY_EGG_TO_ELM and 5 or f.EVENT_BEAT_RIVAL_1 and 4
  or f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON and 3 or t.starter~=0 and 2 or f.POKEPAL_ELM_MISSION and 1 or 0
end
return function(t,s,E,S)
 if t==nil then return true end
 if s.version<9 or s.species==0 or type(t)~="table" then return false end
 local allowed={version=true,map=true,x=true,y=true,facing=true,step=true,starter=true,hp=true,egg=true,flags=true,node=true,battle=true}
 for k in pairs(t) do if not allowed[k] then return false end end
 local function integer(n,a,b) return type(n)=="number" and n==n and n%1==0 and n>=a and n<=b end
 local m=S.maps[t.map]
 if t.version~=1 or not maps[t.map] or not m or not integer(t.x,0,m.width-1) or not integer(t.y,0,m.height-1)
  or not ground(S.tile(t.map,t.x,t.y)) or not S.directions[t.facing] or not integer(t.step,0,1)
  or (t.starter~=0 and not starters[t.starter]) or not integer(t.hp,0,40) or type(t.egg)~="boolean" or type(t.flags)~="table" then return false end
 for k,v in pairs(t.flags) do if not flags[k] or v~=true then return false end end
 local f=t.flags
 if (t.starter~=0)~=(f.EVENT_GOT_A_POKEMON_FROM_ELM==true) or t.starter~=0 and not f.POKEPAL_ELM_MISSION then return false end
 if f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON and t.starter==0 or f.ENGINE_POKEDEX and not f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON
  or f.EVENT_BEAT_RIVAL_1 and not f.ENGINE_POKEDEX or f.EVENT_GAVE_MYSTERY_EGG_TO_ELM and not f.EVENT_BEAT_RIVAL_1 then return false end
 if t.egg~=(f.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON==true and not f.EVENT_GAVE_MYSTERY_EGG_TO_ELM) then return false end
 local n=t.node and nodes[t.node]
 if t.node~=nil and (type(t.node)~="string" or not n or n.op~="text" and n.op~="choice" and n.op~="battle") then return false end
 local event_stage={welcome=0,mom=0,elm=0,request=0,refuse=0,choose=1,mrpokemon=2,oak=3,phone=3,rival=3,fight=3,rivalleft=3,delivery=4,complete=5}
 if event_stage[t.node] and stage(t)~=event_stage[t.node] then return false end
 local event_map={welcome="PlayersHouse2F",mom="PlayersHouse1F",elm="ElmsLab",request="ElmsLab",refuse="ElmsLab",choose="ElmsLab",directions="ElmsLab",delivery="ElmsLab",complete="ElmsLab",
  mrpokemon="MrPokemonsHouse",oak="MrPokemonsHouse",phone="MrPokemonsHouse",remind="MrPokemonsHouse",rival="CherrygroveCity",fight="CherrygroveCity",rivalleft="CherrygroveCity"}
 if event_map[t.node] and t.map~=event_map[t.node] or stage(t)==1 and t.node~="choose"
  or stage(t)==3 and not f.ENGINE_POKEDEX and t.node~="oak" then return false end
 if (t.node=="fight")~=(t.battle~=nil) then return false end
 if t.battle then
  local b=t.battle
  if stage(t)~=3 or not f.ENGINE_POKEDEX or not S.battle.valid(b,E) or b.ally~=t.starter or b.wildid~=starters[t.starter] or b.foe~=1
   or b.team or b.floor or b.gym or b.practice or b.recruited or b.moves or b.defense
   or (b.status~="active" and b.status~="won" and b.status~="lost" and b.status~="draw")
   or (b.status=="lost")~=(t.hp==0) then return false end
 end
 return true
end
