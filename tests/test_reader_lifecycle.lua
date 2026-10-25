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
 instances[#instances+1]=reader;active_ui=ui
 return reader,view
end
local passed,failed=0,0
local function check(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name)
 else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
 for _,reader in ipairs(instances) do
  if reader.onCloseWidget then pcall(reader.onCloseWidget,reader) else pcall(reader.onClose,reader) end
 end
 instances={};screensaver.setup=setup;U.queue={}
end

check('a book view does not suppress KOReader page timing',function()
 local reader,book=plugin('timing',true)
 reader:onPageUpdate(1);reader:onReaderReady()
 for page=2,16 do now=now+60;reader:onPageUpdate(page) end
 assert(reader.reading.counter(reader.counterpath)==900,'15 minutes of reading were not recorded')
 assert(reader.view==book,'KOReader owns the book view')
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

check('bookshelf trips collect reading across book changes exactly once',function()
 local shelf=plugin('trip',false)
 shelf:openPet();shelf:syncReading()
 shelf.engine.act(shelf.state,'readingtrip',2,now)
 local xp,berries=shelf.state.xp,shelf.state.berries
 local remaining=shelf.engine.tripLeft(shelf.state,now)
 assert(shelf.state.trail~=nil)
 shelf.pet_view:leave();shelf:onCloseWidget()
 for i=1,2 do
  local reader=plugin('trip-reader-'..i,true)
  reader.savepath=shelf.savepath;reader.counterpath=shelf.counterpath;reader.backups.path=shelf.savepath
  reader:onPageUpdate(1);reader:onReaderReady()
  for page=2,16 do now=now+30;reader:onPageUpdate(page) end
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
