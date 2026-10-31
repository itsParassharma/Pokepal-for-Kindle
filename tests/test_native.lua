app.owner:syncReading()
local s=app.state;local E=app.engine;local v=app.view
assert(app.owner.pet_view==v)
app.owner:startReadingScan();assert(app.owner.scan_step)
app.owner.scan_step();assert(not app.owner.reading_busy)
for key in pairs(s) do s[key]=nil end
for key,value in pairs(E.new(os.time())) do s[key]=value end
local function tap(action,arg)
 app_paint()
 for _,button in ipairs(v.buttons) do
  if button.action==action and button.arg==arg then
   assert(not button.disabled);local r=v:region(button.x+4,button.y+4,0,0)
   v:onTap(nil,{pos={x=r.x,y=r.y}});return
  end
 end
 error('Missing native control: '..action)
end
tap('nav','allcompanions');app_paint();assert(v.journal_count==386)
tap('entry',3);tap('choose',3);assert(s.species==3)
v:go('profile');tap('nav','companions');tap('nav','allcompanions')
tap('entry',4);tap('partner',4);assert(s.species==4)
v:go('home');s.animation='off';s.food=60;s.berries=6
v:act('feed');assert(s.food==84 and s.berries==5)
s.seen['150']=true;v:act('partner',150);assert(s.species==150 and s.xp==0)
s.xp=60;s.bond=30;v:act('partner',4);v:act('partner',150);assert(s.xp==60 and s.bond==30)
v:go('entry');v.detail_id=150
for _,pose in ipairs({'idle','sleep','walk','attack','eat','hop','rotate','charge','swing','double'}) do
 v.preview_pose=pose
 for frame=1,v.poses[150][pose] do v.frame=frame;app_paint();assert(#v.buttons==14) end
end
assert(app.owner:save())
for id=1,386 do
 v.detail_id=id
 for _,direction in ipairs({'down','left','up','right'}) do v.preview_pose='walk_'..direction;v.frame=1;app_paint() end
 v:freeImages()
end
print('NATIVE FOLLOWERS: all 386 Pokemon drawn in four walking directions')
local save=app.storage.save;app.storage.save=function() return nil,'Test save failure' end
assert(not app.owner:save() and app.owner.save_error)
v:go('more');app_paint();v:go('home');app_paint()
app.storage.save=save;assert(app.owner:save() and not app.owner.save_error)
local loaded=app.storage.load('data/pokepal.dat',E);assert(loaded.species==150 and loaded.partners['4'])
v:onSuspend();assert(#app.ui.queue==0);v:onResume()
print('NATIVE: drawing, actions, partner progress, save reload and suspend passed')
v:act('partner',25);s.animation='off';v:go('explore')
local overview=E.companion.encode(s.world)
tap('nav','worldparty');app_paint()
for _,button in ipairs(v.buttons) do assert(button.action~='campslot') end
tap('nav','explore');assert(E.companion.encode(s.world)==overview)
tap('worldtile',6);assert(s.world.map=='meadow')
tap('worldtile',14);assert(v.screen=='battle')
tap('battleturn',1);assert(s.world.battle.turn==2)
local world=E.companion.encode(s.world)
v:onSuspend();v:onResume();assert(E.companion.encode(s.world)==world)
assert(app.storage.load('data/pokepal.dat',E).world.battle.turn==2)
tap('nav','home');tap('nav','explore');assert(v.screen=='battle')
tap('battleflee');tap('battlefinish');assert(v.screen=='explore')
tap('worldtile',83);assert(s.world.map=='town')
tap('worldtile',25);s.world.hp=1;tap('worldtile',39);assert(s.world.hp==40)
tap('nav','home')
print('NATIVE WORLD: walking, battling, healing, save reload and sleep passed')
for _,id in ipairs({1,7}) do s.seen[tostring(id)]=true;s.world.camp.box[tostring(id)]=true end;s.world.camp.badges=7
 v:go('explore');tap('worldtile',37);tap('campslot',2);tap('campdetail',7);tap('campwithdraw',7);tap('campslot',3);tap('campdetail',1);tap('campwithdraw',1)
v:go('explore');tap('worldtile',83);tap('worldtile',65);tap('worldtile',39);tap('camptower')
assert(s.world.battle.floor==1);tap('nav','worldswitch');tap('campswitch',7)
assert(s.world.partner==7 and s.world.battle.turn==2)
local tower=E.companion.encode(s.world);v:onSuspend();v:onResume();assert(E.companion.encode(s.world)==tower)
assert(app.owner:save());assert(app.storage.load('data/pokepal.dat',E).world.camp.tower.floor==1)
s.world.battle.team={10,43,19}
while s.world.battle.status=='active' do s.world.battle.hp=1;tap('battleturn',1) end
tap('battlefinish');assert(v.screen=='worldtower')
tap('nav','worldparty');tap('nav','worldtower');tap('campbenefit',1)
assert(s.world.battle.floor==2 and s.world.battle.foe==E.world.town.towerFoe(s.world.camp.tower.run,2))
tap('battleflee');tap('battlefinish');tap('nav','home')
print('NATIVE TOWER: party selection, turn-cost switching, save reload and sleep passed')
for _,screen in ipairs({'worldparty','worldbox','worldboxsearch','worldboxname','worldmoves','worldshop','worldquests','worldgym','worldbag','worldrevive'}) do
 v:go(screen);v.box_text='My partner';app_paint()
 local world=E.companion.encode(s.world);v:onSuspend();v:onResume();app_paint()
 assert(v.screen==screen and v.box_text=='My partner' and E.companion.encode(s.world)==world and #app.ui.queue==0)
 local dirty=app_tick();assert(not dirty,'an idle town menu kept repainting')
end
print('NATIVE MENUS: ten town and box screens survive sleep without changing the party or scheduling idle repaints')
local story=dofile('../../../tests/story_runtime.lua')(v,tap);app_paint()
assert(E.companion.encode(app.storage.load('data/pokepal.dat',E).story)==E.companion.encode(story))
print('NATIVE STORY: maps, initial companion, catching, party, box, Gym turns, save reload and sleep passed')
BASE='game';TESTDIR=os.tmpname();os.remove(TESTDIR);assert(host_fs('mkdir',TESTDIR))
dofile('../../../tests/test_reading.lua')
dofile('../../../tests/test_gen3.lua')
dofile('../../../tests/test_adventures.lua')
dofile('../../../tests/test_companion.lua')
dofile('../../../tests/test_backups.lua')
dofile('../../../tests/test_improvements.lua')
dofile('../../../tests/test_town.lua')
dofile('../../../tests/test_collection.lua')
dofile('../../../tests/test_story.lua')
v:go('reading');app_paint();assert(#v.buttons==9)
dofile('game/reading.lua').init(s);s.berries=6;v:act('egg');v:act('readingtrip',1)
assert(s.egg and s.trail)
E.readingReward(s,7200,os.time());v:act('hatch');assert(v.screen=='entry' and s.trip==1)
app_paint();v:act('collect');assert(s.trip==0)
for i=1,#E.backgrounds do E.act(s,'background',i,os.time());v:go('backgrounds');app_paint() end
assert(app.owner:save());loaded=app.storage.load('data/pokepal.dat',E);assert(loaded.background==6)
v:go('home');app_paint()
s.berries=80
for i=1,4 do E.act(s,'decorate',i,os.time()) end
E.act(s,'nickname','Book buddy',os.time());E.act(s,'egg',nil,os.time());E.act(s,'goal',3600,os.time())
local _,recap=E.readingReward(s,5400,os.time());app.owner.recap=recap
for _,screen in ipairs({'recap','weekly','decorations','nickname','profile','backups'}) do v:go(screen);app_paint() end
assert(app.owner.backups:create(s));local preview=assert(app.owner.backups:preview('backup'))
v.restore_preview=preview;v:go('restore');app_paint()
local berries=s.berries;s.berries=berries+1;assert(app.owner.backups:restore(s,preview));assert(s.berries==berries)
assert(app.owner.backups:preview('before-restore').state.berries==berries+1)
v:go('home');app_paint()
local F=dofile('game/filesystem.lua')
local function clean(path)
 for _,name in ipairs(F.list(path)) do
  local file=path..'/'..name
  if F.mode(file)=='directory' then clean(file) else assert(os.remove(file)) end
 end
 assert(F.rmdir(path))
end
clean(TESTDIR)

-- Repeat paints reuse decoded sprites and glyphs; a stage paint skips the UI.
v:go('home');s.animation='off';app_paint()
local images,glyphs,bytes=host_cache_stats();app_paint()
local images2,glyphs2=host_cache_stats();assert(images==images2 and glyphs==glyphs2 and bytes<=4*1024*1024)
app.ui:setDirty(v,'ui',v:stageRegion())
local paint=v.paintTo;v.paintTo=function() error('Full UI painted for an animation') end
local flash,x,y,w,h=app_paint();v.paintTo=paint
assert(not flash and w<600 and h<800)
app.ui:setDirty(v,'ui');flash,x,y,w,h=app_paint();assert(not flash and w==600 and h==800)
app.ui:setDirty(v,'full');flash=app_paint();assert(flash)
assert(host_text_width('Évoli',20,false)>0)
print('NATIVE CACHE: reused sprites and glyphs; regional redraw and explicit refresh passed')
