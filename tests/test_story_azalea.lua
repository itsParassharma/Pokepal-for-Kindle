return function(c)
local E,S,Store=c.E,c.S,c.Store
local copy,advance,dismiss,walk,warp,connect,navigate=c.roundtrip,c.advance,c.dismiss,c.walk,c.warp,c.connect,c.navigate
local dir=debug.getinfo(1,'S').source:match('^@(.*/)')
local fixtures=dofile(dir..'story_collection_fixtures.lua');local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS Azalea: '..name) end
local function ready()
 local s=assert(Store.decode(fixtures.badge,E));assert(S.enter(s,E));dismiss(s);copy(s);return s
end
local function battle(s)
 local t=s.story
 for _=1,110 do
  local b=t.battle
  if b.status~='active' then break end
  if t.hp==0 then
   local replacement
   for _,id in ipairs(t.party) do if S.hp(t,id)>0 then replacement=id;break end end
   assert(replacement and S.lead(t,E,replacement))
  else
   local one,move=S.battle.preview(E,b,1);local two,second=S.battle.preview(E,b,2)
   if move.kind=='seed' then one=one+3 end;if second.kind=='seed' then two=two+3 end
   local slot=two>one and 2 or 1
   if t.hp<=S.battle.incoming(E,b) and t.potions>0 and math.max(one,two)<b.hp then slot='potion' end
   assert(S.turn(t,E,slot))
  end
  copy(s)
 end
 assert(t.battle.status=='won','lost to '..tostring(t.encounter))
 assert(S.finishBattle(t));copy(s);dismiss(s)
end
local function fight(s,key)
 local p=S.trainers[key];assert(s.story.map==p.map);walk(s,p.x,p.y)
 assert(s.story.node=='challenge_'..key,tostring(s.story.node)..' / '..key);advance(s);battle(s)
end
local function egg(s)
 local t=s.story;t.map='VioletPokecenter1F';t.x=4;t.y=5;t.node=nil
 while #t.party>5 do assert(S.deposit(t,t.party[#t.party])) end
 walk(s,4,3);assert(t.node=='aide');advance(s);assert(t.node=='egg_taken');dismiss(s);copy(s)
end
local function unlock(s)
 egg(s);local t=s.story;t.flags.POKEPAL_REACHED_AZALEA=true;t.flags.EVENT_AZALEA_TOWN_SLOWPOKETAIL_ROCKET=true
end

test('five caught-party saves migrate without changing Pokemon, HP, RNG or active fights',function()
 for name,data in pairs(fixtures) do
  local s=assert(Store.decode(data,E));assert(Store.encode(s)==data)
  local old=E.companion.encode(s.story);local care=Store.encode(s):gsub('story=[^\n]+\n',''):gsub('version=11\n','version=13\n')
  assert(S.enter(s,E) and s.story.version==5 and s.version==13)
  local version=s.story.version;s.story.version=3;assert(E.companion.encode(s.story)==old,name);s.story.version=version
  assert(Store.encode(s):gsub('story=[^\n]+\n','')==care);copy(s)
  data=Store.encode(s);assert(not S.enter(s,E) and Store.encode(s)==data)
 end
end)

