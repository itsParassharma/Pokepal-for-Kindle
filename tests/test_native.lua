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
local loaded=app.storage.load('data/pokepal.dat',E);assert(loaded.species==150 and loaded.partners['4'])
v:onSuspend();assert(#app.ui.queue==0);v:onResume()
print('NATIVE: drawing, actions, partner progress, save reload and suspend passed')
