-- Save read failures must never be mistaken for a new game or a safe rollback.
local E=dofile(BASE..'/engine.lua')
local S=dofile(BASE..'/storage.lua')
local F=dofile(BASE..'/filesystem.lua')
local B=dofile(BASE..'/backups.lua')
local R=dofile(BASE..'/reading.lua')
local passed,failed,serial=0,0,0
local function test(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name)
 else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
end
local function path()
 serial=serial+1;return TESTDIR..'/storage-'..serial..'.dat'
end
local function write(p,data)
 local f=assert(io.open(p,'wb'));assert(f:write(data));assert(f:close())
end
local function bytes(p)
 local f=io.open(p,'rb');if not f then return end
 local data=f:read('*a');f:close();return data
end
local function state(xp)
 local s=E.new(1800000000);E.act(s,'choose',4,1800000000);s.xp=xp or 37;return s
end
local function fixture()
 local p=path();local s=state();assert(S.save(p,s,E));s.xp=91;assert(S.save(p,s,E))
 return p,s
end
local function unreadable(p,reason,fn)
 local open=io.open
 io.open=function(name,mode)
  if name==p and mode=='rb' then return nil,reason,13 end
  return open(name,mode)
 end
 local ok,err=pcall(fn);io.open=open;assert(ok,err)
end
local function rejected(p,detail,fs)
 local session,err=S.open(p,{},E,fs or F)
 if session then session.close() end
 assert(not session,'opened an unreadable save')
 assert(err and err:find(p,1,true) and err:find(detail,1,true),tostring(err))
 assert(not F.mode(p..'.session'),'session lock leaked')
