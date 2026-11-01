-- PokePal game rules. Pure Lua 5.1; no device, network, or timer dependency.
local E = {}
local source=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
E.species = dofile(source.."/species.lua")
E.species_count = #E.species
E.companion = dofile(source.."/companion.lua")
E.world = dofile(source.."/world.lua")
E.story = dofile(source.."/story.lua")
E.starters = {1,4,7,25,133,152,155,158,252,255,258}
E.parents = {}
for id,p in ipairs(E.species) do
 for _,child in ipairs(p.evolutions or (p[2] and {p[2]} or {})) do E.parents[child]=id end
end
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
 [172]={"Thunder Shock","Quick Attack","Thunderbolt","Thunder"},
 [196]={"Tackle","Confusion","Psybeam","Psychic"},
 [197]={"Tackle","Bite","Feint Attack","Dark Pulse"},
 [252]={"Pound","Absorb","Leaf Blade","Solar Beam"},
 [255]={"Scratch","Ember","Flame Burst","Flamethrower"},
 [258]={"Tackle","Water Gun","Mud Shot","Hydro Pump"},
}
E.badge_goals={
 {"First friend","Begin your adventure"}, {"Kind heart","Care for your partner 20 times"},
 {"Trail scout","Complete 5 expeditions"}, {"Field researcher","Discover 10 Pokemon"},
 {"Best buddies","Reach 80 bond"}, {"Veteran","Earn 300 XP"},
 {"Bookworm","Read for 10 hours"}, {"A new arrival","Hatch an egg"},
 {"All three trails","Finish every trail"}, {"A place of our own","Place all four decorations"},
 {"Reading together","Remember a book"}, {"Finding a rhythm","Meet four weekly goals"},
 {"Favourite snack","Find a favourite berry"}, {"Kanto explorer","Meet all 151 Kanto Pokemon"},
}
E.routes = {
 {name="Meadow", seconds=1800, energy=12, berries=3, xp=12, pool={10,16,19,39,143}},
 {name="Coast", seconds=7200, energy=20, berries=5, xp=22, pool={54,129,131,147}},
 {name="Moon Cave", seconds=14400, energy=28, berries=8, xp=35, pool={35,41,74,147}},
}
E.backgrounds={"Meadow","Coast","Moon Cave","Forest","Snowfield","Reading nook"}
E.egg_seconds=7200
E.egg_cost=3
E.weekly_targets={3600,7200,10800}
E.decorations={{name="Cushion",cost=5},{name="Plant",cost=8},{name="Lamp",cost=10},{name="Bookshelf",cost=12}}
E.discoveries={{name="Berry patch",detail="Find 1 berry"},{name="Footprints",detail="Follow a new trail for 3 XP"},{name="Campsite",detail="Rest for 8 energy"}}
-- Keep old route IDs and durations so expeditions from older saves finish normally.
for _,route in ipairs(E.routes) do route.pool={} end
for id=1,E.species_count do
 local types=E.species[id].types
 local route=(types:find("Water") or types:find("Ice")) and 2
  or (types:find("Rock") or types:find("Ground") or types:find("Ghost") or types:find("Psychic")) and 3 or 1
 table.insert(E.routes[route].pool,id)
end
function E.kantoCount(s)
 local n=0;for id=1,151 do if s.seen[tostring(id)] then n=n+1 end end;return n
end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi,n)) end
local function integer(n,max) return type(n)=="number" and n==n and n>=0 and n<=max and n%1==0 end
function E.name(id) return E.species[id] and E.species[id][1] or "Egg" end
function E.displayName(s,id)
 id=id or s.species
 return s.nicknames and s.nicknames[tostring(id)] or E.name(id)
end
function E.validNickname(name)
 return E.companion.text.valid(name,12) and not name:find("=",1,true)
