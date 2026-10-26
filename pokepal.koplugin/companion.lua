-- Optional companion features. Old saves do not need these fields.
local C={}
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
C.text=dofile(dir.."/utf8text.lua")
C.preferences={"sleep_screen","auto_rest","footer","large_text","high_contrast"}
C.berries={"Oran","Pecha","Cheri"}
C.traits={"Curious","Quiet","Playful","Patient"}
C.events={
 {title="A fork in the trail",text="There are berries beside the stream and tracks up the hill.",choices={"Follow the stream","Follow the tracks"},rewards={{berries=2},{xp=5}}},
 {title="A tired traveller",text="A small Pokemon is resting by the path. There is room to sit beside it.",choices={"Keep them company","Rest together"},rewards={{bond=3},{energy=10}}},
 {title="A sheltered clearing",text="Your partner found a quiet spot with room to practise.",choices={"Practise a move","Take a breather"},rewards={{xp=5},{energy=10}}},
}
local function integer(n,max) return type(n)=="number" and n==n and n>=0 and n<=max and n%1==0 end
local function keys(t,allowed)
 if type(t)~="table" then return false end
 for k in pairs(t) do if not allowed[k] then return false end end;return true
end
local function map(t,check,limit)
 if type(t)~="table" then return false end
 local n=0;for k,v in pairs(t) do n=n+1;if n>limit or not check(k,v) then return false end end;return true
end
function C.get(s)
 if not s.companion then s.companion={prefs={},favourites={},tastes={},met={},memories={},days={},ko_days={},routes={},hatches=0,goals=0} end
 s.version=math.max(s.version,4);return s.companion
end
function C.option(s,key) return s.companion and s.companion.prefs[key]==true or false end
function C.valid(c,s,E)
 if c==nil then return true end
 if s.version<4 or not keys(c,{prefs=true,favourites=true,tastes=true,met=true,memories=true,days=true,ko_days=true,routes=true,hatches=true,goals=true,sleep=true,journey=true}) then return false end
 local prefs={};for _,k in ipairs(C.preferences) do prefs[k]=true end
 if not keys(c.prefs,prefs) then return false end
 for _,v in pairs(c.prefs) do if type(v)~="boolean" then return false end end
 local function id(k) return type(k)=="string" and tostring(tonumber(k))==k and E.species[tonumber(k)] and s.seen[k] end
 if not map(c.favourites,function(k,v) return id(k) and v==true end,E.species_count)
  or not map(c.tastes,function(k,v) return id(k) and v==true end,E.species_count)
  or not map(c.met,function(k,v) return id(k) and integer(v,1e12) end,E.species_count)
  or not map(c.routes,function(k,v) return (k=="1" or k=="2" or k=="3") and v==true end,3)
  or not integer(c.hatches,1e9) or not integer(c.goals,1e9) then return false end
 local function day(k) return type(k)=="string" and k:match("^%d%d%d%d%-%d%d%-%d%d$")~=nil end
 if not map(c.days,function(k,v) return day(k) and keys(v,{ko=true,kindle=true}) and integer(v.ko,1e12) and integer(v.kindle,1e12) end,62)
  or not map(c.ko_days,function(k,v) return day(k) and integer(v,1e12) end,62) then return false end
 if not map(c.memories,function(k,m)
  return integer(k,100) and k>=1 and keys(m,{title=true,id=true,at=true}) and E.species[m.id]
   and s.seen[tostring(m.id)] and C.text.valid(m.title,100) and integer(m.at,1e12)
 end,100) then return false end
 local memory_count=0;for _ in pairs(c.memories) do memory_count=memory_count+1 end
 if memory_count~=#c.memories then return false end
 for i=1,memory_count do if not c.memories[i] then return false end end
 if c.sleep and (not s.resting or s.trip~=0 or not keys(c.sleep,{at=true,resting=true}) or not integer(c.sleep.at,1e12) or type(c.sleep.resting)~="boolean") then return false end
 if c.journey and (not keys(c.journey,{event=true,choice=true}) or s.trip==0 or not C.events[c.journey.event]
  or (c.journey.choice~=nil and c.journey.choice~=1 and c.journey.choice~=2)) then return false end
 return true
