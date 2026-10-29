return function(View)
 local types={"All","Normal","Fire","Water","Electric","Grass","Ice","Fighting","Poison","Ground","Flying","Psychic","Bug","Rock","Ghost","Dragon","Dark","Steel","Fairy"}
 function View:paintCollection(bb,blocked)
  local E=self.engine;local s=self.state;local w=s.world;local c=w.camp;local A=E.world.town;local screen=self.screen
  local editable=A.canManage(s) and not blocked
  if screen=="worldbox" or screen=="worldchoose" then
   self:title(bb,"Pokemon box",E.count(c.box).." collected / "..#c.party.." in party / "..s.berries.." berries")
   local kind=types[self.box_type or 1]
   self:button(bb,"Search",32,181,172,40,"campsearch")
   self:button(bb,kind,214,181,172,40,"campfilter")
   self:button(bb,"Favourites",396,181,172,40,"campfavourites",nil,nil,false,self.box_favourites)
   local list=A.boxList(s,E,self.box_query,kind,self.box_favourites)
   local pages=math.max(1,math.ceil(#list/5));self.box_page=math.min(self.box_page or 1,pages)
   for row=1,5 do
    local id=list[(self.box_page-1)*5+row];local y=236+(row-1)*74
    if id then
     self:classic(bb,id.."-front",32,y,60)
     self:text(bb,E.displayName(s,id),104,y+4,20,330,true)
     self:text(bb,E.species[id].types..(A.member(c,id) and " / In party" or " / In box"),104,y+36,15,330)
     self:button(bb,"View",448,y+5,120,44,"campdetail",id)
    end
   end
   if #list==0 then self:wrapped(bb,"No Pokemon match this search. Clear the search or change the filters.",252,20) end
   self:button(bb,"Previous",32,624,172,40,"campboxpage",-1,nil,self.box_page==1)
   self:text(bb,self.box_page.." / "..pages,214,634,18,172,false,true)
   self:button(bb,"Next",396,624,172,40,"campboxpage",1,nil,self.box_page==pages)
   if self.box_query and self.box_query~="" then self:text(bb,"Search: "..self.box_query,32,672,15,536) end
  elseif screen=="worldboxdetail" then
   local id=self.box_id or w.partner;local member=A.member(c,id);local p=id==s.species and s or s.partners and s.partners[tostring(id)] or {xp=0,bond=0}
   self:title(bb,E.displayName(s,id),E.name(id).." / "..E.species[id].types)
   self:classic(bb,id.."-front",236,179,128)
   self:text(bb,(member and "In party / slot "..member or "In box").." / "..A.hp(w,id).." of 40 HP",32,319,20,536,true,true)
   self:text(bb,p.xp.." XP / "..p.bond.." bond",32,353,18,536,false,true)
   for i,m in ipairs(E.world.battle.equipped(E,{ally=id,moves=A.moves(s,id)})) do self:text(bb,i..". "..m.name,32,389+(i-1)*28,18,536,false,true) end
   if member then
    self:button(bb,"Make lead",32,453,262,44,"camplead",id,nil,not editable or w.partner==id)
    self:button(bb,"Move to box",306,453,262,44,"campdeposit",id,nil,not editable or #c.party==1)
   else self:button(bb,"Add to party",32,453,536,44,"campwithdraw",id,nil,not editable or #c.party>=6) end
   local fav=s.companion and s.companion.favourites[tostring(id)]
   self:button(bb,fav and "Unfavourite" or "Favourite",32,511,262,44,"campfavourite",id,nil,blocked,fav)
   self:button(bb,"Nickname",306,511,262,44,"campname",id,nil,blocked)
   self:wrapped(bb,editable and (#c.party==6 and "Your party is full. Move a member to the box to make room." or "The PC keeps HP, moves, names and progress.") or "Visit the Centre to change your party. Storage and healing are free.",577,18)
   self:button(bb,"Back to box",32,642,536,38,"nav","worldbox")
  elseif screen=="worldboxsearch" or screen=="worldboxname" then
   local naming=screen=="worldboxname"
   self:title(bb,naming and "Choose a nickname" or "Search your box",naming and "Up to 12 characters." or "Search by name, nickname or Pokedex number.")
   self:outline(bb,32,198,536,58);self:text(bb,self.box_text or "",48,211,25,504,true,true)
   self:paintKeys(bb,"campkey")
   self:button(bb,self.uppercase and "abc" or "ABC",32,553,172,46,"campcase")
   self:button(bb,"Space",214,553,172,46,"campkey"," ")
   self:button(bb,"Delete",396,553,172,46,"campdelete")
   self:button(bb,"Clear",32,628,262,46,"campclear")
   self:button(bb,naming and "Save name" or "Search",306,628,262,46,"camptextsave")
  elseif screen=="worldgym" then
   self:title(bb,"Fern Gym",s.berries.." berries / First badge wins award 5 berries.")
   for i,leader in ipairs(A.leaders) do
    local y=186+(i-1)*158;local owned=A.has(c.badges,i);local unlocked=i==1 or A.has(c.badges,i-1)
    self:text(bb,leader.name.." / "..leader.theme,32,y,23,536,true)
    self:text(bb,leader.badge.." Badge"..(owned and " / Earned" or ""),32,y+34,18,536)
    self:text(bb,"Opens: "..leader.opens,32,y+63,16,536)
    self:button(bb,owned and "Rematch" or unlocked and "Challenge" or "Earn the previous badge",32,y+98,536,44,"campgym",i,nil,blocked or not unlocked or w.hp==0)
   end
  elseif screen=="worldbag" then
   self:title(bb,"Berry bag",s.berries.." berries / Supplies use a turn in battle.")
   self:button(bb,"Potion / "..c.potions.." packed / +16 HP",32,190,536,50,"camppotion",nil,nil,blocked or c.potions==0 or w.hp==0 or w.hp==40 or c.tower~=nil)
   self:button(bb,"Revive / "..c.revives.." packed / 20 HP",32,255,536,50,"nav","worldrevive",nil,blocked or c.revives==0 or c.tower~=nil or w.battle and w.hp==0)
   local recruit,reason=A.canRecruit(s,E)
   self:button(bb,"Offer 3 berries / Befriend",32,320,536,50,"camprecruit",nil,nil,blocked or not recruit)
   self:wrapped(bb,recruit and "This Pokemon will join your box. You can then choose an empty party slot." or reason,385,18)
   self:text(bb,"Earn berries",32,474,21,536,true)
   self:wrapped(bb,"Collect the daily basket at home. Reading rewards, expeditions, discoveries and first victories add more.",509,18)
   self:text(bb,"Spend berries",32,588,21,536,true)
   self:wrapped(bb,"Recruit 3 / Potion 2 / Revive 4 / Lessons 2 or 4 / Tower 3. Outfits and decorations use berries too.",623,17)
  else return false end
  return true
 end
 function View:collectionTap(action,arg)
  local E=self.engine;local s=self.state;local w=s.world;local c=w.camp;local A=E.world.town
  if action=="campdetail" then self.box_id=arg;self:go("worldboxdetail")
  elseif action=="campboxpage" then self.box_page=math.max(1,(self.box_page or 1)+arg)
  elseif action=="campfilter" then self.box_type=(self.box_type or 1)%#types+1;self.box_page=1
  elseif action=="campfavourites" then self.box_favourites=not self.box_favourites;self.box_page=1
  elseif action=="campsearch" then self.box_text=self.box_query or "";self:go("worldboxsearch")
  elseif action=="campname" then self.box_id=arg;self.box_text=s.nicknames and s.nicknames[tostring(arg)] or "";self:go("worldboxname")
  elseif action=="campkey" then
   if #(E.companion.text.chars(self.box_text or "") or {})<(self.screen=="worldboxname" and 12 or 24) then self.box_text=(self.box_text or "")..arg end
  elseif action=="campcase" then self.uppercase=not self.uppercase
  elseif action=="campdelete" then self.box_text=E.companion.text.pop(self.box_text or "")
  elseif action=="campclear" then self.box_text=""
  elseif action=="camptextsave" then
   if self.screen=="worldboxname" then
    local ok,message=A.rename(s,E,self.box_id,self.box_text);if ok then self:go("worldboxdetail") end;return true,ok,message
   end
   self.box_query=self.box_text;self.box_page=1;self:go("worldbox")
  elseif action=="campwithdraw" then
   local ok,message=A.party(s,E,#c.party+1,arg);if ok then self:go("worldparty") end;return true,ok,message
  elseif action=="campdeposit" then local ok,message=A.deposit(s,arg);return true,ok,message
  elseif action=="camplead" then local ok,message=A.lead(s,arg);return true,ok,message
  elseif action=="campfavourite" then return true,true,E.act(s,"favourite",arg,os.time())
  elseif action=="camprecruit" then local ok,message=A.recruit(s,E);return true,ok,message
  elseif action=="campaddrecruit" then local ok,message=A.addRecruit(s,E);return true,ok,message
  elseif action=="camprevive" then local ok,message=A.revive(s,E,arg);return true,ok,message
  elseif action=="campgym" then local ok,message=A.gym(s,E,arg);return true,ok,message
  else return false end
  return true,false
 end
end
