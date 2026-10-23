-- Reading counters only. Book text and annotations are never stored.
local R={limit=10000,max_file=1048576}
local source=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
local C=dofile(source.."/companion.lua")
local cache={}
local cache_count=0
local cache_path
local magic="\0\0\0\0\0\26\177\38"
local function integer(n,max) return type(n)=="number" and n==n and n>=0 and n<=max and n%1==0 end

-- KRDS is a tagged binary format. Skip unknown object names, not unknown types.
function R.kindleTime(data)
 if type(data)~="string" or #data>R.max_file or data:sub(1,8)~=magic then return nil end
 local pos,nodes=9,0
 local function take(n)
  if pos+n-1>#data then error("Truncated KRDS") end
  local value=data:sub(pos,pos+n-1);pos=pos+n;return value
 end
 local function uint(n)
  local value=0
  for byte in take(n):gmatch(".") do value=value*256+byte:byte() end
  return value
 end
 local function utf()
  local null=uint(1);if null==1 then return "" end
  if null~=0 then error("Invalid string") end
  return take(uint(2))
 end
 local value
 value=function(depth)
  nodes=nodes+1;if depth>32 or nodes>100000 then error("KRDS limit") end
  local tag=uint(1)
  if tag==2 then return uint(8),tag
  elseif tag==1 then return uint(4),tag
  elseif tag==3 then return utf(),tag
  elseif tag==254 then
   local name=utf();local first={};local index=0
   while data:byte(pos)~=255 do
    local v,t=value(depth+1);index=index+1
    if name=="timer.model" and index<=3 then first[index]={v,t} end
   end
   take(1)
   return {name=name,fields=first},tag
  else
   local widths={[0]=1,[4]=8,[5]=2,[6]=4,[7]=1,[9]=2}
   if not widths[tag] then error("Unknown KRDS type") end
   take(widths[tag]);return nil,tag
  end
 end
 local success,result=pcall(function()
  local version,vt=value(0);local count,ct=value(0)
  if vt~=2 or version~=1 or ct~=1 or not integer(count,10000) then return nil end
  local seconds
  for _=1,count do
   local object,tag=value(0);if tag~=254 then return nil end
   if object.name=="timer.model" then
    local f=object.fields
    if seconds or not f[1] or f[1][2]~=2 or not f[2] or f[2][2]~=2
      or not f[3] or f[3][2]~=2 or not integer(f[2][1],1e12) or not integer(f[3][1],1e12) then return nil end
    seconds=math.floor(f[2][1]/1000)
   end
  end
  if pos~=#data+1 then return nil end
  return seconds
 end)
 if success then return result end
end

function R.key(name)
 -- Two integer hashes keep filenames out of saves and fit LuaJIT's exact range.
 local a,b=5381,52711
 for i=1,#name do local c=name:byte(i);a=(a*131+c)%2147483647;b=(b*137+c)%2147483629 end
 return string.format("%08x%08x",a,b)
end
function R.loadCache(path)
 cache_path=path;cache={};cache_count=0
 local f=io.open(path,"rb");if not f then return end
 local data=f:read(1048577);f:close()
 if not data or #data>1048576 or data:sub(1,15)~="POKEPAL_SCAN_1\n" then return end
 local count=0
 for line in data:sub(16):gmatch("[^\n]+") do
  local key,modified,size,seconds,checked=line:match("^(%x+),(%d+),(%d+),(%d+),(%d+)$")
  modified,size,seconds,checked=tonumber(modified),tonumber(size),tonumber(seconds),tonumber(checked)
  if not key or #key~=16 or not integer(modified,1e12) or not integer(size,R.max_file)
   or not integer(seconds,1e12) or not integer(checked,1e12) or count>=R.limit then cache={};cache_count=0;return end
  cache[key]={modified=modified,size=size,seconds=seconds,checked=checked};count=count+1;cache_count=count
 end
