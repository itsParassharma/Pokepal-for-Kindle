-- ReaderUI supplies `view`, `document` and `dialog` to every plugin instance.
-- FileManager supplies only `ui`; both tear plugins down with CloseWidget.
-- See frontend/apps/reader/readerui.lua and frontend/ui/uimanager.lua in KOReader.
local P=dofile(BASE..'/main.lua')
local original_time=os.time
local now=1800000000
os.time=function(arg) if arg then return original_time(arg) end;return now end
local original_screensaver=package.loaded['ui/screensaver']
local active_ui
local screensaver={calls=0}
local function setup(self)
 self.calls=self.calls+1;self.ui=active_ui;self.screensaver_type='disable'
end
screensaver.setup=setup
package.loaded['ui/screensaver']=screensaver
local instances={}
local function plugin(name,book)
 local ui={menu={registerToMainMenu=function() end}}
 local view=book and {resume_calls=0,onResume=function(self) self.resume_calls=self.resume_calls+1 end} or nil
 ui.view=view
 local reader=P:new{path=BASE,ui=ui,view=view,document=book and {} or nil,dialog=ui}
 reader.savepath=TESTDIR..'/lifecycle-'..name..'.dat'
 reader.counterpath=reader.savepath..'.reading';reader.backups.path=reader.savepath
 local s=reader.engine.new(now);reader.engine.act(s,'choose',4,now);s.animation='off'
 assert(reader.storage.save(reader.savepath,s,reader.engine))
 reader.state=s
 instances[#instances+1]=reader;active_ui=ui
 return reader,view
end
local passed,failed=0,0
local function check(name,fn)
 local ffiUtil=require('ffi/util');local syncfile,syncdir=ffiUtil.fsyncOpenedFile,ffiUtil.fsyncDirectory
 local device=require('device');local isKindle=device.isKindle
 local ok,err=pcall(fn)
 device.isKindle=isKindle
 ffiUtil.fsyncOpenedFile,ffiUtil.fsyncDirectory=syncfile,syncdir
 if ok then passed=passed+1;print('PASS '..name)
 else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
 for _,reader in ipairs(instances) do
  if reader.onCloseWidget then pcall(reader.onCloseWidget,reader) else pcall(reader.onClose,reader) end
 end
 instances={};screensaver.setup=setup;U.queue={};U.dirty={}
end

check('other KOReader hosts collect rewards without scanning Kindle files',function()
 require('device').isKindle=function() return false end
 local reader=plugin('non-kindle',true)
 assert(#reader.reading_status==1 and reader.reading_status[1]:match('KOReader:'))
 reader.reading.scan=function() error('native Kindle scan on another host') end
 reader.reading.scanAsync=reader.reading.scan
 local r=reader.reading.init(reader.state)
 r.kindle_at=now-100;r.kindle["0123456789abcdef"]=120;r.ko_ready=true
 assert(reader.storage.save(reader.savepath,reader.state,reader.engine))
 assert(reader.reading.saveCounter(reader.counterpath,900))
 reader:openPet();assert(reader.reading_busy)
 reader.scan_step()
 r=reader.state.reading
 assert(not reader.reading_busy and r.seconds==900 and r.ko==900)
 assert(r.kindle_at==now-100 and r.kindle["0123456789abcdef"]==120,'native baseline changed')
 assert(#reader.reading_status==1 and reader.reading_status[1]=='KOReader: automatic tracking on')
 reader:syncReading();assert(r.seconds==900,'reading rewarded twice')
 assert(reader.reading.saveCounter(reader.counterpath,1800))
 reader:syncReading();assert(r.seconds==1800 and r.ko==1800)
 assert(r.kindle_at==now-100 and r.kindle["0123456789abcdef"]==120)
 reader.reading.counter=function() return nil,'unreadable counter' end
 reader:syncReading()
 assert(#reader.reading_status==1 and reader.reading_status[1]=='KOReader: could not save reading time')
end)

check('Kindle still scans native reading records through both paths',function()
 local reader=plugin('kindle-scan',false)
 local async,sync=0,0
 reader.reading.scanAsync=function(path)
  assert(path=='/mnt/us/documents');async=async+1
  return function() return true,{},'Kindle: test records' end
 end
 reader.reading.scan=function(path)
  assert(path=='/mnt/us/documents');sync=sync+1
  return {},'Kindle: test records'
 end
 reader:openPet();reader.scan_step();reader:syncReading()
 assert(async==1 and sync==1 and #reader.reading_status==2)
 assert(reader.reading_status[1]=='Kindle: test records')
 assert(reader.reading_status[2]=='KOReader: automatic tracking on')
end)

check('a book view does not suppress KOReader page timing',function()
 local reader,book=plugin('timing',true)
 reader:onPageUpdate(1);reader:onReaderReady()
 for page=2,16 do now=now+60;reader:onPageUpdate(page) end
 assert(reader.reading.counter(reader.counterpath)==900,'15 minutes of reading were not recorded')
 assert(reader.view==book,'KOReader owns the book view')
end)

check('scrolling counts page changes and excludes pauses and sleep',function()
 local reader=plugin('scroll',true)
 reader:onPosUpdate(0,1);reader:onReaderReady()
 now=now+30;reader:onPosUpdate(200,1)
 now=now+30;reader:onPosUpdate(800,2);reader:onPageUpdate(2)
 assert(reader.reading.counter(reader.counterpath)==60,'scrolling within a page reset the timer')
 now=now+30;reader:onReadingPaused()
 now=now+600;reader:onPosUpdate(1600,3);reader:onReadingResumed()
 now=now+30;reader:onSuspend()
 now=now+7200;reader:onPosUpdate(2400,4);reader:onResume()
 now=now+60;reader:onPosUpdate(3200,5)
 assert(reader.reading.counter(reader.counterpath)==180,'paused or sleeping time was counted')
end)

check('repeated resume notifications keep elapsed reading time',function()
 local reader=plugin('repeat-resume',true)
 reader:onPageUpdate(1);reader:onReaderReady()
 now=now+20;reader:onReadingResumed()
 now=now+40;reader:onPageUpdate(2)
 assert(reader.reading.counter(reader.counterpath)==60,'a resume event discarded reading time')
 reader:onSuspend();now=now+7200;reader:onResume()
 now=now+20;reader:onReadingResumed()
 now=now+40;reader:onPageUpdate(3)
 assert(reader.reading.counter(reader.counterpath)==120)
end)

check('disabled sleep features do not open the game save during suspend',function()
 local reader=plugin('disabled-sleep',false)
 local loads,opens,saves=0,0,0
 local load,open,save=reader.storage.load,reader.storage.open,reader.storage.save
 reader.storage.load=function(...) loads=loads+1;return load(...) end
 reader.storage.open=function(...) opens=opens+1;return open(...) end
 reader.storage.save=function(...) saves=saves+1;return save(...) end
 screensaver:setup();reader:onSuspend()
 assert(loads==0 and opens==0 and saves==0,'disabled sleep features still accessed the game save')
 assert(not reader.fs.mode(reader.counterpath),'sleeping on the bookshelf wrote an empty reading counter')
 now=now+7200;reader:onResume()
 assert(loads==1 and opens==0 and saves==0,'waking should only refresh the cached save')
 assert(#U.queue==0)
end)

check('bookshelf initialization loads saved sleep preferences before the first sleep',function()
 local data=require('datastorage');local getSettingsDir=data.getSettingsDir
 local shelf=plugin('startup-sleep',false)
 local dir=TESTDIR..'/startup-sleep';assert(shelf.fs.mkdir(dir))
 shelf.engine.act(shelf.state,'preference','auto_rest',now)
 assert(shelf.storage.save(dir..'/pokepal.dat',shelf.state,shelf.engine))
 data.getSettingsDir=function() return dir end
 local ok,reader=pcall(function() return P:new{path=BASE,ui={menu={registerToMainMenu=function() end}}} end)
 data.getSettingsDir=getSettingsDir;assert(ok,reader)
 instances[#instances+1]=reader
 assert(reader.state and reader.engine.companion.option(reader.state,'auto_rest'))
 reader:onSuspend()
 assert(reader.storage.load(reader.savepath,reader.engine).companion.sleep)
 now=now+600;reader:onResume()
 assert(not reader.storage.load(reader.savepath,reader.engine).resting)
end)

check('the open game handles each power event once in either broadcast order',function()
 for _,order in ipairs({'game-first','plugin-first'}) do
  local reader=plugin('power-order-'..order,true)
  reader:openPet();reader:syncReading()
  reader.engine.act(reader.state,'preference','auto_rest',now)
  local game=reader.pet_view;local save=reader.save;local saves=0
  reader.save=function(self) saves=saves+1;return save(self) end
  for cycle=1,3 do
   if order=='game-first' then game:onSuspend();reader:onSuspend()
   else reader:onSuspend();game:onSuspend() end
   assert(saves==cycle*2-1 and game.suspended and reader.state.companion.sleep)
   now=now+600
   if order=='game-first' then game:onResume();reader:onResume()
   else reader:onResume();game:onResume() end
   assert(saves==cycle*2 and not game.suspended and not reader.state.companion.sleep)
   reader:cancelReadingScan()
  end
 end
end)

check('waking refreshes progress and sleep preferences changed in KUAL',function()
 local reader=plugin('shared-sleep',false)
 reader:onSuspend()
 local changed=assert(reader.storage.load(reader.savepath,reader.engine))
 changed.xp=42;reader.engine.act(changed,'preference','auto_rest',now)
 reader.engine.companion.suspend(changed,reader.engine,now)
 assert(reader.storage.save(reader.savepath,changed,reader.engine))
 now=now+600;reader:onResume()
 assert(reader.state.xp==42 and not reader.state.resting and not reader.state.companion.sleep)
 assert(reader.engine.companion.option(reader.state,'auto_rest'))
 reader:onSuspend()
 assert(reader.storage.load(reader.savepath,reader.engine).companion.sleep)
 now=now+600;reader:onResume()
 local saved=assert(reader.storage.load(reader.savepath,reader.engine))
 assert(saved.xp==42 and not saved.resting and not saved.companion.sleep)
end)

check('failed reading sync stays pending until a retry succeeds',function()
 local reader=plugin('sync-retry',true)
 local ffiUtil=require('ffi/util');local syncs,writes=0,0
 ffiUtil.fsyncOpenedFile=function() writes=writes+1;return true end
 ffiUtil.fsyncDirectory=function()
  syncs=syncs+1
  if syncs==1 then return false,'directory sync failed' end
  if syncs==2 then error('directory sync failed again') end
  return true
 end
 reader.clock.pending=60;reader.clock.days={['2027-01-15']=60}
 for attempt=1,3 do
  reader:flushReading()
  assert(syncs==attempt and writes==attempt,'the failed sync was not retried')
  assert(reader.clock.pending==0 and next(reader.clock.days)==nil)
  local total,err,primary,days=reader.reading.counter(reader.counterpath)
  assert(total==60 and primary and days['2027-01-15']==60,'a retry counted reading twice')
  if attempt<3 then assert(reader.reading_error,'the error was cleared before recovery')
  else assert(not reader.reading_error) end
 end
 reader:flushReading();assert(syncs==3 and writes==3,'an unchanged, synced counter was rewritten')
end)

check('reading added after a failed sync is saved once',function()
 local reader=plugin('sync-more-reading',true)
 local ffiUtil=require('ffi/util');local syncs=0
 ffiUtil.fsyncDirectory=function()
  syncs=syncs+1;if syncs==1 then return false,'directory sync failed' end;return true
 end
 reader.clock.pending=60;reader.clock.days={['2027-01-15']=60};reader:flushReading()
 reader.clock.pending=30;reader.clock.days={['2027-01-16']=30};reader:flushReading()
 local total,err,primary,days=reader.reading.counter(reader.counterpath)
 assert(total==90 and primary and days['2027-01-15']==60 and days['2027-01-16']==30)
 assert(not reader.reading_error and reader.clock.pending==0)
 reader:flushReading();assert(syncs==2)
end)

check('sleep and wake leave the book view alone and exclude sleeping time',function()
 local reader,book=plugin('sleep',true)
 reader:onPageUpdate(1);reader:onReaderReady();now=now+60
 reader:onSuspend();assert(reader.suspended and not reader.clock.since)
 now=now+7200;reader:onResume()
 assert(not reader.suspended and reader.clock.since==now)
 assert(reader.reading.counter(reader.counterpath)==60)
 assert(reader.view==book and not reader.pet_view and #U.queue==0)
end)

check('the game opens from an open book and returns to reading',function()
 local reader,book=plugin('menu',true)
 reader:onPageUpdate(1);reader:onReaderReady()
 reader:openPet();reader:syncReading()
 assert(reader.pet_view and reader.pet_view~=book,'the game window did not open')
 assert(reader.view==book and not reader.clock.since)
 now=now+600;reader:onPageUpdate(2);reader.pet_view:leave()
 assert(not reader.pet_view and reader.view==book and reader.clock.since==now)
 now=now+60;reader:onPageUpdate(3)
 assert(reader.reading.counter(reader.counterpath)==60,'time in the game was counted as reading')
end)

check('waking a book never schedules a game redraw against its reader view',function()
 local reader,book=plugin('wake-scan',true)
 reader:onReaderReady();reader.suspended=true
 reader.timer.pause(reader.clock,now)
 -- ReaderView receives its own Resume event before the plugin does.
 book:onResume();reader:onResume();U:drain()
 assert(book.resume_calls==1,'PokePal resumed the reader view a second time')
 assert(not reader.pet_view and not reader.reading_busy and not reader.scan_step)
end)

for _,mode in ipairs({'pages','scroll'}) do
check('bookshelf trips collect '..mode..' across book changes exactly once',function()
 local shelf=plugin('trip-'..mode,false)
 shelf:openPet();shelf:syncReading()
 shelf.engine.act(shelf.state,'readingtrip',2,now)
 local xp,berries=shelf.state.xp,shelf.state.berries
 local remaining=shelf.engine.tripLeft(shelf.state,now)
 assert(shelf.state.trail~=nil)
 shelf.pet_view:leave();shelf:onCloseWidget()
 for i=1,2 do
  local reader=plugin('trip-reader-'..i,true)
  reader.savepath=shelf.savepath;reader.counterpath=shelf.counterpath;reader.backups.path=shelf.savepath
  local function turn(page)
   if mode=='scroll' then reader:onPosUpdate(page*800,page) else reader:onPageUpdate(page) end
  end
  turn(1);reader:onReaderReady()
  for page=2,16 do now=now+30;turn(page) end
  reader:onCloseDocument();reader:onCloseWidget()
 end
 local returned=plugin('trip-returned',false)
 returned.savepath=shelf.savepath;returned.counterpath=shelf.counterpath;returned.backups.path=shelf.savepath
 returned:openPet();returned:syncReading()
 assert(returned.state.reading.seconds==900)
 assert(returned.state.xp==xp+3 and returned.state.berries==berries+1)
 assert(returned.engine.tripLeft(returned.state,now)==remaining-900)
 returned.pet_view:leave();returned:openPet();returned:syncReading()
 assert(returned.state.reading.seconds==900 and returned.state.xp==xp+3)
 returned.pet_view:leave()
end)
end

check('sleep setup replaces the image before display and leaves fallback screens alone',function()
 for _,case in ipairs({'partner','disabled','error','poweroff','reboot','other-ui'}) do
  local freed,calls=0,0
  local original={free=function() freed=freed+1 end}
  local partner={free=function() end}
  screensaver.setup=function(screen,event)
   calls=calls+1;screen.ui=case=='other-ui' and {} or active_ui
   screen.image=original;screen.image_file='chosen.png';screen.screensaver_type='cover'
   screen.show_message=true;screen.overlay_message=event;screen.screensaver_background='black'
   return 'upstream-result'
  end
  local reader=plugin('screen-handoff-'..case,false)
  local disabled=reader.sleepImage
  reader.sleepImage=function(self)
   if case=='disabled' then return disabled(self) end
   if case=='error' then error('cannot render partner') end
   return partner
  end
  local saved=reader.storage.encode(reader.state)
  local shown,dirty=U.show_count,#U.dirty
  local event=(case=='poweroff' or case=='reboot') and case or nil
  assert(screensaver:setup(event)=='upstream-result' and calls==1)
  assert(U.show_count==shown and #U.dirty==dirty,'setup painted an intermediate screen')
  assert(reader.storage.encode(reader.state)==saved,'screen setup changed game progress')
  if case=='partner' then
   assert(screensaver.image==partner and freed==1 and screensaver.image_file==nil)
   assert(not screensaver.show_message and screensaver.overlay_message==nil)
  else
   assert(screensaver.image==original and freed==0 and screensaver.image_file=='chosen.png')
   assert(screensaver.show_message and screensaver.overlay_message==event)
  end
  reader:onCloseWidget()
 end
end)

check('book and bookshelf teardown removes the sleep hook every time',function()
 for i=1,20 do
  local reader=plugin('teardown-'..i,i%2==0)
  local calls=screensaver.calls;screensaver:setup()
  assert(screensaver.calls==calls+1)
  assert(reader:onCloseWidget()==nil,'cleanup must not consume CloseWidget')
  assert(screensaver.setup==setup,'a closed plugin left its sleep hook installed')
 end
end)

check('closing the reader also closes its game and releases the save',function()
 local reader,book=plugin('close',true)
 reader:onReaderReady();reader:openPet();reader:syncReading()
 local game=assert(reader.pet_view)
 reader:onCloseWidget()
 assert(game.closed and not reader.pet_view and reader.view==book)
 assert(not reader.session and not reader.clock.since and not reader.document_open)
 local session=assert(reader.storage.open(reader.savepath,{},reader.engine,reader.fs))
 session.close();assert(#U.queue==0 and screensaver.setup==setup)
end)

os.time=original_time;package.loaded['ui/screensaver']=original_screensaver
assert(failed==0,tostring(failed)..' reader lifecycle regressions failed')
print('READER LIFECYCLE: '..passed..' checks passed')
