-- PokePal game rules. Pure Lua 5.1; no device, network, or timer dependency.
local E = {}
E.species = {
 [1]={"Bulbasaur",2,60}, [2]={"Ivysaur",3,180}, [3]={"Venusaur"},
 [4]={"Charmander",5,300}, [5]={"Charmeleon",6,700}, [6]={"Charizard"},
 [7]={"Squirtle",8,60}, [8]={"Wartortle",9,180}, [9]={"Blastoise"},
 [25]={"Pikachu",26,120}, [26]={"Raichu"},
 [133]={"Eevee",134,120}, [134]={"Vaporeon"}, [135]={"Jolteon"}, [136]={"Flareon"},
 [10]={"Caterpie"}, [16]={"Pidgey"}, [19]={"Rattata"}, [35]={"Clefairy"},
 [39]={"Jigglypuff"}, [41]={"Zubat"}, [54]={"Psyduck"}, [74]={"Geodude"},
 [129]={"Magikarp"}, [131]={"Lapras"}, [143]={"Snorlax"}, [147]={"Dratini"},
}
E.starters = {1,4,7,25,133}
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
local function clamp(n, lo, hi) return math.max(lo, math.min(hi,n)) end
function E.name(id) return E.species[id] and E.species[id][1] or "Egg" end
function E.level(s) return math.min(100,1+math.floor(s.xp/20)) end
function E.mood(s,now)
 if s.trip>0 then return now>=s.due and "Home from an adventure" or "Exploring the world" end
 if s.resting then return "Dreaming by the warm campfire" end
 if s.food<40 then return "A little hungry" end
 if s.energy<20 then return "Ready for a nap" end
 if s.dirt>70 then return "Could use a little clean" end
 if s.joy<40 then return "Would love to play" end
 if s.bond>=60 then return "Your very best friend" end
 return "Happy to be with you"
end
function E.moves(s)
 local moves={{name="Scratch",level=1}}
 if s.species==4 or s.species==5 or s.species==6 then
  moves[#moves+1]={name="Ember",level=7}
  moves[#moves+1]={name="Flame Burst",level=20}
  moves[#moves+1]={name="Flamethrower",level=36}
 end
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
 if type(s)~="table" or s.version~=1 then return false end
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
function E.act(s,action,arg,now)
 E.advance(s,now)
 local function done(msg,anim)
  E.note(s,msg,now); E.badges(s,now); return msg,anim
 end
 if action=="choose" and s.species==0 then
  local allowed=false;for _,id in ipairs(E.starters) do if arg==id then allowed=true end end
  if not allowed then return "Choose one of the five starters." end
  s.species=arg;s.seen[tostring(arg)]=true;s.gift=now
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
  local r=E.routes[s.trip];local id=r.pool[rng(s,#r.pool)]
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
 if action=="feed" then
  if s.berries<1 then return "No berries. Explore or check the berry basket." end
  if s.food>=95 then return "Already full! Save that berry for later." end
  s.berries=s.berries-1;s.food=clamp(s.food+24,0,100);s.bond=clamp(s.bond+2,0,100);s.care=s.care+1
  return done("Crunch! A berry makes everything better.","feed")
 elseif action=="play" then
  local allowed,why=E.canPlay(s,now);if not allowed then return why end
  local perfect=arg=="perfect"
  s.played=now;s.energy=s.energy-10;s.joy=clamp(s.joy+20,0,100);s.bond=clamp(s.bond+4,0,100);s.xp=s.xp+5;s.care=s.care+1
  if perfect then s.xp=s.xp+3 end
  return done(perfect and "Perfect berry trail! +8 XP, +4 bond." or "A lovely game together! +5 XP, +4 bond.","play")
 elseif action=="train" then
  if now-s.trained<3600 then return "Training ready in "..math.ceil((3600-now+s.trained)/60).." min." end
  if s.energy<18 or s.food<30 then return "Training needs 18 energy and 30 fullness." end
  local move=arg or "Scratch";local unlocked=false
  for _,m in ipairs(E.moves(s)) do if m.name==move and E.level(s)>=m.level then unlocked=true end end
  if not unlocked then return "That move is not ready yet. Keep growing together." end
  s.trained=now;s.energy=s.energy-18;s.food=s.food-8;s.xp=s.xp+12;s.bond=clamp(s.bond+2,0,100)
  return done(move.." practice! +12 XP, +2 bond.","train")
 elseif action=="clean" then
  if s.dirt<15 then return "Already squeaky clean." end
  s.dirt=0;s.joy=clamp(s.joy+8,0,100);s.bond=clamp(s.bond+2,0,100);s.care=s.care+1;s.cleaned=now
  return done("A tidy nest and a very happy Pokemon.","clean")
 elseif action=="trip" then
  local r=E.routes[arg];if not r then return "Choose a trail." end
  if s.energy<r.energy then return "This trail needs "..r.energy.." energy." end
  if s.food<30 then return "Feed your partner before setting off." end
  s.energy=s.energy-r.energy;s.trip=arg;s.due=now+r.seconds
  return done("Off to "..r.name.."! Return in "..r.seconds/60 .." min.","explore")
 elseif action=="evolve" then
  if not E.ready(s) then return "Evolution needs enough XP and at least 30 bond." end
  local id=E.species[s.species][2]
  if s.species==133 then
   if arg~=134 and arg~=135 and arg~=136 then return "Choose a water, thunder, or fire stone." end
   id=arg
  end
  s.species=id;s.seen[tostring(id)]=true
  return done("Your partner evolved into "..E.name(id).."!","evolve")
 end
 return "Ready for a quiet adventure."
end
return E
