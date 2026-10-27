-- Walking and encounters share the normal save, but do not advance reading time.
local W={}
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
W.battle=dofile(dir.."/battle.lua")
W.maps={
 town={name="Fern Town",rows={
  "TTTTT=TTTTT","TRRR.=.RRRT","TWHW.=.WBWT","T....=....T",
  "T=========T","T..D.=....T","T....=....T","TTTTTTTTTTT"}},
 meadow={name="Fern Meadow",rows={
  "TTTTTTTTTTT","T,,,..,,,,T","T,,T..,T,,T","T,,...,,,,T",
  "T...===...T","T,~~.=.,,,T","T,~~.=.,,,T","TTTTT=TTTTT"}},
 centre={name="Pokemon Centre",rows={
  "WWWWWWWWWWW","W.........W","W..CCCC...W","W....N....W",
  "W.........W","W.........W","W....=....W","WWWWW=WWWWW"}},
}
W.encounters={{x=3,y=2},{x=9,y=3},{x=9,y=6}}
W.directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local function int(n,min,max) return type(n)=="number" and n==n and n>=min and n<=max and n%1==0 end
function W.tile(map,x,y)
 if not W.maps[map] or not int(x,1,11) or not int(y,1,8) then return end
 return W.maps[map].rows[y]:sub(x,x)
end
function W.walkable(map,x,y)
 local tile=W.tile(map,x,y)
 return tile~=nil and tile~="T" and tile~="R" and tile~="W" and tile~="~" and tile~="C"
end
function W.event(map,x,y)
 if map=="meadow" then
  for i,e in ipairs(W.encounters) do if e.x==x and e.y==y then return "encounter",i end end
  if x==6 and y==8 then return "town" end
 elseif map=="town" then
  if x==6 and y==1 then return "meadow" end
  local tile=W.tile(map,x,y)
  if tile=="H" then return "centre" elseif tile=="B" then return "expeditions" elseif tile=="D" then return "guide" end
 elseif map=="centre" then
  if x==6 and y==8 then return "outside" end
  if W.tile(map,x,y)=="N" then return "heal" end
 end
end
function W.enter(s)
 if s.species==0 then return false end
 local fresh=not s.world
 if fresh then
  s.world={map="town",x=6,y=6,facing="up",step=0,partner=s.species,hp=W.battle.max_hp,cleared=0}
 end
 if not s.world.battle and s.world.partner~=s.species then
  s.world.partner=s.species;s.world.hp=W.battle.max_hp;fresh=true
 end
 s.version=math.max(s.version,5)
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
   if not seen[key] and W.walkable(w.map,nx,ny) and (not W.event(w.map,nx,ny) or (nx==x and ny==y)) then
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
 if w.map~="meadow" or math.abs(w.x-e.x)+math.abs(w.y-e.y)~=1 then return false,"Walk up to the Pokemon first." end
 if s.trip>0 then return false,"Your partner is on an expedition. Collect it at the trail board first." end
 if s.resting then return false,"Your partner is asleep. Wake it at home before battling." end
 if w.hp==0 then return false,"Your partner needs the Pokemon Centre. Speak to the nurse." end
 w.battle=W.battle.new(s.species,index)
 return true
end
function W.step(s,x,y)
 local w=s.world
 if not w or w.battle or math.abs(x-w.x)+math.abs(y-w.y)~=1 or not W.walkable(w.map,x,y) then return false end
 w.facing=x>w.x and "right" or x<w.x and "left" or y>w.y and "down" or "up"
 local event,index=W.event(w.map,x,y)
 if event=="encounter" then
  local ok,message=W.startBattle(s,index)
  return true,ok and "battle" or "message",message
 elseif event=="heal" then w.hp=W.battle.max_hp;return true,"message","Your partner is rested. Battle HP is full."
 elseif event=="guide" or event=="expeditions" then return true,event
 elseif event=="centre" then w.map="centre";w.x=6;w.y=7;w.facing="up"
 elseif event=="outside" then w.map="town";w.x=3;w.y=4;w.facing="down"
 elseif event=="meadow" then w.map="meadow";w.x=6;w.y=7;w.facing="up"
 elseif event=="town" then w.map="town";w.x=6;w.y=2;w.facing="down"
 else w.x=x;w.y=y end
 w.step=(w.step+1)%2
 return true,event
end
function W.turn(s,E,slot,now)
 local w=s.world;local b=w and w.battle
 if not b or b.status~="active" or s.resting or s.trip>0 then return false end
 local changed;w.hp,changed=W.battle.step(E,b,w.hp,slot)
 if not changed then return false end
 if b.status=="won" and not W.cleared(w,b.foe) then
  w.cleared=w.cleared+2^(b.foe-1)
  s.berries=math.min(999,s.berries+1);s.xp=math.min(1e12,s.xp+3);s.bond=math.min(100,s.bond+1)
  local id=W.battle.foes[b.foe].id;s.seen[tostring(id)]=true;E.companion.mark(s,id,now)
  b.log[#b.log+1]="First win: +1 berry, +3 XP, +1 bond."
  E.note(s,"Won a meadow battle with "..E.name(id)..".",now)
 end
 return true
end
function W.finish(s)
 local w=s.world;local b=w and w.battle
 if not b or b.status=="active" then return false end
 if b.status=="lost" then w.map="centre";w.x=6;w.y=6;w.facing="up" end
 w.battle=nil;return true
end
function W.valid(w,s,E)
 if w==nil then return true end
 if s.version<5 or type(w)~="table" then return false end
 local allowed={map=true,x=true,y=true,facing=true,step=true,partner=true,hp=true,cleared=true,battle=true}
 for k in pairs(w) do if not allowed[k] then return false end end
 if not W.walkable(w.map,w.x,w.y) or W.event(w.map,w.x,w.y) or not W.directions[w.facing]
  or not int(w.step,0,1) or not int(w.partner,1,E.species_count) or not s.seen[tostring(w.partner)]
  or not int(w.hp,0,W.battle.max_hp) or not int(w.cleared,0,7) then return false end
 if w.battle then
  local b=w.battle
  if not W.battle.valid(b,E) or w.map~="meadow" or b.ally~=w.partner or b.ally~=s.species or s.trip~=0 then return false end
  local e=W.encounters[b.foe]
  if math.abs(w.x-e.x)+math.abs(w.y-e.y)~=1 or (b.status=="lost")~=(w.hp==0) then return false end
  if b.status=="won" and not W.cleared(w,b.foe) then return false end
 end
 return true
end
return W
