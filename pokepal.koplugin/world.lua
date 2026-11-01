-- Walking and encounters share the normal save, but do not advance reading time.
local W={}
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
W.battle=dofile(dir.."/battle.lua")
W.town=dofile(dir.."/town.lua")
local A=W.town
local oldTown={"TTTTT=TTTTT","TRRR.=.RRRT","TWHW.=.WBWT","T....=....T",
 "==========T","TJ.D.=.S.OT","T....=....T","TTTTTTTTTTT"}
local town7={"TTTTT=TTTTT","TRRR.=....T","TWHW.=..B.T",".....=....T",
 "=RR..=RRRRT","TJWD.=WSWOT","T....=....T","TTTTTTTTTTT"}
W.maps={
 town={name="Fern Town",rows={
  "TTTTT=TTTTT","TRRR.=.RR.T","TWHW.=.WG.T",".....=...BT",
  "=RR..=RRRRT","TJWD.=WSWOT","T....=....T","TTTTTTTTTTT"}},
 meadow={name="Fern Meadow",rows={
  "TTTTT=TTTTT","T,,,..,,,,T","T,,T..,T,,T","T,,?..,,,,T",
  "T...===...T","T,~~.=.,,,T","T,~~.=.,,,T","TTTTT=TTTTT"}},
 centre={name="Pokemon Centre",rows={
  "WWWWWWWWWWW","W.........W","W..CCCC...W","W..P.N....W",
  "W.........W","W.........W","W....=....W","WWWWW=WWWWW"}},
}
W.encounters={{map="meadow",x=3,y=2},{map="meadow",x=9,y=3},{map="meadow",x=9,y=6},
 {map="woods",x=3,y=3},{map="woods",x=9,y=2},{map="woods",x=8,y=6,trainer=true},
 {map="coast",x=3,y=2},{map="coast",x=9,y=5},{map="coast",x=4,y=6,trainer=true},
 {map="cave",x=3,y=2},{map="cave",x=9,y=3},{map="cave",x=8,y=6,trainer=true}}
W.maps.woods={name="Fern Woods",rows={"TTTTTTTTTTT","T,,,T..,,,T","T,,,T.....T","T..L.,,T..T","=..===....=","T..,.=....T","T.?..=.,,,T","TTTTT=TTTTT"}}
W.maps.coast={name="Coast",rows={"TTTTT=TTTTT","T::::=::::T","T:~~:=:~~:T","T:~~:=:~~:T","=::::=::::T","T::::=::::T","T:?::=::::T","TTTTTTTTTTT"}}
W.maps.cave={name="Moon Cave",rows={"###########","#....=....#","#.#..=....#","#..K.=.#..#","#....=....=","#....=....#","#.?..=....#","#####=#####"}}
for name,tile in pairs({dojo="J",shop="S",tower="O",gym="G"}) do
 W.maps[name]={name=name=="dojo" and "Training Dojo" or name=="shop" and "Fern Shop" or name=="gym" and "Fern Gym" or "Battle Tower",
  rows={"WWWWWWWWWWW","W.........W","W..CCCC...W","W...."..tile.."....W","W.........W","W.........W","W....=....W","WWWWW=WWWWW"}}
end
W.links={
 town={["6,1"]={"meadow",6,7},["1,5"]={"woods",2,5,"woods-shortcut"}},
 meadow={["6,8"]={"town",6,2},["6,1"]={"woods",6,7}},
 woods={["6,8"]={"meadow",6,2},["1,5"]={"town",2,4,"woods-shortcut"},["11,5"]={"coast",2,5,"coast"}},
 coast={["1,5"]={"woods",10,5},["6,1"]={"cave",6,7,"cave"}},
 cave={["6,8"]={"coast",6,2},["11,5"]={"meadow",6,2,"cave-shortcut"}},
}
W.hints={town="Centre and Gym north. Trail board east. Shops south.",
 meadow="Visible Pokemon wait for you. Fern Woods is north.",
 woods="Mira's lost Pokemon is here. The Coast path lies east.",
 coast="Meet the beach trainer. Moon Cave is north.",
 cave="Inspect the tracks. Return south to the Coast.",
 centre="Nurse: free healing. PC on the left: your box and party.",
 dojo="Speak to the coach to learn moves or practise.",
 shop="Speak to the shopkeeper for supplies, outfits and decorations.",
 gym="Speak to the Gym guide. Three leaders, three badges.",
 tower="Speak to the attendant. Five battles, then a boss."}
