-- Strict data-only saves, with a previous snapshot and atomic promotion.
local S={}
local source=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
local C=dofile(source.."/companion.lua")
local uncertain={}
local numeric={"version","species","food","joy","energy","bond","xp","berries","last","gift","trained","played","cleaned","dirt","trip","due","trips","seed","care","started"}
local function read(path)
 local f=io.open(path,"rb");if not f then return nil end
 local data=f:read(1048577);f:close();return data
end
function S.encode(s)
 local lines={}
 for _,k in ipairs(numeric) do lines[#lines+1]=k.."="..string.format("%.12g",s[k]) end
 lines[#lines+1]="resting="..tostring(s.resting)
 lines[#lines+1]="animation="..s.animation
 for _,key in ipairs({"trail","background","finds"}) do
  if s[key]~=nil then lines[#lines+1]=key.."="..string.format("%.0f",s[key]) end
 end
 if s.egg then lines[#lines+1]="egg="..s.egg.id..","..string.format("%.0f",s.egg.start) end
 if s.week then
  lines[#lines+1]=string.format("week=%.0f,%.0f,%.0f,%s",s.week.target,s.week.start,s.week.seconds,tostring(s.week.claimed))
 end
 for id=1,4 do if s.decor and s.decor[id]~=nil then lines[#lines+1]="decor="..id..","..tostring(s.decor[id]) end end
 local ids={};for id,v in pairs(s.seen) do if v then ids[#ids+1]=tonumber(id) end end;table.sort(ids)
 for _,id in ipairs(ids) do
  lines[#lines+1]="seen="..id
  if s.nicknames and s.nicknames[tostring(id)] then lines[#lines+1]="nickname="..id..","..s.nicknames[tostring(id)] end
  local p=s.partners and s.partners[tostring(id)]
  if p then lines[#lines+1]="partner="..id..","..string.format("%.12g",p.xp)..","..string.format("%.12g",p.bond) end
 end
 local badges={};for badge,v in pairs(s.badges) do if v then badges[#badges+1]=badge end end;table.sort(badges)
 for _,b in ipairs(badges) do lines[#lines+1]="badge="..b end
 for _,v in ipairs(s.log) do lines[#lines+1]="log="..v:gsub("[\r\n]"," ") end
 if s.reading then
  local r=s.reading
  lines[#lines+1]=table.concat({"reading="..tostring(r.enabled),string.format("%.0f",r.seconds),
   string.format("%.0f",r.carry),string.format("%.0f",r.kindle_at),string.format("%.0f",r.ko),tostring(r.ko_ready)},",")
  local keys={};for key in pairs(r.kindle) do keys[#keys+1]=key end;table.sort(keys)
  for _,key in ipairs(keys) do lines[#lines+1]="book="..key..","..string.format("%.0f",r.kindle[key]) end
 end
 if s.companion then lines[#lines+1]="companion="..C.encode(s.companion) end
 return table.concat(lines,"\n").."\n"
end
function S.decode(data,engine)
 if not data or #data>1048576 then return nil end
 local s={seen={},badges={},log={}};local numbers={};local used={}
 for _,k in ipairs(numeric) do numbers[k]=true end
 for line in data:gmatch("[^\n]+") do
  local k,v=line:match("^([a-z]+)=(.*)$")
  if not k then return nil end
  if numbers[k] or k=="resting" or k=="animation" or k=="trail" or k=="background" or k=="egg" or k=="week" or k=="finds" then
   if used[k] then return nil end;used[k]=true
  end
  if numbers[k] then s[k]=tonumber(v)
  elseif k=="trail" or k=="background" or k=="finds" then
   if not v:match("^%d+$") then return nil end;s[k]=tonumber(v)
  elseif k=="egg" then
   local id,start=v:match("^(%d+),(%d+)$");if not id then return nil end
   s.egg={id=tonumber(id),start=tonumber(start)}
  elseif k=="week" then
   local target,start,seconds,claimed=v:match("^(%d+),(%d+),(%d+),(%a+)$")
   if claimed~="true" and claimed~="false" then return nil end
   s.week={target=tonumber(target),start=tonumber(start),seconds=tonumber(seconds),claimed=claimed=="true"}
  elseif k=="decor" then
   local id,placed=v:match("^(%d+),(%a+)$");id=tonumber(id)
   if not id or (placed~="true" and placed~="false") then return nil end
   s.decor=s.decor or {};if s.decor[id]~=nil then return nil end;s.decor[id]=placed=="true"
  elseif k=="resting" then if v~="true" and v~="false" then return nil end;s.resting=v=="true"
  elseif k=="animation" then s.animation=v
  elseif k=="seen" then
   local id=tonumber(v);if not id or not engine.species[id] then return nil end;s.seen[tostring(id)]=true
  elseif k=="partner" then
   local id,xp,bond=v:match("^(%d+),([%d.e+%-]+),([%d.e+%-]+)$")
   if not id or not engine.species[tonumber(id)] then return nil end
   id=tostring(tonumber(id));s.partners=s.partners or {}
   if s.partners[id] then return nil end
   s.partners[id]={xp=tonumber(xp),bond=tonumber(bond)}
  elseif k=="nickname" then
   local id,name=v:match("^(%d+),(.+)$");if not id then return nil end
   id=tostring(tonumber(id));s.nicknames=s.nicknames or {}
   if s.nicknames[id] then return nil end;s.nicknames[id]=name
  elseif k=="reading" then
   if s.reading then return nil end
   local enabled,seconds,carry,at,ko,ready=v:match("^(%a+),(%d+),(%d+),(%d+),(%d+),(%a+)$")
   if (enabled~="true" and enabled~="false") or (ready~="true" and ready~="false") then return nil end
   s.reading={enabled=enabled=="true",seconds=tonumber(seconds),carry=tonumber(carry),
    kindle_at=tonumber(at),ko=tonumber(ko),ko_ready=ready=="true",kindle={}}
  elseif k=="book" then
   local key,seconds=v:match("^(%x+),(%d+)$")
   if not s.reading or not key or #key~=16 or s.reading.kindle[key] then return nil end
   s.reading.kindle[key]=tonumber(seconds)
  elseif k=="companion" then
   if s.companion then return nil end;s.companion=C.decode(v);if not s.companion then return nil end
  elseif k=="badge" then if #v>40 then return nil end;s.badges[v]=true
  elseif k=="log" then if #v>200 or #s.log>=24 then return nil end;s.log[#s.log+1]=v
  else return nil end
 end
 if engine.valid(s) then return s end
end
function S.load(path,engine)
 local primary=read(path);local backup=read(path..".old")
 local state=S.decode(primary,engine)
 if state then return state end
 state=S.decode(backup,engine)
 if state then return state,"Recovered the previous saved snapshot." end
 if primary or backup then return nil,"Save is unreadable; existing files were left unchanged." end
 return nil
end
function S.save(path,s,engine,syncfile,syncdir)
 if not engine.valid(s) then return nil,"Invalid game state." end
 local data=S.encode(s)
 if not S.decode(data,engine) then return nil,"Could not serialize game state." end
 local current=read(path)
 if current==data and not uncertain[path] then return true end
 local f,err=io.open(path..".tmp","wb");if not f then return nil,err end
 local ok;ok,err=f:write(data)
 if ok then ok,err=f:flush() end
 if ok and syncfile then
  local called,result,why=pcall(syncfile,f)
  if not called or result==false then ok=nil;err=why or result end
 end
 local closed,cerr=f:close();if not ok or not closed then return nil,err or cerr end
 -- Keep a good backup if we recovered from a damaged primary.
 if S.decode(read(path),engine) then
  local moved;moved,err=os.rename(path,path..".old")
  if not moved then return nil,err end
 end
 ok,err=os.rename(path..".tmp",path)
 if not ok then return nil,err end
 uncertain[path]=true
 if syncdir then
  local called,result,why=pcall(syncdir,path)
  if not called or result==false then return nil,why or result end
 end
 uncertain[path]=nil
 return true
end
function S.location(fallback,fs)
 if fs.mode("/mnt/us")=="directory" then
  local dir="/mnt/us/pokepal"
  if fs.mode(dir)~="directory" and not fs.mkdir(dir) then return nil,"Could not create the shared save folder." end
  return dir.."/pokepal.dat"
 end
 return fallback
end
function S.open(path,legacy,engine,fs,recover)
 local unlock,err=fs.lock(path..".session")
 if not unlock then return nil,err end
 if recover then
  local ok;ok,err=recover();if not ok then unlock();return nil,err end
 end
 local state,notice=S.load(path,engine)
 if not state and (notice or fs.mode(path) or fs.mode(path..".old")) then
  unlock();return nil,notice or "Could not read the save; existing files were left unchanged."
 end
 if not state then
  local invalid,found=false,0
  for _,oldpath in ipairs(legacy) do
   if oldpath~=path then
    local old,problem=S.load(oldpath,engine)
    if old then found=found+1;if not state or old.last>state.last then state=old end
    elseif problem or fs.mode(oldpath) or fs.mode(oldpath..".old") then invalid=true end
   end
  end
  if not state and invalid then unlock();return nil,"Old save is unreadable; files were left unchanged." end
  if found>0 then notice=found>1 and "Loaded your most recently used save. Original saves kept." or "Moved your progress to the shared save. Original kept." end
 end
 return {state=state,notice=notice,close=unlock}
end
return S
