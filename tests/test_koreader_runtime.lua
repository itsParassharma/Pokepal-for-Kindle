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
-- Keep an existing gesture and QuickMenu to check that onboarding leaves them alone.
local gestures_path=DataStorage:getSettingsDir()..'/gestures.lua'
local gestures_settings=require('luasettings'):open(gestures_path)
gestures_settings.data=require('util').tableDeepCopy(dofile('plugins/gestures.koplugin/defaults.lua'))
gestures_settings.data.gesture_reader.hold_bottom_right_corner={night_mode=true}
gestures_settings.data.gesture_fm.hold_bottom_right_corner={show_history=true,settings={show_as_quickmenu=true}}
gestures_settings:flush()
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
  {name='statistics',main='plugins/statistics.koplugin/main.lua',meta='plugins/statistics.koplugin/_meta.lua',path='plugins/statistics.koplugin'},
  {name='gestures',main='plugins/gestures.koplugin/main.lua',meta='plugins/gestures.koplugin/_meta.lua',path='plugins/gestures.koplugin'}}
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
local function screenBytes()
 local bb=Device.screen.bb
 return require('ffi').string(bb.data,bb.stride*bb.h)
end
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

local function button(dialog,label)
 for _,row in ipairs(dialog.buttons or dialog.buttons_table or {}) do
  for _,item in ipairs(row) do if item.text==label then return item end end
 end
 error('Missing button: '..label)
end
local function menuEntry(ui)
 ui.menu:setUpdateItemTable()
 local found
 local function scan(items,parent)
  for _,item in ipairs(items) do
   if item.id=='pokepal' then assert(parent=='tools','PokePal is not directly in Tools');assert(not found);found=item end
   scan(item.sub_item_table or item,item.id)
  end
 end
 scan(ui.menu.tab_item_table)
 assert(found and found.text=='PokePal','PokePal menu entry missing or misnamed')
 return found
end
local function gesturesUnchanged(ui)
 assert(ui.gestures.data.gesture_reader.hold_bottom_right_corner.night_mode==true)
 local quick=ui.gestures.data.gesture_fm.hold_bottom_right_corner
 assert(quick.show_history and quick.settings.show_as_quickmenu)
 for _,actions in pairs(ui.gestures.gestures) do
  assert(type(actions)~='table' or not actions.pokepal_open,'PokePal assigned itself a gesture')
 end
end
local p,v
check('first launch offers all three buttons and Later stays dismissed after reopening',function()
 p=shelf()
 local welcome=assert(p.shortcut_dialog,'no first-launch welcome')
 assert(U:getTopmostVisibleWidget()==welcome)
 if os.getenv('POKEPAL_SCREENSHOTS') then Device.screen.bb:writePNG(os.getenv('POKEPAL_SCREENSHOTS')..'/welcome.png') end
 button(welcome,'Open PokePal');button(welcome,'Shortcut help')
 button(welcome,'Later').callback()
 assert(not p.shortcut_dialog and not p.pet_view)
 assert(not p.fs.mode(p.savepath),'Later created a game save')
 gesturesUnchanged(p.ui);menuEntry(p.ui)
 G_reader_settings:flush()
 assert(require('luasettings'):open(dir..'/settings.reader.lua'):isTrue('pokepal_welcome_seen'))
 p=shelf();assert(not p.shortcut_dialog,'welcome repeated')
end)

check('welcome help opens above the browser, and can open the game',function()
 G_reader_settings:delSetting('pokepal_welcome_seen');p=shelf()
 button(p.shortcut_dialog,'Shortcut help').callback();pump()
 local help=assert(p.shortcut_dialog)
 assert(help.title=='PokePal shortcuts' and U:getTopmostVisibleWidget()==help)
 gesturesUnchanged(p.ui)
 button(help,'Open PokePal').callback();pump()
 assert(not p.shortcut_dialog and p.pet_view);p.pet_view:leave()
end)

check('welcome Open PokePal opens the game without a second dialog',function()
 G_reader_settings:delSetting('pokepal_welcome_seen');p=shelf()
 button(p.shortcut_dialog,'Open PokePal').callback();pump()
 assert(p.pet_view and not p.shortcut_dialog)
 p.pet_view:leave();pump();assert(not p.shortcut_dialog)
end)