W.directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local function int(n,min,max) return type(n)=="number" and n==n and n>=min and n<=max and n%1==0 end
function W.tile(map,x,y,legacy)
 if not W.maps[map] or not int(x,1,11) or not int(y,1,8) then return end
 if legacy and map=="town" then return (legacy==7 and town7 or oldTown)[y]:sub(x,x) end
 return W.maps[map].rows[y]:sub(x,x)
end
function W.walkable(map,x,y,legacy)
 local tile=W.tile(map,x,y,legacy)
 return tile~=nil and tile~="T" and tile~="R" and tile~="W" and tile~="~" and tile~="C" and tile~="#"
end
function W.event(map,x,y,w)
 for i,e in ipairs(W.encounters) do if e.map==map and e.x==x and e.y==y then return "encounter",i end end
 local link=W.links[map] and W.links[map][x..","..y]
 if link then return link[1],link end
 local tile=W.tile(map,x,y)
 if tile=="L" and w and w.camp and A.has(w.camp.quests,2) then return end
 if map=="town" then return ({H="centre",B="expeditions",D="guide",J="dojo",S="shop",O="tower",G="gym"})[tile] end
 if map=="centre" or map=="dojo" or map=="shop" or map=="tower" or map=="gym" then
  if x==6 and y==8 then return "outside" end
  return ({N="heal",P="party",J="lessons",S="wares",O="towerdesk",G="gymdesk"})[tile]
 end
 return ({L="lost",K="tracks",["?"]="discovery"})[tile]
end
function W.unlocked(w,gate)
 if not gate then return true end
 local c=w.camp
 if gate=="coast" then return c and (A.has(c.badges or 0,1) or A.has(c.quests,2)) end
 if gate=="woods-shortcut" then return c and A.has(c.quests,2) end
 if gate=="cave" then return c and A.has(c.badges or 0,2) or W.cleared(w,9) end
 return c and A.has(c.quests,4)
end
function W.enter(s)
 if s.species==0 then return false end
 local fresh=not s.world
 if fresh then
  s.world={map="town",x=6,y=6,facing="up",step=0,partner=s.species,hp=W.battle.max_hp,cleared=0}
 end
 if not s.world.camp and not s.world.battle and s.world.partner~=s.species then
  s.world.partner=s.species;s.world.hp=W.battle.max_hp;fresh=true
 end
 if A.init(s) then
  fresh=true
  if W.event(s.world.map,s.world.x,s.world.y,s.world) then s.world.x=6;s.world.y=6 end
  if s.world.battle then s.world.battle.moves={1,2} end
 end
 if A.migrate(s,W) then fresh=true end
 if s.world.battle and W.battle.resume(s.world.battle) then fresh=true end
 if s.version<8 then
  if not W.walkable(s.world.map,s.world.x,s.world.y) or W.event(s.world.map,s.world.x,s.world.y,s.world) then
   s.world.x=6;s.world.y=6
  end
  s.version=8;fresh=true
 end
 return fresh
