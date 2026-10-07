local InputContainer=require("ui/widget/container/inputcontainer")
local UIManager=require("ui/uimanager")
local Device=require("device")
local Geom=require("ui/geometry")
local GestureRange=require("ui/gesturerange")
local TextWidget=require("ui/widget/textwidget")
local ImageWidget=require("ui/widget/imagewidget")
local RenderImage=require("ui/renderimage")
local Font=require("ui/font")
local BB=require("ffi/blitbuffer")
local View=InputContainer:extend{covers_fullscreen=true,modal=true}
local BLACK,WHITE,GRAY,LIGHT=BB.COLOR_BLACK,BB.COLOR_WHITE,BB.Color8(170),BB.Color8(238)
local function round(n) return math.floor(n+0.5) end
local function minutes(n) return math.max(0,math.ceil(n/60)) end
local function readyLabel(label,remaining)
 if remaining<=0 then return label end
 if remaining>=3600 then return label.." "..math.ceil(remaining/3600).."h" end
 return label.." "..minutes(remaining).."m"
end
function View:init()
 self.art=dofile(self.path.."/art.lua");self.frames=dofile(self.path.."/assets/frames.lua")
 self.poses=dofile(self.path.."/assets/poses.lua")
 self.screen="home";self.frame=1;self.buttons={};self.images={};self.action_count=0;self.starter_index=1
 self.message=self.engine.act(self.state,"check",nil,os.time())
 self.key_events.Back={{"Back"}};self.key_events.Close={{"Esc"}};self:geometry()
 -- The only scheduled callback is a bounded animation following an action.
 self.tick=function()
  if self.closed or self.suspended or Device.screen_saver_mode then self:stopAnimation();return end
  if not self.animating then return end
  self.step=self.step+1;self.frame=self.sequence[self.step]
  if not self.frame then
   self.frame=1;self.animating=false;self.effect=nil;self.previous_species=nil;self:freeImages()
  else UIManager:scheduleIn(self.interval,self.tick) end
  UIManager:setDirty(self,"ui",self:stageRegion())
 end
end
function View:geometry()
 local w,h=Device.screen:getWidth(),Device.screen:getHeight()
 self.dimen=Geom:new{x=0,y=0,w=w,h=h};self.scale=math.min(w/600,h/800)
 self.ox=round((w-600*self.scale)/2);self.oy=round((h-800*self.scale)/2)
 self.ges_events.Tap={GestureRange:new{ges="tap",range=self.dimen}}
 self.ges_events.Swipe={GestureRange:new{ges="swipe",range=self.dimen}}
end
function View:region(x,y,w,h)
 return Geom:new{x=self.ox+round(x*self.scale),y=self.oy+round(y*self.scale),w=round(w*self.scale),h=round(h*self.scale)}
end
function View:stageRegion() return self:region(116,202,370,212) end
function View:rect(bb,x,y,w,h,color)
 local r=self:region(x,y,w,h);bb:paintRect(r.x,r.y,r.w,r.h,color or BLACK)
end
function View:outline(bb,x,y,w,h,color)
 self:rect(bb,x,y,w,1,color);self:rect(bb,x,y+h-1,w,1,color)
 self:rect(bb,x,y,1,h,color);self:rect(bb,x+w-1,y,1,h,color)
end
function View:text(bb,text,x,y,size,width,bold,center)
 local t=TextWidget:new{text=tostring(text),face=Font:getFace(bold and "tfont" or "cfont",math.max(9,round(size*self.scale))),bold=bold,max_width=round((width or 536)*self.scale),padding=0}
 local r=self:region(x,y,0,0)
 if center then r.x=r.x+round(((width or 536)*self.scale-t:getSize().w)/2) end
 t:paintTo(bb,r.x,r.y);t:free()