end
function E.reaction(s)
 local name=E.displayName(s)
 if s.resting then return name..(s.decor and s.decor[1] and " is asleep on the cushion." or " is curled up for a nap.") end
 if s.food<40 then return name.." keeps looking at the berry basket." end
 if s.energy<20 then return name.." lets out a long yawn." end
 if s.dirt>70 then return name.." has tracked mud into the nest." end
 if s.joy<40 then return name.." nudges a ball toward you." end
 if s.decor and s.decor[2] and tonumber(os.date("%H"))%3==0 then return name.." is sniffing the plant." end
 if s.decor and s.decor[4] and tonumber(os.date("%H"))%3==1 then return name.." is looking through the bookshelf." end
 if s.bond>=80 then return name.." settles in beside you." end
 if s.bond>=30 then return name.." perks up when you come back." end
 return name.." looks happy to see you."
end
function E.level(s) return math.min(100,1+math.floor(s.xp/20)) end
function E.evolutionChoices(id)
 local p=E.species[id];return p and (p.evolutions or (p[2] and {p[2]})) or {}
end
local function parentOf(id)
 return E.parents[id]
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
 if s.trip>0 then return E.tripLeft(s,now)==0 and "Home from an adventure" or "Exploring the world" end
 if s.resting then return "Taking a nap" end
 if s.food<40 then return "A little hungry" end
 if s.energy<20 then return "Ready for a nap" end
 if s.dirt>70 then return "Could use a little clean" end
 if s.joy<40 then return "Would love to play" end
 if s.bond>=60 then return "Glad to see you" end
 return "Happy to be with you"
end
function E.moves(s)
 local ancestor=s.species
 while ancestor and not E.move_sets[ancestor] do ancestor=parentOf(ancestor) end
 local by_type={
  Normal={"Tackle","Quick Attack","Swift","Take Down"}, Fire={"Scratch","Ember","Flame Wheel","Flamethrower"},
  Water={"Tackle","Water Gun","Bubble Beam","Hydro Pump"}, Grass={"Tackle","Vine Whip","Razor Leaf","Solar Beam"},
  Electric={"Thunder Shock","Quick Attack","Thunderbolt","Thunder"}, Ice={"Tackle","Icy Wind","Aurora Beam","Blizzard"},
  Fighting={"Low Kick","Karate Chop","Brick Break","Close Combat"}, Poison={"Poison Sting","Acid","Sludge","Sludge Bomb"},
  Ground={"Mud-Slap","Dig","Mud Shot","Earthquake"}, Flying={"Peck","Gust","Wing Attack","Air Slash"},
  Psychic={"Confusion","Psybeam","Zen Headbutt","Psychic"}, Bug={"Bug Bite","String Shot","Pin Missile","Bug Buzz"},
  Rock={"Rock Throw","Rollout","Rock Slide","Stone Edge"}, Ghost={"Lick","Night Shade","Shadow Punch","Shadow Ball"},
  Dragon={"Twister","Dragon Breath","Dragon Claw","Dragon Pulse"}, Steel={"Metal Claw","Metal Sound","Iron Head","Flash Cannon"},
  Dark={"Bite","Feint Attack","Crunch","Dark Pulse"},
  Fairy={"Disarming Voice","Fairy Wind","Draining Kiss","Moonblast"},
 }
 local kind=E.species[s.species] and E.species[s.species].types:match("^%a+") or "Normal"
 local names=E.move_sets[ancestor] or by_type[kind] or by_type.Normal
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
 if type(s)~="table" or (s.version~=1 and s.version~=2 and s.version~=3 and s.version~=4 and s.version~=5 and s.version~=6 and s.version~=7 and s.version~=8 and s.version~=9 and s.version~=10 and s.version~=11 and s.version~=12 and s.version~=13) then return false end
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
 local function readingStart(n)
  return type(n)=="number" and n==n and n>=0 and n%1==0 and s.reading and n<=s.reading.seconds
 end
 if s.trail~=nil and (s.trip==0 or s.due~=0 or not readingStart(s.trail)) then return false end
 if s.egg~=nil then
  if type(s.egg)~="table" or not E.species[s.egg.id] or not readingStart(s.egg.start) then return false end
  -- Eggs from the original roster can predate the newly added baby forms.
  local parent=parentOf(s.egg.id)
  if parent and not (s.egg.id<=160 and parent>160) then return false end
 end
 if s.background~=nil and not E.backgrounds[s.background] then return false end
 if s.week~=nil then
  local w=s.week
  if type(w)~="table" or (w.target~=3600 and w.target~=7200 and w.target~=10800)
   or not integer(w.start,1e12) or not integer(w.seconds,1e12) or type(w.claimed)~="boolean" then return false end
 end
 if s.decor~=nil then
  if type(s.decor)~="table" then return false end
  for id,placed in pairs(s.decor) do if not E.decorations[id] or type(placed)~="boolean" then return false end end
 end
 if s.finds~=nil and (s.trip==0 or not integer(s.finds,3)) then return false end
 if s.nicknames~=nil then
  if type(s.nicknames)~="table" then return false end
  for id,name in pairs(s.nicknames) do
   if type(id)~="string" or not E.species[tonumber(id)] or not s.seen[id] or not E.validNickname(name) then return false end
  end
 end
 return type(s.resting)=="boolean" and E.companion.valid(s.companion,s,E) and E.world.valid(s.world,s,E) and E.story.valid(s.story,s,E)