end
function W.cleared(w,index) return math.floor(w.cleared/2^(index-1))%2==1 end
function W.path(w,x,y)
 if not W.walkable(w.map,x,y) then return nil end
 if w.x==x and w.y==y then return {} end
 local queue={{x=w.x,y=w.y}};local head=1;local seen={[w.y*11+w.x]=true};local found
 while head<=#queue do
  local item=queue[head];head=head+1
  for _,d in ipairs({{0,-1},{1,0},{0,1},{-1,0}}) do
   local nx,ny=item.x+d[1],item.y+d[2];local key=ny*11+nx
   if not seen[key] and W.walkable(w.map,nx,ny) and (not W.event(w.map,nx,ny,w) or (nx==x and ny==y)) then
    local node={x=nx,y=ny,parent=item};seen[key]=true;queue[#queue+1]=node
    if nx==x and ny==y then found=node;break end
   end
  end
  if found then break end
 end
 if not found then return nil end
 local path={}
 while found.parent do table.insert(path,1,{x=found.x,y=found.y});found=found.parent end
 return path
end
function W.startBattle(s,index)
 local w=s.world
 if not w or w.battle or not W.encounters[index] then return false,"Finish the current encounter first." end
 local e=W.encounters[index]
 if w.map~=e.map or math.abs(w.x-e.x)+math.abs(w.y-e.y)~=1 then return false,"Walk up to the Pokemon first." end
 if s.trip>0 then return false,"Your partner is on an expedition. Collect it at the trail board first." end
 if s.resting then return false,"Your partner is asleep. Wake it at home before battling." end
 if w.hp==0 then return false,"Your partner needs the Pokemon Centre. Speak to the nurse." end
 local team=e.trainer and W.battle.rollTeam(s,index,#w.camp.party) or nil
 w.battle=W.battle.new(w.partner,index,w.camp and A.moves(s,w.partner),nil,nil,team)
 if team then
  w.battle.party_size=#w.camp.party;local t=A.trainers[index]
  w.battle.log={t[1]..": "..t[W.cleared(w,index) and 3 or 2],"Each trainer brings "..#w.camp.party.." Pokemon."}
 elseif w.camp then w.battle.wildid=w.camp.wild[tostring(index)] end
 return true
end
function W.step(s,x,y)
 local w=s.world
 if not w or w.battle or w.camp and w.camp.tower or math.abs(x-w.x)+math.abs(y-w.y)~=1 or not W.walkable(w.map,x,y) then return false end
 w.facing=x>w.x and "right" or x<w.x and "left" or y>w.y and "down" or "up"
 local event,index=W.event(w.map,x,y,w)
 if event=="encounter" then
  local ok,message=W.startBattle(s,index)
  return true,ok and "battle" or "message",message
 elseif type(index)=="table" then
  if not W.unlocked(w,index[4]) then return true,"message",index[4]=="cave" and "Earn the Tide Badge or beat the Coast trainer." or "Earn the Leaf Badge or help Mira at the town guide." end
  w.map=index[1];w.x=index[2];w.y=index[3]
 elseif event=="heal" then A.heal(w,40);return true,"message","The whole party is rested. Battle HP is full."
 elseif event=="guide" or event=="expeditions" or event=="party" or event=="lessons" or event=="wares" or event=="towerdesk" or event=="gymdesk" then return true,event
 elseif event=="lost" then w.camp.quests=A.set(w.camp.quests,1);return true,"message","Pikachu is safe. Speak to Mira at the town guide."
 elseif event=="tracks" then w.camp.quests=A.set(w.camp.quests,3);return true,"message","These are Onix tracks. Tell Theo at the town guide."
 elseif event=="discovery" then
  local bit=({meadow=1,woods=2,coast=3,cave=4})[w.map]
  if A.has(w.camp.finds,bit) then return true,"message","You already explored this spot." end
  w.camp.finds=A.set(w.camp.finds,bit);s.berries=math.min(999,s.berries+1)
  return true,"message","A small discovery: one berry tucked beside the path."
 elseif event=="centre" or event=="dojo" or event=="shop" or event=="tower" or event=="gym" then w.map=event;w.x=6;w.y=7;w.facing="up"
 elseif event=="outside" then
  local doors={centre={3,4},dojo={2,7},shop={8,7},tower={10,7},gym={9,4}}
  local p=doors[w.map];w.map="town";w.x=p[1];w.y=p[2];w.facing="down"
 else w.x=x;w.y=y end
 w.step=(w.step+1)%2
 return true,event
end
function W.resolve(s,E,now)
 local w=s.world;local b=w.battle
 if w.camp then A.settle(s,E) end
 if b.status=="won" and b.gym and not A.has(w.camp.badges,b.gym) then
  w.camp.badges=A.set(w.camp.badges,b.gym);s.berries=math.min(999,s.berries+5)
  b.log={A.leaders[b.gym].badge.." Badge earned! +5 berries.","Unlocked: "..A.leaders[b.gym].opens.."."}
  E.note(s,"Earned the "..A.leaders[b.gym].badge.." Badge.",now)
 end
 if (b.status=="won" or b.status=="befriended") and not b.floor and not b.practice and not b.gym and not W.cleared(w,b.foe) then
  w.cleared=w.cleared+2^(b.foe-1)
  local reward=W.encounters[b.foe].trainer and 3 or 1
  s.berries=math.min(999,s.berries+reward);A.reward(s,b.ally,3,1)
  local id=W.battle.opponent(b)
  for _,member in ipairs(b.team or {id}) do s.seen[tostring(member)]=true;E.companion.mark(s,member,now) end
  b.log[#b.log+1]="First encounter: +"..reward..(reward==1 and " berry" or " berries")..", +3 XP, +1 bond."
  while #b.log>4 do table.remove(b.log,1) end
  E.note(s,"Won a route battle with "..E.name(id)..".",now)
 end
end
function W.turn(s,E,slot,now)
 local w=s.world;local b=w and w.battle
 if not b or b.status~="active" or s.resting or s.trip>0 or (slot~=1 and slot~=2) then return false end
 local changed;w.hp,changed=W.battle.step(E,b,w.hp,slot)
 if not changed then return false end
 W.resolve(s,E,now);return true
end
function W.finish(s)
 local w=s.world;local b=w and w.battle
 if not b or b.status=="active" then return false end
 if b.floor then
  local c=w.camp
  if b.status=="won" then
   if b.floor==6 then c.rank=math.min(999,c.rank+1);s.berries=math.min(999,s.berries+6);c.outfits=A.set(c.outfits,2);c.tower=nil
   else c.tower.choice=true end
  else c.tower=nil;w.map="centre";w.x=6;w.y=6;w.facing="up" end
 elseif b.status=="lost" then w.map="centre";w.x=6;w.y=6;w.facing="up" end
 if w.camp and w.camp.wild and not b.team and not b.practice and W.encounters[b.foe] and not W.encounters[b.foe].trainer then
  w.camp.wild[tostring(b.foe)]=W.battle.rollWild(s,W.encounters[b.foe].map)
 end
 w.battle=nil;return true
end
function W.valid(w,s,E)
 if w==nil then return true end
 if s.version<5 or type(w)~="table" then return false end
 local allowed={map=true,x=true,y=true,facing=true,step=true,partner=true,hp=true,cleared=true,battle=true,camp=true}
 for k in pairs(w) do if not allowed[k] then return false end end
 if not W.walkable(w.map,w.x,w.y,s.version<8 and (s.version==7 and 7 or true)) or not W.directions[w.facing]
  or not int(w.step,0,1) or not int(w.partner,1,E.species_count) or not s.seen[tostring(w.partner)]
  or not int(w.hp,0,W.battle.max_hp) or not int(w.cleared,0,w.camp and 4095 or 7) then return false end
 if w.camp and not A.valid(w.camp,s,E) then return false end
 if not w.camp and s.version>=6 then return false end
 local event=W.event(w.map,w.x,w.y,w)
 if s.version<8 and w.map=="town" then event=({H=true,B=true,D=true,J=true,S=true,O=true})[W.tile(w.map,w.x,w.y,s.version==7 and 7 or true)] end
 if event and (w.camp or s.version>=6) then return false end
 if w.battle then
  local b=w.battle
  if not W.battle.valid(b,E) or b.ally~=w.partner or (not w.camp and b.ally~=s.species) or s.trip~=0 then return false end
  if s.version<8 and (b.gym or b.recruited or b.party_size or b.wildid) then return false end
  if b.floor then
   local t=w.camp and w.camp.tower
   if not t or t.choice or b.floor~=t.floor or b.defense~=t.defense then return false end
   local foe=A.towerFoe(t.run,t.floor)
   if b.foe~=foe then return false end
  elseif b.gym then
   if w.map~="gym" or not w.camp or (b.gym>1 and not A.has(w.camp.badges,b.gym-1))
    or (b.status=="won" and not A.has(w.camp.badges,b.gym)) then return false end
  elseif b.practice then if w.map~="dojo" or not w.camp or b.foe~=2 then return false end
  else
   local e=W.encounters[b.foe]
   if not e or w.map~=e.map or math.abs(w.x-e.x)+math.abs(w.y-e.y)~=1 then return false end
   if b.team and not e.trainer then return false end
   if (b.status=="won" or b.status=="befriended") and not W.cleared(w,b.foe) then return false end
  end
  if b.status=="lost" and (w.hp~=0 or w.camp and A.alive(w)) then return false end
  if b.status=="active" and w.hp==0 and (not w.camp or not A.alive(w)) then return false end
  if w.camp then
   if b.party_size and b.party_size~=#w.camp.party then return false end
   if b.recruited and (not w.camp.box or not w.camp.box[tostring(W.battle.opponent(b))]) then return false end
   if b.wildid and (not w.camp.wild or w.camp.wild[tostring(b.foe)]~=b.wildid) then return false end
   local slots=A.moves(s,w.partner)
   if not b.moves or b.moves[1]~=slots[1] or b.moves[2]~=slots[2] then return false end
  end
 end
 return true
end
return W
