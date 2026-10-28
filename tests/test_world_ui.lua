local S=dofile(BASE..'/storage.lua');local checks=0
local original_time=os.time;local now=original_time()
os.time=function(t) return t and original_time(t) or now end
local function test(name,fn) fn();checks=checks+1;print('PASS world UI: '..name) end
local function view(id)
 local v=newView(id or 25);v.state.animation='off'
 v.owner.save=function(owner) assert(E.valid(v.state));owner.saved=(owner.saved or 0)+1;return true end
 v:go('explore');return v
end
local function encounter(v,index)
 tapButton(v,'worldtile',6)
 assert(v.state.world.map=='meadow')
 local p=E.world.encounters[index or 1]
 tapButton(v,'worldtile',(p.y-1)*11+p.x)
 assert(v.screen=='battle' and v.state.world.battle)
end
test('home opens the map and the trail board opens existing expeditions',function()
 local v=newView(25);v.state.animation='off'
 tapButton(v,'nav','explore');assert(v.state.world and v.screen=='explore')
 tapButton(v,'worldtile',31);assert(v.screen=='expeditions')
 tapButton(v,'tripmode','reading');assert(v.trip_mode=='reading')
 v:go('home');v:go('reading');tapButton(v,'nav','expeditions');assert(v.screen=='expeditions');v:leave()
end)
test('tap-to-walk and arrows work in portrait and landscape',function()
 for _,size in ipairs({{600,800},{1072,1448},{800,600}}) do
  D.w=size[1];D.h=size[2];local v=view()
  tapButton(v,'worlddir','up');assert(v.state.world.y==5)
  tapButton(v,'worldtile',25);assert(v.state.world.map=='centre')
  v.state.world.hp=1;tapButton(v,'worldtile',39);assert(v.state.world.hp==40)
  tapButton(v,'worldtile',83);assert(v.state.world.map=='town');v:leave()
 end
 D.w=600;D.h=800
end)
test('animated walks stop on sleep and stale callbacks stay cancelled after waking',function()
 local v=view();v.state.animation='gentle';tapButton(v,'worldtile',6)
 assert(v.world_tick and #U.queue==1);local late=v.world_tick
 v:onSuspend();local saved=S.encode(v.state);assert(#U.queue==0 and not v.world_tick)
 late();assert(S.encode(v.state)==saved)
 v:onResume();saved=S.encode(v.state);late();assert(S.encode(v.state)==saved and #U.queue==0)
 v:leave()
end)
test('a new destination and navigation invalidate earlier walks',function()
 local v=view();v.state.animation='eco';tapButton(v,'worldtile',6);local late=v.world_tick
 tapButton(v,'worlddir','left');local saved=S.encode(v.state);late();assert(S.encode(v.state)==saved)
 tapButton(v,'worldtile',6);late=v.world_tick;v:go('worldhelp');saved=S.encode(v.state)
 late();assert(S.encode(v.state)==saved and #U.queue==0);v:leave()
end)
test('map transitions have finite callbacks and Off walks without a timer',function()
 for _,mode in ipairs({'gentle','eco','off'}) do
  local v=view();v.state.animation=mode;tapButton(v,'worldtile',6)
  if mode=='off' then assert(#U.queue==0) else assert(U:drain()<88) end
  assert(v.state.world.map=='meadow' and #U.queue==0 and not v.world_path);v:leave()
 end
end)
test('battle survives pause, save reload, sleep and orientation changes',function()
 local v=view();encounter(v);tapButton(v,'battleturn',1)
 local saved=S.encode(v.state);tapButton(v,'nav','home');tapButton(v,'nav','explore')
 assert(v.screen=='battle' and S.encode(v.state)==saved)
 v.state=assert(S.decode(saved,E));v:onSuspend();D.w=800;D.h=600;v:onResume()
 assert(v.screen=='battle' and S.encode(v.state)==saved and #U.queue==0)
 v:paintTo(bb,0,0);tapButton(v,'battleflee');assert(v.state.world.battle.status=='fled')
 tapButton(v,'battlefinish');assert(v.screen=='explore' and not v.state.world.battle);v:leave()
 D.w=600;D.h=800
end)
test('a failed turn save blocks further turns until the same state saves',function()
 local v=view();encounter(v);local save=v.owner.save
 v.owner.save=function(owner) owner.save_error=true;return nil,'Disk full' end
 tapButton(v,'battleturn',1);assert(v.world_save_failed and v.state.world.battle.turn==2)
 local saved=S.encode(v.state);tapButton(v,'battleturn',2);assert(S.encode(v.state)==saved)
 v.owner.save=function(owner) owner.save_error=nil;return save(owner) end
 tapButton(v,'worldretry');assert(not v.world_save_failed and S.encode(v.state)==saved)
 tapButton(v,'battleturn',1);assert(v.state.world.battle.turn==3);v:leave()
end)
test('battle animations do not advance turns and stop when the view closes',function()
 local v=view();encounter(v);v.state.animation='gentle'
 tapButton(v,'battleturn',1);assert(#U.queue==1)
 local saved=S.encode(v.state);U:drain();assert(S.encode(v.state)==saved)
 tapButton(v,'battleturn',2);assert(#U.queue==1);local late=v.tick
 v:leave();saved=S.encode(v.state);late();assert(S.encode(v.state)==saved and #U.queue==0)
end)
test('screensaver and restore locks block taps and queued walking',function()
 local v=view();local saved=S.encode(v.state);Device.screen_saver_mode=true
 tapButton(v,'worlddir','up');assert(S.encode(v.state)==saved);Device.screen_saver_mode=false
 v.state.animation='gentle';tapButton(v,'worldtile',6);local late=v.world_tick
 v.owner.backups={blocked=true};saved=S.encode(v.state);late();assert(S.encode(v.state)==saved and #U.queue==0)
 v.owner.backups=nil;v:leave()
end)
test('town menus choose a full party, train, equip and start the Tower through touch',function()
 local v=view();local w=v.state.world
 tapButton(v,'worldtile',25);tapButton(v,'worldtile',37);assert(v.screen=='worldparty')
 tapButton(v,'campslot',2);tapButton(v,'campchoose',7);assert(w.camp.party[2]==7)
 tapButton(v,'campslot',3);tapButton(v,'campchoose',1);assert(w.camp.party[3]==1)
 v:go('explore');tapButton(v,'worldtile',83);tapButton(v,'worldtile',57);assert(w.map=='dojo')
 tapButton(v,'worldtile',39);assert(v.screen=='worldmoves')
 tapButton(v,'camplearn',3);tapButton(v,'campmoveslot',2);tapButton(v,'campequip',3)
 assert(w.camp.training['25'].slots[2]==3)
 v:go('explore');tapButton(v,'worldtile',83);tapButton(v,'worldtile',65);tapButton(v,'worldtile',39)
 assert(v.screen=='worldtower');tapButton(v,'camptower');assert(v.screen=='battle' and w.camp.tower.floor==1)
 tapButton(v,'nav','worldswitch');tapButton(v,'campswitch',7);assert(v.screen=='battle' and w.partner==7 and w.battle.turn==2)
 v:onSuspend();local saved=S.encode(v.state);v:onResume();assert(S.encode(v.state)==saved)
 v:leave()
end)
test('failed town saves block purchases, party edits and Tower choices until retry',function()
 local v=view();local w=v.state.world;w.map='shop';v:go('worldshop')
 local save=v.owner.save;v.owner.save=function(owner) owner.save_error=true;return nil,'Disk full' end
 tapButton(v,'campbuy','potion');local saved=S.encode(v.state)
 assert(v.world_save_failed);tapButton(v,'campbuy','potion');assert(S.encode(v.state)==saved)
 v.owner.save=function(owner) owner.save_error=nil;return save(owner) end
 tapButton(v,'worldretry');assert(not v.world_save_failed);tapButton(v,'campbuy','potion');assert(w.camp.potions==2)
 v:leave()
end)
test('directional pad choice persists and standing still schedules no repaints',function()
 local v=view();v:go('worldhelp');tapButton(v,'campdpad');assert(not v.state.world.camp.dpad)
 v.state=assert(S.decode(S.encode(v.state),E));v:go('explore');v:paintTo(bb,0,0)
 for _,b in ipairs(v.buttons) do assert(b.action~='worlddir') end
 assert(#U.queue==0);v:leave()
end)

test('reopening moves after replacing a party member trains the current partner',function()
 local v=view();local w=v.state.world
 tapButton(v,'worldtile',25);tapButton(v,'worldtile',37)
 tapButton(v,'campslot',2);tapButton(v,'campchoose',7)
 tapButton(v,'nav','worldmoves');tapButton(v,'campmember',7);tapButton(v,'campmoveslot',2)
 v:go('worldparty');tapButton(v,'campslot',2);tapButton(v,'campchoose',1)
 v:go('explore');tapButton(v,'worldtile',83);tapButton(v,'worldtile',57);tapButton(v,'worldtile',39)
 tapButton(v,'camplearn',3);tapButton(v,'campequip',3)
 assert(w.camp.training['25'] and w.camp.training['25'].slots[1]==3,'move menu kept a removed party member')
 assert(not w.camp.training['7']);v:leave()
end)
test('the map party overview shows HP and moves without allowing changes',function()
 local v=view();local w=v.state.world;local before=S.encode(v.state)
 tapButton(v,'nav','worldparty');assert(v.screen=='worldparty')
 local lines={};local text=v.text
 v.text=function(self,buffer,line,...) lines[line]=true;return text(self,buffer,line,...) end
 v:paintTo(bb,0,0)
 assert(lines['40 / 40 HP'] and lines['1. Quick Attack'] and lines['2. Thunder Shock'])
 for _,button in ipairs(v.buttons) do assert(button.action~='campslot' and button.arg~='worldmoves') end
 assert(not E.world.town.party(v.state,E,1,7) and not E.world.town.equip(v.state,25,1,2))
 tapButton(v,'nav','explore');assert(v.screen=='explore' and S.encode(v.state)==before);v:leave()
end)

test('quest progress changes after each objective and Pikachu leaves the woods',function()
 local v=view(7);local w=v.state.world;local lines={};local text=v.text;local sprite=v.classic;local lost=0
 v.text=function(self,buffer,line,...) lines[line]=true;return text(self,buffer,line,...) end
 v.classic=function(self,buffer,id,...) if id=="25-walk-down-0" then lost=lost+1 end;return sprite(self,buffer,id,...) end
 w.map='woods';v:paintTo(bb,0,0);assert(lost==1)
 w.map='town';v:go('worldquests');v:paintTo(bb,0,0)
 assert(lines["Mira's Pikachu / Find"] and lines['Reward: 4 berries and a ranger outfit'])
 w.camp.quests=21;lines={};v:paintTo(bb,0,0)
 assert(lines["Mira's Pikachu / Return"] and lines["Theo's cave tracks / Return"] and lines["Ari's practice / Return"])
 for i=1,3 do tapButton(v,'campquest',i) end
 lines={};v:paintTo(bb,0,0);assert(lines["Mira's Pikachu / Completed"] and lines['Received: 4 berries and a ranger outfit'])
 w.map='woods';v:go('explore');lost=0;v:paintTo(bb,0,0);assert(lost==0);v:leave()
end)

test('Tower preparation shows moves and benefits preview the next opponent',function()
 local v=view();local w=v.state.world;local A=E.world.town
 w.map='centre';assert(A.party(v.state,E,2,7) and A.party(v.state,E,3,1))
 w.map='tower';v:go('worldtower');local lines={};local text=v.text
 v.text=function(self,buffer,line,...) lines[line]=true;return text(self,buffer,line,...) end
 v:paintTo(bb,0,0)
 assert(lines['1. Quick Attack'] and lines['2. Withdraw'] and lines['2. Leech Seed'])
 tapButton(v,'camptower');w.battle.team={10,43,19}
 local classic=v.classic;local portrait=false
 v.classic=function(self,buffer,name,...) if name=='portrait-gentleman' then portrait=true end;return classic(self,buffer,name,...) end
 v:paintTo(bb,0,0);assert(portrait)
 w.battle.hp=1;tapButton(v,'battleturn',1);portrait=false;v:paintTo(bb,0,0);assert(not portrait)
 while w.battle.status=='active' do w.battle.hp=1;tapButton(v,'battleturn',1) end
 tapButton(v,'battlefinish')
 local team=E.world.battle.rollTeam({seed=v.state.seed},A.towerFoe(w.camp.tower.run,2),3)
 local nextfoe={id=team[1],type=E.species[team[1]].types:match('^%a+')}
 lines={};v:paintTo(bb,0,0);assert(lines['Next: '..E.name(nextfoe.id)])
 assert(lines[E.species[nextfoe.id].types..' / attacks with '..nextfoe.type])
 tapButton(v,'nav','worldparty');tapButton(v,'nav','worldtower');tapButton(v,'campbenefit',1)
 assert(w.battle.foe==A.towerFoe(w.camp.tower.run,2) and table.concat(w.battle.team,',')==table.concat(team,','));v:leave()
end)
print('WORLD UI: '..checks..' movement, lifecycle, save failure and touch checks passed')
os.time=original_time
