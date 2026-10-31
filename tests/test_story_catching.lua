local E=dofile(BASE..'/engine.lua');local S=E.story;local B=S.battle;local Store=dofile(BASE..'/storage.lua')
local checks=0;local now=1800000000
local function test(name,fn) fn();checks=checks+1;print('PASS story catching: '..name) end
local function copy(s)
 assert(E.valid(s),'Invalid story collection');local encoded=Store.encode(s)
 local result=assert(Store.decode(encoded,E));assert(Store.encode(result)==encoded);return result
end
local function fresh()
 local s=E.new(now);E.act(s,'choose',25,now);S.enter(s,E);S.advance(s.story,1,E)
 s.story.flags.POKEPAL_ELM_MISSION=true;return s
end
local function wild(s,id)
 local t=s.story;t.map='Route31';t.flags.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON=true;t.flags.ENGINE_POKEDEX=true
 t.flags.EVENT_BEAT_RIVAL_1=true;t.flags.EVENT_GAVE_MYSTERY_EGG_TO_ELM=true;t.egg=false
 local m=S.maps[t.map]
 for y=0,m.height-1 do for x=0,m.width-1 do if S.tile(t.map,x,y)=='G' then t.x=x;t.y=y end end end
 t.node='wild';t.encounter='wild';t.opponent=1;t.battle=B.new(t.partner,1);t.battle.wildid=id or 16
 t.grace=0;copy(s);return t
end
local function capture(s,id)
 local t=wild(s,id);t.battle.hp=1;t.seed=1;local balls=t.balls
 assert(S.catch(t,E));assert(t.battle.status=='befriended' and t.balls==balls-1);copy(s)
 assert(not S.catch(t,E));S.finishBattle(t);copy(s)
