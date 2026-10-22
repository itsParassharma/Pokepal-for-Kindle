local s=app.state;local E=app.engine;local v=app.view
for key in pairs(s) do s[key]=nil end
for key,value in pairs(E.new(os.time())) do s[key]=value end
if s.species==0 then v:act('choose',4) end
v:go('home');s.animation='off';s.food=60;s.berries=6
v:act('feed');assert(s.food==84 and s.berries==5)
s.seen['150']=true;v:act('partner',150);assert(s.species==150 and s.xp==0)
s.xp=60;s.bond=30;v:act('partner',4);v:act('partner',150);assert(s.xp==60 and s.bond==30)
v:go('entry');v.detail_id=150
for _,pose in ipairs({'idle','sleep','walk','attack','eat'}) do
 v.preview_pose=pose
 for frame=1,v.poses[150][pose] do v.frame=frame;app_paint();assert(#v.buttons==8) end
end
assert(app.owner:save())
local save=app.storage.save;app.storage.save=function() return nil,'Test save failure' end
assert(not app.owner:save() and app.owner.save_error)
v:go('more');app_paint();v:go('home');app_paint()
app.storage.save=save;assert(app.owner:save() and not app.owner.save_error)
local loaded=app.storage.load('data/pokepal.dat',E);assert(loaded.species==150 and loaded.partners['4'])
v:onSuspend();assert(#app.ui.queue==0);v:onResume()
print('NATIVE: drawing, actions, partner progress, save reload and suspend passed')
BASE='game';TESTDIR=os.tmpname();os.remove(TESTDIR);assert(host_fs('mkdir',TESTDIR))
dofile('../../../tests/test_reading.lua')
dofile('../../../tests/test_adventures.lua')
dofile('../../../tests/test_companion.lua')
dofile('../../../tests/test_backups.lua')
v:go('reading');app_paint();assert(#v.buttons==7)
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
