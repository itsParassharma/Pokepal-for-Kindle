local E=dofile(BASE..'/engine.lua')
local S=dofile(BASE..'/storage.lua')
local R=dofile(BASE..'/reading.lua')
local T=dofile(BASE..'/reading_timer.lua')
local C=E.companion
local now=1800000000
local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS '..name) end
local function pet() local s=E.new(now);E.act(s,'choose',4,now);R.init(s);return s end
test('old saves load without enabling any preference',function()
 local old=E.new(now);old.species=4;old.seen['4']=true
 local s=assert(S.decode(S.encode(old),E));assert(s.version==1 and not s.companion)
 for _,key in ipairs(C.preferences) do assert(not C.option(s,key)) end
end)
test('automatic rest survives reload and duplicate sleep and wake events',function()
 local s=pet();s.energy=10;E.act(s,'preference','auto_rest',now)
 C.suspend(s,E,now);C.suspend(s,E,now+60)
 s=assert(S.decode(S.encode(s),E));assert(s.resting and s.companion.sleep.at==now)
 C.resume(s,E,now+3600);assert(s.energy==22 and not s.resting and not s.companion.sleep)
 C.resume(s,E,now+3600);assert(s.energy==22)
 E.act(s,'rest',nil,now+3600);C.suspend(s,E,now+3600);C.resume(s,E,now+7200);assert(s.resting)
end)
test('automatic rest leaves trips alone and handles a backwards clock',function()
 local s=pet();E.act(s,'preference','auto_rest',now);E.act(s,'trip',1,now)
 C.suspend(s,E,now);assert(not s.resting and not s.companion.sleep)
 s.trip=0;s.due=0;s.finds=nil;s.companion.journey=nil
 C.suspend(s,E,now);local energy=s.energy;C.resume(s,E,now-100);assert(s.energy==energy and s.last==now and not s.resting)
end)
test('new saves round-trip optional data and reject malformed extras',function()
 local s=pet();C.get(s).favourites['4']=true;E.act(s,'memory','A book = a memory, too',now)
 C.history(s,{['2027-01-15']=75},30,now)
 local encoded=S.encode(s);local copy=assert(S.decode(encoded,E));assert(S.encode(copy)==encoded)
 assert(not S.decode(encoded..'companion=74303a\n',E))
 for _,bad in ipairs({'00','f','73393939393939393a','74313a73313a616e313a00'}) do assert(not C.decode(bad)) end
 copy.companion.prefs.unknown=true;assert(not E.valid(copy))
end)
test('Unicode names count characters and delete complete codepoints',function()
 local s=pet();E.act(s,'nickname','Évoli',now);assert(E.displayName(s)=='Évoli')
 assert(C.text.pop('Évoli')=='Évol' and C.text.pop('é')=='')
 E.act(s,'nickname',string.rep('é',12),now);assert(E.displayName(s)==string.rep('é',12))
 E.act(s,'nickname',string.rep('é',13),now);assert(E.displayName(s)==string.rep('é',12))
 for _,bad in ipairs({string.char(192,175),string.char(237,160,128),'bad\nname',string.char(226,128,174)..'name'}) do assert(not E.validNickname(bad)) end
 assert(S.decode(S.encode(s),E))
end)
test('favourite berries are stable through evolution and only pay on feeding',function()
 local s=pet();local trait,berry=C.profile(s,4,E)
 assert(select(2,C.profile(s,5,E))==berry)
 s.food=60;E.act(s,'feed',berry,now);assert(s.bond==3 and s.companion.tastes['4'])
 local count=s.care;s.food=100;E.act(s,'feed',berry,now);assert(s.care==count)
 assert(s.badges['Favourite snack'])
end)
test('journal filters use each partners own progress and stable recent order',function()
 local s=pet();s.seen['25']=true;s.seen['7']=true;s.partners={['7']={xp=400,bond=30}}
 C.mark(s,25,now+1);E.act(s,'favourite',25,now)
 assert(C.journal(s,E,'','favourites')[1]==25)
 assert(C.journal(s,E,'','recent')[1]==25)
 assert(C.journal(s,E,'','Water')[1]==7)
 assert(C.journal(s,E,'','ready')[1]==7)
 E.act(s,'nickname','Ember',now);assert(C.journal(s,E,'emb','met')[1]==4)
end)
test('trail choices survive reload and cannot grant rewards twice',function()
 local s=pet();E.act(s,'trip',1,now);local event=s.companion.journey.event
 E.act(s,'trailchoice',1,now);assert(not s.companion.journey.choice)
 s=assert(S.decode(S.encode(s),E));assert(s.companion.journey.event==event)
 E.act(s,'trailchoice',1,now+1800);E.act(s,'trailchoice',2,now+1800);assert(s.companion.journey.choice==1)
 E.act(s,'collect',nil,now+1800);local save=S.encode(s);E.act(s,'collect',nil,now+1800)
 assert(S.encode(s)==save and s.companion.routes['1'] and not s.companion.journey)
end)
test('book memories cannot duplicate entries or farm rewards',function()
 local s=pet();local xp,berries=s.xp,s.berries
 E.act(s,'memory','The Hobbit',now);E.act(s,'memory','The Hobbit',now)
 assert(#s.companion.memories==1 and s.xp==xp and s.berries==berries and s.badges['Reading together'])
 assert(S.decode(S.encode(s),E).companion.memories[1].title=='The Hobbit')
end)
test('dated reading counters preserve totals and do not credit dates twice',function()
 local s=pet();local path=TESTDIR..'/dated.reading';local days={['2027-01-14']=100}
 assert(R.saveCounter(path,100,nil,nil,days));local total,err,primary,loaded=R.counter(path)
 assert(total==100 and primary and loaded['2027-01-14']==100)
 R.collect(s,E,{},100,now,loaded);assert(not s.companion.days['2027-01-14'])
 days['2027-01-14']=160;days['2027-01-15']=60
 R.collect(s,E,{},220,now+120,days)
 assert(s.companion.days['2027-01-14'].ko==60 and s.companion.days['2027-01-15'].ko==60)
 R.collect(s,E,{},220,now+120,days);assert(s.companion.days['2027-01-15'].ko==60)
 s.reading.enabled=false;days['2027-01-15']=120;R.collect(s,E,{},280,now+180,days)
 s.reading.enabled=true;R.collect(s,E,{},280,now+180,days);assert(s.companion.days['2027-01-15'].ko==60)
 assert(not R.saveCounter(path,1,nil,nil,days))
end)
test('page timers split the bounded interval at midnight',function()
 local midnight=os.time{year=2027,month=1,day=15,hour=0,min=0,sec=0}
 local t=T.new();T.resume(t,1,midnight-60);T.pause(t,midnight+60)
 assert(t.pending==120 and t.days['2027-01-14']==60 and t.days['2027-01-15']==60)
 T.pause(t,midnight+120);assert(t.pending==120)
end)
test('unchanged saves skip writes but failed directory sync is retried',function()
 local s=pet();local path=TESTDIR..'/no-op.dat';local writes=0
 local sync=function() writes=writes+1;return true end
 assert(S.save(path,s,E,sync));assert(S.save(path,s,E,sync));assert(writes==1)
 s.berries=s.berries+1;assert(not S.save(path,s,E,sync,function() return false,'test' end))
 assert(S.save(path,s,E,sync,function() return true end));assert(writes==3)
 local loaded=assert(S.load(path,E));assert(loaded.berries==s.berries)
end)
test('bounded scan yields before completion and reports failures without partial credit',function()
 local names={};for i=1,72 do names[i]='book'..i end
 local fs={list=function() return names end,mode=function() return 'file' end}
 local step=R.scanAsync('/test',fs);local done=step();assert(not done)
 local ticks=1;repeat ticks=ticks+1;done=step() until done;assert(ticks==4)
 local fail=R.scanAsync('/test',{list=function() return nil end});local finished,counters=fail();assert(finished and not counters)
end)
test('scan caches survive restart, expire and can be bypassed',function()
 local path=TESTDIR..'/scan-cache';local file=TESTDIR..'/book.sdr/time.azw3f'
 local F=dofile(BASE..'/filesystem.lua');assert(F.mkdir(TESTDIR..'/book.sdr'))
 local f=assert(io.open(file,'wb'));f:write('fixture');f:close()
 local modified=os.time()-10
 local fs={list=function(p) return p==TESTDIR and {'book.sdr'} or {'time.azw3f'} end,
  mode=function(p) return p:match('sdr$') and 'directory' or 'file' end,
  mtime=function() return modified end,size=function() return 7 end}
 local parsed=0;local parser=R.kindleTime
 R.kindleTime=function() parsed=parsed+1;return 120 end
 R.loadCache(path);assert(R.scan(TESTDIR,fs));assert(parsed==1);R.saveCache()
 R.loadCache(path);assert(R.scan(TESTDIR,fs));assert(parsed==1)
 R.clearCache();assert(R.scan(TESTDIR,fs));assert(parsed==2)
 local clock=os.time;os.time=function(...) if select('#',...)>0 then return clock(...) end;return clock()+3601 end
 assert(R.scan(TESTDIR,fs));assert(parsed==3);os.time=clock;R.kindleTime=parser
end)
test('dated counters stay paired with backups through restore',function()
 local F=dofile(BASE..'/filesystem.lua');local B=dofile(BASE..'/backups.lua')
 local path=TESTDIR..'/dated-backup.dat';local s=pet();local days={['2027-01-14']=100}
 assert(R.saveCounter(path..'.reading',100,nil,nil,days))
 local b=B.new(path,E,R,F);assert(b:create(s));local preview=assert(b:preview('backup'))
 assert(preview.days['2027-01-14']==100)
 days['2027-01-15']=60;assert(R.saveCounter(path..'.reading',160,nil,nil,days))
 assert(b:restore(s,preview));local total,err,primary,restored=R.counter(path..'.reading')
 assert(total==100 and restored['2027-01-14']==100 and not restored['2027-01-15'])
 assert(b:preview('before-restore').days['2027-01-15']==60)
end)
test('asynchronous visits keep the original timed-trip recap and stop rewards',function()
 local s=pet();R.collect(s,E,{},0,now);E.act(s,'trip',1,now)
 local visit=R.visit(s);E.advance(s,now+1350)
 local _,recap=R.collect(s,E,{},900,now+1350,{},visit)
 assert(recap.trip_before==0 and recap.trip_after==1350 and #recap.events==3)
 assert(recap.berries==2 and recap.xp==6)
end)
print('IMPROVEMENTS: '..checks..' checks passed')
