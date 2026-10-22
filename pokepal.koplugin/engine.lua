-- PokePal game rules. Pure Lua 5.1; no device, network, or timer dependency.
local E = {}
local source=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
E.species = dofile(source.."/species.lua")
E.starters = {1,4,7,25,133,152,155,158}
E.evolution_branches = {[133]={134,135,136}}
E.evolution_stones = {[134]="Water stone",[135]="Thunder stone",[136]="Fire stone"}
-- Practice unlocks are PokePal rules, not a battle-game learnset.
E.move_sets = {
 [1]={"Tackle","Vine Whip","Razor Leaf","Solar Beam"},
 [4]={"Scratch","Ember","Flame Burst","Flamethrower"},
 [7]={"Tackle","Water Gun","Bubble Beam","Hydro Pump"},
 [25]={"Thunder Shock","Quick Attack","Thunderbolt","Thunder"},
 [133]={"Tackle","Quick Attack","Bite","Swift"},
 [134]={"Tackle","Water Gun","Aurora Beam","Hydro Pump"},
 [135]={"Tackle","Thunder Shock","Thunderbolt","Thunder"},
 [136]={"Tackle","Ember","Fire Fang","Flamethrower"},
 [152]={"Tackle","Razor Leaf","Magical Leaf","Solar Beam"},
 [155]={"Tackle","Ember","Flame Wheel","Flamethrower"},
 [158]={"Scratch","Water Gun","Bite","Hydro Pump"},
}
E.badge_goals={
 {"First friend","Begin your adventure"}, {"Kind heart","Care for your partner 20 times"},
 {"Trail scout","Complete 5 expeditions"}, {"Field researcher","Discover 10 Pokemon"},
 {"Best buddies","Reach 80 bond"}, {"Veteran","Earn 300 XP"},
}
E.routes = {
 {name="Meadow", seconds=1800, energy=12, berries=3, xp=12, pool={10,16,19,39,143}},
 {name="Coast", seconds=7200, energy=20, berries=5, xp=22, pool={54,129,131,147}},
 {name="Moon Cave", seconds=14400, energy=28, berries=8, xp=35, pool={35,41,74,147}},
}
-- Keep old route IDs and durations so expeditions from older saves finish normally.
for _,route in ipairs(E.routes) do route.pool={} end
for id=1,160 do
 local types=E.species[id].types
 local route=(types:find("Water") or types:find("Ice")) and 2
  or (types:find("Rock") or types:find("Ground") or types:find("Ghost") or types:find("Psychic")) and 3 or 1
 table.insert(E.routes[route].pool,id)
end
function E.kantoCount(s)
 local n=0;for id=1,151 do if s.seen[tostring(id)] then n=n+1 end end;return n
end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi,n)) end
function E.name(id) return E.species[id] and E.species[id][1] or "Egg" end
function E.level(s) return math.min(100,1+math.floor(s.xp/20)) end
function E.evolutionChoices(id)
 if E.evolution_branches[id] then return E.evolution_branches[id] end
 local p=E.species[id];return p and p[2] and {p[2]} or {}
end
local function parentOf(id)
 for parent in pairs(E.species) do
  for _,child in ipairs(E.evolutionChoices(parent)) do if child==id then return parent end end
 end
end
function E.evolutionLine(id)
 local line={id};local parent=parentOf(id)
 while parent do table.insert(line,1,parent);parent=parentOf(parent) end
 local choices=E.evolutionChoices(id)
 -- Branching partners show their choices separately; evolved partners retain their ancestry.
 while #choices==1 do id=choices[1];line[#line+1]=id;choices=E.evolutionChoices(id) end
 return line
end
function E.mood(s,now)
 if s.trip>0 then return now>=s.due and "Home from an adventure" or "Exploring the world" end
 if s.resting then return "Taking a nap" end
 if s.food<40 then return "A little hungry" end
 if s.energy<20 then return "Ready for a nap" end
 if s.dirt>70 then return "Could use a little clean" end
 if s.joy<40 then return "Would love to play" end
 if s.bond>=60 then return "Glad to see you" end
 return "Happy to be with you"
