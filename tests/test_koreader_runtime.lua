-- Run from an unpacked KOReader Linux release with an empty KO_HOME.
-- Uses its real reader, plugin loader, widgets, image buffers and file syncs.
-- Only elapsed reading/sleep time and the display hardware are simulated.
io.stdout:setvbuf('line')
require('setupkoenv')
local DataStorage=require('datastorage')
local dir=DataStorage:getDataDir()
assert(os.getenv('KO_HOME'),'Set KO_HOME to a new test directory')
local existing=io.open(DataStorage:getSettingsDir()..'/pokepal.dat','r')
if existing then existing:close();error('Use an empty KO_HOME; existing game left untouched') end
G_defaults=require('luadefaults'):open()
G_reader_settings=require('luasettings'):open(dir..'/settings.reader.lua')
G_reader_settings:saveSetting('screensaver_type','disable')
G_reader_settings:saveSetting('screensaver_show_message',false)
G_reader_settings:saveSetting('screensaver_delay','disable')
local Device=require('device')
require('document/canvascontext'):init(Device)
require('ui/bidi').setup()
local U=require('ui/uimanager')
local Event=require('ui/event')
local time=require('ui/time')
local Screensaver=require('ui/screensaver')
local original_setup,original_cleanup=Screensaver.setup,Screensaver.cleanup
local Loader=require('pluginloader')
local plugin_path=assert(arg[1],'Pass the absolute pokepal.koplugin path')
Loader._discover=function()
 return {{name='pokepal',main=plugin_path..'/main.lua',meta=plugin_path..'/_meta.lua',path=plugin_path},
  {name='statistics',main='plugins/statistics.koplugin/main.lua',meta='plugins/statistics.koplugin/_meta.lua',path='plugins/statistics.koplugin'}}
end
local FileManager=require('apps/filemanager/filemanager')
local ReaderUI=require('apps/reader/readerui')
local original_time=os.time
local now=original_time()
os.time=function(t) return t and original_time(t) or now end
local logger=require('logger')
local original_error=logger.err
local errors=0
logger.err=function(...) errors=errors+1;original_error(...) end
local passed,failed=0,0
local function check(name,fn)
 local before=errors
 local ok,err=pcall(fn)
 if ok and errors~=before then ok=false;err='KOReader logged a handler error' end
 G_reader_settings:saveSetting('screensaver_type','disable')
 G_reader_settings:saveSetting('screensaver_delay','disable')
 if ok then passed=passed+1;print('PASS '..name)
 else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
end
local function pump(seconds)
 U:shiftScheduledTasksBy(-time.s(seconds or 0.2));U:_checkTasks();U:_repaint()
end
local books={}
for book=1,2 do
 books[book]=dir..'/reading-'..book..'.txt'
 local file=assert(io.open(books[book],'w'))
 for page=1,500 do file:write('Chapter ',page,'\n\n',string.rep('A quiet morning by the sea. We read beside the open window. ',8),'\n\n') end
 file:close()
end
local function shelf()
 if ReaderUI.instance then ReaderUI.instance:onClose() end
 if FileManager.instance then FileManager.instance:onClose() end
 assert(Screensaver.setup==original_setup and Screensaver.cleanup==original_cleanup,'a closed plugin left a sleep hook behind')
 FileManager:showFiles(dir);pump()
 return assert(FileManager.instance.pokepal)
end
local function openBook(index,mode)
 if FileManager.instance then FileManager.instance:onClose() end
 if ReaderUI.instance then ReaderUI.instance:onClose() end
 ReaderUI:doShowReader(books[index]);pump()
 local reader=assert(ReaderUI.instance)
 reader:handleEvent(Event:new('SetViewMode',mode));pump()
 assert(reader.pokepal and reader.pokepal.view==reader.view)
 return reader,reader.pokepal
end
local function game(p)
 p:openPet();p:syncReading();pump()
 return assert(p.pet_view)
end
local function counter(p) return assert(p.reading.counter(p.counterpath))+(p.clock.pending or 0) end
local function suspend()
 Screensaver:setup();Screensaver:show();U:broadcastEvent(Event:new('Suspend'));U:_repaint()
end
local function resume(wait)
 now=now+7200
 Screensaver:close();U:broadcastEvent(Event:new('Resume'))
 if wait then
  now=now+wait
  if Screensaver.screensaver_lock_widget then Screensaver.screensaver_lock_widget:onTap()
  elseif Screensaver.screensaver_widget then Screensaver.screensaver_widget:onTap() end
 end
 pump(2)
 assert(not Device.screen_saver_mode,'sleep screen did not close')
end

local p=shelf();local v=game(p)
p.engine.act(p.state,'choose',25,now);p.state.animation='off';assert(p:save());v:leave()

