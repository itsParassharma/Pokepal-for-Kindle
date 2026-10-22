-- Screens for optional features; the home controls stay in their usual places.
return function(View,UIManager,BB)
 local BLACK,WHITE,GRAY=BB.COLOR_BLACK,BB.COLOR_WHITE,BB.Color8(170)
 function View:paintPreferences(bb)
  self:title(bb,"Preferences","Choose what feels right for your Kindle.")
  local labels={"Sleeping partner screen","Rest when the Kindle sleeps","Reading footer (KOReader)","Larger text","Stronger contrast"}
  for i,key in ipairs(self.engine.companion.preferences) do
   local on=self.engine.companion.option(self.state,key)
   self:button(bb,labels[i]..": "..(on and "On" or "Off"),32,195+(i-1)*72,536,54,"preference",key,nil,(key=="footer" or key=="sleep_screen") and self.owner.native,on)
  end
  self:wrapped(bb,self.owner.native and "The KUAL edition keeps the Kindle sleep screen. The partner sleep screen is available in KOReader."
   or "The sleep screen is still while the device sleeps. Your lock settings stay in place.",582,18)
  self:button(bb,"Preview sleep screen",32,650,536,46,"nav","sleeppreview")
  self:backButton(bb)
 end
 function View:paintSleep(bb,preview)
  bb:paintRect(0,0,self.dimen.w,self.dimen.h,WHITE)
  self.buttons={};self:text(bb,self.engine.displayName(self.state),32,112,32,536,true,true)
  self:landscape(bb);self:sprite(bb,self.state.species,188,190,224,1,"sleep")
  if self.state.egg then self.art.egg(self,bb,425,354,3,1-self.engine.eggLeft(self.state)/self.engine.egg_seconds,WHITE) end
  self:text(bb,self.state.trip>0 and "Resting on the trail" or "Taking a nap",32,443,22,536,true,true)
  self:text(bb,"See you after a few more pages.",32,490,21,536,false,true)
  if preview then self:button(bb,"Back to preferences",32,717,536,44,"nav","preferences") end
 end
 function View:paintFilters(bb)
  self:title(bb,"Find a friend","Search names, then narrow the list if you like.")
  local filters={{"All friends","met"},{"Favourites","favourites"},{"Can evolve","ready"},{"Recent","recent"},
   {"Grass","Grass"},{"Fire","Fire"},{"Water","Water"},{"Electric","Electric"},{"Normal","Normal"},{"Bug","Bug"},
   {"Flying","Flying"},{"Poison","Poison"},{"Ground","Ground"},{"Rock","Rock"},{"Psychic","Psychic"},{"Ice","Ice"},
   {"Fighting","Fighting"},{"Ghost","Ghost"},{"Dragon","Dragon"},{"Fairy","Fairy"},{"Steel","Steel"}}
  for i,f in ipairs(filters) do self:button(bb,f[1],32+(i-1)%3*182,188+math.floor((i-1)/3)*66,172,50,"filter",f[2],nil,false,self.journal_filter==f[2]) end
  self:button(bb,"Back to journal",32,717,536,44,"nav","journal")
 end
 function View:paintSnacks(bb)
  local C=self.engine.companion;local trait,berry=C.profile(self.state,self.state.species,self.engine)
  local known=self.state.companion and self.state.companion.tastes[tostring(self.state.species)]
  self:title(bb,"A berry for your partner",trait.." / "..(known and "Likes "..berry.." berries" or "Favourite berry still a mystery"))
  self:sprite(bb,self.state.species,204,200,192,1,"idle")
  for i,name in ipairs(C.berries) do self:button(bb,name.." / 1 berry",32,424+(i-1)*75,536,54,"feed",name,"berry") end
  self:backButton(bb)
 end
 function View:paintMemories(bb)
  local memories=self.state.companion and self.state.companion.memories or {}
  self:title(bb,"Books we read together",#memories.." books remembered")
  self:button(bb,"Remember a finished book",32,185,536,48,"newmemory")
  local pages=math.max(1,math.ceil(#memories/5));self.page=math.min(self.page or 1,pages)
  for i=(self.page-1)*5+1,math.min(#memories,self.page*5) do
   local m=memories[i];local y=258+((i-1)%5)*73
   self:text(bb,m.title,32,y,20,536,true)
   self:text(bb,self.engine.displayName(self.state,m.id).." / "..os.date("%d %b %Y",m.at),32,y+29,17,536)
  end
  if #memories==0 then self:wrapped(bb,"Finished a book? Save its title and the partner who kept you company.",336,21) end
  self:button(bb,"Previous",32,652,170,44,"extrapage",-1,nil,self.page==1)
  self:text(bb,self.page.." / "..pages,217,664,19,166,false,true)
  self:button(bb,"Next",398,652,170,44,"extrapage",1,nil,self.page==pages)
  self:backButton(bb)
 end
 function View:paintBookConfirm(bb)
  self:title(bb,"Remember this book?","Add it when you have finished reading.")
  self:wrapped(bb,self.input_text or "",233,24)
  self:sprite(bb,self.state.species,204,312,192,1,"idle")
  self:text(bb,"Read with "..self.engine.displayName(self.state),32,544,22,536,true,true)
  self:button(bb,"Save this memory",32,620,536,54,"savememory")
  self:button(bb,"Cancel",32,717,536,44,"nav","memories")
 end
 function View:paintReadingHistory(bb)
  local C=self.engine.companion;local days=self.state.companion and self.state.companion.days or {}
  self.history_week=math.max(0,math.min(7,self.history_week or 0))
  local d=os.date("*t",self.engine.weekStart(os.time()));d.day=d.day-7*self.history_week
  local start=os.time(d);self:title(bb,"Reading history","Week of "..os.date("%d %b %Y",start))
  self:text(bb,"Day",32,199,18,140,true);self:text(bb,"KOReader",180,199,18,178,true,true);self:text(bb,"Kindle visits",376,199,18,192,true,true)
  local kt,nt=0,0
  for i=0,6 do
   local date=os.date("*t",start);date.day=date.day+i;local at=os.time(date)
   local entry=days[os.date("%Y-%m-%d",at)] or {ko=0,kindle=0};kt=kt+entry.ko;nt=nt+entry.kindle
   local y=243+i*43
   self:text(bb,os.date("%a %d",at),32,y,19,140)
   self:text(bb,math.floor(entry.ko/60).." min",180,y,19,178,false,true)
   self:text(bb,math.floor(entry.kindle/60).." min",376,y,19,192,false,true)
  end
  self:text(bb,math.floor((kt+nt)/60).." minutes recorded",32,555,22,536,true,true)
  self:wrapped(bb,"KOReader shows reading dates. Kindle shows the day you collected the time. Older sessions have no dates.",594,17)
  self:button(bb,"Older",32,653,262,44,"historyweek",1,nil,self.history_week==7)
  self:button(bb,"Newer",306,653,262,44,"historyweek",-1,nil,self.history_week==0)
  self:backButton(bb)
 end
 function View:paintTrailStory(bb)
  local j=self.state.companion and self.state.companion.journey
  if not j then self:paintExplore(bb);return end
  local event=self.engine.companion.events[j.event]
  self:title(bb,event.title,"Something happened on the way home.")
  self:sprite(bb,self.state.species,204,205,192,1,"walk")
  self:wrapped(bb,event.text,425,20)
  for i,label in ipairs(event.choices) do self:button(bb,label,32,530+(i-1)*70,536,54,"trailchoice",i,nil,j.choice~=nil,j.choice==i) end
  self:button(bb,j.choice and "Collect discoveries" or "Carry on and collect",32,717,536,44,"collect")
 end
 function View:editText(kind,value)
  self.input_kind=kind;self.input_text=value or "";self.input_limit=kind=="search" and 40 or kind=="nickname" and 12 or 100
  local ok,Dialog=pcall(require,"ui/widget/inputdialog")
  if ok then
   local dialog
   dialog=Dialog:new{title=kind=="search" and "Find a Pokemon" or kind=="nickname" and "Nickname" or "Book title",input=self.input_text,
    buttons={{{text="Cancel",callback=function() UIManager:close(dialog) end},
     {text="Continue",is_enter_default=true,callback=function()
      local value=dialog:getInputText():gsub("^%s+",""):gsub("%s+$","")
      if value=="" or self.engine.companion.text.valid(value,self.input_limit) then
       UIManager:close(dialog);self.input_text=value;self:finishText()
      else UIManager:show(require("ui/widget/infomessage"):new{text="Use up to "..self.input_limit.." characters, with no line breaks."}) end
     end}}}}
   UIManager:show(dialog);dialog:onShowKeyboard()
  else self:go("textentry");self.uppercase=true end
 end
 function View:finishText()
  if self.input_kind=="search" then self.journal_query=self.input_text;self:go("journal")
  elseif self.input_kind=="nickname" then self.message=self.engine.act(self.state,"nickname",self.input_text,os.time());self.owner:save();self:go("profile")
  elseif self.engine.companion.text.valid(self.input_text,100) then self:go("bookconfirm") end
 end
 function View:paintTextEntry(bb)
  self:title(bb,self.input_kind=="search" and "Find a Pokemon" or self.input_kind=="nickname" and "Nickname" or "Book title","Use letters or switch to accents.")
  self:wrapped(bb,self.input_text=="" and "Tap a letter to start." or self.input_text,210,20)
  self:button(bb,self.uppercase and "abc" or "ABC",32,266,100,36,"inputcase")
  self:paintKeys(bb,"inputkey")
  self:button(bb,"ABC / accents",32,553,172,46,"accents")
  self:button(bb,"Space",214,553,172,46,"inputkey"," ")
  self:button(bb,"Delete",396,553,172,46,"inputdelete")
  self:button(bb,"Continue",32,630,536,50,"inputsave")
  self:button(bb,"Cancel",32,717,536,44,"nav",self.input_kind=="search" and "journal" or self.input_kind=="nickname" and "profile" or "memories")
 end
 function View:paintKeys(bb,action)
  local rows=self.accents and {"áàâäãåæçéè","êëíìîïñóòô","öõøúùûüýÿß","ÁÉÍÓÚÑÇ"} or {"1234567890","QWERTYUIOP","ASDFGHJKL","ZXCVBNM"}
  for row,letters in ipairs(rows) do
   local chars=self.engine.companion.text.chars(letters);local x=(600-(#chars*54-6))/2
   for i,key in ipairs(chars) do if not self.uppercase then key=key:lower() end;self:button(bb,key,x+(i-1)*54,310+(row-1)*60,48,48,action,key) end
  end
 end
 function View:companionTap(action,arg)
  local E=self.engine
  if action=="rescan" then
   if self.owner.rescanReading then self.owner:rescanReading() end
  elseif action=="preference" or action=="favourite" then
   self.message=E.act(self.state,action,arg,os.time());self.owner:save()
   if self.owner.updateCompanion then self.owner:updateCompanion() end
  elseif action=="dismissrecap" then self.recap_dismissed=true
  elseif action=="journalSearch" then self:editText("search",self.journal_query)
  elseif action=="filter" then self.journal_filter=arg;self:go("journal")
  elseif action=="newmemory" then self:editText("memory",self.owner.bookTitle and self.owner:bookTitle() or "")
  elseif action=="savememory" then self.message=E.act(self.state,"memory",self.input_text,os.time());self.owner:save();self:go("memories")
  elseif action=="historyweek" then self.history_week=(self.history_week or 0)+arg
  elseif action=="extrapage" then self.page=math.max(1,(self.page or 1)+arg)
  elseif action=="trailchoice" then self.message=E.act(self.state,action,arg,os.time());self.owner:save()
  elseif action=="accents" then self.accents=not self.accents
  elseif action=="unicodekeyboard" then self:editText("nickname",self.nickname_text)
  elseif action=="inputcase" then self.uppercase=not self.uppercase
  elseif action=="inputkey" then if #(E.companion.text.chars(self.input_text) or {})<self.input_limit then self.input_text=self.input_text..arg end
  elseif action=="inputdelete" then self.input_text=E.companion.text.pop(self.input_text)
  elseif action=="inputsave" then self:finishText()
  else return false end
  UIManager:setDirty(self,"ui");return true
 end
end
