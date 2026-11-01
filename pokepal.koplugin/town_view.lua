return function(View,UIManager)
 dofile(debug.getinfo(1,"S").source:sub(2):match("^(.*)/").."/collection_view.lua")(View)
 function View:paintPartyCards(bb,editable,tower)
  local E=self.engine;local w=self.state.world;local A=E.world.town
  for i=1,6 do
   local id=w.camp.party[i];local y=184+(i-1)*68
   if id then
    self:classic(bb,id.."-front",36,y+2,56)
    self:text(bb,E.displayName(self.state,id),104,y+2,19,160,true)
    local hp=A.hp(w,id)
    self:text(bb,tower and "Starts at 40 HP" or hp==0 and "Fainted" or hp.." / 40 HP",104,y+33,15,174)
    local moves=E.world.battle.equipped(E,{ally=id,moves=A.moves(self.state,id)})
    for slot,move in ipairs(moves) do self:text(bb,slot..". "..move.name,274,y+4+(slot-1)*26,14,172) end
    if editable then self:button(bb,"Manage",448,y+6,120,42,"campdetail",id) end
   elseif editable then self:button(bb,"Add from box",104,y+6,464,42,"campslot",i,nil,i>#w.camp.party+1)
   else self:text(bb,"Empty slot",104,y+17,20,464) end
  end
 end
 function View:paintTownMenu(bb)
  local E=self.engine;local W=E.world;local A=W.town;local w=self.state.world;local c=w and w.camp
  if not c then self:paintWorld(bb);return end
  local screen=self.screen;local blocked=self.world_save_failed or self.owner.save_error
  if self:paintCollection(bb,blocked) then
  elseif screen=="worldparty" then
   local editable=w.map=="centre" and not w.battle and not c.tower and not blocked and not self.state.resting and self.state.trip==0
   self:title(bb,"Your party",#c.party.." of 6 slots / Empty slots stay empty.")
   self:paintPartyCards(bb,editable,false)
   self:button(bb,"Pokemon box",32,600,262,40,"nav","worldbox")
   self:button(bb,"Berry bag",306,600,262,40,"nav","worldbag")
   if editable then self:button(bb,"Equipped moves",32,648,536,38,"nav","worldmoves") end
  elseif screen=="worldmoves" then
   local id=self.party_move_id or w.partner
   self:title(bb,"Battle moves","Learn at the dojo; equip two moves.")
   for i,member in ipairs(c.party) do self:button(bb,E.name(member),32+(i-1)%3*182,181+math.floor((i-1)/3)*47,172,40,"campmember",member,nil,false,member==id) end
   local slot=self.move_slot or 1;local r=c.training[tostring(id)] or {learned=3,slots={1,2}}
   for i=1,2 do self:button(bb,"Equip slot "..i,32+(i-1)*274,279,262,40,"campmoveslot",i,nil,false,i==slot) end
   for i,move in ipairs(W.battle.catalog(E,id)) do
    local learned=A.has(r.learned,i);local y=333+(i-1)*76
    local equipped=r.slots[1]==i and " [1]" or r.slots[2]==i and " [2]" or ""
    self:button(bb,(learned and move.name..equipped or "Learn "..move.name.." / "..(i==4 and 4 or 2).." berries"),32,y,536,44,learned and "campequip" or "camplearn",i,nil,blocked or w.battle~=nil or c.tower~=nil)
    self:text(bb,W.battle.description(move),42,y+48,15,516)
   end
   if w.map=="dojo" then self:button(bb,"Practice battle",32,650,262,36,"camppractice",nil,nil,blocked);self:button(bb,"Care training",306,650,262,36,"nav","train") end
  elseif screen=="worldshop" then
   self:title(bb,"Fern Shop",self.state.berries.." berries / Healing and PC storage are free.")
   local items={{"Potion / 2 berries / "..c.potions.." packed","potion"},{"Revive / 4 berries / "..c.revives.." packed","revive"},{"Ranger outfit / "..(A.has(c.outfits,1) and "owned" or "5 berries"),1},
    {"Tower outfit / "..(A.has(c.outfits,2) and "owned" or "8 berries"),2},{"Original outfit",0}}
   for i,item in ipairs(items) do self:button(bb,item[1],32,186+(i-1)*68,536,50,"campbuy",item[2],nil,blocked) end
   self:button(bb,"Decorations for your room",32,532,536,54,"nav","decorations")
   self:button(bb,"Use potion / +16 HP",32,605,536,44,"camppotion",nil,nil,blocked or c.potions==0 or w.hp==40 or w.hp==0)
  elseif screen=="worldquests" then
   self:title(bb,"Town neighbours","Check your progress and collect rewards.")
   local names={"Mira's Pikachu","Theo's cave tracks","Ari's practice"}
   local people={"Mira","Theo","Ari"}
   local tasks={"Find Pikachu in Fern Woods.","Find the tracks in Moon Cave.","Win a practice battle at the dojo."}
   local ready={"Pikachu is safe. Speak to Mira.","Tell Theo about the Onix tracks.","Speak to Ari after your practice win."}
   local done={"Pikachu is home with Mira.","The cave shortcut is open.","Ari is ready for the Tower."}
   local rewards={"4 berries and a ranger outfit","A plant for your room","3 berries"}
   local routes={"Opens the Coast and woods shortcut.","Opens the cave shortcut.",""}
   for i,name in ipairs(names) do
    local complete=A.has(c.quests,i*2);local found=A.has(c.quests,i*2-1);local y=184+(i-1)*155
    local status=complete and "Completed" or found and "Return" or i==3 and "Practise" or "Find"
    self:text(bb,name.." / "..status,32,y,20,536,true)
    self:text(bb,complete and done[i] or found and ready[i] or tasks[i],32,y+31,16,536)
    self:text(bb,(complete and "Received: " or "Reward: ")..rewards[i],32,y+56,15,536)
    self:text(bb,routes[i],32,y+78,15,536)
    self:button(bb,found and not complete and "Claim reward" or "Speak to "..people[i],32,y+103,536,36,"campquest",i,nil,blocked)
   end
  elseif screen=="worldtower" then
   local t=c.tower
   local roster=W.battle.rollTeam({seed=self.state.seed},A.towerFoe(t and t.run or c.runs+1,t and t.floor+1 or 1),#c.party)
   local nextfoe={id=roster[1],type=E.species[roster[1]].types:match("^%a+")}
   self:title(bb,"Battle Tower",t and "Battle "..t.floor.." won. Choose a benefit." or "Rank "..c.rank..". Five trainers, then a boss.")
   if t and t.choice then
    self:text(bb,"Next: "..E.name(nextfoe.id),32,193,21,536,true)
    self:text(bb,E.species[nextfoe.id].types.." / attacks with "..nextfoe.type,32,226,16,536)
    local names={"Heal the whole party by 16 HP","Take 1 less damage per hit","Heal 3 HP whenever you switch"}
    for i,name in ipairs(names) do self:button(bb,name,32,267+(i-1)*103,536,65,"campbenefit",i,nil,blocked) end
    self:wrapped(bb,"Your choice starts the next battle. Benefits last for this run.",562,18)
    self:button(bb,"Check your party",32,632,536,38,"nav","worldparty")
   else
    self:paintPartyCards(bb,false,true)
    self:text(bb,"First: "..E.name(nextfoe.id).." / "..E.species[nextfoe.id].types,32,598,17,536,true)
    self:text(bb,"Teams match your party size. Entry: 3 berries.",32,626,16,536)
    self:button(bb,(A.has(c.badges,3) and "Start / 3 berries" or "Earn the Stone Badge"),32,650,536,38,"camptower",nil,nil,blocked or not A.has(c.badges,3) or self.state.berries<3)
   end
  elseif screen=="worldswitch" or screen=="worldrevive" then
   local revive=screen=="worldrevive"
   self:title(bb,revive and "Use a revive" or "Switch Pokemon",revive and "Restores a fainted member to 20 HP." or w.hp==0 and "Free replacement. Choose who enters next." or "Switching spends a turn.")
   for i,id in ipairs(c.party) do
    local y=184+(i-1)*78;self:classic(bb,id.."-front",42,y,60)
    self:button(bb,E.name(id).." / "..A.hp(w,id).." HP",130,y,438,44,revive and "camprevive" or "campswitch",id,nil,blocked or (revive and (A.hp(w,id)~=0 or c.revives==0) or not revive and (id==w.partner or A.hp(w,id)==0)))
    local detail=revive and (A.hp(w,id)==0 and "Revive to 20 HP." or "Does not need a revive.") or id==w.partner and "Already battling." or A.hp(w,id)==0 and "Fainted. Needs healing."
    if not detail and w.battle then
     local taken,hp=A.switchPreview(self.state,E,id)
     detail="Takes "..taken.." damage. "..(hp==0 and "Will faint." or "Ends at "..hp.." HP.")
    end
    self:text(bb,detail or "",130,y+49,15,438)
   end
  end
  if self.world_message then self:wrapped(bb,self.world_message,687,13) end
  if blocked then self:button(bb,"Retry save",32,733,536,36,"worldretry")
  else
   local towerparty=screen=="worldparty" and c.tower and c.tower.choice
   local back=(screen=="worldboxsearch" or screen=="worldboxname") and "worldbox" or w.battle and "battle" or towerparty and "worldtower" or c.tower and "home" or "explore"
   self:button(bb,back=="battle" and "Back to battle" or back=="worldbox" and "Back to box" or towerparty and "Back to Tower" or c.tower and "Pause at home" or "Back to Explore",32,733,536,36,"nav",back)
  end
 end
 function View:townTap(action,arg)
  if action:sub(1,4)~="camp" then return false end
  local E=self.engine;local A=E.world.town;local w=self.state.world;local c=w and w.camp
  if not c or self.world_save_failed or self.owner.save_error then return true end
  self:stopAnimation();self:freeImages();local changed,message
  local handled;handled,changed,message=self:collectionTap(action,arg)
  if handled then
  elseif action=="campslot" then self.box_page=1;self:go("worldbox")
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