end
function R.saveCache()
 if not cache_path then return end
 local keys={};for key,item in pairs(cache) do if item.modified and item.size then keys[#keys+1]=key end end;table.sort(keys)
 local lines={"POKEPAL_SCAN_1"}
 for i=1,math.min(#keys,R.limit) do local key=keys[i];local c=cache[key]
  lines[#lines+1]=string.format("%s,%.0f,%.0f,%.0f,%.0f",key,c.modified,c.size,c.seconds,c.checked)
 end
 -- This is a disposable cache, never a source of credited progress.
 local f=io.open(cache_path..".tmp","wb");if not f then return end
 local ok=f:write(table.concat(lines,"\n").."\n");local closed=f:close()
 if ok and closed then os.rename(cache_path..".tmp",cache_path) end
end
function R.scan(root,fs,yield_step)
 local counters={};local visited,books,skipped,bytes=0,0,0,0
 local function walk(path,depth,book)
  if depth>20 then error("Library depth limit") end
  local names=fs.list(path);if not names then error("Unreadable directory") end
  table.sort(names)
  for _,name in ipairs(names) do
   visited=visited+1;if visited>100000 then error("Library size limit") end
   local full=path.."/"..name;local mode=fs.mode(full)
   if yield_step and visited%24==0 then yield_step() end
   if mode=="directory" then
    walk(full,depth+1,name:match("^(.*)%.sdr$") or book)
   elseif mode=="file" and book and (name:match("%.azw3f$") or name:match("%.yjf$")
      or name:match("%.mbs$") or name:match("%.tas$") or name:match("%.pdt$")) then
    local modified=fs.mtime and fs.mtime(full);local size=fs.size and fs.size(full)
    local key=R.key(full);local old=cache[key];local seconds;local checked=os.time()
    -- Recent files are read again: FAT timestamps can miss same-second changes.
    if old and modified and size and modified==old.modified and size==old.size and checked-modified>3
     and checked>=old.checked and checked-old.checked<3600 then
     seconds=old.seconds
    else
     local f=io.open(full,"rb");local data=f and f:read(R.max_file+1);if f then f:close() end
     bytes=bytes+(data and #data or 0);if bytes>67108864 then error("Scan size limit") end
     seconds=R.kindleTime(data)
     if seconds and (cache[key] or cache_count<R.limit) then
      if not cache[key] then cache_count=cache_count+1 end
      cache[key]={modified=modified,size=size,seconds=seconds,checked=checked}
     elseif not seconds and cache[key] then cache[key]=nil;cache_count=cache_count-1 end
    end
    if seconds then
     local key=R.key(book)
     if counters[key]==nil then books=books+1;if books>R.limit then error("Book limit") end end
     -- Multiple reader profiles and copied books must not multiply time.
     counters[key]=math.max(counters[key] or 0,seconds)
    else skipped=skipped+1 end
   end
  end
 end
 local success=pcall(walk,root,0,nil)
 if not success then return nil,"Kindle: reading data unavailable" end
 return counters,books>0 and ("Kindle: "..books.." book"..(books==1 and "" or "s").." detected")
  or (skipped>0 and "Kindle: no supported timing records" or "Kindle: read a book to get started")
end
function R.scanAsync(root,fs)
 local thread=coroutine.create(function() return R.scan(root,fs,function() coroutine.yield() end) end)
 return function()
  local ok,counters,status=coroutine.resume(thread)
  if not ok then return true,nil,"Kindle: reading data unavailable" end
  return coroutine.status(thread)=="dead",counters,status
 end
end
function R.clearCache() cache={};cache_count=0 end
function R.init(s)
 s.reading=s.reading or {enabled=true,seconds=0,carry=0,kindle_at=0,kindle={},ko=0,ko_ready=false}
 s.version=math.max(s.version,2)
 return s.reading
end
function R.visit(s) return {at=s.last,berries=s.berries,xp=s.xp,finds=s.finds} end
function R.collect(s,engine,counters,ko,now,days,visit)
 local r=R.init(s);local seconds=0
 if counters and now>=r.kindle_at then
  local delta=0;local count=0;for _ in pairs(r.kindle) do count=count+1 end
  for key,total in pairs(counters) do
   local old=r.kindle[key]
   if old~=nil or count<R.limit then
    if old==nil then count=count+1 end
    if r.kindle_at>0 then delta=delta+math.max(0,total-(old or 0)) end
    r.kindle[key]=math.max(old or 0,total)
   end
  end
  -- A restored/synced book cannot award more time than the elapsed interval.
  if r.kindle_at>0 then seconds=math.min(delta,now-r.kindle_at) end
  r.kindle_at=now
 end
 local native_seconds=seconds;local dated={}
 if ko and integer(ko,1e12) then
  local delta=r.ko_ready and math.max(0,ko-r.ko) or 0
  seconds=seconds+delta
  if days then
   local c=C.get(s);local ks={};for day in pairs(days) do ks[#ks+1]=day end;table.sort(ks)
   for i=#ks,1,-1 do local day=ks[i];local n=math.min(delta,math.max(0,days[day]-(c.ko_days[day] or 0)))
    if n>0 then dated[day]=n;delta=delta-n end
    c.ko_days[day]=math.max(c.ko_days[day] or 0,days[day])
   end
  end
  r.ko=math.max(r.ko,ko);r.ko_ready=true
 end
 if not r.enabled then seconds=0 else C.history(s,dated,native_seconds,now) end
 C.history(s,{},0,now)
 local message,recap=engine.readingReward(s,seconds,now)
 if recap and visit then
  recap.berries=math.max(0,s.berries-visit.berries);recap.xp=math.max(0,s.xp-visit.xp)
  if s.trip>0 and s.trail==nil then recap.trip_before=engine.routes[s.trip].seconds-engine.tripLeft(s,visit.at) end
  if visit.finds and s.finds and s.finds>visit.finds then
   recap.events={};for i=visit.finds+1,s.finds do recap.events[#recap.events+1]=engine.discoveries[i].name end
  end
 end
 return message,recap
end
function R.validDays(days,total)
 if type(days)~="table" then return false end
 local count,sum=0,0
 for day,n in pairs(days) do
  count=count+1;if count>62 or type(day)~="string" or not day:match("^%d%d%d%d%-%d%d%-%d%d$") or not integer(n,1e12) then return false end
  sum=sum+n
 end
 return sum<=total
end
function R.counter(path)
 local function read(p)
  local f,_,code=io.open(p,"rb");if not f then return nil,code~=2 end
  local data=f:read(8193);f:close();if not data or #data>8192 then return nil,true end
  local version,n,tail=data:match("^POKEPAL_READING_(%d)\n(%d+)\n(.*)$");n=tonumber(n)
  if not integer(n,1e12) or (version~="1" and version~="2") then return nil,true end
  local days={}
  if version=="1" then if tail~="" then return nil,true end
  else
   local rest=tail
   for line in tail:gmatch("[^\n]+") do
    local day,value=line:match("^(%d%d%d%d%-%d%d%-%d%d)=(%d+)$")
    if not day or days[day] then return nil,true end;days[day]=tonumber(value)
    rest=rest:sub(#line+2)
   end
   if rest~="" or not R.validDays(days,n) then return nil,true end
  end
  return n,true,days
 end
 local n,exists,days=read(path);if n then return n,nil,true,days end
 local backup,old,previous=read(path..".old");if backup then return backup,nil,false,previous end
 if exists or old then return nil,"Reading counter is unreadable." end
 return 0,nil,false,{}
end
function R.saveCounter(path,n,syncfile,syncdir,days)
 if not integer(n,1e12) then return nil,"Invalid reading counter." end
 if days and not R.validDays(days,n) then return nil,"Invalid reading dates." end
 local data="POKEPAL_READING_"..(days and "2" or "1").."\n"..string.format("%.0f",n).."\n"
 if days then local ks={};for day in pairs(days) do ks[#ks+1]=day end;table.sort(ks)
  for _,day in ipairs(ks) do data=data..day.."="..string.format("%.0f",days[day]).."\n" end
 end
 local f,err=io.open(path..".tmp","wb");if not f then return nil,err end
 local good;good,err=f:write(data)
 if good then good,err=f:flush() end
 if good and syncfile then
  local called,result,why=pcall(syncfile,f)
  if not called or result==false then good=nil;err=why or result end
 end
 local closed=f:close();if not good or not closed then return nil,err end
 local _,_,primary=R.counter(path)
 if primary then local moved;moved,err=os.rename(path,path..".old");if not moved then return nil,err end end
 good,err=os.rename(path..".tmp",path)
 if not good then return nil,err end
 if syncdir then
  local called,result,why=pcall(syncdir,path)
  if not called or result==false then return nil,why or result,true end
 end
 return true,nil,true
end
return R