test('walk Violet to Azalea, rescue the Slowpoke, earn Hive and face the rival',function()
 local s=ready();local t=s.story;local origin=t.origin
 navigate(s,'VioletPokecenter1F',4,3);assert(t.node=='aide');advance(s,2);dismiss(s)
 walk(s,4,3);advance(s);assert(t.node=='egg_full' and not t.flags.EVENT_GOT_TOGEPI_EGG_FROM_ELMS_AIDE);dismiss(s)
 assert(S.deposit(t,187));walk(s,4,3);advance(s);assert(t.node=='egg_taken' and S.partySize(t)==6);dismiss(s)
 walk(s,3,1);dismiss(s);warp(s,'VIOLET_CITY');connect(s,'down');assert(t.map=='Route32')
 fight(s,'albert');warp(s,'ROUTE_32_POKECENTER_1F');walk(s,3,1);dismiss(s);warp(s,'ROUTE_32')
 warp(s,'UNION_CAVE_1F');assert(t.map=='UnionCave1F');fight(s,'russell')
 warp(s,'ROUTE_33');connect(s,'left');assert(t.node=='azalea');dismiss(s)
 walk(s,10,16);assert(t.node=='rocket_locked' and t.map=='AzaleaTown');dismiss(s)
 walk(s,31,9);assert(t.node=='well_locked');dismiss(s)
 warp(s,'KURTS_HOUSE');walk(s,3,2);assert(t.node=='kurt');dismiss(s);assert(t.flags.EVENT_AZALEA_TOWN_SLOWPOKETAIL_ROCKET)
 warp(s,'AZALEA_TOWN');warp(s,'SLOWPOKE_WELL_B1F');walk(s,16,14);dismiss(s)
 for _,key in ipairs({'rocket29','rocket2','rocketf1','rocket1'}) do fight(s,key) end
 assert(t.map=='KurtsHouse' and t.flags.EVENT_CLEARED_SLOWPOKE_WELL and t.hp==40 and t.balls==10)
 warp(s,'AZALEA_TOWN');warp(s,'AZALEA_GYM');assert(t.map=='AzaleaGym')
 for _,key in ipairs({'amy','al','josh','benny','bugsy'}) do fight(s,key) end
 assert(t.flags.ENGINE_HIVEBADGE and S.stage(t)==13)
 warp(s,'AZALEA_TOWN');warp(s,'ILEX_FOREST_AZALEA_GATE');assert(t.node=='challenge_azalea_rival');advance(s);battle(s)
 warp(s,'ILEX_FOREST_AZALEA_GATE');assert(t.map=='IlexForestAzaleaGate' and S.stage(t)==14)
 walk(s,5,2);assert(t.node=='forest_gate');dismiss(s)
 warp(s,'ILEX_FOREST');assert(t.map=='IlexForest' and t.node=='ilex');dismiss(s)
 assert(t.origin==origin and s.species==origin and t.box[tostring(origin)] and t.flags.EVENT_TOGEPI_HATCHED and t.box['175']);copy(s)
end)