check('closing a browser cancels its pending welcome and stale launch callbacks',function()
 FileManager.instance:onClose();G_reader_settings:delSetting('pokepal_welcome_seen')
 FileManager:showFiles(dir);local old=FileManager.instance.pokepal
 local pending=assert(old.welcome_task)
 FileManager.instance:onClose();pending();pump()
 assert(not old.welcome_task and not old.shortcut_dialog and not G_reader_settings:isTrue('pokepal_welcome_seen'))
 p=shelf();local launch=button(p.shortcut_dialog,'Open PokePal').callback
 FileManager.instance:onClose();launch();pump()
 assert(not p.pet_view and not p.shortcut_dialog)
end)

check('opening a book before the welcome appears cancels the old browser prompt',function()
 G_reader_settings:delSetting('pokepal_welcome_seen')
 FileManager:showFiles(dir);local background=FileManager.instance.pokepal
 ReaderUI:showReader(books[1]);pump();pump();p=ReaderUI.instance.pokepal
 assert(p.shortcut_dialog,'book welcome was not shown')
 assert(background.closed and not background.shortcut_dialog,'old browser prompt survived')
 local before=counter(p)
 now=now+300;ReaderUI.instance.rolling:onGotoViewRel(1)
 assert(counter(p)==before,'welcome time counted as reading')
 G_reader_settings:saveSetting('screensaver_type','random_image')
 G_reader_settings:saveSetting('screensaver_delay','gesture')
 suspend();resume(300)
 assert(p.shortcut_dialog and counter(p)==before,'waking at the welcome started the reading timer')
 button(p.shortcut_dialog,'Later').callback()
 now=now+60;ReaderUI.instance.rolling:onGotoViewRel(1)
 assert(counter(p)==before+60,'reading did not resume after Later')
 ReaderUI.instance:onClose()
end)

check('a queued welcome waits through sleep and appears after waking',function()
 G_reader_settings:delSetting('pokepal_welcome_seen')
 FileManager:showFiles(dir);p=FileManager.instance.pokepal
 suspend();pump()
 assert(not p.shortcut_dialog and not G_reader_settings:isTrue('pokepal_welcome_seen'))
 resume();assert(p.shortcut_dialog)
 button(p.shortcut_dialog,'Later').callback()
 FileManager.instance:onClose()
end)

check('opening the game before the welcome is ready does not show a late prompt',function()
 G_reader_settings:delSetting('pokepal_welcome_seen')
 FileManager:showFiles(dir);p=FileManager.instance.pokepal
 p:openPet();pump();assert(p.pet_view and not p.shortcut_dialog)
 p.pet_view:leave();pump();assert(not p.shortcut_dialog)
 p=shelf();assert(not p.shortcut_dialog)
end)

local Dispatcher=require('dispatcher')
for _,context in ipairs({'shelf','book'}) do
check('Tools, gesture action and QuickMenu open PokePal from '..context,function()
 if context=='shelf' then p=shelf() else local reader;reader,p=openBook(1,'page') end
 assert(Dispatcher:getNameFromItem('pokepal_open')=='Open PokePal')
 local entry=menuEntry(p.ui)
 entry.callback();pump();assert(p.pet_view);p.pet_view:leave()
 local choices={};Dispatcher:_addItem(p.ui.gestures,choices,{},'test','general')
 local count=0;for _,item in ipairs(choices) do if item.text=='Open PokePal' then count=count+1 end end
 assert(count==1,'action missing or registered more than once')
 local gestures=p.ui.gestures.gestures
 local previous=gestures.hold_top_right_corner
 gestures.hold_top_right_corner={pokepal_open=true}
 p.ui.gestures:gestureAction('hold_top_right_corner',{ges='hold'})
 gestures.hold_top_right_corner=previous
 pump();local view=assert(p.pet_view)
 Dispatcher:execute({pokepal_open=true});assert(p.pet_view==view,'action opened the game twice');view:leave()
 Dispatcher:execute({pokepal_open=true,settings={show_as_quickmenu=true}});pump()
 local quick=U:getTopmostVisibleWidget();assert(quick~=p.ui and not p.pet_view)
 button(quick,'Open PokePal').callback();pump();assert(p.pet_view);p.pet_view:leave()
 for _,rotation in ipairs({0,1}) do
  Device.screen:setRotationMode(rotation);U:broadcastEvent(Event:new('SetDimensions',Device.screen:getSize()))
  entry.hold_callback();pump();local help=assert(p.shortcut_dialog)
  assert(U:getTopmostVisibleWidget()==help)
  local size=help:getContentSize()
  assert(size.w<=Device.screen:getWidth() and size.h<=Device.screen:getHeight(),'shortcut help exceeds screen')
  if os.getenv('POKEPAL_SCREENSHOTS') then Device.screen.bb:writePNG(os.getenv('POKEPAL_SCREENSHOTS')..'/shortcuts-'..context..'-'..rotation..'.png') end
  button(help,'Close').callback();assert(not p.shortcut_dialog)
 end
 Device.screen:setRotationMode(0);U:broadcastEvent(Event:new('SetDimensions',Device.screen:getSize()))
 gesturesUnchanged(p.ui)
end)
end

