local E=dofile(BASE..'/engine.lua');local Store=dofile(BASE..'/storage.lua');local S=E.story
local now=1800000000;local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS story: '..name) end
local function roundtrip(s)
 assert(E.valid(s),'invalid story at '..s.story.map..' / '..tostring(s.story.node))
 local data=Store.encode(s);local copy=assert(Store.decode(data,E),'story did not reload')
 assert(Store.encode(copy)==data);return copy
end
local function fresh(id)
 local s=E.new(now);E.act(s,'choose',25,now);if id then s.seen[tostring(id)]=true;E.act(s,'partner',id,now) end;assert(S.enter(s,E));roundtrip(s);return s
end
local function advance(s,choice) assert(S.advance(s.story,choice or 1,E));roundtrip(s) end
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
local function mission(s)
 dismiss(s);warp(s,'PLAYERS_HOUSE_1F');dismiss(s);warp(s,'NEW_BARK_TOWN')
 warp(s,'ELMS_LAB');walk(s,5,2);dismiss(s);assert(s.story.node=='request')
 advance(s,2);dismiss(s);assert(S.stage(s.story)==0)
 walk(s,5,2);dismiss(s);advance(s,1);assert(s.story.node=='directions')
 dismiss(s);warp(s,'NEW_BARK_TOWN')
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

test('existing saves remain unchanged until starting, and Explore preserves version 10',function()
 local s=E.new(now);E.act(s,'choose',25,now)
 local data=Store.encode(s);assert(Store.encode(assert(Store.decode(data,E)))==data and not s.story)
 S.enter(s,E);local story=E.companion.encode(s.story);E.world.enter(s)
 assert(s.version==10 and E.companion.encode(s.story)==story);roundtrip(s)
 data=Store.encode(s);assert(not S.enter(s,E) and Store.encode(s)==data)
 assert(not S.enter(E.new(now),E))
end)
test('all opening maps, collisions, reciprocal doors and tile counts are bounded',function()
 local count=0
 for name,m in pairs(S.maps) do
  count=count+1;assert(#m.tiles==m.width*m.height and #m.walk==m.height)
  for _,row in ipairs(m.walk) do assert(#row==m.width and not row:find('[^.#CDLRbcU]')) end
  assert(S.tile(name,-2,0)=='#' and S.tile(name,0,-1)=='#' and S.tile(name,m.width,0)=='#')
  for _,p in ipairs(m.warps) do assert(S.tile(name,p[1],p[2])=='.') end
 end
 assert(count==17)
end)
local encounter
for choice,id in ipairs({25,7,94}) do
 test('complete the opening on foot with '..E.name(id)..', pausing at every step and event',function()
  local s=fresh(id);E.world.enter(s)
  local world=E.companion.encode(s.world);local oldversion=s.version
  local before=Store.encode(s);mission(s);assert(s.story.partner==id and s.species==id)
  visit(s);assert(s.story.battle.wildid==s.story.rival)
  if choice==1 then encounter=roundtrip(s) end
  local turns=0
  while s.story.battle.status=='active' do
   local b=s.story.battle;local slot=S.battle.preview(E,b,2)>S.battle.preview(E,b,1) and 2 or 1
   assert(S.turn(s.story,E,slot));roundtrip(s);turns=turns+1;assert(turns<=100)
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
  function(t) t.partner=0 end,function(t) t.flags.SOMETHING_NEW=true end,
  function(t) t.flags.ENGINE_POKEDEX=nil end,function(t) t.egg=false end,
  function(t) t.node='deliver' end,function(t) t.node='missing' end,
  function(t) t.battle.wildid=25 end,function(t) t.battle.status='fled' end,
  function(t) t.battle.hp=-1 end,function(t) t.battle=nil end,
 }) do
  local copy=assert(Store.decode(data,E));change(copy.story)
  assert(not E.valid(copy) and not Store.decode(Store.encode(copy),E),'accepted corrupt case '..i)
 end
 assert(not S.advance(s.story,1,E) and not S.turn(s.story,E,3) and not S.finishBattle(s.story))
 assert(Store.encode(s)==data)
end)
test('old Explore saves migrate before starting the story, keeping the companion',function()
 local s=E.new(now);E.act(s,'choose',25,now);E.world.enter(s)
 s.version=5;s.world.camp=nil
 assert(E.valid(s));assert(S.enter(s,E));roundtrip(s)
 assert(s.world.partner==25 and s.species==25 and s.version==10)
end)
test('the town gate requires accepting the errand and unopened doors leave the player on the map',function()
 local s=fresh();dismiss(s);warp(s,'PLAYERS_HOUSE_1F');dismiss(s);warp(s,'NEW_BARK_TOWN')
 connect(s,'left');assert(s.story.map=='NewBarkTown' and s.story.node=='gate');dismiss(s)
 warp(s,'PLAYERS_NEIGHBORS_HOUSE');assert(s.story.map=='NewBarkTown' and s.story.node=='closed');dismiss(s);roundtrip(s)
end)
test('ledges permit a jump only in their marked direction',function()
 local s=fresh();mission(s);connect(s,'left');local t=s.story;local m=S.maps[t.map];local checked=0
 for y=1,m.height-3 do for x=0,m.width-1 do
  if S.tile(t.map,x,y)=='D' and S.tile(t.map,x,y-1)=='.' and S.tile(t.map,x,y+2)=='.' then
   t.x=x;t.y=y-1;assert(S.step(t,0,1));assert(t.y==y);roundtrip(s)
   assert(S.step(t,0,1));assert(t.y==y+2)
   assert(S.step(t,0,-1));assert(t.y==y+2);roundtrip(s);checked=checked+1
  end
 end end
 assert(checked>0)
end)
local test_dir=debug.getinfo(1,'S').source:match('^@(.*/)') or BASE..'/../tests/'
local legacy=dofile(test_dir..'story_legacy_fixtures.lua')
local function chapter2()
 local s=assert(Store.decode(legacy.complete,E));assert(S.enter(s,E));dismiss(s);roundtrip(s);return s