end
test('a fresh party contains only the chosen care companion and never resyncs',function()
 local s=fresh();local t=s.story;assert(t.origin==25 and #t.party==1 and t.party[1]==25 and t.box['25'])
 s.seen['7']=true;E.act(s,'partner',7,now);assert(not S.enter(s,E) and t.partner==25 and not t.box['7']);copy(s)
 capture(s,16);assert(#t.party==2 and t.party[2]==16 and s.species==7 and not s.seen['16'])
end)
test('HP controls catch chance, failed throws cost a ball and a turn, reloads keep the result',function()
 local s=fresh();local t=wild(s);local chance=S.catchChance(t);t.battle.hp=1;assert(S.catchChance(t)>chance)
 t.battle.hp=24
 local failed
 for seed=1,100 do
  t.seed=seed;local snapshot=Store.encode(s);local trial=assert(Store.decode(snapshot,E));S.catch(trial.story,E)
  if trial.story.battle.status=='active' then failed={snapshot=snapshot,result=Store.encode(trial)};break end
 end
 assert(failed);s=assert(Store.decode(failed.snapshot,E));t=s.story;local balls,hp=t.balls,t.hp
 assert(S.catch(t,E));assert(t.balls==balls-1 and t.battle.turn==2 and t.hp<hp and not t.box['16'])
 assert(Store.encode(s)==failed.result);copy(s)
end)
test('a full party sends a catch to the box and the Centre can exchange members',function()
 local s=fresh();local t=s.story
 for _,id in ipairs({16,10,69,13,187,92}) do capture(s,id) end
 assert(#t.party==6 and t.box['92'] and not S.member(t,92));copy(s)
 assert(not S.deposit(t,16) and not S.withdraw(t,92))
 t.map='VioletPokecenter1F';t.x=4;t.y=5;t.flags.POKEPAL_REACHED_VIOLET=true
 assert(not S.withdraw(t,92));assert(S.deposit(t,16));assert(S.withdraw(t,92));assert(S.member(t,92) and t.box['16']);copy(s)
 local first=t.origin;assert(S.deposit(t,first) and t.box[tostring(first)] and t.partner~=first);copy(s)
 while #t.party>1 do assert(S.deposit(t,t.party[#t.party])) end
 assert(not S.deposit(t,t.partner));copy(s)
end)
test('no catching trainers, fainted targets, owned species or with empty supplies',function()
 local s=fresh();local t=wild(s);local original=Store.encode(s)
 t.balls=0;local data=Store.encode(s);assert(not S.catch(t,E) and Store.encode(s)==data)
 s=assert(Store.decode(original,E));t=s.story;t.battle.hp=0;t.battle.status='won';data=Store.encode(s)
 assert(not S.catch(t,E) and Store.encode(s)==data);copy(s)
 s=assert(Store.decode(original,E));t=s.story;t.box['16']=true;data=Store.encode(s)
 assert(not S.catch(t,E) and Store.encode(s)==data);copy(s)
 t.map='VioletGym';t.x=5;t.y=2;t.flags.POKEPAL_REACHED_VIOLET=true;t.node='battle_falkner';t.encounter='falkner';t.battle.hp=24;t.battle.status='active'
 data=Store.encode(s);assert(not S.catch(t,E) and not S.flee(t) and Store.encode(s)==data);copy(s)
end)
test('switching costs a turn, fainted replacements are free and HP persists per Pokemon',function()
 local s=fresh();capture(s,16);local t=wild(s,69);t.health['16']=30
 local turn=t.battle.turn;assert(S.lead(t,E,16));assert(t.partner==16 and t.battle.ally==16 and t.battle.turn==turn+1 and S.hp(t,25)==40);copy(s)
 local hp=t.hp;assert(S.lead(t,E,25));assert(S.hp(t,16)==hp);copy(s)
 t.hp=1;assert(S.turn(t,E,1));assert(t.hp==0 and t.battle.status=='active');copy(s)
 turn=t.battle.turn;local enemyhp=t.battle.hp;assert(not S.catch(t,E) and not S.turn(t,E,'potion'))
 assert(S.lead(t,E,16));assert(t.hp==hp and t.battle.turn==turn and t.battle.hp==enemyhp and t.battle.status=='active');copy(s)
 t.hp=1;S.turn(t,E,1);assert(t.battle.status=='lost');copy(s)
 S.finishBattle(t);assert(t.hp==40 and S.hp(t,25)==40 and t.balls==S.max_balls);copy(s)
 t=wild(s,69);t.hp=1;t.battle.turn=100;S.turn(t,E,1)
 assert(t.hp==0 and S.alive(t) and t.battle.status=='draw' and t.battle.turn==101);copy(s)
 S.finishBattle(t);assert(t.hp==40);copy(s)
 t=wild(s);t.battle.hp=1;S.turn(t,E,1);assert(t.battle.status=='won');copy(s)
 local map=t.map;S.finishBattle(t);assert(t.map==map and not t.battle and t.grace==3);copy(s)
end)
test('walking triggers sourced encounters, stops at battles and honors day and night pools',function()
 local s=fresh();local t=s.story;t.map='Route29';t.grace=0
 local m=S.maps[t.map];local x,y
 for yy=1,m.height-2 do for xx=1,m.width-2 do
  if S.tile(t.map,xx,yy)=='G' and S.tile(t.map,xx-1,yy)=='G' then x,y=xx,yy end
 end end
 assert(x);t.x=x-1;t.y=y;t.seed=100;assert(S.step(t,1,0,E,12) and t.encounter=='wild');copy(s)
 local before=Store.encode(s);assert(not S.step(t,1,0,E,12) and Store.encode(s)==before)
 assert(S.flee(t));S.finishBattle(t);assert(t.grace==3);copy(s)
 local seed=t.seed;assert(S.step(t,-1,0,E,12));assert(not t.battle and t.seed==seed)
 local seen={}
 for _,hour in ipairs({6,12,22}) do
  for n=1,400 do
   t.map='SproutTower2F';t.x=6;t.y=5;t.node=nil;t.battle=nil;t.encounter=nil;t.opponent=nil;t.grace=0;t.seed=n*100
   t.flags.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON=true;t.flags.ENGINE_POKEDEX=true;t.flags.EVENT_BEAT_RIVAL_1=true;t.flags.EVENT_GAVE_MYSTERY_EGG_TO_ELM=true;t.flags.POKEPAL_REACHED_VIOLET=true;t.egg=false
   if S.maybeWild(t,E,hour) then
    seen[t.battle.wildid]=true
    if hour~=22 then assert(t.battle.wildid==19) end
    copy(s)
   end
  end
 end
 assert(seen[19] and seen[92])
end)
test('chapter 2 snapshots migrate without changing active trainer progress or care data',function()
 local dir=debug.getinfo(1,'S').source:match('^@(.*/)') or BASE..'/../tests/'
 for name,encoded in pairs(dofile(dir..'story_chapter2_fixtures.lua')) do
  local s=assert(Store.decode(encoded,E));assert(Store.encode(s)==encoded)
  local t=s.story;local old=E.companion.encode(t);local turn=t.battle and t.battle.turn;local opponent=t.opponent;local hp=t.hp
  local care=Store.encode(s):gsub('story=[^\n]+\n',''):gsub('version=10\n','version=11\n')
  assert(S.enter(s,E));assert(t.version==3 and t.party[1]==t.partner and t.hp==hp and t.opponent==opponent)
  if turn then assert(t.battle.turn==turn) end
  assert(Store.encode(s):gsub('story=[^\n]+\n','')==care);copy(s)
  local after=Store.encode(s);assert(not S.enter(s,E) and Store.encode(s)==after)
 end
end)
test('malformed inventories, rosters and catches fail validation without throwing',function()
 local s=fresh();wild(s);local data=Store.encode(s)
 for i,change in ipairs({
  function(t) t.balls=-1 end,function(t) t.balls=11 end,function(t) t.seed=0 end,function(t) t.grace=4 end,
  function(t) t.party={} end,function(t) t.party={25,25} end,function(t) t.party={[1]=25,[3]=16} end,
  function(t) t.party[2]=16 end,function(t) t.box['25']=nil end,function(t) t.box['001']=true end,
  function(t) t.health['16']=10 end,function(t) t.health['25']=41 end,function(t) t.origin=0 end,
  function(t) t.battle.wildid=386 end,function(t) t.battle.status='befriended';t.battle.recruited=true end,
  function(t) t.map='NewBarkTown' end,function(t) t.opponent=2 end,
 }) do
  local c=assert(Store.decode(data,E));change(c.story);local ok,valid=pcall(E.valid,c)
  assert(ok and not valid and not Store.decode(Store.encode(c),E),'invalid collection '..i)
 end
end)
print('STORY CATCHING: '..checks..' checks passed')