end
function E.weekStart(now)
 local d=os.date("*t",now)
 return os.time{year=d.year,month=d.month,day=d.day-(d.wday+5)%7,hour=0,min=0,sec=0}
end
function E.updateWeek(s,now)
 if s.week then
  local start=E.weekStart(now)
  if start>s.week.start then s.week.start=start;s.week.seconds=0;s.week.claimed=false end
 end
end
function E.weekReward(s,now)
 local w=s.week
 if not w or w.claimed or w.seconds<w.target or s.species==0 then return end
 w.claimed=true
 local companion=E.companion.get(s);companion.goals=companion.goals+1
 local berries=math.min(5,999-s.berries);local xp=math.min(10,1e12-s.xp)
 s.berries=s.berries+berries;s.xp=s.xp+xp
 E.note(s,"Weekly goal met! +"..berries.." berries, +"..xp.." XP.",now)
end
function E.tripLeft(s,now)
 if s.trip==0 then return 0 end
 if s.trail~=nil then return math.max(0,E.routes[s.trip].seconds-(s.reading.seconds-s.trail)) end
 return clamp(s.due-now,0,E.routes[s.trip].seconds)
end
function E.eggLeft(s)
 if not s.egg then return E.egg_seconds end
 return math.max(0,E.egg_seconds-(s.reading.seconds-s.egg.start))