end
function E.moves(s)
 local root=E.evolutionLine(s.species)[1]
 local by_type={
  Normal={"Tackle","Quick Attack","Swift","Take Down"}, Fire={"Scratch","Ember","Flame Wheel","Flamethrower"},
  Water={"Tackle","Water Gun","Bubble Beam","Hydro Pump"}, Grass={"Tackle","Vine Whip","Razor Leaf","Solar Beam"},
  Electric={"Thunder Shock","Quick Attack","Thunderbolt","Thunder"}, Ice={"Tackle","Icy Wind","Aurora Beam","Blizzard"},
  Fighting={"Low Kick","Karate Chop","Brick Break","Close Combat"}, Poison={"Poison Sting","Acid","Sludge","Sludge Bomb"},
  Ground={"Mud-Slap","Dig","Mud Shot","Earthquake"}, Flying={"Peck","Gust","Wing Attack","Air Slash"},
  Psychic={"Confusion","Psybeam","Zen Headbutt","Psychic"}, Bug={"Bug Bite","String Shot","Pin Missile","Bug Buzz"},
  Rock={"Rock Throw","Rollout","Rock Slide","Stone Edge"}, Ghost={"Lick","Night Shade","Shadow Punch","Shadow Ball"},
  Dragon={"Twister","Dragon Breath","Dragon Claw","Dragon Pulse"}, Steel={"Metal Claw","Metal Sound","Iron Head","Flash Cannon"},
  Fairy={"Disarming Voice","Fairy Wind","Draining Kiss","Moonblast"},
 }
 local kind=E.species[s.species] and E.species[s.species].types:match("^%a+") or "Normal"
 local names=E.move_sets[s.species] or E.move_sets[root] or by_type[kind] or by_type.Normal
 local levels={1,7,20,36};local moves={}
 for i,name in ipairs(names) do moves[i]={name=name,level=levels[i]} end
 return moves
end
function E.canPlay(s,now)
 if s.species==0 then return false,"Choose your partner first." end
 if s.trip>0 then return false,"Your partner is exploring. Check the trail first." end
 if s.resting then return false,"Your partner is napping. Tap Wake up first." end
 if now-s.played<1800 then return false,"Play again in "..math.ceil((1800-now+s.played)/60).." min." end
 if s.energy<10 then return false,"Playing needs 10 energy. A little rest first." end
 return true
end
function E.new(now)
 return {version=1, species=0, food=80, joy=80, energy=80, bond=0, xp=0,
  berries=6, last=now, gift=0, trained=0, played=0, cleaned=0, dirt=0,
  trip=0, due=0, trips=0, seen={}, badges={}, log={}, animation="eco",
  seed=now % 2147483646 + 1, resting=false, care=0, started=now}
end
function E.valid(s)
 if type(s)~="table" or (s.version~=1 and s.version~=2) then return false end
 for _,k in ipairs({"species","food","joy","energy","bond","xp","berries","last","gift","trained","played","cleaned","dirt","trip","due","trips","seed","care","started"}) do
  local n=s[k]; if type(n)~="number" or n~=n or n<0 or n>1e12 then return false end
 end
 if s.species~=0 and not E.species[s.species] then return false end
 if s.trip%1~=0 or s.trip>3 then return false end
 for _,k in ipairs({"food","joy","energy","bond","dirt"}) do if s[k]>100 then return false end end
 if s.berries>999 or s.seed<1 or s.seed>=2147483647 then return false end
 if type(s.seen)~="table" or type(s.badges)~="table" or type(s.log)~="table" then return false end
 for id,v in pairs(s.seen) do if not E.species[tonumber(id)] or v~=true then return false end end
 if #s.log>24 then return false end
 for _,v in ipairs(s.log) do if type(v)~="string" or #v>200 then return false end end
 if s.animation~="gentle" and s.animation~="eco" and s.animation~="off" then return false end
 if s.partners~=nil then
  if type(s.partners)~="table" then return false end
  for id,p in pairs(s.partners) do
   if type(id)~="string" or not E.species[tonumber(id)] or not s.seen[id] or type(p)~="table" then return false end
   for _,k in ipairs({"xp","bond"}) do local n=p[k];if type(n)~="number" or n~=n or n<0 or n>(k=="bond" and 100 or 1e12) then return false end end
  end
 end
 if s.reading~=nil then
  local r=s.reading
  if type(r)~="table" or type(r.enabled)~="boolean" or type(r.ko_ready)~="boolean" or type(r.kindle)~="table" then return false end
  for _,k in ipairs({"seconds","carry","kindle_at","ko"}) do
   local n=r[k];if type(n)~="number" or n~=n or n<0 or n>1e12 or n%1~=0 then return false end
  end
  local count=0
  for key,n in pairs(r.kindle) do
   count=count+1
   if count>10000 or type(key)~="string" or #key~=16 or not key:match("^%x+$")
    or type(n)~="number" or n~=n or n<0 or n>1e12 or n%1~=0 then return false end
  end
 end
 return type(s.resting)=="boolean"