end
test('Kobo uses the settings path and does not create a Kindle save folder',function()
 local p=path();local calls=0
 local fs={mode=function() return nil end,mkdir=function() calls=calls+1;return true end}
 assert(S.location(p,fs)==p and calls==0)
 fs.mode=function(p) return p=='/mnt/us' and 'directory' or nil end
 assert(S.location(p,fs)=='/mnt/us/pokepal/pokepal.dat' and calls==1)
end)
test('genuinely missing saves allow a new session without writing game files',function()
 local p=path();local session=assert(S.open(p,{},E,F))
 assert(not session.state and not session.notice);session.close()
 assert(not F.mode(p) and not F.mode(p..'.old') and not F.mode(p..'.tmp'))
end)
test('empty saves are rejected as data rather than treated as absent',function()
 local p=path();write(p,'');write(p..'.old','')
 local s,err=S.load(p,E);assert(not s and err,'empty files were treated as absent')
 local session=S.open(p,{},E,F);if session then session.close() end;assert(not session)
 assert(bytes(p)=='' and bytes(p..'.old')=='' and not F.mode(p..'.session'))
end)
test('a directory at the save path reports its read error and stays untouched',function()
 local p=path();assert(F.mkdir(p));write(p..'/keep','keep');write(p..'.old',S.encode(state()))
 rejected(p,'read')
 assert(F.mode(p)=='directory' and bytes(p..'/keep')=='keep')
 assert(bytes(p..'.old')==S.encode(state()) and not F.mode(p..'.tmp'))
end)
test('permission failures do not silently load an older snapshot',function()
 local p=fixture();local current,old=bytes(p),bytes(p..'.old')
 unreadable(p,'Permission denied',function() rejected(p,'Permission denied') end)
 assert(bytes(p)==current and bytes(p..'.old')==old)
end)
test('a failed stat cannot turn a file-open error into a new game',function()
 local p=path();write(p,S.encode(state()))
 local fs={lock=F.lock,mode=function() return nil end}
 unreadable(p,'Permission denied',function() rejected(p,'Permission denied',fs) end)
 assert(bytes(p)==S.encode(state()) and not F.mode(p..'.tmp'))
end)
test('unknown open failures without an errno are preserved',function()
 local p=path();local open=io.open
 io.open=function(name,mode) if name==p and mode=='rb' then return nil end;return open(name,mode) end
 local ok,err=pcall(function() rejected(p,'read') end);io.open=open;assert(ok,err)
end)
test('read and close errors are reported and the opened handle is closed',function()
 for _,failure in ipairs({'read','close'}) do
  local p=fixture();local current,old=bytes(p),bytes(p..'.old');local closed=false;local open=io.open
  io.open=function(name,mode)
   if name==p and mode=='rb' then return {
    read=function() if failure=='read' then return nil,'Input/output error',5 end;return current end,
    close=function() closed=true;if failure=='close' then return nil,'Input/output error',5 end;return true end,
   } end
   return open(name,mode)
  end
  local ok,err=pcall(function() rejected(p,'Input/output error') end);io.open=open;assert(ok,err)
  assert(closed and bytes(p)==current and bytes(p..'.old')==old)
 end
end)
test('readable bad or empty primary still recovers a valid old snapshot without writes',function()
 for _,data in ipairs({'broken',''}) do
  local p=path();local old=S.encode(state());write(p,data);write(p..'.old',old)
  local session=assert(S.open(p,{},E,F))
  assert(S.encode(session.state)==old and session.notice:find('previous saved snapshot',1,true));session.close()
  assert(bytes(p)==data and bytes(p..'.old')==old and not F.mode(p..'.tmp'))
  assert(S.save(p,state(),E) and bytes(p..'.old')==old)
 end
end)
test('an absent primary can recover the old snapshot',function()
 local p=path();write(p..'.old',S.encode(state()))
 local session=assert(S.open(p,{},E,F));assert(session.state.xp==37);session.close()
 assert(not F.mode(p) and bytes(p..'.old')==S.encode(state()))
end)
test('fallback read errors block loading when the primary cannot be decoded',function()
 local p=path();write(p,'broken');write(p..'.old',S.encode(state()))
 unreadable(p..'.old','Permission denied',function() rejected(p,'Permission denied') end)
 assert(bytes(p)=='broken' and bytes(p..'.old')==S.encode(state()))
end)
test('a valid primary can be inspected when the fallback cannot be read',function()
 local p=fixture()
 unreadable(p..'.old','Permission denied',function()
  local s,err=S.load(p,E);assert(s and s.xp==91 and not err)
 end)
end)
test('save refuses to overwrite a primary or snapshot it cannot read',function()
 for _,suffix in ipairs({'','.old'}) do
  local p,s=fixture();write(p..'.tmp','keep staged bytes')
  local current,old=bytes(p),bytes(p..'.old');s.xp=120
  unreadable(p..suffix,'Permission denied',function()
   local ok,err=S.save(p,s,E)
   assert(not ok and err:find('Permission denied',1,true),'save ignored a read failure')
  end)
  assert(bytes(p)==current and bytes(p..'.old')==old and bytes(p..'.tmp')=='keep staged bytes')
 end
end)
test('cache does not hide an I/O failure or retain it after access returns',function()
 local p=path();local cache={};assert(not S.load(p,E,cache))
 unreadable(p,'Permission denied',function()
  local s,err=S.load(p,E,cache);assert(not s and err and err:find('Permission denied',1,true))
 end)
 local s,err=S.load(p,E,cache);assert(not s and not err)
 write(p,S.encode(state()));assert(S.load(p,E,cache).xp==37)
 unreadable(p,'Permission denied',function() assert(not S.load(p,E,cache)) end)
 assert(S.load(p,E,cache).xp==37)
end)
test('inaccessible legacy saves prevent a fresh game',function()
 local p,legacy=path(),path();write(legacy,S.encode(state()))
 unreadable(legacy,'Permission denied',function()
  local session,err=S.open(p,{legacy},E,{lock=F.lock,mode=function() return nil end})
  if session then session.close() end
  assert(not session and err and not F.mode(p..'.session'))
 end)
 assert(not F.mode(p) and bytes(legacy)==S.encode(state()))
end)
test('backup candidates can be inspected with broken game files without restoring',function()
 local p=path();local b=B.new(p,E,R,F);local s=state();R.init(s)
 local backup=assert(b:encode(s,100,1800000000));write(p,'');write(p..'.old','')
 for _,slot in ipairs({'backup','before-restore','before-story'}) do
  write(p..'.'..slot,'broken');write(p..'.'..slot..'.old',backup)
  local candidate=assert(b:preview(slot));assert(candidate.previous and candidate.state.xp==37 and candidate.ko==100)
  assert(bytes(p..'.'..slot)=='broken' and bytes(p..'.'..slot..'.old')==backup)
 end
 assert(bytes(p)=='' and bytes(p..'.old')=='' and not F.mode(p..'.restore'))
end)
test('temporary files are preserved and are not automatically promoted',function()
 local p=path();write(p,'broken');write(p..'.old','broken');local data=S.encode(state());write(p..'.tmp',data)
 local session,err=S.open(p,{},E,F);if session then session.close() end
 assert(not session and err and bytes(p)=='broken' and bytes(p..'.old')=='broken' and bytes(p..'.tmp')==data)
end)
print('STORAGE: '..passed..' passed, '..failed..' failed')
assert(failed==0,'Storage regressions failed')