end
function View:wrapped(bb,text,y,size)
 local face=Font:getFace("cfont",math.max(9,round((size or 17)*self.scale)))
 local line,rows="",{}
 for word in text:gmatch("%S+") do
  local trial=line=="" and word or line.." "..word
  local t=TextWidget:new{text=trial,face=face,padding=0}
  local too_wide=t:getSize().w>round(504*self.scale);t:free()
  if too_wide and line~="" then rows[#rows+1]=line;line=word else line=trial end
 end
 rows[#rows+1]=line
 for i=1,math.min(2,#rows) do self:text(bb,rows[i],46,y+(i-1)*22,size or 17,508,false,true) end
end
function View:button(bb,label,x,y,w,h,action,arg,icon,disabled,selected)
 if selected then self:rect(bb,x,y,w,h,LIGHT) end
 self:outline(bb,x,y,w,h,disabled and GRAY or BLACK)
 if icon then
  self.art.icon(self,bb,icon,x+12,y+round((h-20)/2),2,disabled and GRAY or BLACK)
  self:text(bb,label,x+40,y+round((h-21)/2),18,w-46,false,true)
 else self:text(bb,label,x+6,y+round((h-21)/2),18,w-12,selected,true) end
 self.buttons[#self.buttons+1]={x=x,y=y,w=w,h=h,action=action,arg=arg,disabled=disabled}
end
function View:sprite(bb,id,x,y,size,frame,pose)
 local pose_list=self.poses[id]
 if pose and (not pose_list or not pose_list[pose]) then pose=pose_list and "idle" or nil end
 frame=math.min(frame or 1,pose and pose_list[pose] or self.frames[id] or 1)
 local key=id.."-"..(pose or "normal").."-"..frame.."-"..round(size*self.scale);local img=self.images[key]
 if not img then
  local file=self.path.."/assets/"..id.."-"..(pose and pose.."-" or "")..frame..".png"
  local raw=RenderImage:renderImageFile(file,false)
  assert(raw,"Missing PokePal sprite: "..file)
  local pixels=round(size*self.scale);local scaled=raw
  if raw:getWidth()~=pixels or raw:getHeight()~=pixels then scaled=raw:scale(pixels,pixels);raw:free() end
  img=ImageWidget:new{image=scaled,image_disposable=true,alpha=true,width=pixels,height=pixels,scale_for_dpi=false}
  self.images[key]=img
 end
 local r=self:region(x,y,0,0);img:paintTo(bb,r.x,r.y)
end
function View:freeImages() for _,img in pairs(self.images) do img:free() end;self.images={} end
function View:stopAnimation()
 UIManager:unschedule(self.tick);self.animating=false;self.frame=1;self.effect=nil;self.previous_species=nil
end
function View:poseFor(effect)
 if not self.poses[self.state.species] then return nil end
 if effect=="rest" or effect=="ambient_sleep" then return self.state.resting and "sleep" or "idle" end
 if effect=="feed" then return self.poses[self.state.species].eat and "eat" or "idle" end
 if effect=="train" then return "attack" end
 if effect=="play" then return "walk" end
 return self.state.resting and "sleep" or "idle"
end
function View:animate(effect,previous)
 self:stopAnimation()
 if not effect or self.state.animation=="off" or self.suspended or Device.screen_saver_mode then return end
 self.effect=effect;self.previous_species=previous;self.animating=true;self.step=1;self.frame=1
 local pose=self:poseFor(effect)
 local count=pose and self.poses[self.state.species][pose] or self.frames[self.state.species] or 1
 self.sequence={}
 if self.state.animation=="eco" then self.sequence={1,math.max(1,math.ceil(count/2))};self.interval=0.8
 else for i=1,count do self.sequence[#self.sequence+1]=i end;self.interval=0.45 end
 UIManager:scheduleIn(self.interval,self.tick)
end
function View:go(screen)
 self:stopAnimation();self:freeImages();self.screen=screen;self.page=1;UIManager:setDirty(self,"ui")
end
function View:act(action,arg)
 local previous=self.state.species
 self.message,self.next_effect=self.engine.act(self.state,action,arg,os.time())
 self.owner:save();self:freeImages();self.screen="home"
 self:animate(self.next_effect,self.next_effect=="evolve" and previous or nil)
 self.action_count=self.action_count+1;UIManager:setDirty(self,self.action_count%12==0 and "flashui" or "ui")
end
function View:paintTo(bb,x,y)
 bb:paintRect(0,0,self.dimen.w,self.dimen.h,WHITE);self.buttons={}
 self.art.text(self,bb,"POKEPAL",32,28,3);self.art.icon(self,bb,"berry",373,24,2)
 self:text(bb,self.state.berries,406,29,18,64);self:button(bb,"Exit",492,20,76,40,"exit")
 self:rect(bb,32,75,536,1)
 if self.state.species==0 then self:paintWelcome(bb)
 elseif self.screen=="home" then self:paintHome(bb)
 elseif self.screen=="explore" then self:paintExplore(bb)
 elseif self.screen=="journal" then self:paintJournal(bb)
 elseif self.screen=="history" then self:paintHistory(bb)
 elseif self.screen=="profile" then self:paintProfile(bb)
 elseif self.screen=="badges" then self:paintBadges(bb)
 elseif self.screen=="play" then self:paintPlay(bb)
 elseif self.screen=="train" then self:paintTrain(bb)
 elseif self.screen=="help" then self:paintHelp(bb)
 else self:paintMore(bb) end
end
function View:paintWelcome(bb)
 local id=self.engine.starters[self.starter_index]
 self:text(bb,"Choose your partner",32,105,29,536,true,true)
 self:text(bb,self.engine.name(id),32,166,25,536,true,true);self:sprite(bb,id,176,218,248,1)
 self:text(bb,self.starter_index.." / "..#self.engine.starters,32,488,18,536,false,true)
 self:wrapped(bb,"Feed, play, explore and grow together. Choose a friend for your adventure.",530,19)
 self:button(bb,"Previous",60,602,232,48,"starter",-1)
 self:button(bb,"Next",308,602,232,48,"starter",1)
 self:button(bb,"Start with "..self.engine.name(id),60,670,480,62,"choose",id,"heart")
end
function View:landscape(bb)
 self:outline(bb,32,153,536,265);self:rect(bb,33,154,534,263,WHITE)
 local hour=tonumber(os.date("%H"));local night=hour<7 or hour>=19
 if night then
  self.art.icon(self,bb,"moon",491,174,3)
  for _,p in ipairs({{86,191},{157,177},{391,189},{454,220}}) do self:rect(bb,p[1],p[2],3,3) end
 else
  self:rect(bb,493,175,25,25,GRAY);self:rect(bb,485,183,41,9,GRAY)
  self.art.icon(self,bb,"cloud",69,179,3,LIGHT);self.art.icon(self,bb,"cloud",371,168,3,LIGHT)
 end
 self:rect(bb,33,294,534,123,LIGHT)
 self:rect(bb,33,289,89,5,LIGHT);self:rect(bb,96,282,94,12,LIGHT)
 self:rect(bb,363,283,112,11,LIGHT);self:rect(bb,469,288,98,6,LIGHT);self:rect(bb,33,344,534,2,GRAY)
 for _,p in ipairs({{57,261,3},{119,274,2},{459,253,3},{514,272,2}}) do self.art.icon(self,bb,"tree",p[1],p[2],p[3],GRAY) end
 for _,p in ipairs({{61,385},{94,399},{494,384},{530,401}}) do
  self:rect(bb,p[1],p[2],2,7,GRAY);self:rect(bb,p[1]-3,p[2]+2,3,2,GRAY)
 end
 if self.state.dirt>=15 then self.art.icon(self,bb,"poop",122,381,2,BB.Color8(85)) end
end
function View:paintHome(bb)
 local s=self.state;local now=os.time()
 self.art.text(self,bb,self.engine.name(s.species),32,94,3);self:text(bb,"Lv "..self.engine.level(s),438,94,25,130,true,true)
 self:text(bb,self.engine.mood(s,now),32,124,17,536,false,true);self:landscape(bb)
 if s.trip>0 and now<s.due and not self.animating then
  self.art.icon(self,bb,"boot",270,258,6);self:text(bb,self.engine.routes[s.trip].name,169,345,20,263,true,true)
  self:text(bb,minutes(s.due-now).." min until home",169,377,17,263,false,true)
 else
  local size=192;local id=s.species
  for i,member in ipairs(self.engine.evolutionLine(id)) do if member==id then size=176+i*16 end end
  if self.effect=="evolve" and self.previous_species and self.step<=2 then id=self.previous_species end
  local dy=(self.animating and self.effect=="play" and self.frame%2==0) and -6 or 0
  self:rect(bb,253,401,94,3,GRAY);self:rect(bb,265,398,70,3,GRAY)
  local pose=self.animating and self:poseFor(self.effect) or self:poseFor(nil)
  self:sprite(bb,id,(600-size)/2,414-size+dy,size,self.frame,pose)
  if self.animating and self.effect~="ambient" and self.effect~="ambient_sleep" then self:paintEffect(bb) end
 end
 self:wrapped(bb,self.message,433)
 local stats={{"Food",s.food},{"Joy",s.joy},{"Energy",s.energy},{"Hygiene",100-s.dirt}}
 for i,v in ipairs(stats) do
  local x=32+((i-1)%2)*276;local y=486+math.floor((i-1)/2)*36
  self:text(bb,v[1].." "..math.floor(v[2]),x,y,16,107);self:outline(bb,x+111,y+3,149,12)
  self:rect(bb,x+113,y+5,math.floor(145*v[2]/100),8)
 end
 self:text(bb,self.engine.ready(s) and "Evolution is ready!" or "Bond "..math.floor(s.bond).." / 100   |   "..s.xp.." XP",32,559,17,350)
 self:button(bb,"Profile",431,547,137,36,"nav","profile")
 local buttons={{"Feed","feed",nil,"berry"},{readyLabel("Play",s.played+1800-now),"startplay",nil,"ball"},{readyLabel("Train",s.trained+3600-now),"nav","train","ball"},
  {s.resting and "Wake" or "Rest","rest",nil,"moon"},{"Explore","nav","explore","boot"},{"Journal","nav","journal","book"},
  {"Clean","clean",nil,"clean"},{readyLabel("Basket",s.gift+86400-now),"gift",nil,"berry"},{"More","nav","more","settings"}}
 for i,b in ipairs(buttons) do self:button(bb,b[1],32+(i-1)%3*182,596+math.floor((i-1)/3)*57,172,48,b[2],b[3],b[4]) end
 self.buttons[#self.buttons+1]={x=168,y=211,w=264,h=204,action="hello"}
end
function View:paintEffect(bb)
 local up=self.frame%2==0 and -7 or 0;local e=self.effect
 if e=="feed" then self.art.icon(self,bb,"berry",160,279+up,3)
 elseif e=="play" then self.art.icon(self,bb,"ball",409,277+up,3)
 elseif e=="train" then self.art.icon(self,bb,"ball",410,275+up,3)
 elseif e=="clean" or e=="evolve" then self.art.icon(self,bb,"clean",148,248+up,3);self.art.icon(self,bb,"clean",414,284-up,3)
 elseif e=="rest" then return
 else self.art.icon(self,bb,"heart",419,253+up,3) end
end
function View:backButton(bb) self:button(bb,"Back to companion",32,717,536,44,"nav","home") end
function View:title(bb,title,subtitle)
 self:text(bb,title,32,101,29,536,true);if subtitle then self:text(bb,subtitle,32,145,17,536) end
end
function View:paintExplore(bb)
 self:title(bb,"Expeditions","Adventures finish while your Kindle sleeps.");local s=self.state
 if s.trip>0 then
  local left=s.due-os.time();local r=self.engine.routes[s.trip];self:sprite(bb,s.species,186,220,228,1)
  self:text(bb,r.name,32,469,27,536,true,true)
  self:text(bb,left<=0 and "Home again! Your discoveries are ready." or "About "..minutes(left).." minutes remaining.",32,514,18,536,false,true)
  self:button(bb,left<=0 and "Collect discoveries" or "Check expedition",62,581,476,57,"collect",nil,"boot")
 else
  for i,r in ipairs(self.engine.routes) do
   local y=199+(i-1)*153;self:button(bb,r.name.." / "..r.seconds/60 .." min",32,y,536,57,"trip",i,"boot")
   self:text(bb,r.energy.." energy   +"..r.berries.." berries   +"..r.xp.." XP",43,y+71,18,513)
   self:text(bb,i==1 and "A gentle stroll. Grassland friends await." or i==2 and "Salty air, quiet waves, water Pokemon." or "A longer trail beneath the mountain.",43,y+101,16,513)
  end
 end
 self:backButton(bb)
end
function View:paintJournal(bb)
 local ids={};for id,v in pairs(self.state.seen) do if v then ids[#ids+1]=tonumber(id) end end;table.sort(ids)
 local pages=math.max(1,math.ceil(#ids/6));self.page=math.min(self.page or 1,pages)
 self:title(bb,"Field journal",#ids.." Pokemon discovered on your journey")
 for pos=(self.page-1)*6+1,math.min(self.page*6,#ids) do
  local i=pos-(self.page-1)*6-1;local x=32+(i%3)*182;local y=194+math.floor(i/3)*187
  self:sprite(bb,ids[pos],x+20,y,132,1);self:text(bb,self.engine.name(ids[pos]),x,y+139,17,172,false,true)
 end
 self:button(bb,"Previous",32,597,170,43,"page",-1,nil,self.page==1)
 self:text(bb,self.page.." / "..pages,217,609,20,166,false,true)
 self:button(bb,"Next",398,597,170,43,"page",1,nil,self.page==pages)
 self:button(bb,"Activity",32,659,262,43,"nav","history","book")
 self:button(bb,"Badges",306,659,262,43,"nav","badges","badge");self:backButton(bb)
end
function View:paintHistory(bb)
 local entries=self.state.log
 local pages=math.max(1,math.ceil(#entries/6));self.page=math.min(self.page or 1,pages)
 self:title(bb,"Activity",#entries.." recent moments")
 for pos=(self.page-1)*6+1,math.min(self.page*6,#entries) do
  local i=pos-(self.page-1)*6-1;local y=191+i*66
  local stamp,entry=entries[pos]:match("^(.-) | (.*)$")
  if stamp then self:text(bb,stamp,44,y,14,510);self:text(bb,entry,44,y+23,18,510)
  else self:text(bb,entries[pos],44,y+12,18,510) end
  self:rect(bb,44,y+56,512,1,LIGHT)
 end
 self:button(bb,"Previous",32,597,170,43,"page",-1,nil,self.page==1)
 self:text(bb,self.page.." / "..pages,217,609,20,166,false,true)
 self:button(bb,"Next",398,597,170,43,"page",1,nil,self.page==pages)
 self:button(bb,"Field journal",32,659,536,43,"nav","journal","book")
 self:backButton(bb)
end
function View:paintProfile(bb)
 local s=self.state;local lv=self.engine.level(s)
 local line=self.engine.evolutionLine(s.species);local choices=self.engine.evolutionChoices(s.species)
 self:title(bb,"Partner",self.engine.name(s.species).."   /   Lv "..lv.."   /   Bond "..math.floor(s.bond).." / 100")
 for i,id in ipairs(line) do
  local x=(600-(#line*182-10))/2+(i-1)*182;self:sprite(bb,id,x+16,207,140,1)
  self:text(bb,self.engine.name(id),x,355,18,172,id==s.species,true)
  local previous=i>1 and self.engine.species[line[i-1]]
  local requirement=previous and "Lv "..(1+math.ceil(previous[3]/20)).." + 30 bond" or "Your first friend"
  self:text(bb,requirement,x,389,14,172,false,true)
  if id==s.species then self:rect(bb,x+30,422,112,3) end
 end
 local p=self.engine.species[s.species]
 if #choices>1 then
  self:wrapped(bb,"Choose a stone at Lv "..(1+math.ceil(p[3]/20)).." and 30 bond. Each stone leads to a different friend.",454,18)
  for i,id in ipairs(choices) do
   self:button(bb,self.engine.evolution_stones[id]..": "..self.engine.name(id),32,511+(i-1)*51,536,44,"evolve",id,nil,not self.engine.ready(s))
  end
 elseif #choices==1 then
  local id=choices[1]
  self:wrapped(bb,"Next: "..self.engine.name(id)..". Reach Lv "..(1+math.ceil(p[3]/20)).." and 30 bond, then evolve when you are ready.",466,19)
  self:button(bb,self.engine.ready(s) and "Evolve into "..self.engine.name(id) or "Growing toward "..self.engine.name(id),32,538,536,56,"evolve",id,"clean",not self.engine.ready(s))
 else self:wrapped(bb,self.engine.name(s.species).." is fully evolved. Keep exploring and fill your field journal together.",465,19) end
 self:text(bb,"Together for "..math.max(0,math.floor((os.time()-s.started)/86400)).." days   /   "..s.trips.." expeditions",32,681,18,536,false,true)
 self:backButton(bb)
end
function View:paintBadges(bb)
 self:title(bb,"Achievements",self.engine.count(self.state.badges).." of 6 badges earned")
 for i,b in ipairs(self.engine.badge_goals) do
  local y=192+(i-1)*79;local earned=self.state.badges[b[1]];self.art.icon(self,bb,"badge",39,y+6,3,earned and BLACK or GRAY)
  self:text(bb,b[1]..(earned and " - earned" or ""),91,y,20,469,earned);self:text(bb,b[2],91,y+33,16,469);self:rect(bb,91,y+66,477,1,LIGHT)
 end
 self:backButton(bb)
end
function View:startPlay()
 self.engine.advance(self.state,os.time());local allowed,why=self.engine.canPlay(self.state,os.time())
 if not allowed then self.message=why;UIManager:setDirty(self,"ui");return end
 self:go("play");self.play_phase="show";self.play_pos=1;self.play_sequence={}
 local seed=(os.time()+self.state.seed)%2147483647
 for i=1,3 do seed=(seed*48271)%2147483647;self.play_sequence[i]=seed%3+1 end
end
function View:paintPlay(bb)
 self:title(bb,"Berry trail","Remember the path, then help your friend follow it.");self:sprite(bb,self.state.species,204,198,192,1)
 if self.play_phase=="show" then
  self:text(bb,"Remember these bushes in order:",32,420,20,536,false,true);self.art.text(self,bb,table.concat(self.play_sequence," - "),192,473,4)
  self:button(bb,"I'm ready - hide the path",32,556,536,55,"hidepath",nil,"berry")
 else
  self:text(bb,"Choose bush "..self.play_pos.." of 3",32,420,22,536,true,true)
  for i=1,3 do self:button(bb,"Bush "..i,32+(i-1)*182,494,172,79,"pickbush",i,"berry") end
  self:text(bb,"A perfect trail earns 3 extra XP.",32,620,17,536,false,true)
 end
 self:backButton(bb)
end
function View:pickBush(i)
 if self.play_phase~="pick" then return end
 if i~=self.play_sequence[self.play_pos] then self.play_phase="done";self:act("play","try");return end
 self.play_pos=self.play_pos+1
 if self.play_pos>3 then self.play_phase="done";self:act("play","perfect") else UIManager:setDirty(self,"ui") end
end
function View:paintTrain(bb)
 self:title(bb,"A little move practice","18 energy   /   8 food   /   +12 XP   /   +2 bond");local lv=self.engine.level(self.state)
 for i,m in ipairs(self.engine.moves(self.state)) do
  local y=200+(i-1)*112;local locked=lv<m.level
  self:button(bb,m.name,32,y,536,56,"train",m.name,"ball",locked)
  self:text(bb,locked and "Unlocks at Lv "..m.level or "Ready to practice with your partner",43,y+71,17,513)
 end
 self:backButton(bb)
end
function View:paintMore(bb)
 self:title(bb,"Settings","Animation plays briefly while the screen is on.")
 for i,b in ipairs({{"Gentle","gentle"},{"Eco","eco"},{"Off","off"}}) do self:button(bb,b[1],32+(i-1)*182,199,172,48,"animation",b[2],nil,false,self.state.animation==b[2]) end
 self:text(bb,"Gentle: up to 8 frames. Eco: 2 frames. Off: still.",32,267,17,536)
 self:button(bb,"Refresh screen - clear ghosting",32,323,536,48,"refresh",nil,"clean")
 self:button(bb,"How to care for your partner",32,391,536,48,"nav","help","book")
 self:button(bb,"Evolution and partner profile",32,459,536,48,"nav","profile","clean")
 self:button(bb,"Activity",32,527,536,48,"nav","history","book")
 self:text(bb,"Latest activity",32,623,19,536,true);if self.state.log[1] then self:text(bb,self.state.log[1],32,655,16,536) end
 self:backButton(bb)
end
function View:paintHelp(bb)
 self:title(bb,"Care guide","Two or three brief visits a day are enough.")
 local help={{"Feed","One berry restores 24 food. The basket refills daily."},{"Play","Follow a 3-step berry trail. Ready every 30 minutes."},
  {"Train","Practice a move each hour to earn XP and bond."},{"Rest and clean","Rest restores energy faster. Keep the little nest tidy."},
  {"Explore","Send your friend away, then collect its discoveries."},{"Grow together","Every 20 XP is a level. Evolve from the partner profile."}}
 for i,h in ipairs(help) do local y=190+(i-1)*78;self:text(bb,h[1],32,y,20,536,true);self:text(bb,h[2],32,y+31,16,536) end
 self:backButton(bb)
end
function View:onTap(_,ges)
 if self.closed or self.suspended then return true end
 local x=(ges.pos.x-self.ox)/self.scale;local y=(ges.pos.y-self.oy)/self.scale
 for _,b in ipairs(self.buttons) do if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then
  if b.action=="exit" then self:leave()
  elseif b.disabled then return true
  elseif b.action=="starter" then
   self.starter_index=(self.starter_index-1+b.arg)%#self.engine.starters+1
   self:freeImages();UIManager:setDirty(self,"ui")
  elseif b.action=="nav" then
   if b.arg=="home" then self.message=self.engine.act(self.state,"check",nil,os.time()) end;self:go(b.arg)
  elseif b.action=="hello" then self:animate("hello");UIManager:setDirty(self,"ui",self:stageRegion())
  elseif b.action=="startplay" then self:startPlay()
  elseif b.action=="hidepath" then self.play_phase="pick";UIManager:setDirty(self,"ui")
  elseif b.action=="pickbush" then self:pickBush(b.arg)
  elseif b.action=="refresh" then self:stopAnimation();UIManager:setDirty(self,"full")
  elseif b.action=="page" then
   local count=self.screen=="history" and #self.state.log or self.engine.count(self.state.seen)
   self:freeImages();self.page=math.max(1,math.min(math.max(1,math.ceil(count/6)),self.page+b.arg));UIManager:setDirty(self,"ui")
  elseif b.action=="animation" then self.engine.act(self.state,"animation",b.arg,os.time());self.owner:save();UIManager:setDirty(self,"ui")
  else self:act(b.action,b.arg) end
  return true
 end end
 return true
end
function View:onSwipe() return true end
function View:onBack() if self.screen=="home" then self:leave() else self:go("home") end;return true end
function View:onClose() self:leave();return true end
function View:leave()
 if self.closed then return end
 self:stopAnimation();self.closed=true;local ok=self.owner:save();UIManager:close(self,"full")
 if not ok then UIManager:show(require("ui/widget/infomessage"):new{text="PokePal could not save. Check free space on the Kindle before playing again."}) end
end
function View:onCloseWidget() self:stopAnimation();self.closed=true;self:freeImages();self.owner.view=nil end
function View:onSuspend()
 if self.suspended or self.closed then return end;self.suspended=true;self:stopAnimation();self.owner:save()
end
function View:onResume()
 if not self.suspended or self.closed then return end
 self.suspended=false;self:freeImages();self:geometry();self.message=self.engine.act(self.state,"check",nil,os.time());UIManager:setDirty(self,"full")
end
function View:onSetDimensions() self:stopAnimation();self:freeImages();self:geometry();UIManager:setDirty(self,"full");return true end
return View