end
function E.note(s,text,now)
 if now then text=os.date("%d %b %H:%M",now).." | "..text end
 table.insert(s.log,1,text)
 while #s.log>24 do table.remove(s.log) end
 return text
end
function E.advance(s,now)
 -- Keep a high-water mark if the clock moves backwards. No duplicated rewards.
 if now<=s.last then return end
 local hours=math.min((now-s.last)/3600,72)
 if s.species~=0 then
  s.food=clamp(s.food-hours*(s.resting and 1 or 2),15,100)
  s.joy=clamp(s.joy-hours*0.7,20,100)
  s.energy=clamp(s.energy+hours*(s.resting and 12 or 4),0,100)
  s.dirt=clamp(s.dirt+hours*1.3,0,100)
 end
 s.last=now
end
local function rng(s,n)
 s.seed=(s.seed*48271)%2147483647
 return math.floor(s.seed% n)+1
end
function E.count(t) local n=0;for _,v in pairs(t) do if v then n=n+1 end end;return n end
function E.badges(s,now)
 local rules={ {"First friend",s.species~=0},{"Kind heart",s.care>=20},
  {"Trail scout",s.trips>=5},{"Field researcher",E.count(s.seen)>=10},
  {"Best buddies",s.bond>=80},{"Veteran",s.xp>=300} }
 for _,r in ipairs(rules) do
  if r[2] and not s.badges[r[1]] then s.badges[r[1]]=true;E.note(s,"Badge earned: "..r[1].."!",now) end
 end
end
function E.ready(s)
 local p=E.species[s.species]
 return p and p[2] and s.xp>=p[3] and s.bond>=30
end
function E.readingReward(s,seconds,now)
 local r=s.reading;if not r or not r.enabled then return nil end
 if type(seconds)~="number" or seconds~=seconds or seconds<0 or seconds>1e12 then return nil end
 seconds=math.floor(seconds)
 r.seconds=math.min(1e12,r.seconds+seconds);r.carry=math.min(1e12,r.carry+seconds)
 if s.species==0 then return nil end
 local rewards=math.floor(r.carry/900);if rewards==0 then return nil end
 r.carry=r.carry%900
 local berries=math.min(rewards,999-s.berries)
 s.berries=s.berries+berries;s.xp=math.min(1e12,s.xp+rewards*3)
 local message="Reading: +"..berries..(berries==1 and " berry" or " berries")..", +"..(rewards*3).." XP."
 E.note(s,message,now);E.badges(s,now);return message