end
local function battle(s)
 local t=s.story;local turns=0
 while t.battle.status=='active' do
  local b=t.battle;local slot=S.battle.preview(E,b,2)>S.battle.preview(E,b,1) and 2 or 1
  assert(S.turn(t,E,slot));roundtrip(s);turns=turns+1;assert(turns<=100)
 end
 local won=t.battle.status=='won'
 assert(S.finishBattle(t));roundtrip(s);dismiss(s);return won
end
local constants=dofile(BASE..'/story_maps.lua').constants
-- Search actual reachable doors, including the tower's disconnected floor sections.
local function navigate(s,map,x,y)
 for _=1,30 do
  local t=s.story
  if t.map==map and S.path(t,x,y) then walk(s,x,y);return end
  local queue={{map=t.map,x=t.x,y=t.y,route={}}};local seen={};local head=1;local route
  while head<=#queue do
   local p=queue[head];head=head+1
   local probe={map=p.map,x=p.x,y=p.y,flags=t.flags}
   if p.map==map and S.path(probe,x,y) then route=p.route;break end
   for i,w in ipairs(S.maps[p.map].warps) do
    local dest=constants[w[3]];local target=dest and S.maps[dest].warps[w[4]]
    local key=dest and dest..':'..w[4]
    if target and not seen[key] and S.path(probe,w[1],w[2]) then
     seen[key]=true;local steps={};for _,v in ipairs(p.route) do steps[#steps+1]=v end;steps[#steps+1]=i
     queue[#queue+1]={map=dest,x=target[1],y=target[2],route=steps}
    end
   end
  end
  assert(route and #route>0,'no route from '..t.map..' to '..map..' '..x..','..y)
  local w=S.maps[t.map].warps[route[1]]
  if t.x==w[1] and t.y==w[2] then
   for _,d in pairs(S.directions) do
    local x,y=t.x+d[1],t.y+d[2];local path=S.path(t,x,y)
    if path and #path==1 and not S.warpAt(t.map,x,y) then walk(s,x,y);break end
   end
  end
  walk(s,w[1],w[2])
  if t.node then assert(t.node=='tower_rival' or t.node=='violet',t.node);dismiss(s) end
 end
 error('navigation loop')
end
local function challenge(s,key)
 local p=S.trainers[key];navigate(s,p.map,p.x,p.y)
 if s.story.node=='tower_rival' then dismiss(s);navigate(s,p.map,p.x,p.y) end
 assert(s.story.node=='challenge_'..key,tostring(s.story.node)..' / '..key)
 advance(s);assert(s.story.encounter==key and s.story.opponent==1)
end
test('every companion starts immediately without a second starter choice',function()
 for id=1,E.species_count do
  local s=fresh(id);assert(s.story.partner==id and not s.story.starter)
  assert(S.nodes.choose==nil and S.nodes.chikorita==nil);roundtrip(s)
 end
end)
test('five real chapter 1 snapshots migrate only on entry without resetting progress',function()
 for key,data in pairs(legacy) do
  local s=assert(Store.decode(data,E));assert(Store.encode(s)==data)
  local t=s.story;local map,x,y,hp=t.map,t.x,t.y,t.hp;local oldflags={};for k,v in pairs(t.flags) do oldflags[k]=v end
  local turn=t.battle and t.battle.turn;local foehp=t.battle and t.battle.hp
  assert(S.enter(s,E));assert(t.version==2 and s.version==10 and t.partner==s.species and not t.starter)
  assert(t.map==map and t.x==x and t.y==y and t.hp==hp)
  oldflags.EVENT_GOT_A_POKEMON_FROM_ELM=nil;assert(E.companion.encode(oldflags)==E.companion.encode(t.flags))
  if key=='choose' then assert(t.node=='directions') end
  if turn then assert(t.battle.turn==turn and t.battle.hp==foehp and t.battle.ally==s.species and t.encounter=='rival') end
  roundtrip(s);local migrated=Store.encode(s);assert(not S.enter(s,E) and Store.encode(s)==migrated)
 end
end)
test('partner changes and evolution sync between fights without healing or restarting',function()
 local s=chapter2();local t=s.story;t.hp=19;s.nicknames={['25']='Sparky'}
 s.seen['26']=true;E.act(s,'partner',26,now);assert(S.enter(s,E))
 assert(t.partner==26 and t.hp==19 and S.stage(t)==5);roundtrip(s)
 t.map='VioletGym';t.x=5;t.y=2;t.flags.POKEPAL_REACHED_VIOLET=true;t.node='challenge_falkner';advance(s)
 s.seen['7']=true;E.act(s,'partner',7,now);assert(not S.enter(s,E))
 assert(t.partner==26 and t.battle.ally==26);roundtrip(s)
 battle(s);assert(S.sync(s) and t.partner==7 and t.hp>0);roundtrip(s)
end)
test('trainer rosters preserve repeated species and save each replacement opponent',function()
 local count=0
 for key,p in pairs(S.trainers) do
  local s=chapter2();local t=s.story;t.map=p.map
  for _,d in pairs(S.directions) do
   if S.tile(p.map,p.x+d[1],p.y+d[2])=='.' then t.x=p.x+d[1];t.y=p.y+d[2];break end
  end
  t.flags.POKEPAL_REACHED_VIOLET=true;t.flags.POKEPAL_SPROUT_RIVAL_SEEN=true;t.node='challenge_'..key
  roundtrip(s);advance(s)
  local i=1
  while t.battle.status=='active' do
   assert(t.battle.wildid==p.team[i]);local b=t.battle
   local slot=S.battle.preview(E,b,2)>S.battle.preview(E,b,1) and 2 or 1
   assert(S.turn(t,E,slot));roundtrip(s)
   if t.opponent~=i then assert(t.opponent==i+1 and t.battle.hp==24 and not t.flags[p.flag]);i=t.opponent end
  end
  assert(t.battle.status=='won' and i==#p.team,key);assert(not t.flags[p.flag])
  assert(S.finishBattle(t));assert(t.flags[p.flag]);roundtrip(s)
  assert(not S.finishBattle(t));dismiss(s);count=count+1
 end
 assert(count==14 and S.trainers.wade.team[1]==S.trainers.wade.team[2])
end)
test('walk Route 31, Sprout Tower and Violet Gym, then revisit without duplicate rewards',function()
 local s=chapter2();local t=s.story
 warp(s,'NEW_BARK_TOWN');connect(s,'left');connect(s,'left');connect(s,'up');connect(s,'up')
 assert(t.map=='Route31');warp(s,'ROUTE_31_VIOLET_GATE');warp(s,'VIOLET_CITY')
 assert(t.node=='violet' and S.stage(t)==6);dismiss(s)
 for _,key in ipairs({'nico','chow','edmond','jin','troy','neal','li','abe','rod','falkner'}) do
  navigate(s,'VioletPokecenter1F',3,1);assert(t.hp==40);dismiss(s)
  challenge(s,key);assert(battle(s),'lost to '..key)
 end
 assert(t.flags.EVENT_GOT_HM05_FLASH and t.flags.ENGINE_ZEPHYRBADGE and S.stage(t)==8)
 local flags=E.companion.encode(t.flags);local hp=t.hp;walk(s,5,1);dismiss(s)
 assert(E.companion.encode(t.flags)==flags and t.hp==hp and not t.battle);roundtrip(s)
end)
test('trainer defeats and turn-limit draws send the player to heal without rewards',function()
 for _,draw in ipairs({false,true}) do
  local s=chapter2();local t=s.story;t.map='VioletGym';t.x=5;t.y=2;t.flags.POKEPAL_REACHED_VIOLET=true;t.node='challenge_falkner';advance(s)
  if draw then t.battle.turn=100;t.battle.hp=1 else t.hp=1 end
  assert(S.turn(t,E,1));roundtrip(s);assert(t.battle.status==(draw and 'draw' or 'lost'))
  assert(S.finishBattle(t));assert(t.map=='VioletPokecenter1F' and t.hp==40 and not t.flags.ENGINE_ZEPHYRBADGE)
  roundtrip(s);dismiss(s);challenge(s,'falkner');assert(t.opponent==1 and t.battle.hp==24);roundtrip(s)
 end
end)
test('Falkner is available before the tower and completing the tower later preserves the badge',function()
 local s=chapter2();local t=s.story;t.flags.POKEPAL_REACHED_VIOLET=true;t.map='VioletGym';t.x=5;t.y=2;t.node='challenge_falkner'
 advance(s);assert(battle(s));assert(t.flags.ENGINE_ZEPHYRBADGE and not t.flags.EVENT_GOT_HM05_FLASH)
 navigate(s,'VioletPokecenter1F',3,1);dismiss(s);challenge(s,'li');assert(battle(s))
 assert(t.flags.ENGINE_ZEPHYRBADGE and t.flags.EVENT_GOT_HM05_FLASH);roundtrip(s)
end)
test('Ghost partners can use a damaging move against Normal trainer Pokemon',function()
 for _,id in ipairs({92,93,94}) do
  local s=chapter2();s.seen[tostring(id)]=true;E.act(s,'partner',id,now);S.enter(s,E)
  local t=s.story;t.map='VioletGym';t.x=5;t.y=2;t.flags.POKEPAL_REACHED_VIOLET=true;t.node='challenge_falkner'
  advance(s);assert(t.battle.moves[2]==3 and S.battle.preview(E,t.battle,2)>0);assert(battle(s));roundtrip(s)
 end
end)
test('invalid trainer indices, partners and award flags are rejected on load',function()
 local s=chapter2();local t=s.story;t.map='VioletGym';t.x=5;t.y=2;t.flags.POKEPAL_REACHED_VIOLET=true;t.node='challenge_falkner';advance(s)
 local data=Store.encode(s)
 for i,change in ipairs({
  function(t) t.opponent=0 end,function(t) t.opponent=3 end,function(t) t.opponent=2 end,
  function(t) t.encounter='unknown' end,function(t) t.encounter=nil end,function(t) t.partner=7 end,
  function(t) t.node='battle_li' end,function(t) t.flags.EVENT_BEAT_FALKNER=true end,
  function(t) t.flags.ENGINE_ZEPHYRBADGE=true end,function(t) t.flags.EVENT_GOT_HM05_FLASH=true end,
  function(t) t.flags.POKEPAL_REACHED_VIOLET=nil end,function(t) t.rival=25 end,
  function(t) t.potions=-1 end,function(t) t.potions=6 end,function(t) t.potions=nil end,
 }) do
  local copy=assert(Store.decode(data,E));change(copy.story)
  assert(not E.valid(copy) and not Store.decode(Store.encode(copy),E),'accepted corrupt trainer case '..i)
 end
end)
test('Super Potions consume a turn, persist, refill at rest and leave care resources intact',function()
 local s=chapter2();local t=s.story;t.map='VioletGym';t.x=5;t.y=2;t.flags.POKEPAL_REACHED_VIOLET=true;t.node='challenge_falkner';advance(s)
 local before=Store.encode(s);assert(not S.turn(t,E,'potion') and Store.encode(s)==before)
 t.hp=1;local berries,xp=s.berries,s.xp;assert(S.turn(t,E,'potion'))
 assert(t.hp==40-S.battle.incoming(E,t.battle) and t.potions==4 and t.battle.turn==2)
 assert(s.berries==berries and s.xp==xp);roundtrip(s)
 t.potions=0;before=Store.encode(s);assert(not S.turn(t,E,'potion') and Store.encode(s)==before)
 t.hp=1;S.turn(t,E,1);assert(t.battle.status=='lost');assert(not S.turn(t,E,'potion'))
 S.finishBattle(t);assert(t.hp==40 and t.potions==S.max_potions);roundtrip(s)
 dismiss(s);t.potions=0;walk(s,3,1);assert(t.hp==40 and t.potions==S.max_potions);roundtrip(s)
end)
test('all 386 companions can defeat every trainer using their moves and saved Potions',function()
 local total=0
 for id=1,E.species_count do for key,p in pairs(S.trainers) do
  local s=assert(Store.decode(legacy.complete,E));s.seen[tostring(id)]=true;E.act(s,'partner',id,now);S.enter(s,E)
  local t=s.story;t.map=p.map;t.x=p.x;t.y=p.y
  t.flags.POKEPAL_REACHED_VIOLET=true;t.flags.POKEPAL_SPROUT_RIVAL_SEEN=true;t.node='challenge_'..key
  assert(S.advance(t,1,E));local turns=0
  while t.battle.status=='active' do
   local b=t.battle;local one,move=S.battle.preview(E,b,1);local two,second=S.battle.preview(E,b,2)
   if move.kind=='seed' then one=one+3 end
   if second.kind=='seed' then two=two+3 end
   local slot=two>one and 2 or 1
   if t.hp<=S.battle.incoming(E,b) and t.potions>0 and math.max(one,two)<b.hp then slot='potion' end
   assert(S.turn(t,E,slot));assert(E.valid(s));turns=turns+1;assert(turns<=100)
  end
  assert(t.battle.status=='won',E.name(id)..' cannot defeat '..key);roundtrip(s);total=total+1
 end end
 assert(total==5404)
end)
test('the northern route stays closed until the errand is done and Dark Cave explains its boundary',function()
 local s=fresh();mission(s);connect(s,'left');connect(s,'left');connect(s,'up');connect(s,'up')
 assert(s.story.map=='Route30' and s.story.node=='errand_first');roundtrip(s)
 s=chapter2();local t=s.story;t.map='Route31';t.x=33;t.y=7
 warp(s,'DARK_CAVE_VIOLET_ENTRANCE');assert(t.map=='Route31' and t.node=='closed');roundtrip(s)
end)
print('STORY: '..checks..' checks passed')