for _,mode in ipairs({'page','scroll'}) do
check('bookshelf expedition counts 15 minutes across two books in '..mode..' mode',function()
 p=shelf();v=game(p)
 p.state.trip=0;p.state.trail=nil;p.state.finds=nil
 if p.state.companion then p.state.companion.journey=nil end
 p.state.egg=nil;p.state.berries=10;p.state.energy=100
 p.engine.act(p.state,'egg',nil,now);p.engine.act(p.state,'readingtrip',2,now)
 local seconds,xp,berries=p.state.reading.seconds,p.state.xp,p.state.berries
 local trip,egg=p.engine.tripLeft(p.state,now),p.engine.eggLeft(p.state)
 assert(p.state.egg and p.state.trail~=nil);assert(p:save());v:leave()
 for book=1,2 do
  local reader;reader,p=openBook(book,mode)
  for page=1,15 do
   now=now+30;reader.rolling:onGotoViewRel(1)
   if page==7 then suspend();resume() end
  end
  reader:onClose()
 end
 p=shelf();v=game(p)
 assert(p.state.reading.seconds==seconds+900,'reading time was lost or sleeping time was included')
 assert(p.state.xp==xp+3 and p.state.berries==berries+1,'incorrect XP or berries')
 assert(p.engine.tripLeft(p.state,now)==trip-900 and p.engine.eggLeft(p.state)==egg-900,'trip or egg did not advance')
 v:leave();v=game(p)
 assert(p.state.reading.seconds==seconds+900 and p.state.xp==xp+3,'a repeat visit paid twice')
 v:leave()
end)
end

for _,kind in ipairs({'image','lock-only'}) do
check('waiting to unlock the '..kind..' screensaver does not earn reading time',function()
 local reader;reader,p=openBook(1,'page')
 G_reader_settings:saveSetting('screensaver_type',kind=='image' and 'random_image' or 'disable')
 G_reader_settings:saveSetting('screensaver_delay','gesture')
 local before=counter(p)
 suspend();resume(300)
 now=now+60;reader.rolling:onGotoViewRel(1)
 assert(counter(p)==before+60,'time spent at the lock screen was counted as reading: '..(counter(p)-before)..' seconds')
 G_reader_settings:saveSetting('screensaver_type','disable')
 G_reader_settings:saveSetting('screensaver_delay','disable')
 reader:onClose()
end)
end

check('disabled sleep features do no game-save I/O during suspend',function()
 p=shelf();v=game(p);local c=p.engine.companion.get(p.state)
 c.prefs.auto_rest=false;c.prefs.sleep_screen=false;assert(p:save());v:leave()
 local load,open,save=p.storage.load,p.storage.open,p.storage.save
 local calls=0
 p.storage.load=function(...) calls=calls+1;return load(...) end
 p.storage.open=function(...) calls=calls+1;return open(...) end
 p.storage.save=function(...) calls=calls+1;return save(...) end
 local start=time.now();suspend();local elapsed=time.to_ms(time.since(start))
 p.storage.load,p.storage.open,p.storage.save=load,open,save
 resume()
 assert(calls==0,'disabled features still touched the game save')
 print(string.format('TIMING disabled features: %.1f ms for desktop sleep preparation; zero game-save calls',elapsed))
end)

local cycles,max_sleep=0,0
for _,context in ipairs({'shelf','book','game'}) do
check('sleep/wake works with every preference and unlock mode from '..context,function()
 local reader
 if context=='shelf' then p=shelf() else reader,p=openBook(1,'page') end
 v=game(p)
 p.state.trip=0;p.state.trail=nil;p.state.finds=nil;p.state.companion.journey=nil
 if context~='game' then v:leave();v=nil end
 for _,prefs in ipairs({{false,false},{true,false},{false,true},{true,true}}) do
  p.state.companion.prefs.auto_rest=prefs[1];p.state.companion.prefs.sleep_screen=prefs[2];assert(p:save())
  for _,rotation in ipairs({0,1}) do
   Device.screen:setRotationMode(rotation)
   U:broadcastEvent(Event:new('SetDimensions',Device.screen:getSize()))
   for _,delay in ipairs({'disable','gesture','1'}) do
    G_reader_settings:saveSetting('screensaver_type','random_image')
    G_reader_settings:saveSetting('screensaver_delay',delay)
    local start=time.now();suspend();max_sleep=math.max(max_sleep,time.to_ms(time.since(start)))
    resume(delay=='gesture' and 0 or nil);cycles=cycles+1
    assert(not Device.screen_saver_lock and not p.suspended and not p.reading_error)
    assert(p.engine.valid(p.state))
    if reader then assert(p.view==reader.view,'PokePal replaced KOReader\'s book view') end
    if v then
     assert(not v.suspended and v.dimen.w==Device.screen:getWidth() and v.dimen.h==Device.screen:getHeight())
     v:paintTo(Device.screen.bb,0,0)
    end
   end
  end
 end
 if v then v:leave() end
end)
end
print(string.format('SLEEP MATRIX: %d real KOReader cycles; slowest desktop sleep preparation %.1f ms',cycles,max_sleep))

if ReaderUI.instance then ReaderUI.instance:onClose() end
if FileManager.instance then FileManager.instance:onClose() end
assert(Screensaver.setup==original_setup and Screensaver.cleanup==original_cleanup)
logger.err=original_error;os.time=original_time;U:quit()
assert(failed==0,tostring(failed)..' real KOReader runtime checks failed')
print('KOREADER RUNTIME: '..passed..' checks passed')