test('the Egg reserves a slot, hatches once on movement and leaves care eggs alone',function()
 local s=ready();local t=s.story;egg(s)
 assert(S.partySize(t)==6 and not S.withdraw(t,187))
 t.map='Route32';local m=S.maps[t.map]
 for y=1,m.height-2 do for x=1,m.width-2 do if S.tile(t.map,x,y)=='G' and S.tile(t.map,x-1,y)=='G' then t.x=x;t.y=y end end end
 t.node='wild';t.encounter='wild';t.opponent=1;t.battle=S.battle.new(t.partner,1);t.battle.wildid=194;t.battle.hp=1;t.seed=1
 assert(S.catch(t,E) and t.box['194'] and not S.member(t,194) and #t.party==5);copy(s);S.finishBattle(t)
 t.map='VioletPokecenter1F';t.x=4;t.y=5;t.togepi_steps=S.egg_steps-1;local before=Store.encode(s):gsub('story=[^\n]+\n','')
 assert(S.step(t,1,0,E,12));assert(t.node=='hatched' and #t.party==6 and t.party[6]==175 and not t.togepi_steps);copy(s)
 assert(Store.encode(s):gsub('story=[^\n]+\n','')==before);dismiss(s)
 local party=E.companion.encode(t.party);assert(S.step(t,-1,0,E,12));assert(E.companion.encode(t.party)==party);copy(s)
 s=ready();t=s.story;t.box['175']=true;t.health['175']=7;egg(s);t.togepi_steps=S.egg_steps-1
 assert(S.step(t,1,0,E,12));assert(t.node=='hatched_owned' and #t.party==5 and t.health['175']==7);copy(s)
end)

test('all new trainer positions and imported teams are playable and repeat rewards are blocked',function()
 local count=0
 for key,p in pairs(S.trainers) do if p.need and p.chapter~=4 then
  local s=ready();unlock(s);local t=s.story
  if p.need=='EVENT_CLEARED_SLOWPOKE_WELL' then t.flags.EVENT_CLEARED_SLOWPOKE_WELL=true;t.flags.EVENT_BEAT_ROCKET_GRUNTM_1=true end
  t.map=p.map;t.x=p.x;t.y=p.y;t.node='challenge_'..key;S.heal(t);copy(s);advance(s)
  assert(#p.team>=1 and #p.team<=6);battle(s);assert(t.flags[p.flag]);copy(s)
  local flags=E.companion.encode(t.flags);local balls=t.balls;assert(not S.finishBattle(t));assert(E.companion.encode(t.flags)==flags and t.balls==balls)
  count=count+1
 end end
 assert(count==25 and S.trainers.bugsy.team[3]==123 and S.trainers.anthony.team[2]==66)
end)

test('the rival keeps the original starter family and a Normal lead can switch or retreat',function()
 for starter,evolved in pairs({[152]=153,[155]=156,[158]=159}) do
  local s=ready();unlock(s);local t=s.story;t.rival=starter
  t.flags.EVENT_CLEARED_SLOWPOKE_WELL=true;t.flags.EVENT_BEAT_ROCKET_GRUNTM_1=true
  t.map='AzaleaTown';t.x=6;t.y=10;t.node='challenge_azalea_rival';advance(s)
  assert(t.battle.wildid==92);t.battle.hp=1;S.turn(t,E,2);assert(t.battle.wildid==41);t.battle.hp=1;S.turn(t,E,2)
  assert(t.battle.wildid==evolved);copy(s)
 end
 local s=ready();unlock(s);local t=s.story;t.flags.EVENT_CLEARED_SLOWPOKE_WELL=true;t.flags.EVENT_BEAT_ROCKET_GRUNTM_1=true
 t.map='AzaleaTown';t.x=6;t.y=10;t.node=nil;assert(S.lead(t,E,16));t.node='challenge_azalea_rival';advance(s)
 assert(S.battle.preview(E,t.battle,1)==0 and S.battle.preview(E,t.battle,2)==0)
 local turn=t.battle.turn;assert(S.lead(t,E,25));assert(t.battle.turn==turn+1 and S.battle.preview(E,t.battle,2)>0);copy(s)
 assert(S.retreat(t));copy(s);S.finishBattle(t);assert(t.map=='AzaleaPokecenter1F' and not t.flags.EVENT_RIVAL_AZALEA_TOWN);copy(s)
end)

test('inconsistent chapter flags, Egg capacity and premature map access fail closed',function()
 local s=ready();local encoded=Store.encode(s)
 for i,change in ipairs({
  function(t) t.map='Route32';t.x=18;t.y=0 end,
  function(t) t.flags.EVENT_GOT_TOGEPI_EGG_FROM_ELMS_AIDE=true end,
  function(t) t.togepi_steps=0 end,
  function(t) t.flags.POKEPAL_REACHED_AZALEA=true end,
  function(t) t.flags.EVENT_CLEARED_SLOWPOKE_WELL=true end,
  function(t) t.flags.EVENT_BEAT_ROCKET_GRUNTM_1=true end,
  function(t) t.flags.ENGINE_HIVEBADGE=true end,
  function(t) t.flags.EVENT_RIVAL_AZALEA_TOWN=true end,
  function(t) t.flags.EVENT_TOGEPI_HATCHED=true end,
 }) do local bad=assert(Store.decode(encoded,E));change(bad.story);local ok,valid=pcall(E.valid,bad);assert(ok and not valid,'bad chapter '..i) end
 egg(s);encoded=Store.encode(s)
 for _,n in ipairs({-1,0.5,S.egg_steps}) do local bad=assert(Store.decode(encoded,E));bad.story.togepi_steps=n;assert(not E.valid(bad)) end
 s.story.party[#s.story.party+1]=187;assert(not E.valid(s))
end)
print('AZALEA: '..checks..' checks passed')
c.battle=battle;c.fight=fight
end