end
function E.act(s,action,arg,now)
 E.advance(s,now)
 local function done(msg,anim)
  E.note(s,msg,now); E.badges(s,now); return msg,anim
 end
 if action=="choose" and s.species==0 then
  local allowed=false;for _,id in ipairs(E.starters) do if arg==id then allowed=true end end
  if not allowed then return "Choose one of the available starters." end
  s.species=arg;s.seen[tostring(arg)]=true;s.gift=now;s.started=now
  E.readingReward(s,0,now)
  return done(E.name(arg).." is your new friend!","hello")
 end
 if action=="animation" then
  if arg=="gentle" or arg=="eco" or arg=="off" then s.animation=arg end
  return "Animation: "..s.animation
 end
 if s.species==0 then return "Choose your first partner." end
 if action=="check" then
  if s.trip>0 and now>=s.due then return "Your partner is back! Tap Explore to collect." end
  if s.resting then return "Resting peacefully. Energy recovers while you read." end
  return E.name(s.species)..(s.food<40 and " would love a berry." or " is happy to see you.")
 elseif action=="gift" then
  if now-s.gift<86400 then return "The berry basket refills every 24 hours." end
  s.gift=now;s.berries=math.min(999,s.berries+5)
  return done("The berry basket has 5 fresh berries!","feed")
 elseif action=="collect" then
  if s.trip==0 then return "Pick a trail to explore." end
  if now<s.due then return "Still exploring. Come back in "..math.ceil((s.due-now)/60).." min." end
  local r=E.routes[s.trip];local pool={}
  for _,id in ipairs(r.pool) do if not s.seen[tostring(id)] then pool[#pool+1]=id end end
  if #pool==0 then pool=r.pool end
  local id=pool[rng(s,#pool)]
  local fresh=not s.seen[tostring(id)];s.seen[tostring(id)]=true
  s.berries=math.min(999,s.berries+r.berries);s.xp=s.xp+r.xp;s.bond=clamp(s.bond+4,0,100)
  s.trips=s.trips+1;s.trip=0;s.due=0
  return done((fresh and "New: " or "Met ")..E.name(id).."! +"..r.berries.." berries, +"..r.xp.." XP.","explore")
 end
 if s.trip>0 then return "Your partner is exploring. Tap Explore for details." end
 if action=="rest" then
  s.resting=not s.resting
  return done(s.resting and "Nap time! Rest continues while you read." or "Awake and ready for a little adventure.","rest")
 end
 if s.resting then return "Your partner is napping. Tap Wake up first." end
 if action=="partner" then
  if not E.species[arg] or not s.seen[tostring(arg)] then return "Meet this Pokemon on a trail first." end
  if arg==s.species then return E.name(arg).." is already with you." end
  s.partners=s.partners or {};s.partners[tostring(s.species)]={xp=s.xp,bond=s.bond}
  local p=s.partners[tostring(arg)] or {xp=0,bond=0}
  s.species=arg;s.xp=p.xp;s.bond=p.bond
  return done(E.name(arg).." joins you. Your other friends keep their progress.","hello")
 elseif action=="feed" then
  if s.berries<1 then return "No berries. Explore or check the berry basket." end
  if s.food>=95 then return "Already full! Save that berry for later." end
  s.berries=s.berries-1;s.food=clamp(s.food+24,0,100);s.bond=clamp(s.bond+2,0,100);s.care=s.care+1
  return done("Berry eaten.","feed")
 elseif action=="play" then
  local allowed,why=E.canPlay(s,now);if not allowed then return why end
  local perfect=arg=="perfect"
  s.played=now;s.energy=s.energy-10;s.joy=clamp(s.joy+20,0,100);s.bond=clamp(s.bond+4,0,100);s.xp=s.xp+5;s.care=s.care+1
  if perfect then s.xp=s.xp+3 end
  return done(perfect and "Perfect berry trail! +8 XP, +4 bond." or "Good try. +5 XP, +4 bond.","play")
 elseif action=="train" then
  if now-s.trained<3600 then return "Training ready in "..math.ceil((3600-now+s.trained)/60).." min." end
  if s.energy<18 or s.food<30 then return "Training needs 18 energy and 30 fullness." end
  local move=arg or E.moves(s)[1].name;local unlocked=false
  for _,m in ipairs(E.moves(s)) do if m.name==move and E.level(s)>=m.level then unlocked=true end end
  if not unlocked then return "That move is not ready yet. Keep growing together." end
  s.trained=now;s.energy=s.energy-18;s.food=s.food-8;s.xp=s.xp+12;s.bond=clamp(s.bond+2,0,100)
  return done(move.." practice! +12 XP, +2 bond.","train")
 elseif action=="clean" then
  if s.dirt<15 then return "Already squeaky clean." end
  s.dirt=0;s.joy=clamp(s.joy+8,0,100);s.bond=clamp(s.bond+2,0,100);s.care=s.care+1;s.cleaned=now
  return done("Nest cleaned.","clean")
 elseif action=="trip" then
  local r=E.routes[arg];if not r then return "Choose a trail." end
  if s.energy<r.energy then return "This trail needs "..r.energy.." energy." end
  if s.food<30 then return "Feed your partner before setting off." end
  s.energy=s.energy-r.energy;s.trip=arg;s.due=now+r.seconds
  return done("Off to "..r.name.."! Return in "..r.seconds/60 .." min.","explore")
 elseif action=="evolve" then
  if not E.ready(s) then return "Evolution needs enough XP and at least 30 bond." end
  local choices=E.evolutionChoices(s.species)
  local id=arg or (#choices==1 and choices[1]);local allowed=false
  for _,choice in ipairs(choices) do if choice==id then allowed=true end end
  if not allowed then return "Choose an evolution from your partner's profile." end
  s.partners=s.partners or {};s.partners[tostring(s.species)]={xp=s.xp,bond=s.bond}
  local previous=s.partners[tostring(id)]
  if previous then s.xp=math.max(s.xp,previous.xp);s.bond=math.max(s.bond,previous.bond) end
  s.species=id;s.seen[tostring(id)]=true
  return done("Your partner evolved into "..E.name(id).."!","evolve")
 end
 return "Ready when you are."
end
return E
