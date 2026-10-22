-- Reading counters only. Book text and annotations are never stored.
local R={limit=10000,max_file=1048576}
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
function R.scan(root,fs)
 local counters={};local visited,books,skipped,bytes=0,0,0,0
 local function walk(path,depth,book)
  if depth>20 then error("Library depth limit") end
  local names=fs.list(path);if not names then error("Unreadable directory") end
  table.sort(names)
  for _,name in ipairs(names) do
   visited=visited+1;if visited>100000 then error("Library size limit") end
   local full=path.."/"..name;local mode=fs.mode(full)
   if mode=="directory" then
    walk(full,depth+1,name:match("^(.*)%.sdr$") or book)
   elseif mode=="file" and book and (name:match("%.azw3f$") or name:match("%.yjf$")
      or name:match("%.mbs$") or name:match("%.tas$") or name:match("%.pdt$")) then
    local f=io.open(full,"rb");local data=f and f:read(R.max_file+1);if f then f:close() end
    bytes=bytes+(data and #data or 0);if bytes>67108864 then error("Scan size limit") end
    local seconds=R.kindleTime(data)
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
function R.init(s)
 s.reading=s.reading or {enabled=true,seconds=0,carry=0,kindle_at=0,kindle={},ko=0,ko_ready=false}
 s.version=2
 return s.reading
end
function R.collect(s,engine,counters,ko,now)
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
 if ko and integer(ko,1e12) then
  if r.ko_ready then seconds=seconds+math.max(0,ko-r.ko) end
  r.ko=math.max(r.ko,ko);r.ko_ready=true
 end
 if not r.enabled then seconds=0 end
 return engine.readingReward(s,seconds,now)
end
function R.counter(path)
 local function read(p)
  local f,_,code=io.open(p,"rb");if not f then return nil,code~=2 end
  local text=f:read(80);f:close()
  local n=tonumber(text and text:match("^POKEPAL_READING_1\n(%d+)\n$"))
  return integer(n,1e12) and n or nil,true
 end
 local n,exists=read(path);if n then return n,nil,true end
 local backup,old=read(path..".old");if backup then return backup end
 if exists or old then return nil,"Reading counter is unreadable." end
 return 0
end
function R.saveCounter(path,n,syncfile,syncdir)
 if not integer(n,1e12) then return nil,"Invalid reading counter." end
 local f,err=io.open(path..".tmp","wb");if not f then return nil,err end
 local good;good,err=f:write("POKEPAL_READING_1\n"..string.format("%.0f",n).."\n")
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