p=shelf();v=game(p)
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

local function gameTap(view,action,arg)
 view:paintTo(Device.screen.bb,0,0)
 for _,item in ipairs(view.buttons) do
  if item.action==action and item.arg==arg then
   assert(not item.disabled,'control is disabled: '..action)
   local r=view:region(item.x+item.w/2,item.y+item.h/2,0,0)
   view:onTap(nil,{pos={x=r.x,y=r.y}});pump();return
  end
 end
 error('Missing game control: '..action)
end
local function clearTrip(p)
 p.state.trip=0;p.state.trail=nil;p.state.finds=nil;p.state.companion.journey=nil
 p.state.resting=false;p.state.companion.sleep=nil;p.state.world=nil
end
check('walking, battles and pause resume work through real widgets without counting reading',function()
 local reader;reader,p=openBook(1,'scroll');v=game(p);clearTrip(p)
 p.state.animation='off';local before=counter(p)
 gameTap(v,'nav','explore');assert(v.state.world.map=='town')
 if os.getenv('POKEPAL_SCREENSHOTS') then Device.screen.bb:writePNG(os.getenv('POKEPAL_SCREENSHOTS')..'/world-town.png') end
 gameTap(v,'worldtile',6);assert(v.state.world.map=='meadow')
 gameTap(v,'worldtile',14);assert(v.screen=='battle')
 gameTap(v,'battleturn',1);local b=v.state.world.battle
 local saved=p.engine.companion.encode(v.state.world)
 if os.getenv('POKEPAL_SCREENSHOTS') then Device.screen.bb:writePNG(os.getenv('POKEPAL_SCREENSHOTS')..'/world-battle.png') end
 now=now+900;reader.rolling:onGotoViewRel(1);pump()
 assert(counter(p)==before,'playing counted as reading')
 v:leave();v=game(p);gameTap(v,'nav','explore')
 assert(v.screen=='battle' and p.engine.companion.encode(v.state.world)==saved)
 gameTap(v,'battleflee');gameTap(v,'battlefinish');assert(v.screen=='explore')
 v:leave();now=now+60;reader.rolling:onGotoViewRel(1)
 assert(counter(p)==before+60,'reading did not resume after playing')
end)
check('real suspend cancels a walking callback, including after waking',function()
 p=shelf();v=game(p);clearTrip(p);p.state.animation='gentle'
 v:go('explore');v:walkWorld(6,1);local late=assert(v.world_tick)
 local saved=p.engine.companion.encode(v.state.world)
 suspend();resume();late();pump()
 assert(not v.world_tick and p.engine.companion.encode(v.state.world)==saved)
 assert(p.engine.valid(p.state));v:leave()
end)

check('party and Tower widgets preserve turns and exclude playing from reading',function()
 local reader;reader,p=openBook(1,'scroll');v=game(p);clearTrip(p)
 p.engine.act(p.state,'partner',25,now);p.state.animation='off';local before=counter(p)
 gameTap(v,'nav','explore');local overview=p.engine.companion.encode(p.state.world)
 gameTap(v,'nav','worldparty')
 for _,item in ipairs(v.buttons) do assert(item.action~='campslot') end
 gameTap(v,'nav','explore');assert(p.engine.companion.encode(p.state.world)==overview)
 gameTap(v,'worldtile',25);gameTap(v,'worldtile',37)
 for _,id in ipairs({1,7}) do p.state.seen[tostring(id)]=true;p.state.world.camp.box[tostring(id)]=true end;p.state.world.camp.badges=7
 gameTap(v,'campslot',2);gameTap(v,'campdetail',7);gameTap(v,'campwithdraw',7);gameTap(v,'campslot',3);gameTap(v,'campdetail',1);gameTap(v,'campwithdraw',1)
 v:go('explore');gameTap(v,'worldtile',83);gameTap(v,'worldtile',65);gameTap(v,'worldtile',39)
 gameTap(v,'camptower');gameTap(v,'nav','worldswitch')
 local _,forecast=p.engine.world.town.switchPreview(p.state,p.engine,7)
 gameTap(v,'campswitch',7)
 assert(p.state.world.partner==7 and p.state.world.battle.turn==2 and p.state.world.hp==forecast)
 local saved=p.engine.companion.encode(p.state.world)
 now=now+900;reader.rolling:onGotoViewRel(1);pump();assert(counter(p)==before)
 suspend();resume();assert(p.engine.companion.encode(p.state.world)==saved)
 v:leave();v=game(p);gameTap(v,'nav','explore');assert(v.screen=='battle' and p.engine.companion.encode(p.state.world)==saved)
 p.state.world.battle.team={10,43,19}
 while p.state.world.battle.status=='active' do p.state.world.battle.hp=1;gameTap(v,'battleturn',1) end
 gameTap(v,'battlefinish');assert(v.screen=='worldtower')
 gameTap(v,'nav','worldparty');gameTap(v,'nav','worldtower')
 local expected=p.engine.world.town.towerFoe(p.state.world.camp.tower.run,2)
 gameTap(v,'campbenefit',3);assert(p.state.world.battle.foe==expected)
 gameTap(v,'battleflee');gameTap(v,'battlefinish');v:leave()
end)

