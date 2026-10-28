return function(View,UIManager)
 function View:paintPartyCards(bb,editable,tower)
  local E=self.engine;local w=self.state.world;local A=E.world.town
  for i=1,3 do
   local id=w.camp.party[i];local y=190+(i-1)*132
   if id then
    self:sprite(bb,id,42,y+7,80,1,"idle")
    self:text(bb,E.name(id),137,y+2,21,editable and 300 or 431,true)
    local hp=A.hp(w,id)
    self:text(bb,tower and "Starts at 40 HP" or hp==0 and "Fainted" or hp.." / 40 HP",137,y+32,16,431)
    local moves=E.world.battle.equipped(E,{ally=id,moves=A.moves(self.state,id)})
    for slot,move in ipairs(moves) do self:text(bb,slot..". "..move.name,137,y+57+(slot-1)*25,16,431) end
    if editable then self:button(bb,"Change",448,y,120,38,"campslot",i) end
   elseif editable then self:button(bb,"Choose a Pokemon",137,y+15,431,54,"campslot",i)
   else self:text(bb,"Empty slot",137,y+28,20,431) end
  end
 end
 function View:paintTownMenu(bb)
  local E=self.engine;local W=E.world;local A=W.town;local w=self.state.world;local c=w and w.camp
  if not c then self:paintWorld(bb);return end
  local screen=self.screen;local blocked=self.world_save_failed or self.owner.save_error
  if screen=="worldparty" then
   local editable=w.map=="centre" and not w.battle and not c.tower and not blocked and not self.state.resting and self.state.trip==0
   self:title(bb,"Your party","HP and equipped moves for each partner.")
   self:paintPartyCards(bb,editable,false)
   if editable then self:button(bb,"Equipped moves",32,608,536,44,"nav","worldmoves")
   else self:wrapped(bb,"Visit the Centre to heal or change your party.",608,18) end
  elseif screen=="worldchoose" then
   self:title(bb,"Choose party slot "..(self.party_slot or 1),"All 386 available. No duplicates.")
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
   self:title(bb,"Battle moves","Learn at the dojo; equip two moves.")
   for i,member in ipairs(c.party) do self:button(bb,E.name(member),32+(i-1)*182,181,172,42,"campmember",member,nil,false,member==id) end
   local slot=self.move_slot or 1;local r=c.training[tostring(id)] or {learned=3,slots={1,2}}
   for i=1,2 do self:button(bb,"Equip slot "..i,32+(i-1)*274,232,262,40,"campmoveslot",i,nil,false,i==slot) end
   for i,move in ipairs(W.battle.catalog(E,id)) do
    local learned=A.has(r.learned,i);local y=289+(i-1)*87
    local equipped=r.slots[1]==i and " [1]" or r.slots[2]==i and " [2]" or ""
    self:button(bb,(learned and move.name..equipped or "Learn "..move.name.." / 2 berries"),32,y,536,44,learned and "campequip" or "camplearn",i,nil,blocked or w.battle~=nil or c.tower~=nil)
    self:text(bb,W.battle.description(move),42,y+49,16,516)
   end
   if w.map=="dojo" then self:button(bb,"Practice battle",32,638,262,40,"camppractice",nil,nil,blocked);self:button(bb,"Care training",306,638,262,40,"nav","train") end
  elseif screen=="worldshop" then
   self:title(bb,"Fern Shop","Supplies, outfits and room decorations.")
   local items={{"Potion / 2 berries / "..c.potions.." packed","potion"},{"Ranger outfit / "..(A.has(c.outfits,1) and "owned" or "5 berries"),1},
    {"Tower outfit / "..(A.has(c.outfits,2) and "owned" or "8 berries"),2},{"Original outfit",0}}
   for i,item in ipairs(items) do self:button(bb,item[1],32,196+(i-1)*83,536,56,"campbuy",item[2],nil,blocked) end
   self:button(bb,"Decorations for your room",32,528,536,54,"nav","decorations")
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
   local nextfoe=W.battle.foes[A.towerFoe(t and t.run or c.runs+1,t and t.floor+1 or 1)]
   self:title(bb,"Battle Tower",t and "Battle "..t.floor.." won. Choose a benefit." or "Rank "..c.rank..". Five trainers, then a boss.")
   if t and t.choice then
    self:text(bb,"Next: "..E.name(nextfoe.id),32,193,21,536,true)
    self:text(bb,E.species[nextfoe.id].types.." / attacks with "..nextfoe.type,32,226,16,536)
    local names={"Heal the whole party by 16 HP","Improve defensive moves","Heal 3 HP whenever you switch"}
    for i,name in ipairs(names) do self:button(bb,name,32,267+(i-1)*103,536,65,"campbenefit",i,nil,blocked) end
    self:wrapped(bb,"Your choice starts the next battle. Benefits last for this run.",562,18)
    self:button(bb,"Check your party",32,632,536,38,"nav","worldparty")
   else
    self:paintPartyCards(bb,false,true)
    self:text(bb,"First: "..E.name(nextfoe.id).." / "..E.species[nextfoe.id].types,32,573,17,536,true)
    self:text(bb,"Care levels do not affect battle strength.",32,607,16,536)
    self:button(bb,"Start a new run",32,640,536,38,"camptower",nil,nil,blocked or #c.party~=3)
   end
  elseif screen=="worldswitch" then
   self:title(bb,"Switch Pokemon","Switching spends a turn.")
   for i,id in ipairs(c.party) do
    local y=208+(i-1)*135;self:sprite(bb,id,42,y,88,1,"idle")
    self:button(bb,E.name(id).." / "..A.hp(w,id).." HP",147,y+17,421,60,"campswitch",id,nil,blocked or id==w.partner or A.hp(w,id)==0)
    local detail=id==w.partner and "Already battling." or A.hp(w,id)==0 and "Fainted. Needs healing."
    if not detail and w.battle then
     local taken,hp=A.switchPreview(self.state,E,id)
     detail="Takes "..taken.." damage. "..(hp==0 and "Will faint." or "Ends at "..hp.." HP.")
    end
    self:text(bb,detail or "",147,y+88,15,421)
   end
  end
  if self.world_message then self:wrapped(bb,self.world_message,684,14) end
  if blocked then self:button(bb,"Retry save",32,733,536,36,"worldretry")
  else
   local towerparty=screen=="worldparty" and c.tower and c.tower.choice
   self:button(bb,screen=="worldswitch" and "Back to battle" or towerparty and "Back to Tower" or c.tower and "Pause at home" or "Back to Explore",32,733,536,36,"nav",screen=="worldswitch" and "battle" or towerparty and "worldtower" or c.tower and "home" or "explore")
  end
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