end
function E.discover(s,now)
 if s.trip==0 or s.finds==nil then return end
 local total=E.routes[s.trip].seconds
 local reached=math.min(3,math.floor(4*(total-E.tripLeft(s,now))/total))
 local events={}
 while s.finds<reached do
  s.finds=s.finds+1;local id=s.finds;local item=E.discoveries[id];local reward
  if id==1 then local n=math.min(1,999-s.berries);s.berries=s.berries+n;reward="+"..n.." berry."
  elseif id==2 then local n=math.min(3,1e12-s.xp);s.xp=s.xp+n;reward="+"..n.." XP."
  else local n=math.min(8,100-s.energy);s.energy=s.energy+n;reward="+"..math.floor(n).." energy." end
  E.note(s,item.name..": "..reward,now);events[#events+1]=item.name
 end
 if #events>0 then E.badges(s,now);return events end
end
function E.note(s,text,now)
 if now then text=os.date("%d %b %H:%M",now).." | "..text end
 table.insert(s.log,1,text)
 while #s.log>24 do table.remove(s.log) end
 return text
end
function E.advance(s,now)
 E.updateWeek(s,now)
 -- Keep a high-water mark if the clock moves backwards. No duplicated rewards.
 if now<=s.last then E.discover(s,now);return end
 local hours=math.min((now-s.last)/3600,72)
 if s.species~=0 then
  s.food=clamp(s.food-hours*(s.resting and 1 or 2),15,100)
  s.joy=clamp(s.joy-hours*0.7,20,100)
  s.energy=clamp(s.energy+hours*(s.resting and 12 or 4),0,100)
  s.dirt=clamp(s.dirt+hours*1.3,0,100)
 end
 s.last=now
 E.discover(s,now)
end
local rng=dofile(source.."/random.lua")
function E.count(t) local n=0;for _,v in pairs(t) do if v then n=n+1 end end;return n end
function E.badges(s,now)
 E.companion.badges(s,E,now)
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
 E.updateWeek(s,now)
 local old_berries,old_xp=s.berries,s.xp
 local trip_before=s.trip>0 and E.routes[s.trip].seconds-E.tripLeft(s,s.trail~=nil and now or s.last) or 0
 local egg_before=s.egg and E.egg_seconds-E.eggLeft(s) or 0
 r.seconds=math.min(1e12,r.seconds+seconds);r.carry=math.min(1e12,r.carry+seconds)
 if s.species==0 then return nil end
 local rewards=math.floor(r.carry/900)
 r.carry=r.carry%900
 local berries=math.min(rewards,999-s.berries)
 s.berries=s.berries+berries;s.xp=math.min(1e12,s.xp+rewards*3)
 local claimed=s.week and s.week.claimed
 if s.week then s.week.seconds=math.min(1e12,s.week.seconds+seconds);E.weekReward(s,now) end
 local events=E.discover(s,now)
 local earned_berries,earned_xp=s.berries-old_berries,s.xp-old_xp
 local recap=seconds>0 and {seconds=seconds,berries=earned_berries,xp=earned_xp,events=events,weekly=s.week and s.week.claimed and not claimed,
  route=s.trip,trip_before=trip_before,trip_after=s.trip>0 and E.routes[s.trip].seconds-E.tripLeft(s,now) or 0,
  egg=s.egg~=nil,egg_before=egg_before,egg_after=s.egg and E.egg_seconds-E.eggLeft(s) or 0} or nil
 E.badges(s,now)
 if earned_berries==0 and earned_xp==0 then return nil,recap end
 local message="Reading: +"..earned_berries..(earned_berries==1 and " berry" or " berries")..", +"..earned_xp.." XP."
 E.note(s,message,now);E.badges(s,now);return message,recap
end
function E.act(s,action,arg,now)
 E.advance(s,now)
 local extra=E.companion.act(s,E,action,arg,now)
 if extra then return extra end
 local function done(msg,anim)
  E.note(s,msg,now); E.badges(s,now); return msg,anim
 end
 if action=="choose" and s.species==0 then
  if not E.species[arg] then return "Choose a Pokemon from the list." end
  s.species=arg;s.seen[tostring(arg)]=true;s.gift=now;s.started=now
  E.companion.mark(s,arg,now)
  E.readingReward(s,0,now)
  return done(E.name(arg).." is your new friend!","hello")
 end
 if action=="animation" then
  if arg=="gentle" or arg=="eco" or arg=="off" then s.animation=arg end
  return "Animation: "..s.animation
 end
 if action=="background" then
  if E.backgrounds[arg] then s.background=arg;s.version=math.max(s.version,3) end
  return "Background: "..E.backgrounds[s.background or 1]
 end
 if s.species==0 then return "Choose your first partner." end
 if action=="nickname" then
  if type(arg)~="string" then return "Choose a nickname of up to 12 characters." end
  local name=arg:gsub("^%s+",""):gsub("%s+$","")
  if name~="" and not E.validNickname(name) then return "Use up to 12 characters, with no line breaks." end
  s.nicknames=s.nicknames or {};s.nicknames[tostring(s.species)]=name~="" and name or nil;s.version=math.max(s.version,3)
  return done(name~="" and "You named your partner "..name.."." or "Back to "..E.name(s.species)..".")
 elseif action=="decorate" then
  local item=E.decorations[arg];if not item then return "Choose something for your space." end
  s.decor=s.decor or {}
  if s.decor[arg]==nil then
   if s.berries<item.cost then return "You need "..item.cost.." berries for the "..item.name:lower().."." end
   s.berries=s.berries-item.cost;s.decor[arg]=true;s.version=math.max(s.version,3)
   return done("A new "..item.name:lower().." for your space.")
  end
  s.decor[arg]=not s.decor[arg]
  return s.decor[arg] and item.name.." placed." or item.name.." tucked away."
 elseif action=="goal" then
  if arg~=3600 and arg~=7200 and arg~=10800 then return "Choose 60, 120 or 180 minutes." end
  s.week=s.week or {start=E.weekStart(now),seconds=0,claimed=false};s.week.target=arg;s.version=math.max(s.version,3)
  E.weekReward(s,now)
  return done("Weekly goal: "..arg/60 .." minutes. Pick up your book when you feel like it.")
 elseif action=="check" then
  if s.egg and E.eggLeft(s)==0 then return "Your egg is ready! Tap it to meet your new friend." end
  if s.trip>0 and E.tripLeft(s,now)==0 then return "Your partner is back! Tap Explore to collect." end
  if s.trip>0 then return E.displayName(s).." is exploring "..E.routes[s.trip].name.."." end
  return E.reaction(s)
 elseif action=="gift" then
  if now-s.gift<86400 then return "The berry basket refills every 24 hours." end
  s.gift=now;s.berries=math.min(999,s.berries+5)
  return done("The berry basket has 5 fresh berries!","feed")
 elseif action=="egg" then
  if s.egg then return "You already have an egg to look after." end
  if not s.reading or not s.reading.enabled then return "Turn on reading rewards to raise an egg." end
  if s.berries<E.egg_cost then return "An egg costs "..E.egg_cost.." berries." end
  local pool,all={},{}
  for id=1,E.species_count do
   if not parentOf(id) then
    all[#all+1]=id;if not s.seen[tostring(id)] then pool[#pool+1]=id end
   end
  end
  if #pool==0 then pool=all end
  s.egg={id=pool[rng(s,#pool)],start=s.reading.seconds};s.version=math.max(s.version,3);s.berries=s.berries-E.egg_cost
  return done("An egg for your next chapters. Read for 120 minutes to hatch it.")
 elseif action=="hatch" then
  if not s.egg then return "Pick up an egg first." end
  if E.eggLeft(s)>0 then return "Your egg needs "..math.ceil(E.eggLeft(s)/60).." more reading minutes." end
  local id=s.egg.id;s.seen[tostring(id)]=true;s.egg=nil
  if s.world and s.world.camp and s.world.camp.box then s.world.camp.box[tostring(id)]=true end
  E.companion.mark(s,id,now);local c=E.companion.get(s);c.hatches=c.hatches+1
  return done(E.name(id).." hatched! Find your new friend in the journal.")
 elseif action=="collect" then
  if s.trip==0 then return "Pick a trail to explore." end
  local left=E.tripLeft(s,now)
  if left>0 then return s.trail~=nil and "Read for "..math.ceil(left/60).." more minutes to finish this trail."
   or "Still exploring. Come back in "..math.ceil(left/60).." min." end
  local r=E.routes[s.trip];local pool={}
  for _,id in ipairs(r.pool) do if not s.seen[tostring(id)] then pool[#pool+1]=id end end
  if #pool==0 then pool=r.pool end
  local id=pool[rng(s,#pool)]
  local fresh=not s.seen[tostring(id)];s.seen[tostring(id)]=true
  s.berries=math.min(999,s.berries+r.berries);s.xp=s.xp+r.xp;s.bond=clamp(s.bond+4,0,100)
  E.companion.mark(s,id,now);local story=E.companion.finishTrip(s,E)
  s.trips=s.trips+1;s.trip=0;s.due=0;s.trail=nil;s.finds=nil
  return done((fresh and "New: " or "Met ")..E.name(id).."! +"..r.berries.." berries, +"..r.xp.." XP."..(story or ""),"explore")
 end
 if s.world and (s.world.battle or s.world.camp and s.world.camp.tower) and (action=="partner" or action=="evolve" or action=="trip" or action=="readingtrip") then
  return "Finish or leave the battle under Explore first."
 end
 if s.trip>0 then return "Your partner is exploring. Tap Explore for details." end
 if action=="rest" then
  s.resting=not s.resting
  return done(s.resting and "Nap time! Rest continues while you read." or "Awake and ready for a little adventure.","rest")
 end
 if s.resting then return "Your partner is napping. Tap Wake up first." end
 if action=="partner" then
  if s.world and s.world.camp and s.world.camp.box and not s.world.camp.box[tostring(arg)] then return "Befriend this Pokemon in Explore first." end
  if not E.species[arg] then return "Choose a Pokemon from the list." end
  if arg==s.species then return E.name(arg).." is already with you." end
  s.partners=s.partners or {};s.partners[tostring(s.species)]={xp=s.xp,bond=s.bond}
  local p=s.partners[tostring(arg)] or {xp=0,bond=0}
  s.species=arg;s.xp=p.xp;s.bond=p.bond;s.seen[tostring(arg)]=true
  E.companion.mark(s,arg,now)
  return done(E.name(arg).." joins you. Your other friends keep their progress.","hello")
 elseif action=="feed" then
  if s.berries<1 then return "No berries. Explore or check the berry basket." end
  if s.food>=95 then return "Already full! Save that berry for later." end
  s.berries=s.berries-1;s.food=clamp(s.food+24,0,100);s.bond=clamp(s.bond+2,0,100);s.care=s.care+1
  local _,favourite=E.companion.profile(s,s.species,E)
  if arg==favourite then
   E.companion.get(s).tastes[tostring(s.species)]=true;s.bond=clamp(s.bond+1,0,100)
   return done(E.displayName(s).." perks up. "..favourite.." is a favourite!","feed")
  end
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
 elseif action=="trip" or action=="readingtrip" then
  local r=E.routes[arg];if not r then return "Choose a trail." end
  if action=="readingtrip" and (not s.reading or not s.reading.enabled) then return "Turn on reading rewards to start a reading trail." end
  if s.energy<r.energy then return "This trail needs "..r.energy.." energy." end
  if s.food<30 then return "Feed your partner before setting off." end
  s.energy=s.energy-r.energy;s.trip=arg;s.due=now+r.seconds;s.finds=0;s.version=math.max(s.version,3)
  E.companion.get(s).journey={event=rng(s,#E.companion.events)}
  if action=="readingtrip" then
   s.trail=s.reading.seconds;s.due=0;s.version=math.max(s.version,3)
   return done("Off to "..r.name.."! Read for "..r.seconds/60 .." minutes to finish.","explore")
  end
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
  if s.nicknames and s.nicknames[tostring(s.species)] and not s.nicknames[tostring(id)] then
   s.nicknames[tostring(id)]=s.nicknames[tostring(s.species)]
  end
  s.species=id;s.seen[tostring(id)]=true
  if s.world and s.world.camp and s.world.camp.box then s.world.camp.box[tostring(id)]=true end
  E.companion.mark(s,id,now)
  return done("Your partner evolved into "..E.name(id).."!","evolve")
 end
 return "Ready when you are."
end
return E