check('berry recruitment, box controls and badges survive real widget sleep and reload',function()
 local reader;reader,p=openBook(1,'page');v=game(p);clearTrip(p)
 p.state.world=nil;p.engine.act(p.state,'partner',25,now);p.state.animation='off';p.state.berries=20
 v:go('explore');local w=p.state.world;local A=p.engine.world.town;local before=counter(p)
 w.camp.box['10']=nil;w.camp.health['10']=nil;w.camp.training['10']=nil
 gameTap(v,'worldtile',6);gameTap(v,'worldtile',14);w.battle.hp=1
 gameTap(v,'nav','worldbag');gameTap(v,'camprecruit');assert(w.camp.box['10'] and #w.camp.party==1)
 local saved=p.engine.companion.encode(w);suspend();resume();assert(p.engine.companion.encode(w)==saved)
 gameTap(v,'campaddrecruit');gameTap(v,'battlefinish');gameTap(v,'worldtile',83)
 gameTap(v,'worldtile',25);gameTap(v,'worldtile',37);gameTap(v,'nav','worldbox')
 gameTap(v,'campsearch');for letter in ('caterpie'):gmatch('.') do gameTap(v,'campkey',letter) end
 gameTap(v,'camptextsave');gameTap(v,'campdetail',10);gameTap(v,'campfavourite',10)
 gameTap(v,'campdeposit',10);assert(#w.camp.party==1);gameTap(v,'campwithdraw',10);assert(#w.camp.party==2)
 v:go('explore');gameTap(v,'worldtile',83);gameTap(v,'worldtile',31);gameTap(v,'worldtile',39)
 gameTap(v,'campgym',1);assert(#w.battle.team==2);w.battle.team={10,43}
 while w.battle.status=='active' do w.battle.hp=1;gameTap(v,'battleturn',1) end
 assert(w.camp.badges==1);gameTap(v,'battlefinish');assert(p:save())
 saved=p.engine.companion.encode(w);v:leave();reader,p=openBook(1,'page');v=game(p);v:go('explore')
 assert(p.engine.companion.encode(p.state.world)==saved and p.state.companion.favourites['10'])
 assert(counter(p)==before);v:leave()
end)

local cycles,max_sleep=0,0
for _,context in ipairs({'shelf','book','game','map','battle','tower','benefit','centre','worldparty','worldbox','worldboxsearch','worldboxname','worldmoves','worldshop','worldquests','worldgym','worldbag','worldswitch','worldrevive','resting-battle','resting-result'}) do
check('sleep/wake works with every preference and unlock mode from '..context,function()
 local reader
 if context=='shelf' then p=shelf() else reader,p=openBook(1,'page') end
 local behind=U._window_stack[#U._window_stack].widget
 v=game(p)
 clearTrip(p);p.state.animation='off'
 if context=='map' or context=='battle' then v:go('explore') end
 if context=='battle' then gameTap(v,'worldtile',6);gameTap(v,'worldtile',14);assert(v.screen=='battle') end
 if context=='tower' or context=='benefit' then
  p.engine.act(p.state,'partner',25,now);v:go('explore');local w=p.state.world;local A=p.engine.world.town
  for _,id in ipairs({1,7}) do p.state.seen[tostring(id)]=true;w.camp.box[tostring(id)]=true end;w.camp.badges=7
  w.map='centre';assert(A.party(p.state,p.engine,2,7));assert(A.party(p.state,p.engine,3,1))
  w.map='tower';assert(A.startTower(p.state,p.engine))
  if context=='benefit' then
   w.battle.team={10,43,19}
   while w.battle.status=='active' do w.battle.hp=1;assert(p.engine.world.turn(p.state,p.engine,1,now)) end
   assert(p.engine.world.finish(p.state))
  end
  v:go('explore')
 end
 if context=='centre' or context:match('^world') or context:match('^resting') then
  p.engine.act(p.state,'partner',25,now);v:go('explore')
  local w=p.state.world;local A=p.engine.world.town
  w.map='centre';w.camp.badges=7;p.state.berries=50
  for slot,id in ipairs({7,1,133,252,255}) do
   p.state.seen[tostring(id)]=true;w.camp.box[tostring(id)]=true;assert(A.party(p.state,p.engine,slot+1,id))
  end
  w.camp.potions=1;w.camp.revives=1
  if context=='worldswitch' or context:match('^resting') then
   w.map='meadow';w.x=3;w.y=3;assert(p.engine.world.startBattle(p.state,1))
   if context=='resting-result' then w.battle.hp=1;assert(p.engine.world.turn(p.state,p.engine,1,now)) end
   if context:match('^resting') then p.engine.act(p.state,'rest',nil,now) end
  elseif context=='worldrevive' then w.camp.health['7']=0
  else w.map=({worldmoves='dojo',worldshop='shop',worldquests='town',worldgym='gym'})[context] or 'centre' end
  v:go(context=='centre' and 'explore' or context:match('^resting') and 'battle' or context)
  v.box_id=7;v.box_text='My Squirtle';v.box_query='squirtle';v.box_type=4;v.box_favourites=false
 end
 if context=='shelf' or context=='book' then v:leave();v=nil end
 local reading=counter(p)
 for _,prefs in ipairs({{false,false},{true,false},{false,true},{true,true}}) do
  p.state.companion.prefs.auto_rest=prefs[1];p.state.companion.prefs.sleep_screen=prefs[2];assert(p:save())
  for _,rotation in ipairs({0,1}) do
   Device.screen:setRotationMode(rotation)
   U:broadcastEvent(Event:new('SetDimensions',Device.screen:getSize()))
   for _,delay in ipairs({'disable','gesture','1'}) do
    G_reader_settings:saveSetting('screensaver_type','random_image')
    G_reader_settings:saveSetting('screensaver_delay',delay)
    local world=p.state.world and p.engine.companion.encode(p.state.world)
    local screen=v and v.screen;local input=v and v.box_text
    local start=time.now();suspend();max_sleep=math.max(max_sleep,time.to_ms(time.since(start)))
    resume(delay=='gesture' and 0 or nil);cycles=cycles+1
    assert(not Device.screen_saver_lock and not p.suspended and not p.reading_error)
    assert(p.engine.valid(p.state))
    if world then assert(p.engine.companion.encode(p.state.world)==world,'sleep advanced the world or battle') end
    if reader then assert(p.view==reader.view,'PokePal replaced KOReader\'s book view') end
    if v then
     assert(not v.suspended and v.dimen.w==Device.screen:getWidth() and v.dimen.h==Device.screen:getHeight())
     assert(v.screen==screen and v.box_text==input,'sleep lost the menu or unfinished text')
     assert(counter(p)==reading and not p.clock.since,'playing or sleeping counted as reading')
     assert(U._window_stack[#U._window_stack].widget==v,'a sleep overlay remained above the game')
     local actual=screenBytes()
     v:paintTo(Device.screen.bb,0,0)
     assert(actual==screenBytes(),'wake left stale pixels on '..context)
    end
   end
  end
 end
 if v then
  local late=v.tick;v:leave();pump();late();pump()
  assert(not p.pet_view and not p.session and not p.reading_busy and not v.world_tick and next(v.images)==nil)
  assert(U._window_stack[#U._window_stack].widget==behind,'a game window survived closing')
  local actual=screenBytes();U:setDirty(p.ui,'full');pump()
  assert(actual==screenBytes(),'game pixels remained over the reader after closing '..context)
 end
end)
end
print(string.format('SLEEP MATRIX: %d real KOReader cycles; slowest desktop sleep preparation %.1f ms',cycles,max_sleep))

if ReaderUI.instance then ReaderUI.instance:onClose() end
if FileManager.instance then FileManager.instance:onClose() end
assert(Screensaver.setup==original_setup and Screensaver.cleanup==original_cleanup)
BASE=plugin_path;TESTDIR=dir;BOOKSHELF_REAL_UI=true
dofile(plugin_path..'/../tests/test_bookshelf.lua')
dofile(plugin_path..'/../tests/test_simpleui.lua')
logger.err=original_error;os.time=original_time;U:quit()
assert(failed==0,tostring(failed)..' real KOReader runtime checks failed')
print('KOREADER RUNTIME: '..passed..' checks passed')
