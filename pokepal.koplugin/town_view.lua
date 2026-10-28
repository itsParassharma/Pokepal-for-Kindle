return function(View,UIManager)
 function View:paintTownMenu(bb)
  local E=self.engine;local W=E.world;local A=W.town;local w=self.state.world;local c=w and w.camp
  if not c then self:paintWorld(bb);return end
  local screen=self.screen;local blocked=self.world_save_failed or self.owner.save_error
  if screen=="worldparty" then
   self:title(bb,"Your party","Choose three friends. Each keeps its own battle HP.")
   for i=1,3 do
    local id=c.party[i];local y=203+(i-1)*131
    if id then self:sprite(bb,id,42,y,80,1,"idle") end
    self:button(bb,i.." / "..(id and E.name(id).." / "..A.hp(w,id).." HP" or "Choose a Pokemon"),137,y+8,431,54,"campslot",i,nil,blocked)
   end
   self:button(bb,"Equipped moves",32,608,536,44,"nav","worldmoves")
  elseif screen=="worldchoose" then
   self:title(bb,"Choose party slot "..(self.party_slot or 1),"All 386 are available; a party cannot contain duplicates.")
   local region=self.party_region or 1;local first=({1,152,252})[region];local last=({151,251,386})[region]
   for i,name in ipairs({"Kanto","Johto","Hoenn"}) do self:button(bb,name,32+(i-1)*182,181,172,40,"campregion",i,nil,false,i==region) end
   local page=self.party_page or 1;local pages=math.ceil((last-first+1)/9)
   for i=0,8 do
    local id=first+(page-1)*9+i
    if id<=last then
     local x,y=32+i%3*182,234+math.floor(i/3)*117
     self:sprite(bb,id,x+52,y,68,1,"idle")
     self:button(bb,E.name(id),x,y+69,172,40,"campchoose",id,nil,blocked)
    end
   end
   self:button(bb,"Previous",32,608,172,42,"camppage",-1,nil,page==1)
   self:text(bb,page.." / "..pages,214,618,18,172,false,true)
   self:button(bb,"Next",396,608,172,42,"camppage",1,nil,page==pages)
  elseif screen=="worldmoves" then
   local id=self.party_move_id or w.partner
   self:title(bb,"Battle moves","Choose two learned moves. Lessons are at the dojo.")
   for i,member in ipairs(c.party) do self:button(bb,E.name(member),32+(i-1)*182,181,172,42,"campmember",member,nil,false,member==id) end
   local slot=self.move_slot or 1;local r=c.training[tostring(id)] or {learned=3,slots={1,2}}
   for i=1,2 do self:button(bb,"Equip slot "..i,32+(i-1)*274,232,262,40,"campmoveslot",i,nil,false,i==slot) end
   for i,move in ipairs(W.battle.catalog(E,id)) do
    local learned=A.has(r.learned,i);local y=289+(i-1)*87
    local equipped=r.slots[1]==i and " [1]" or r.slots[2]==i and " [2]" or ""
    self:button(bb,(learned and move.name..equipped or "Learn "..move.name.." / 2 berries"),32,y,536,44,learned and "campequip" or "camplearn",i,nil,blocked or w.battle~=nil or c.tower~=nil)
    self:text(bb,move.kind=="quick" and "Interrupts charging" or move.kind=="break" and "Breaks a guard" or move.kind=="guard" and "Blocks; strengthens your next hit" or move.kind=="seed" and "Drains HP for three turns" or "Restores 3 HP when it hits",42,y+49,16,516)
   end
   if w.map=="dojo" then self:button(bb,"Practice battle",32,638,262,40,"camppractice",nil,nil,blocked);self:button(bb,"Care training",306,638,262,40,"nav","train") end
  elseif screen=="worldshop" then
   self:title(bb,"Fern Shop","Berries buy supplies and a place that feels like home.")
   local items={{"Potion / 2 berries / "..c.potions.." packed","potion"},{"Ranger outfit / "..(A.has(c.outfits,1) and "owned" or "5 berries"),1},
    {"Tower outfit / "..(A.has(c.outfits,2) and "owned" or "8 berries"),2},{"Original outfit",0}}
   for i,item in ipairs(items) do self:button(bb,item[1],32,196+(i-1)*83,536,56,"campbuy",item[2],nil,blocked) end
   self:button(bb,"Decorations for your room",32,528,536,54,"nav","decorations")
   self:button(bb,"Use potion / +16 HP",32,605,536,44,"camppotion",nil,nil,blocked or c.potions==0 or w.hp==40 or w.hp==0)
  elseif screen=="worldquests" then
   self:title(bb,"Town neighbours","Small favours open routes and reward exploration.")
   local names={"Mira's lost Pikachu","Theo's cave tracks","Ari's Tower practice"}
   local lines={"Find Pikachu in Fern Woods, then return here.","Inspect Moon Cave's tracks, then report back.","Win a practice battle at the training dojo."}
   for i,name in ipairs(names) do
    local y=196+(i-1)*144
    self:text(bb,name,32,y,22,536,true);self:wrapped(bb,lines[i],y+35,17)
    self:button(bb,A.has(c.quests,i*2) and "Speak again" or "Talk / claim reward",32,y+80,536,45,"campquest",i,nil,blocked)
   end
  elseif screen=="worldtower" then
   local t=c.tower
   self:title(bb,"Battle Tower",t and "Battle "..t.floor.." won. Choose one benefit." or "Five trainers and a boss. Current rank: "..c.rank)
   if t and t.choice then
    local names={"Heal the whole party by 16 HP","Improve defensive moves","Heal 3 HP whenever you switch"}
    for i,name in ipairs(names) do self:button(bb,name,32,226+(i-1)*124,536,70,"campbenefit",i,nil,blocked) end
    self:wrapped(bb,"Benefits last for this run. Your choice starts the next battle.",603,18)
   else
    for i,id in ipairs(c.party) do self:sprite(bb,id,48+(i-1)*182,215,140,1,"idle");self:text(bb,E.name(id),32+(i-1)*182,366,18,172,true,true) end
    self:wrapped(bb,"All partners use 40 HP and fixed move power. Levels do not change Tower strength.",427,19)
    self:wrapped(bb,"Bring three different Pokemon. Switching costs a turn. Supplies stay outside.",499,18)
    self:button(bb,"Start a new run",32,594,536,58,"camptower",nil,nil,blocked or #c.party~=3)
   end
  elseif screen=="worldswitch" then
   self:title(bb,"Switch Pokemon","Switching uses your turn. Read the next attack first.")
   for i,id in ipairs(c.party) do
    local y=208+(i-1)*135;self:sprite(bb,id,42,y,88,1,"idle")
    self:button(bb,E.name(id).." / "..A.hp(w,id).." HP",147,y+17,421,60,"campswitch",id,nil,blocked or id==w.partner or A.hp(w,id)==0)
   end
  end
  if self.world_message then self:wrapped(bb,self.world_message,684,14) end
  if blocked then self:button(bb,"Retry save",32,733,536,36,"worldretry")
  else self:button(bb,screen=="worldswitch" and "Back to battle" or c.tower and "Pause at home" or "Back to Explore",32,733,536,36,"nav",screen=="worldswitch" and "battle" or c.tower and "home" or "explore") end
 end
 function View:townTap(action,arg)
  if action:sub(1,4)~="camp" then return false end
  local E=self.engine;local A=E.world.town;local w=self.state.world;local c=w and w.camp
  if not c or self.world_save_failed or self.owner.save_error then return true end
  self:stopAnimation();self:freeImages();local changed,message
  if action=="campslot" then self.party_slot=arg;self.party_page=1;self:go("worldchoose")
  elseif action=="campregion" then self.party_region=arg;self.party_page=1
  elseif action=="camppage" then self.party_page=(self.party_page or 1)+arg
  elseif action=="campchoose" then changed,message=A.party(self.state,E,self.party_slot or 1,arg);if changed then self:go("worldparty") end
  elseif action=="campmember" then self.party_move_id=arg
  elseif action=="campmoveslot" then self.move_slot=arg
  elseif action=="campequip" then changed,message=A.equip(self.state,self.party_move_id or w.partner,self.move_slot or 1,arg)
  elseif action=="camplearn" then changed,message=A.learn(self.state,E,self.party_move_id or w.partner,arg)
  elseif action=="camppractice" then changed,message=A.practice(self.state,E)
  elseif action=="campbuy" then changed,message=A.buy(self.state,arg)
  elseif action=="camppotion" then changed,message=A.potion(self.state,E)
  elseif action=="campquest" then changed,message=A.quest(self.state,arg)
  elseif action=="camptower" then changed,message=A.startTower(self.state,E)
  elseif action=="campbenefit" then changed,message=A.benefit(self.state,E,arg)
  elseif action=="campswitch" then changed,message=A.switch(self.state,E,arg)
  elseif action=="campdpad" then c.dpad=not c.dpad;changed=true
  end
  self.world_message=message
  if changed then self.world_dirty=true;self:saveWorld();if w.battle then self:go("battle") end end
  UIManager:setDirty(self,"ui");return true
 end
end
