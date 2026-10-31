local E=dofile(BASE..'/engine.lua');local Store=dofile(BASE..'/storage.lua');local S=E.story
local now=1800000000;local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS story: '..name) end
local function roundtrip(s)
 assert(E.valid(s),'invalid story at '..s.story.map..' / '..tostring(s.story.node))
 local data=Store.encode(s);local copy=assert(Store.decode(data,E),'story did not reload')
 assert(Store.encode(copy)==data);return copy
end
local function fresh()
 local s=E.new(now);E.act(s,'choose',25,now);assert(S.enter(s,E));roundtrip(s);return s
end
local function advance(s,choice) assert(S.advance(s.story,choice or 1));roundtrip(s) end
local function dismiss(s)
 for _=1,10 do
  if not s.story.node or S.nodes[s.story.node].op~='text' then return end
  advance(s)
 end
 error('unbounded dialogue')
end
local function walk(s,x,y)
 local t=s.story;local map=t.map
 local path=assert(S.path(t,x,y),'unreachable '..map..' '..x..','..y)
 for _,d in ipairs(path) do
  assert(S.step(t,d[1],d[2]));roundtrip(s)
  if t.node or t.map~=map then break end
 end
end
local function warp(s,dest)
 for _,p in ipairs(S.maps[s.story.map].warps) do if p[3]==dest then walk(s,p[1],p[2]);return end end
 error('no warp to '..dest)
