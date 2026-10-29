local E=dofile(BASE..'/engine.lua')
local S=dofile(BASE..'/storage.lua')
local R=dofile(BASE..'/reading.lua')
local F=dofile(BASE..'/filesystem.lua')
local B=dofile(BASE..'/backups.lua')
local now=1800000000
local passed=0;local serial=0
local function test(name,fn) fn();passed=passed+1;print('PASS '..name) end
local function bytes(path)
 local f=io.open(path,'rb');if not f then return end
 local data=f:read('*a');f:close();return data
end
local function write(path,data)
 local f=assert(io.open(path,'wb'));assert(f:write(data));assert(f:close())
end
local function fixture()
 serial=serial+1;local path=TESTDIR..'/backup-'..serial..'.dat'
 local s=E.new(now);E.act(s,'choose',4,now);R.init(s)
 s.reading.ko=100;s.reading.ko_ready=true
 assert(R.saveCounter(path..'.reading',100))
 local b=B.new(path,E,R,F);assert(b:create(s));return s,b,path
end
test('backup restores game and counter together and keeps the replaced game',function()
 local s,b,p=fixture();s.berries=80
 E.act(s,'egg',nil,now);E.act(s,'goal',3600,now);E.act(s,'decorate',2,now);E.act(s,'nickname','Ember',now)
 assert(b:create(s));local original=S.encode(s);local preview=assert(b:preview('backup'))
 s.xp=91;s.berries=50;assert(R.saveCounter(p..'.reading',200));assert(S.save(p,s,E))
 local current=S.encode(s);assert(b:restore(s,preview))
 assert(S.encode(s)==original and S.encode(assert(S.load(p,E)))==original and R.counter(p..'.reading')==100)
 local undo=assert(b:preview('before-restore'));assert(undo.ko==200 and S.encode(undo.state)==current)
 assert(b:restore(s,undo));assert(S.encode(s)==current and R.counter(p..'.reading')==200)
 assert(not F.mode(p..'.restore') and not b.blocked)
end)
test('preview is read only and a changed backup must be previewed again',function()
 local s,b,p=fixture();local game,counter=bytes(p),bytes(p..'.reading')
 local preview=assert(b:preview('backup'))
 assert(bytes(p)==game and bytes(p..'.reading')==counter and not F.mode(p..'.before-restore'))
 s.xp=8;assert(b:create(s));local ok,err=b:restore(s,preview)
 assert(not ok and err:find('changed') and s.xp==8 and not F.mode(p..'.restore'))
 assert(not b:preview('../other'))
end)
test('backup parsing rejects corruption and recovers the previous complete copy',function()
 local s,b,p=fixture();local data=bytes(p..'.backup')
 for _,bad in ipairs({data:sub(1,-2),data..'extra',data:gsub('POKEPAL_BACKUP_%d','POKEPAL_BACKUP_9'),
  data:gsub('\n100\n','\n1000000000001\n'),(data:gsub('species=4','species=999'))}) do assert(not b:decode(bad)) end
 s.xp=9;assert(b:create(s));write(p..'.backup','broken')
 local preview=assert(b:preview('backup'));assert(preview.previous and preview.state.xp==0)
 assert(b:restore(s,preview) and s.xp==0)
end)
test('failed counter or game promotion resumes before the next session can load',function()
 for _,suffix in ipairs({'.reading.tmp','.tmp'}) do
  local s,b,p=fixture();local preview=assert(b:preview('backup'))
  s.xp=99;assert(S.save(p,s,E));assert(R.saveCounter(p..'.reading',200))
  local rename=os.rename
  os.rename=function(a,c) if a==p..suffix then return nil,'simulated full disk' end;return rename(a,c) end
  local ok=b:restore(s,preview);assert(not ok and b.blocked and s.xp==99 and F.mode(p..'.restore'))
  local failed=S.open(p,{},E,F,function() return b:recover() end);assert(not failed and not F.mode(p..'.session'))
  os.rename=rename
  local session=assert(S.open(p,{},E,F,function() return b:recover() end))
  assert(session.state.xp==0 and R.counter(p..'.reading')==100 and not F.mode(p..'.restore'));session.close()
  assert(b:preview('before-restore').state.xp==99)
  local restored=bytes(p);assert(b:recover() and bytes(p)==restored)
 end
end)
test('failure to keep the current game prevents any restore writes',function()
 local s,b,p=fixture();local preview=assert(b:preview('backup'));s.xp=32
 assert(S.save(p,s,E));local game,counter=bytes(p),bytes(p..'.reading')
 local rename=os.rename
 os.rename=function(a,c) if a==p..'.before-restore.tmp' then return nil,'simulated full disk' end;return rename(a,c) end
 assert(not b:restore(s,preview));os.rename=rename
 assert(not b.blocked and not F.mode(p..'.restore') and bytes(p)==game and bytes(p..'.reading')==counter and s.xp==32)
end)
test('journal sync and removal failures keep recovery available',function()
 for _,failure in ipairs({'sync','remove'}) do
  local s,b,p=fixture();local preview=assert(b:preview('backup'));s.xp=42;assert(S.save(p,s,E))
  local remove=os.remove
  if failure=='sync' then b.syncdir=function(path) if path==p..'.restore' then return false,'sync failed' end;return true end
  else os.remove=function(path) if path==p..'.restore' then return nil,'remove failed' end;return remove(path) end end
  assert(not b:restore(s,preview) and b.blocked and F.mode(p..'.restore'))
  b.syncdir=nil;os.remove=remove
  assert(b:recover() and S.load(p,E).xp==0 and b:preview('before-restore').state.xp==42)
 end
end)
test('busy or unreadable counters cannot produce a mismatched backup',function()
 local s,b,p=fixture();local saved=bytes(p..'.backup');local preview=assert(b:preview('backup'))
 local unlock=assert(F.lock(p..'.reading.session'))
 assert(not b:create(s) and not b:restore(s,preview) and bytes(p..'.backup')==saved);unlock()
 write(p..'.reading','broken');write(p..'.reading.old','broken')
 assert(not b:create(s) and not b:restore(s,preview) and bytes(p..'.backup')==saved)
end)
test('malformed pending restore blocks loading without replacing either save',function()
 local s,b,p=fixture();write(p..'.restore','broken');local game,counter=bytes(p),bytes(p..'.reading')
 local session,err=S.open(p,{},E,F,function() return b:recover() end)
 assert(not session and err and bytes(p)==game and bytes(p..'.reading')==counter and not F.mode(p..'.session'))
end)
test('restored KOReader totals do not pay an already collected interval twice',function()
 local s,b,p=fixture();R.collect(s,E,{},1000,now);assert(R.saveCounter(p..'.reading',1000));assert(b:create(s))
 local preview=assert(b:preview('backup'));local xp=s.xp
 R.collect(s,E,{},1900,now+900);assert(R.saveCounter(p..'.reading',1900))
 assert(b:restore(s,preview));R.collect(s,E,{},R.counter(p..'.reading'),now+900)
 assert(s.xp==xp);assert(R.saveCounter(p..'.reading',1900));R.collect(s,E,{},1900,now+1800)
 assert(s.xp==xp+3)
end)
test('a backup restores a battle turn, map and reading counter together',function()
 local s,b,p=fixture();local W=E.world;W.enter(s)
 s.world.map='meadow';s.world.x=3;s.world.y=3
 assert(W.startBattle(s,1));assert(W.turn(s,E,1,now));assert(b:create(s))
 local original=S.encode(s);local preview=assert(b:preview('backup'))
 assert(W.turn(s,E,2,now));assert(R.saveCounter(p..'.reading',200));assert(S.save(p,s,E))
 local current=S.encode(s);assert(current~=original)
 assert(b:restore(s,preview));assert(S.encode(s)==original and s.world.battle.turn==2)
 assert(R.counter(p..'.reading')==100 and S.encode(assert(S.load(p,E)))==original)
 local undo=assert(b:preview('before-restore'));assert(S.encode(undo.state)==current)
 assert(b:restore(s,undo));assert(S.encode(s)==current and R.counter(p..'.reading')==200)
end)
test('a Tower backup restores the party, learned moves, benefits and turn together',function()
 local s,b,p=fixture();local W=E.world;local A=W.town;W.enter(s)
 for _,id in ipairs({1,7}) do s.seen[tostring(id)]=true;s.world.camp.box[tostring(id)]=true end;s.world.camp.badges=7
 s.world.map='centre';assert(A.party(s,E,2,7));assert(A.party(s,E,3,1))
 s.world.map='dojo';assert(A.learn(s,E,s.world.partner,3));assert(A.equip(s,s.world.partner,2,3))
 s.world.map='tower';assert(A.startTower(s,E));assert(b:create(s))
 local original=S.encode(s);local preview=assert(b:preview('backup'))
 assert(A.switch(s,E,7));assert(R.saveCounter(p..'.reading',300));assert(S.save(p,s,E))
 assert(b:restore(s,preview) and S.encode(s)==original and R.counter(p..'.reading')==100)
 assert(s.world.battle.turn==1 and s.world.camp.tower.floor==1 and #s.world.camp.party==3)
end)
print('BACKUPS: '..passed..' checks passed')