end
-- Bounded, deterministic data encoding. No Lua source is evaluated on load.
function C.encode(value)
 local function enc(v)
  if type(v)=="boolean" then return v and "b1" or "b0" end
  if type(v)=="number" then return "n"..string.format("%.0f",v)..":" end
  if type(v)=="string" then return "s"..#v..":"..v end
  local ks={};for k in pairs(v) do ks[#ks+1]=k end
  table.sort(ks,function(a,b) return type(a)==type(b) and a<b or type(a)<type(b) end)
  local out={"t"..#ks..":"};for _,k in ipairs(ks) do out[#out+1]=enc(k);out[#out+1]=enc(v[k]) end
  return table.concat(out)
 end
 return (enc(value):gsub(".",function(c) return string.format("%02x",c:byte()) end))
end
function C.decode(hex)
 if type(hex)~="string" or #hex>131072 or #hex%2~=0 or hex:find("[^%x]") then return nil end
 local data=hex:gsub("..",function(c) return string.char(tonumber(c,16)) end)
 local pos,nodes=1,0
 local function dec(depth)
  nodes=nodes+1;if depth>8 or nodes>4096 then error("Data limit") end
  local kind=data:sub(pos,pos);pos=pos+1
  if kind=="b" then local b=data:sub(pos,pos);pos=pos+1;if b~="0" and b~="1" then error("Boolean") end;return b=="1" end
  local ending=data:find(":",pos,true);if not ending or ending-pos>13 then error("Length") end
  local digits=data:sub(pos,ending-1);if not digits:match("^%d+$") then error("Number") end
  local n=tonumber(digits);pos=ending+1
  if kind=="n" then return n
  elseif kind=="s" then if n>2048 or pos+n-1>#data then error("String") end;local v=data:sub(pos,pos+n-1);pos=pos+n;return v
  elseif kind=="t" then
   if n>1024 then error("Table") end
   local t={};for _=1,n do local k=dec(depth+1);if (type(k)~="string" and type(k)~="number") or t[k]~=nil then error("Key") end;t[k]=dec(depth+1) end;return t
  end
  error("Type")
 end
 local ok,value=pcall(dec,0);if ok and pos==#data+1 then return value end
end
function C.profile(s,id,E)
 local root=E.evolutionLine(id)[1]
 return C.traits[(root*7)%#C.traits+1],C.berries[(root*11)%#C.berries+1]
end
function C.mark(s,id,now) local c=C.get(s);c.met[tostring(id)]=c.met[tostring(id)] or now end
function C.suspend(s,E,now)
 if not C.option(s,"auto_rest") or s.species==0 or s.trip>0 then return end
 local c=C.get(s);if c.sleep then return end
 E.advance(s,now);c.sleep={at=now,resting=s.resting};s.resting=true
end
function C.resume(s,E,now)
 local c=s.companion;if not c or not c.sleep then return end
 E.advance(s,now);s.resting=c.sleep.resting;c.sleep=nil
end
function C.badges(s,E,now)
 local c=s.companion
 local rules={{"Bookworm",s.reading and s.reading.seconds>=36000},{"A new arrival",c and c.hatches>0},
  {"All three trails",c and E.count(c.routes)==3},{"A place of our own",s.decor and E.count(s.decor)>=4},
  {"Reading together",c and #c.memories>0},{"Finding a rhythm",c and c.goals>=4},
  {"Favourite snack",c and E.count(c.tastes)>0},{"Kanto explorer",E.kantoCount(s)==151}}
 for _,r in ipairs(rules) do if r[2] and not s.badges[r[1]] then s.badges[r[1]]=true;E.note(s,"Badge earned: "..r[1].."!",now) end end
end
function C.history(s,ko,kindle,now)
 if not s.companion and (not ko or next(ko)==nil) and (not kindle or kindle<=0) then return end
 local c=C.get(s)
 for day,n in pairs(ko or {}) do local d=c.days[day] or {ko=0,kindle=0};d.ko=math.min(1e12,d.ko+n);c.days[day]=d end
 if kindle and kindle>0 then local day=os.date("%Y-%m-%d",now);local d=c.days[day] or {ko=0,kindle=0};d.kindle=math.min(1e12,d.kindle+kindle);c.days[day]=d end
 for _,t in ipairs({c.days,c.ko_days}) do local ks={};for k in pairs(t) do ks[#ks+1]=k end;table.sort(ks);while #ks>62 do t[table.remove(ks,1)]=nil end end
end
function C.act(s,E,action,arg,now)
 if action=="preference" then
  for _,key in ipairs(C.preferences) do if arg==key then
   local c=C.get(s);c.prefs[key]=not c.prefs[key]
   if key=="auto_rest" and not c.prefs[key] then C.resume(s,E,now) end
   return "Preference saved."
  end end
  return "Choose a preference."
 elseif action=="favourite" then
  if not s.seen[tostring(arg)] then return "Meet this Pokemon first." end
  local c=C.get(s);local key=tostring(arg);c.favourites[key]=not c.favourites[key] or nil
  return c.favourites[key] and "Added to favourites." or "Removed from favourites."
 elseif action=="memory" then
  if s.species==0 then return "Choose your partner first." end
  if not C.text.valid(arg,100) then return "Enter a book title of up to 100 characters." end
  local c=C.get(s)
  for _,m in ipairs(c.memories) do if m.title==arg and m.id==s.species then return "That book is already in your memories." end end
  if #c.memories>=100 then return "Your book shelf is full (100 memories)." end
  table.insert(c.memories,1,{title=arg,id=s.species,at=now});C.badges(s,E,now)
  return "Saved a book you read together."
 elseif action=="trailchoice" then
  local c=s.companion;local j=c and c.journey
  if not j or E.tripLeft(s,now)>0 then return "Finish the trail first." end
  if arg~=1 and arg~=2 then return "Choose what happened on the trail." end
  if j.choice then return "You already chose." end
  j.choice=arg;return "Choice saved. Collect your partner to hear the rest."
 end
end
function C.finishTrip(s,E)
 local c=C.get(s);c.routes[tostring(s.trip)]=true
 local j=c.journey;local message
 if j and j.choice then
  local reward=C.events[j.event].rewards[j.choice]
  for k,n in pairs(reward) do
   local before=s[k];s[k]=math.min(k=="berries" and 999 or k=="xp" and 1e12 or 100,s[k]+n)
   message=" +"..math.floor(s[k]-before).." "..(k=="xp" and "XP" or k).." from the trail."
  end
 end
 c.journey=nil;return message
end
function C.journal(s,E,query,filter)
 local list={};query=(query or ""):lower()
 for id=1,E.species_count do
  local known=s.seen[tostring(id)];local p=s.partners and s.partners[tostring(id)] or {xp=0,bond=0}
  if id==s.species then p=s end
  local c=s.companion
  local match=filter=="all" or filter==nil or (filter=="met" and known) or (filter=="favourites" and c and c.favourites[tostring(id)])
   or (filter=="ready" and known and E.species[id][2] and p.xp>=E.species[id][3] and p.bond>=30)
   or (filter=="recent" and known) or E.species[id].types:lower():find((filter or ""):lower(),1,true)~=nil
  if known and match and (query=="" or E.name(id):lower():find(query,1,true) or E.displayName(s,id):lower():find(query,1,true) or tostring(id)==query) then list[#list+1]=id end
 end
 if filter=="recent" then table.sort(list,function(a,b)
  local m=s.companion and s.companion.met or {};local x,y=m[tostring(a)] or 0,m[tostring(b)] or 0
  return x==y and a<b or x>y
 end) end
 return list
end
return C
