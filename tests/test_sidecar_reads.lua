-- Reading totals and recovery copies must survive temporary filesystem failures.
local E=dofile(BASE..'/engine.lua')
local R=dofile(BASE..'/reading.lua')
local F=dofile(BASE..'/filesystem.lua')
local B=dofile(BASE..'/backups.lua')
local passed,failed,serial=0,0,0
local function test(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name)
 else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
end
local function path()
 serial=serial+1;return TESTDIR..'/sidecar-'..serial
end
local function write(p,data)
 local f=assert(io.open(p,'wb'));assert(f:write(data));assert(f:close())
end
local function bytes(p)
 local f=io.open(p,'rb');if not f then return end
 local data=f:read('*a');f:close();return data
end
local function failure(p,kind,fn)
 local open=io.open;local data=bytes(p);local closed=false
 io.open=function(name,mode)
  if name==p and mode=='rb' then
   if kind=='open' then return nil,'Permission denied',13 end
   if kind=='unknown' then return nil end
   return {
    read=function() if kind=='read' then return nil,'Input/output error',5 end;return data end,
    close=function() closed=true;if kind=='close' then return nil,'Input/output error',5 end;return true end,
   }
  end
  return open(name,mode)
 end
 local ok,err=pcall(fn);io.open=open;assert(ok,err)
 if kind=='read' or kind=='close' then assert(closed,'read handle leaked') end
end
local function rejected(result,err,p)
 assert(not result,'I/O failure was ignored')
 assert(err and err:find(p,1,true),'read error did not identify the affected file')
end
local function counter()
 local p=path();assert(R.saveCounter(p,100));assert(R.saveCounter(p,900));return p
end
local function backup()
 local p=path();local s=E.new(1800000000);E.act(s,'choose',4,1800000000)
 local b=B.new(p,E,R,F);local q=p..'.backup'
 assert(b:write(q,b:encode(s,100,1800000000)))
 s.xp=91;assert(b:write(q,b:encode(s,900,1800000000)))
 s.xp=120;return b,q,b:encode(s,960,1800000000)
end
for _,kind in ipairs({'open','read','close','unknown'}) do
 test('counter '..kind..' failures do not roll back to an older total',function()
  local p=counter();local current,old=bytes(p),bytes(p..'.old')
  failure(p,kind,function() local n,err=R.counter(p);rejected(n,err,p) end)
  assert(bytes(p)==current and bytes(p..'.old')==old)
 end)
 test('backup '..kind..' failures do not silently preview an older game',function()
  local b,p=backup();local current,old=bytes(p),bytes(p..'.old')
  failure(p,kind,function() local s,err=b:preview('backup');rejected(s,err,p) end)
  assert(bytes(p)==current and bytes(p..'.old')==old)
 end)
end
for _,suffix in ipairs({'','.old'}) do
 test('counter write preserves unreadable '..(suffix=='' and 'primary' or 'snapshot'),function()
  local p=counter();local current,old=bytes(p),bytes(p..'.old');write(p..'.tmp','keep staged bytes')
  failure(p..suffix,'open',function()
   local ok,err,committed=R.saveCounter(p,960);rejected(ok,err,p..suffix);assert(not committed)
  end)
  assert(bytes(p)==current and bytes(p..'.old')==old and bytes(p..'.tmp')=='keep staged bytes')
  assert(R.saveCounter(p,960) and R.counter(p)==960 and bytes(p..'.old')==current)
 end)
 test('backup write preserves unreadable '..(suffix=='' and 'primary' or 'snapshot'),function()
  local b,p,data=backup();local current,old=bytes(p),bytes(p..'.old');write(p..'.tmp','keep staged bytes')
  failure(p..suffix,'open',function() local ok,err=b:write(p,data);rejected(ok,err,p..suffix) end)
  assert(bytes(p)==current and bytes(p..'.old')==old and bytes(p..'.tmp')=='keep staged bytes')
  assert(b:write(p,data) and bytes(p)==data and bytes(p..'.old')==current)
 end)
end
test('counter and backup fallback failures identify the inaccessible snapshot',function()
 local p=counter();write(p,'broken')
 failure(p..'.old','open',function() local n,err=R.counter(p);rejected(n,err,p..'.old') end)
 local b,q=backup();write(q,'broken')
 failure(q..'.old','open',function() local s,err=b:preview('backup');rejected(s,err,q..'.old') end)
end)
test('valid counter and backup primaries can still be inspected with inaccessible snapshots',function()
 local p=counter()
 failure(p..'.old','open',function() assert(R.counter(p)==900) end)
 local b,q=backup()
 failure(q..'.old','open',function() assert(b:preview('backup').state.xp==91) end)
end)
test('empty or damaged sidecars still recover readable snapshots',function()
 for _,bad in ipairs({'','broken'}) do
  local p=counter();local old=bytes(p..'.old');write(p,bad)
  assert(R.counter(p)==100 and R.saveCounter(p,160) and bytes(p..'.old')==old)
  local b,q,data=backup();local previous=bytes(q..'.old');write(q,bad)
  local preview=assert(b:preview('backup'));assert(preview.previous and preview.state.xp==0)
  assert(b:write(q,data) and bytes(q..'.old')==previous)
 end
end)
test('unreadable restore journals remain pending and report the file error',function()
 local b,p,data=backup();local journal=b.path..'.restore';write(journal,data)
 local current,old=bytes(p),bytes(p..'.old')
 failure(journal,'open',function() local ok,err=b:recover();rejected(ok,err,journal);assert(b.blocked) end)
 assert(bytes(journal)==data and bytes(p)==current and bytes(p..'.old')==old)
 assert(not F.mode(b.path..'.reading.session') and not F.mode(b.path..'.reading'))
end)
print('SIDECAR READS: '..passed..' passed, '..failed..' failed')
assert(failed==0,'sidecar read regressions failed')