end
local function connect(s,direction)
 local t=s.story;local m=S.maps[t.map];local d=S.directions[direction]
 local link
 for _,p in ipairs(m.links) do if p[1]==({up='north',down='south',left='west',right='east'})[direction] then link=p end end
 assert(link,'missing connection');local dest=S.maps[link[2]];local best
 for y=0,m.height-1 do for x=0,m.width-1 do
  if (d[1]==1 and x==m.width-1 or d[1]==-1 and x==0 or d[2]==1 and y==m.height-1 or d[2]==-1 and y==0) and S.tile(t.map,x,y)=='.' then
   local nx=d[1]==1 and 0 or d[1]==-1 and dest.width-1 or x-link[3]*2
   local ny=d[2]==1 and 0 or d[2]==-1 and dest.height-1 or y-link[3]*2
   if S.tile(link[2],nx,ny)=='.' then
    local path=S.path(t,x,y)
    if path and (not best or #path<#best.path) then best={x=x,y=y,path=path} end
   end
  end
 end end
 assert(best,'unreachable connection '..t.map..' '..direction)
 walk(s,best.x,best.y)
 if not t.node then assert(S.step(t,d[1],d[2]));roundtrip(s) end
end
local function starter(s,choice)
 dismiss(s);warp(s,'PLAYERS_HOUSE_1F');dismiss(s);warp(s,'NEW_BARK_TOWN')
 warp(s,'ELMS_LAB');walk(s,5,2);dismiss(s);assert(s.story.node=='request')
 advance(s,2);dismiss(s);assert(S.stage(s.story)==0)
 walk(s,5,2);dismiss(s);advance(s,1);assert(s.story.node=='choose')
 advance(s,choice);dismiss(s);warp(s,'NEW_BARK_TOWN')
end
local function visit(s)
 connect(s,'left');assert(s.story.map=='Route29')
 connect(s,'left');assert(s.story.map=='CherrygroveCity')
 warp(s,'CHERRYGROVE_POKECENTER_1F');s.story.hp=12;walk(s,5,1);assert(s.story.hp==40);dismiss(s)
 warp(s,'CHERRYGROVE_CITY');connect(s,'up');assert(s.story.map=='Route30')
 warp(s,'MR_POKEMONS_HOUSE');walk(s,3,5);assert(s.story.node=='mrpokemon')
 advance(s);assert(s.story.egg and s.story.node=='oak');advance(s)
 assert(s.story.flags.ENGINE_POKEDEX and s.story.node=='phone');dismiss(s)
 walk(s,3,5);dismiss(s);assert(s.story.egg)
 warp(s,'ROUTE_30');connect(s,'down');assert(s.story.map=='CherrygroveCity')
 connect(s,'right');assert(s.story.node=='rival');advance(s);assert(s.story.node=='fight')
end
local function finish(s)
 assert(S.finishBattle(s.story));roundtrip(s);dismiss(s)
 assert(S.stage(s.story)==4);connect(s,'right');assert(s.story.map=='Route29')
 connect(s,'right');assert(s.story.map=='NewBarkTown');warp(s,'ELMS_LAB')
 assert(s.story.node=='delivery');dismiss(s);assert(S.stage(s.story)==5 and not s.story.egg and s.story.hp==40)
 local saved=E.companion.encode(s.story.flags);walk(s,5,2);dismiss(s)
 assert(saved==E.companion.encode(s.story.flags));roundtrip(s)
end

test('existing saves remain unchanged until starting, and Explore preserves version 9',function()
 local s=E.new(now);E.act(s,'choose',25,now)
 local data=Store.encode(s);assert(Store.encode(assert(Store.decode(data,E)))==data and not s.story)
 S.enter(s,E);local story=E.companion.encode(s.story);E.world.enter(s)
 assert(s.version==9 and E.companion.encode(s.story)==story);roundtrip(s)
 data=Store.encode(s);assert(not S.enter(s,E) and Store.encode(s)==data)
 assert(not S.enter(E.new(now),E))
end)
test('all opening maps, collisions, reciprocal doors and tile counts are bounded',function()
 local count=0
 for name,m in pairs(S.maps) do
  count=count+1;assert(#m.tiles==m.width*m.height and #m.walk==m.height)
  for _,row in ipairs(m.walk) do assert(#row==m.width and not row:find('[^.#CDLRbc]')) end
  assert(S.tile(name,-2,0)=='#' and S.tile(name,0,-1)=='#' and S.tile(name,m.width,0)=='#')
  for _,p in ipairs(m.warps) do assert(S.tile(name,p[1],p[2])=='.') end
 end
 assert(count==9)
end)
local encounter
for choice,id in ipairs({152,155,158}) do
 test('complete the opening on foot with '..E.name(id)..', pausing at every step and event',function()
  local s=fresh();E.world.enter(s)
  local world=E.companion.encode(s.world);local oldversion=s.version
  local before=Store.encode(s);starter(s,choice);assert(s.story.starter==id)
  visit(s);assert(s.story.battle.wildid==({[152]=155,[155]=158,[158]=152})[id])
  if choice==1 then encounter=roundtrip(s) end
  local turns=0
  while s.story.battle.status=='active' do
   assert(S.turn(s.story,E,1));roundtrip(s);turns=turns+1;assert(turns<=100)
  end
  assert(not S.turn(s.story,E,1));finish(s)
  assert(E.companion.encode(s.world)==world)
  local story=s.story;s.story=nil
  local expected=Store.decode(before,E);expected.story=nil
  assert(Store.encode(s)==Store.encode(expected),'story changed companion, reading, rewards or world')
  s.story=story;s.version=oldversion;roundtrip(s)
 end)
end
test('losing the rival encounter still permits the return to Elm',function()
 local s=roundtrip(encounter);s.story.hp=1;assert(S.turn(s.story,E,1))
 assert(s.story.battle.status=='lost');roundtrip(s);finish(s)
end)
test('bad input and duplicated story data cannot execute or enter a broken save',function()
 local s=roundtrip(encounter);local data=Store.encode(s)
 assert(not Store.decode(data..'story='..E.companion.encode(s.story)..'\n',E))
 for i,change in ipairs({
  function(t) t.x=-1 end,function(t) t.y=0/0 end,function(t) t.map='Unknown' end,
  function(t) t.starter=25 end,function(t) t.flags.SOMETHING_NEW=true end,
  function(t) t.flags.ENGINE_POKEDEX=nil end,function(t) t.egg=false end,
  function(t) t.node='deliver' end,function(t) t.node='missing' end,
  function(t) t.battle.wildid=25 end,function(t) t.battle.status='fled' end,
  function(t) t.battle.hp=-1 end,function(t) t.battle=nil end,
 }) do
  local copy=assert(Store.decode(data,E));change(copy.story)
  assert(not E.valid(copy) and not Store.decode(Store.encode(copy),E),'accepted corrupt case '..i)
 end
 assert(not S.advance(s.story,1) and not S.turn(s.story,E,3) and not S.finishBattle(s.story))
 assert(Store.encode(s)==data)
end)
test('old Explore saves migrate before starting the story, keeping the companion',function()
 local s=E.new(now);E.act(s,'choose',25,now);E.world.enter(s)
 s.version=5;s.world.camp=nil
 assert(E.valid(s));assert(S.enter(s,E));roundtrip(s)
 assert(s.world.partner==25 and s.species==25 and s.version==9)
end)
test('the town gate requires a starter and unopened doors leave the player on the map',function()
 local s=fresh();dismiss(s);warp(s,'PLAYERS_HOUSE_1F');dismiss(s);warp(s,'NEW_BARK_TOWN')
 connect(s,'left');assert(s.story.map=='NewBarkTown' and s.story.node=='gate');dismiss(s)
 warp(s,'PLAYERS_NEIGHBORS_HOUSE');assert(s.story.map=='NewBarkTown' and s.story.node=='closed');dismiss(s);roundtrip(s)
end)
test('ledges permit a jump only in their marked direction',function()
 local s=fresh();starter(s,1);connect(s,'left');local t=s.story;local m=S.maps[t.map];local checked=0
 for y=1,m.height-3 do for x=0,m.width-1 do
  if S.tile(t.map,x,y)=='D' and S.tile(t.map,x,y-1)=='.' and S.tile(t.map,x,y+2)=='.' then
   t.x=x;t.y=y-1;assert(S.step(t,0,1));assert(t.y==y);roundtrip(s)
   assert(S.step(t,0,1));assert(t.y==y+2)
   assert(S.step(t,0,-1));assert(t.y==y+2);roundtrip(s);checked=checked+1
  end
 end end
 assert(checked>0)
end)
print('STORY: '..checks..' checks passed')
