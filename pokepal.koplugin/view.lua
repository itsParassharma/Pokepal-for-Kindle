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
local function savedDate(at)
 local ok,date=pcall(os.date,"%d %b %Y, %H:%M",at)
 return ok and date or "Date unavailable"
end
local function readyLabel(label,remaining)
 if remaining<=0 then return label end
 if remaining>=3600 then return label.." "..math.ceil(remaining/3600).."h" end
 return label.." "..minutes(remaining).."m"
end
function View:init()
 self.art=dofile(self.path.."/art.lua");self.frames=dofile(self.path.."/assets/frames.lua")
 self.poses=dofile(self.path.."/assets/poses.lua")
 self.sprites=dofile(self.path.."/assets/sprites.lua")
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
 -- Font:getFace scales again in KOReader. Our layout already uses screen pixels.
 self.font_scale=Device.screen.scaleBySize and 600/Device.screen:scaleBySize(600)
 self.ges_events.Tap={GestureRange:new{ges="tap",range=self.dimen}}
 self.ges_events.Swipe={GestureRange:new{ges="swipe",range=self.dimen}}
end
function View:region(x,y,w,h)
 return Geom:new{x=self.ox+round(x*self.scale),y=self.oy+round(y*self.scale),w=round(w*self.scale),h=round(h*self.scale)}
end
function View:stageRegion()
 if self.screen=="entry" then return self:region(120,184,360,280) end
 return self:region(32,180,536,240)
end
function View:animationSpecies() return self.screen=="entry" and self.detail_id or self.state.species end
function View:rect(bb,x,y,w,h,color)
 local r=self:region(x,y,w,h);bb:paintRect(r.x,r.y,r.w,r.h,color or BLACK)
end
function View:outline(bb,x,y,w,h,color)
 self:rect(bb,x,y,w,1,color);self:rect(bb,x,y+h-1,w,1,color)
 self:rect(bb,x,y,1,h,color);self:rect(bb,x+w-1,y,1,h,color)
end
function View:fontFace(size,bold)
 local pixels=math.max(9,round(size*self.scale))
 -- KOReader rounds up; aim halfway inside the target pixel to avoid rounding twice.
 local size_arg=self.font_scale and (pixels-0.5)*self.font_scale or pixels
 return Font:getFace(bold and "tfont" or "cfont",size_arg)
end
function View:text(bb,text,x,y,size,width,bold,center,height)
 if self.engine.companion.option(self.state,"large_text") and size<20 then size=math.min(21,size+2) end
 if self.engine.companion.option(self.state,"high_contrast") then bold=true end
 local t=TextWidget:new{text=tostring(text),face=self:fontFace(size,bold),bold=bold,max_width=round((width or 536)*self.scale),padding=0}
 local r=self:region(x,y,0,0)
 if center then r.x=r.x+round(((width or 536)*self.scale-t:getSize().w)/2) end
 if height then r.y=r.y+round((round(height*self.scale)-t:getSize().h)/2) end
 t:paintTo(bb,r.x,r.y);t:free()
end
function View:wrapped(bb,text,y,size)
 local measure=size or 17
 if self.engine.companion.option(self.state,"large_text") and measure<20 then measure=math.min(21,measure+2) end
 local bold=self.engine.companion.option(self.state,"high_contrast")
 local face=self:fontFace(measure,bold)
 local line,rows="",{}
 for word in text:gmatch("%S+") do
  local trial=line=="" and word or line.." "..word
  local t=TextWidget:new{text=trial,face=face,bold=bold,padding=0}
  local too_wide=t:getSize().w>round(504*self.scale);t:free()
  if too_wide and line~="" then rows[#rows+1]=line;line=word else line=trial end
 end
 rows[#rows+1]=line
 for i=1,math.min(2,#rows) do self:text(bb,rows[i],46,y+(i-1)*22,size or 17,508,false,true) end
end
function View:button(bb,label,x,y,w,h,action,arg,icon,disabled,selected)
 if disabled then label="- "..label end
 if selected then self:rect(bb,x,y,w,h,LIGHT) end
 self:outline(bb,x,y,w,h,disabled and GRAY or BLACK)
 if icon then
  self.art.icon(self,bb,icon,x+12,y+round((h-20)/2),2,disabled and GRAY or BLACK)
  self:text(bb,label,x+40,y,18,w-44,false,true,h)
 else self:text(bb,label,x+6,y,18,w-12,selected,true,h) end
 self.buttons[#self.buttons+1]={x=x,y=y,w=w,h=h,action=action,arg=arg,disabled=disabled}
end
function View:progress(bb,x,y,w,value,total)
 self:outline(bb,x,y,w,12,GRAY)
 self:rect(bb,x+2,y+2,math.floor((w-4)*math.max(0,math.min(1,value/total))),8)
end
function View:sprite(bb,id,x,y,size,frame,pose)
 local pose_list=self.poses[id]
 if pose and (not pose_list or not pose_list[pose]) then pose=pose_list and "idle" or nil end
 frame=math.min(frame or 1,pose and pose_list[pose] or self.frames[id] or 1)
 local key=id.."-"..(pose or "normal").."-"..frame.."-"..round(size*self.scale);local img=self.images[key]
 if not img then
  local file=id.."-"..(pose and pose.."-" or "")..frame..".png"
  local data=self.sprites.read(self.path.."/assets",file)
  local raw=RenderImage:renderImageData(data,#data,false)
  assert(raw,"Cannot decode PokePal sprite: "..file)
  local pixels=round(size*self.scale);local scaled=raw
  if raw:getWidth()~=pixels or raw:getHeight()~=pixels then scaled=raw:scale(pixels,pixels);raw:free() end
  img=ImageWidget:new{image=scaled,image_disposable=true,alpha=true,width=pixels,height=pixels,scale_for_dpi=false}
  self.images[key]=img
 end
 local r=self:region(x,y,0,0);img:paintTo(bb,r.x,r.y)
end
function View:freeImages()
 for _,img in pairs(self.images) do img:free() end;self.images={}
 if self.stage_background then self.stage_background:free();self.stage_background=nil end
 self.stage_cached=false
end
function View:stopAnimation()
 UIManager:unschedule(self.tick);self.animating=false;self.frame=1;self.effect=nil;self.previous_species=nil
end
function View:poseFor(effect)
 local id=self:animationSpecies()
 if not self.poses[id] then return nil end
 if self.screen=="entry" then return self.preview_pose or "idle" end
 if effect=="rest" or effect=="ambient_sleep" then return self.state.resting and "sleep" or "idle" end
 if effect=="feed" then return self.poses[self:animationSpecies()].eat and "eat" or "idle" end
 if effect=="train" then return "attack" end
 if effect=="play" then return "walk" end
 return self.state.resting and "sleep" or "idle"
end
function View:animate(effect,previous)
 self:stopAnimation()
 if not effect or self.state.animation=="off" or self.suspended or Device.screen_saver_mode then return end
 if self.screen=="home" and self.engine.tripLeft(self.state,os.time())>0 and effect~="explore" then return end
 self.effect=effect;self.previous_species=previous;self.animating=true;self.step=1;self.frame=1
 local pose=self:poseFor(effect)
 local count=pose and self.poses[self:animationSpecies()][pose] or self.frames[self:animationSpecies()] or 1
 self.sequence={}
 if self.state.animation=="eco" then self.sequence={1,math.min(count,math.floor(count/2)+1)};self.interval=0.8
 else for i=1,count do self.sequence[#self.sequence+1]=i end;self.interval=0.45 end
 UIManager:scheduleIn(self.interval,self.tick)
end
function View:go(screen)
 self:stopAnimation();self:freeImages();self.screen=screen;self.page=1;self.hatched=nil;UIManager:setDirty(self,"ui")
 local now=os.time()
 if now>self.state.last and not (self.owner.backups and self.owner.backups.blocked) then
  self.engine.advance(self.state,now);self.owner:save()
 end
 if screen=="nickname" then self.nickname_text=self.state.nicknames and self.state.nicknames[tostring(self.state.species)] or "";self.uppercase=true end
 if screen=="backups" then self:loadBackups() end
end
function View:act(action,arg)
 if self.owner.backups and self.owner.backups.blocked then return end
 local previous=self.state.species
 local hatching=action=="hatch" and self.state.egg and self.state.egg.id
 self.message,self.next_effect=self.engine.act(self.state,action,arg,os.time())
 self.owner:save();self:freeImages();self.screen="home";self.entry_from=nil
 if hatching and not self.state.egg then
  self.screen="entry";self.detail_id=hatching;self.preview_pose="idle";self.hatched=hatching;self.next_effect="hello"
 end
 self:animate(self.next_effect,self.next_effect=="evolve" and previous or nil)
 self.action_count=self.action_count+1;UIManager:setDirty(self,self.action_count%12==0 and "flashui" or "ui")
end
function View:paintTo(bb,x,y)
 bb:paintRect(0,0,self.dimen.w,self.dimen.h,WHITE);self.buttons={}
 self.art.text(self,bb,"POKEPAL",32,28,3);self.art.icon(self,bb,"berry",373,24,2)
 self:text(bb,self.state.berries,406,29,18,64);self:button(bb,"Exit",492,20,76,40,"exit")
 self:rect(bb,32,75,536,1)
 if self.state.species==0 and self.screen~="allcompanions" and self.screen~="entry" then self:paintWelcome(bb)
 elseif self.screen=="home" then self:paintHome(bb)
 elseif self.screen=="explore" then self:paintExplore(bb)
 elseif self.screen=="journal" or self.screen=="companions" or self.screen=="allcompanions" then self:paintJournal(bb)
 elseif self.screen=="entry" then self:paintEntry(bb)
 elseif self.screen=="history" then self:paintHistory(bb)
 elseif self.screen=="profile" then self:paintProfile(bb)
 elseif self.screen=="badges" then self:paintBadges(bb)
 elseif self.screen=="play" then self:paintPlay(bb)
 elseif self.screen=="train" then self:paintTrain(bb)
 elseif self.screen=="help" then self:paintHelp(bb)
 elseif self.screen=="reading" then self:paintReading(bb)
 elseif self.screen=="egg" then self:paintEgg(bb)
 elseif self.screen=="backgrounds" then self:paintBackgrounds(bb)
 elseif self.screen=="recap" then self:paintRecap(bb)
 elseif self.screen=="weekly" then self:paintWeekly(bb)
 elseif self.screen=="decorations" then self:paintDecorations(bb)
 elseif self.screen=="nickname" then self:paintNickname(bb)
 elseif self.screen=="backups" then self:paintBackups(bb)
 elseif self.screen=="restore" then self:paintRestore(bb)
 elseif self.screen=="preferences" then self:paintPreferences(bb)
 elseif self.screen=="sleeppreview" then self:paintSleep(bb,true)
 elseif self.screen=="filters" then self:paintFilters(bb)
 elseif self.screen=="snacks" then self:paintSnacks(bb)
 elseif self.screen=="memories" then self:paintMemories(bb)
 elseif self.screen=="bookconfirm" then self:paintBookConfirm(bb)
 elseif self.screen=="readinghistory" then self:paintReadingHistory(bb)
 elseif self.screen=="trailstory" then self:paintTrailStory(bb)
 elseif self.screen=="textentry" then self:paintTextEntry(bb)
 else self:paintMore(bb) end
 if self.owner.save_error and not (self.owner.backups and self.owner.backups.blocked) then
  self:text(bb,"Not saved. Check free storage, then try again.",32,774,16,536,true,true)
 end
end
function View:paintWelcome(bb)
 local id=self.engine.starters[self.starter_index]
 self:text(bb,"Choose your partner",32,105,29,536,true,true)
 self:text(bb,self.engine.name(id),32,166,25,536,true,true);self:sprite(bb,id,176,218,248,1)
 self:text(bb,self.starter_index.." / "..#self.engine.starters,32,488,18,536,false,true)
 self:wrapped(bb,"Feed, play, explore and grow together. Choose a friend for your adventure.",530,19)
 self:button(bb,"Previous",60,602,232,48,"starter",-1)
 self:button(bb,"Next",308,602,232,48,"starter",1)
 self:button(bb,"Start with "..self.engine.name(id),60,658,480,52,"choose",id,"heart")
 self:button(bb,"Choose from all 160 Pokemon",60,720,480,44,"nav","allcompanions")
end
function View:landscape(bb,background)
 local hour=tonumber(os.date("%H"));local night=hour<7 or hour>=19
 self.art.scene(self,bb,background or self.state.background or 1,night,WHITE,GRAY,LIGHT)
 self.art.decorate(self,bb,self.state.decor,WHITE,GRAY,LIGHT)
 if self.screen=="home" and self.state.dirt>=15 then self.art.icon(self,bb,"poop",122,381,2,BB.Color8(85)) end
end
function View:paintHome(bb)
 local s=self.state;local now=os.time()
 self:text(bb,self.engine.displayName(s),32,94,27,395,true);self:text(bb,"Lv "..self.engine.level(s),438,94,25,130,true,true)
 self:text(bb,self.engine.mood(s,now),32,124,17,536,false,true)
 self:paintHomeStage(bb)
 local left=self.engine.tripLeft(s,now)
 local recap=self.owner.recap
 if recap and not self.recap_dismissed then
  self:button(bb,math.floor(recap.seconds/60).." min read / +"..recap.berries.." berries / +"..recap.xp.." XP",32,431,462,42,"nav","recap")
  self:button(bb,"X",506,431,62,42,"dismissrecap")
 else self:wrapped(bb,self.owner.reading_busy and "Checking reading time..." or self.message,433) end
 local stats={{"Food",s.food},{"Joy",s.joy},{"Energy",s.energy},{"Hygiene",100-s.dirt}}
 for i,v in ipairs(stats) do
  local x=32+((i-1)%2)*276;local y=486+math.floor((i-1)/2)*36
  self:text(bb,v[1].." "..math.floor(v[2]),x,y,16,140);self:outline(bb,x+146,y+3,114,12)
  self:rect(bb,x+148,y+5,math.floor(110*v[2]/100),8)
 end
 self:text(bb,self.engine.ready(s) and "Evolution is ready!" or "Bond "..math.floor(s.bond).." / 100   |   "..s.xp.." XP",32,559,17,350)
 self:button(bb,"Profile",431,547,137,36,"nav","profile")
 local buttons={{"Feed","feed",nil,"berry"},{readyLabel("Play",s.played+1800-now),"startplay",nil,"ball"},{readyLabel("Train",s.trained+3600-now),"nav","train","ball"},
  {s.resting and "Wake" or "Rest","rest",nil,"moon"},{s.trip>0 and left==0 and "Collect!" or "Explore","nav","explore","boot"},{"Journal","nav","journal","book"},
  {"Clean","clean",nil,"clean"},{readyLabel("Basket",s.gift+86400-now),"gift",nil,"berry"},{"More","nav","more","settings"}}
 for i,b in ipairs(buttons) do self:button(bb,b[1],32+(i-1)%3*182,596+math.floor((i-1)/3)*57,172,48,b[2],b[3],b[4]) end
 if s.egg then self.buttons[#self.buttons+1]={x=416,y=344,w=60,h=67,action="nav",arg="egg"} end
 self.buttons[#self.buttons+1]={x=168,y=211,w=264,h=204,action=s.trip>0 and "nav" or "hello",arg=s.trip>0 and "explore" or nil}
end
function View:paintHomeStage(bb)
 local s=self.state;local now=os.time();local left=self.engine.tripLeft(s,now)
 local r=self:stageRegion()
 if self.stage_cached and host_stage_restore then host_stage_restore()
 elseif self.stage_background and bb.blitFrom then bb:blitFrom(self.stage_background,r.x,r.y,r.x,r.y,r.w,r.h)
 else
  self:rect(bb,32,180,536,240,WHITE);self:landscape(bb)
  if host_stage_save then host_stage_save(r.x,r.y,r.w,r.h);self.stage_cached=true
  elseif bb.copy then self.stage_background=bb:copy() end
 end
 if s.trip>0 and left>0 and not self.animating then
  self:rect(bb,157,236,286,169,WHITE)
  self.art.icon(self,bb,"boot",270,247,6);self:text(bb,self.engine.routes[s.trip].name,169,310,20,263,true,true)
  self:text(bb,minutes(left)..(s.trail~=nil and " min of reading left" or " min until home"),169,343,17,263,false,true)
  self:progress(bb,181,381,238,self.engine.routes[s.trip].seconds-left,self.engine.routes[s.trip].seconds)
 else
  local size=192;local id=s.species
  for i,member in ipairs(self.engine.evolutionLine(id)) do if member==id then size=176+i*16 end end
  if self.effect=="evolve" and self.previous_species and self.step<=2 then id=self.previous_species end
  local dy=(self.animating and self.effect=="play" and self.frame%2==0) and -6 or 0
  self:rect(bb,253,401,94,3,GRAY);self:rect(bb,265,398,70,3,GRAY)
  local pose=self.animating and self:poseFor(self.effect) or self:poseFor(nil)
  local px=(600-size)/2
  if s.decor and not self.animating then
   if s.resting and s.decor[1] then px=218-size/2
   elseif not s.resting and s.decor[2] and tonumber(os.date("%H"))%3==0 then px=458-size/2;pose="idle"
   elseif not s.resting and s.decor[4] and tonumber(os.date("%H"))%3==1 then px=150-size/2;pose="idle" end
  end
  self:sprite(bb,id,px,414-size+dy,size,self.frame,pose)
  if self.animating and self.effect~="ambient" and self.effect~="ambient_sleep" then self:paintEffect(bb) end
 end
 if s.egg then
  self.art.egg(self,bb,422,353,3,1-self.engine.eggLeft(s)/self.engine.egg_seconds,WHITE)

 end
end
function View:paintStage(bb)
 if self.screen=="home" then self:paintHomeStage(bb)
 elseif self.screen=="entry" then self:rect(bb,120,184,360,280,WHITE);self:sprite(bb,self.detail_id,174,196,252,self.frame,self.preview_pose or "idle")
 else self:paintTo(bb,0,0) end
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
 local s=self.state
 self:title(bb,"Expeditions","Pick a trail and see who you meet.")
 if s.trip>0 then
  local left=self.engine.tripLeft(s,os.time());local r=self.engine.routes[s.trip]
  self:text(bb,r.name,32,196,27,536,true,true)
  self:text(bb,left==0 and "Your discoveries are ready." or minutes(left)..(s.trail~=nil and " reading minutes left" or " minutes until home"),32,241,20,536,false,true)
  self:progress(bb,62,283,476,r.seconds-left,r.seconds)
  for i,item in ipairs(s.finds~=nil and self.engine.discoveries or {}) do
   local y=327+(i-1)*70;local found=s.finds and s.finds>=i
   self.art.icon(self,bb,found and "badge" or "boot",46,y+5,3,found and BLACK or GRAY)
   self:text(bb,item.name..(found and " / found" or " / "..i*25 .."%"),94,y,20,460,true)
   self:text(bb,item.detail,94,y+30,17,460)
  end
  if s.finds==nil then self:wrapped(bb,"Your partner is already on its way. Trail discoveries start with your next expedition.",387,19) end
  self:wrapped(bb,s.trail~=nil and s.reading and not s.reading.enabled and "Reading rewards are paused. Turn them on in Reading."
   or s.trail~=nil and "Keep reading your book. Check back to see what your partner finds." or "Your partner explores while the game is closed.",549,17)
  local story=left==0 and s.companion and s.companion.journey
  self:button(bb,story and "Hear about the trail" or left==0 and "Collect discoveries" or "Check expedition",62,595,476,55,story and "nav" or "collect",story and "trailstory" or nil,"boot")
  self:text(bb,"At the finish: +"..r.berries.." berries, +"..r.xp.." XP and a Pokemon",32,672,17,536,false,true)
 else
  local timed=self.trip_mode~="reading"
  self:button(bb,"As you read",32,185,262,46,"tripmode","reading",nil,false,not timed)
  self:button(bb,"On a timer",306,185,262,46,"tripmode","timed",nil,false,timed)
  for i,r in ipairs(self.engine.routes) do
   local y=253+(i-1)*139
   self:button(bb,r.name.." / "..r.seconds/60 .." min",32,y,536,54,timed and "trip" or "readingtrip",i,"boot")
   self:text(bb,r.energy.." energy   +"..r.berries.." berries   +"..r.xp.." XP",43,y+65,18,513)
   self:text(bb,i==1 and "Grass, Bug, Fire, Electric and other land Pokemon." or i==2 and "Water and Ice Pokemon live along this trail." or "Rock, Ground, Ghost and Psychic Pokemon.",43,y+94,16,513)
  end
  self:text(bb,timed and "Trips finish after real time passes." or "Only new recorded reading moves you along the trail.",32,666,17,536,false,true)
 end
 self:backButton(bb)
end
function View:paintEgg(bb)
 local s=self.state;local left=self.engine.eggLeft(s);local ready=s.egg and left==0
 self:title(bb,"One more chapter",s.egg and "An egg is keeping you company." or "A surprise friend for your reading breaks.")
 self.art.egg(self,bb,244,218,7,s.egg and 1-left/self.engine.egg_seconds or 0,WHITE)
 self:text(bb,ready and "Something is stirring!" or s.egg and minutes(left).." reading minutes to hatch" or "Hatches after 120 reading minutes",32,378,23,536,true,true)
 self:progress(bb,62,427,476,s.egg and self.engine.egg_seconds-left or 0,self.engine.egg_seconds)
 self:wrapped(bb,s.egg and "Keep reading your book, then check back on your egg." or "Pick up an egg for 3 berries. It hatches into a first-form Pokemon, with new friends favoured.",476,18)
 if s.egg then
  self:button(bb,ready and "Hatch your egg" or "Keep reading",62,572,476,56,"hatch",nil,nil,not ready)
 else self:button(bb,"Pick up an egg / 3 berries",62,572,476,56,"egg") end
 self:text(bb,s.reading and not s.reading.enabled and "Reading rewards are paused. Turn them on in Reading."
  or "Hatchlings join your journal. Your partner stays.",32,661,17,536,false,true)
 self:backButton(bb)
end
function View:paintRecap(bb)
 local r=self.owner.recap
 self:title(bb,"Welcome back",r and "Since your last visit" or "Your next reading session will show up here.")
 if r then
  self:text(bb,r.seconds<60 and "Less than a minute read" or math.floor(r.seconds/60).." min read",32,205,30,536,true,true)
  self:text(bb,"+"..r.berries.." berries    +"..r.xp.." XP",32,259,24,536,false,true)
  if r.route>0 then
   local total=self.engine.routes[r.route].seconds
   self:text(bb,self.engine.routes[r.route].name,46,336,21,508,true)
   self:text(bb,math.floor(100*r.trip_before/total).."% to "..math.floor(100*r.trip_after/total).."% of the trail",46,370,18,508)
   self:progress(bb,46,406,508,r.trip_after,total)
  else self:text(bb,"Pick a trail under Explore for your next chapter.",46,370,18,508) end
  if r.egg then
   local percent=math.floor(100*r.egg_after/self.engine.egg_seconds)
   self:text(bb,percent==100 and "Your egg is ready to hatch!" or "Your egg is "..percent.."% of the way there",46,464,21,508,true)
   self:progress(bb,46,508,508,r.egg_after,self.engine.egg_seconds)
  else self:text(bb,"Eggs hatch as you read. Pick one up for 3 berries.",46,479,18,508) end
  if r.events then self:wrapped(bb,"Found: "..table.concat(r.events,", "),550,17) end
  self:wrapped(bb,r.weekly and "Weekly goal reached! Your bonus is included above." or "Keep reading your book. Your next visit will bring more progress.",610,18)
 end
 self:backButton(bb)
end
function View:paintWeekly(bb)
 local w=self.state.week
 self:title(bb,"A little reading goal","A fresh start each Monday. No streak to keep.")
 self:text(bb,"How much would you like to read?",32,203,22,536,true,true)
 for i,target in ipairs(self.engine.weekly_targets) do
  self:button(bb,target/60 .." min",32+(i-1)*182,257,172,54,"goal",target,nil,false,w and w.target==target)
 end
 if w then
  self:text(bb,math.floor(w.seconds/60).." / "..w.target/60 .." min this week",32,367,27,536,true,true)
  self:progress(bb,62,423,476,w.seconds,w.target)
  self:wrapped(bb,w.claimed and "Goal met. Your bonus has been collected." or "Reach your goal for 5 extra berries and 10 XP.",478,19)
 else self:wrapped(bb,"Choose a goal to get started. Reach it for 5 extra berries and 10 XP.",384,20) end
 self:wrapped(bb,"Minutes count in the week you collect them. You can change your target and keep your progress.",590,18)
 self:backButton(bb)
end
function View:paintBackgrounds(bb)
 self:title(bb,"Make yourself at home")
 self:landscape(bb);self:sprite(bb,self.state.species,204,222,192,1,self.state.resting and "sleep" or "idle")
 for i,name in ipairs(self.engine.backgrounds) do
  self:button(bb,name,32+(i-1)%2*274,445+math.floor((i-1)/2)*78,262,56,"background",i,nil,false,(self.state.background or 1)==i)
 end
 self:text(bb,"Tap a scene to keep it as your background.",32,675,17,536,false,true)
 self:backButton(bb)
end
function View:paintDecorations(bb)
 self:title(bb,"Something for your space")
 self:landscape(bb);self:sprite(bb,self.state.species,204,222,192,1,self.state.resting and "sleep" or "idle")
 for id,item in ipairs(self.engine.decorations) do
  local placed=self.state.decor and self.state.decor[id]
  local label=placed~=nil and ((placed and "Hide " or "Place ")..item.name:lower()) or item.name.." / "..item.cost.." berries"
  self:button(bb,label,32+(id-1)%2*274,445+math.floor((id-1)/2)*78,262,56,"decorate",id,nil,false,placed)
 end
 self:wrapped(bb,self.decor_message or "Buy something once, then place it in any background. Tuck it away whenever you like.",625,18)
 self:backButton(bb)
end
function View:paintJournal(bb)
 local choosing=self.screen=="companions" or self.screen=="allcompanions"
 local ids={}
 if choosing then
  local starters={};for _,id in ipairs(self.engine.starters) do starters[id]=true end
  for id=1,160 do
   if self.screen=="allcompanions" or starters[id] or self.state.seen[tostring(id)] then ids[#ids+1]=id end
  end
 else ids=self.engine.companion.journal(self.state,self.engine,self.journal_query,self.journal_filter or "met") end
 self.journal_count=#ids
 local pages=math.max(1,math.ceil(#ids/6));self.page=math.min(self.page or 1,pages)
 if choosing then
  self:title(bb,self.screen=="allcompanions" and "All 160 Pokemon" or "Change companion",
   self.screen=="allcompanions" and "Every Pokemon is available to choose." or "Starters and friends you've met.")
  self:wrapped(bb,"Tap a Pokemon to see its details, then choose it.",190,18)
 else
  self:title(bb,"Field journal",self.engine.kantoCount(self.state).." / 151 Kanto   |   "..#ids.." shown")
  self:button(bb,self.journal_query and self.journal_query~="" and self.journal_query or "Search",32,184,172,42,"journalSearch")
  self:button(bb,"Filter",214,184,172,42,"nav","filters")
  self:button(bb,"My partner",396,184,172,42,"entry",self.state.species)
 end
 for pos=(self.page-1)*6+1,math.min(self.page*6,#ids) do
  local i=pos-(self.page-1)*6-1;local x=32+(i%3)*182;local y=241+math.floor(i/3)*164
  self:sprite(bb,ids[pos],x+28,y,116,1);self:text(bb,self.engine.displayName(self.state,ids[pos]),x,y+124,17,172,false,true)
  self.buttons[#self.buttons+1]={x=x,y=y,w=172,h=154,action="entry",arg=ids[pos]}
 end
 self:button(bb,"Previous",32,597,170,43,"page",-1,nil,self.page==1)
 self:text(bb,self.page.." / "..pages,217,609,20,166,false,true)
 self:button(bb,"Next",398,597,170,43,"page",1,nil,self.page==pages)
 if choosing then
  if self.screen=="companions" then
   self:button(bb,"Choose from all 160 Pokemon",32,652,536,44,"nav","allcompanions")
  else self:wrapped(bb,"XP, bond and nicknames stay with each friend.",662,18) end
  local back=self.state.species==0 and "home" or self.screen=="allcompanions" and "companions" or "profile"
  local label=back=="home" and "Back to starters" or back=="companions" and "Back to companions" or "Back to profile"
  self:button(bb,label,32,717,536,44,"nav",back)
 else
  self:button(bb,"Activity",32,659,262,43,"nav","history","book")
  self:button(bb,"Badges",306,659,262,43,"nav","badges","badge");self:backButton(bb)
 end
end
function View:paintEntry(bb)
 local id=self.detail_id;local name=self.engine.name(id)
 self:title(bb,self.hatched==id and "Just hatched!" or string.format("#%03d  %s",id,name),
  (self.hatched==id and name.."   /   " or "")..self.engine.species[id].types)
 self:sprite(bb,id,174,196,252,self.frame,self.preview_pose or "idle")
 local poses={{"Idle","idle"},{"Sleep","sleep"},{"Walk","walk"},{"Attack","attack"},{"Eat","eat"}}
 for i,p in ipairs(poses) do
  local available=self.poses[id] and self.poses[id][p[2]]
  self:button(bb,p[1],32+(i-1)*109,476,100,46,"preview",p[2],nil,not available,self.preview_pose==p[2])
 end
 local p=id==self.state.species and self.state or (self.state.partners and self.state.partners[tostring(id)]) or {xp=0,bond=0}
 self:text(bb,p.xp.." XP   /   Bond "..math.floor(p.bond).."   /   Tap a pose to preview",32,546,17,536,false,true)
 local label=id==self.state.species and "Your current partner" or self.state.trip>0 and "Collect your trip before changing"
  or self.state.resting and "Wake up before changing" or "Choose "..name
 self:button(bb,label,32,594,536,52,self.state.species==0 and "choose" or "partner",id,"heart",id==self.state.species or self.state.trip>0 or self.state.resting)
 local C=self.engine.companion;local trait,berry=C.profile(self.state,id,self.engine)
 local c=self.state.companion;local known=c and c.tastes[tostring(id)]
 self:text(bb,trait..(known and " / Likes "..berry or " / Try different berries"),32,658,17,344)
 self:button(bb,c and c.favourites[tostring(id)] and "Unfavourite" or "Favourite",398,652,170,42,"favourite",id,nil,not self.state.seen[tostring(id)])
 local back=self.entry_from or "journal"
 self:button(bb,back=="journal" and "Back to journal" or back=="allcompanions" and "Back to all 160 Pokemon" or "Back to companions",32,717,536,44,"nav",back)
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
 self:title(bb,"Partner",self.engine.displayName(s).."   /   Lv "..lv.."   /   Bond "..math.floor(s.bond).." / 100")
 self:button(bb,"Change companion",182,97,239,40,"nav","companions")
 self:button(bb,"Nickname",431,97,137,40,"nav","nickname")
 for i,id in ipairs(line) do
  local x=(600-(#line*182-10))/2+(i-1)*182;self:sprite(bb,id,x+26,183,120,1)
  self:text(bb,self.engine.name(id),x,317,18,172,id==s.species,true)
  local previous=i>1 and self.engine.species[line[i-1]]
  local requirement=previous and "Lv "..(1+math.ceil(previous[3]/20)).." + 30 bond" or "First form"
  self:text(bb,requirement,x,350,14,172,false,true)
  if id==s.species then self:rect(bb,x+30,378,112,3) end
 end
 local p=self.engine.species[s.species]
 if #choices>0 then
  self:text(bb,"XP "..s.xp.." / "..p[3],32,409,18,262,true)
  local xp_left=math.max(0,p[3]-s.xp)
  self:text(bb,xp_left==0 and "XP ready" or xp_left.." XP to go",306,409,17,262,false,true)
  self:progress(bb,32,438,536,s.xp,p[3])
  local bond_left=math.max(0,math.ceil(30-s.bond))
  self:text(bb,"Bond "..math.floor(s.bond).." / 30",32,465,18,262,true)
  self:text(bb,bond_left==0 and "Bond ready" or bond_left.." bond to go",306,465,17,262,false,true)
  self:progress(bb,32,493,536,s.bond,30)
 end
 if #choices>1 then
  for i,id in ipairs(choices) do
   self:button(bb,self.engine.evolution_stones[id]..": "..self.engine.name(id),32,520+(i-1)*50,536,44,"evolve",id,nil,not self.engine.ready(s))
  end
 elseif #choices==1 then
  local id=choices[1]
  self:button(bb,self.engine.ready(s) and "Evolve into "..self.engine.name(id) or "Growing toward "..self.engine.name(id),32,538,536,56,"evolve",id,"clean",not self.engine.ready(s))
  self:text(bb,"Feed, play and train together to build your bond.",32,620,17,536,false,true)
 else self:wrapped(bb,self.engine.name(s.species).." is fully evolved. Keep exploring and fill your field journal together.",465,19) end
 self:text(bb,"Together for "..math.max(0,math.floor((os.time()-s.started)/86400)).." days   /   "..s.trips.." expeditions",32,681,18,536,false,true)
 self:backButton(bb)
end
function View:paintNickname(bb)
 self:title(bb,"What should we call you?","Up to 12 characters. Kept after evolution.")
 self:outline(bb,32,198,536,58)
 self:text(bb,self.nickname_text~="" and self.nickname_text or self.engine.name(self.state.species),48,211,25,504,true,true)
 self:text(bb,#(self.engine.companion.text.chars(self.nickname_text) or {}).." / 12",32,271,16,300,false,true)
 self:button(bb,"Keyboard",398,263,170,38,"unicodekeyboard")
 self:paintKeys(bb,"nickkey")
 self:button(bb,self.uppercase and "abc" or "ABC",32,553,172,46,"nickcase")
 self:button(bb,"Space",214,553,172,46,"nickkey"," ")
 self:button(bb,"Delete",396,553,172,46,"nickdelete")
 self:button(bb,"Reset",32,628,120,50,"nickclear")
 self:button(bb,"Accents",164,628,130,50,"accents")
 self:button(bb,"Save name",306,628,262,50,"nicksave")
 self:button(bb,"Back to profile",32,717,536,44,"nav","profile")
end
function View:loadBackups()
 self.backup_info={};self.backup_errors={}
 for _,slot in ipairs({"backup","before-restore"}) do
  if self.owner.backups then self.backup_info[slot],self.backup_errors[slot]=self.owner.backups:preview(slot)
  else self.backup_errors[slot]="Backups are unavailable." end
 end
end
function View:paintBackups(bb)
 self:title(bb,"Keep your progress","Your game and reading records, saved together.")
 if self.owner.backups and self.owner.backups.blocked then
  self:wrapped(bb,"Restore stopped before it finished. Close and reopen PokePal to finish restoring.",310,22)
  self:button(bb,"Close PokePal",32,595,536,55,"exit");return
 end
 if not self.backup_info then self:loadBackups() end
 self:button(bb,"Save a backup now",32,194,536,52,"makebackup",nil,nil,not self.owner.backups)
 for i,slot in ipairs({"backup","before-restore"}) do
  local b=self.backup_info[slot];local y=283+(i-1)*164
  self:text(bb,i==1 and "Saved backup" or "Before last restore",32,y,23,536,true)
  self:text(bb,b and savedDate(b.at)..(b.previous and " / previous copy" or "") or self.backup_errors[slot],32,y+35,17,536)
  self:button(bb,"Preview",32,y+74,536,46,"previewbackup",slot,nil,not b)
 end
 self:wrapped(bb,self.backup_message or "Preview a backup before restoring. Your current game is kept so you can go back.",632,18)
 self:backButton(bb)
end
function View:paintRestore(bb)
 local b=self.restore_preview
 if not b then self:paintBackups(bb);return end
 local s=b.state
 self:title(bb,"Restore this backup?",savedDate(b.at))
 self:text(bb,self.engine.displayName(s).." / Lv "..self.engine.level(s),32,202,26,536,true,true)
 if s.species~=0 then self:sprite(bb,s.species,204,252,192,1) end
 self:text(bb,s.berries.." berries / "..self.engine.count(s.seen).." Pokemon met",32,465,20,536,false,true)
 self:text(bb,math.floor((s.reading and s.reading.seconds or 0)/60).." minutes read",32,504,20,536,false,true)
 self:wrapped(bb,"Your current game will be kept under Before last restore.",553,18)
 self:button(bb,"Restore this backup",32,618,536,55,"restorebackup")
 self:button(bb,"Cancel",32,717,536,44,"nav","backups")
end
function View:paintBadges(bb)
 self:title(bb,"Achievements",self.engine.count(self.state.badges).." of "..#self.engine.badge_goals.." badges earned")
 local pages=math.ceil(#self.engine.badge_goals/6);self.page=math.min(self.page or 1,pages)
 for i=(self.page-1)*6+1,math.min(self.page*6,#self.engine.badge_goals) do
  local b=self.engine.badge_goals[i];local y=185+(i-1)%6*73;local earned=self.state.badges[b[1]];self.art.icon(self,bb,"badge",39,y+6,3,earned and BLACK or GRAY)
  self:text(bb,b[1]..(earned and " - earned" or ""),91,y,20,469,earned);self:text(bb,b[2],91,y+33,16,469);self:rect(bb,91,y+66,477,1,LIGHT)
 end
 self:button(bb,"Previous",32,652,262,44,"extrapage",-1,nil,self.page==1)
 self:button(bb,"Next",306,652,262,44,"extrapage",1,nil,self.page==pages)
 self:backButton(bb)
end
function View:startPlay()
 self.engine.advance(self.state,os.time());local allowed,why=self.engine.canPlay(self.state,os.time())
 if not allowed then self.message=why;self:go("home");return end
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
 self:title(bb,"Around the nest","A few small comforts for your partner.")
 self:button(bb,"Preferences",32,191,262,50,"nav","preferences")
 self:button(bb,"Books together",306,191,262,50,"nav","memories")
 self:button(bb,"Backgrounds",32,263,262,50,"nav","backgrounds")
 self:button(bb,"Decorations",306,263,262,50,"nav","decorations")
 self:text(bb,"Animation",32,339,20,536,true)
 for i,b in ipairs({{"Gentle","gentle"},{"Eco","eco"},{"Off","off"}}) do self:button(bb,b[1],32+(i-1)*182,375,172,48,"animation",b[2],nil,false,self.state.animation==b[2]) end
 self:text(bb,"Gentle: up to 4 frames. Eco: 2 frames. Off: still.",32,440,17,536)
 self:button(bb,"Refresh screen - clear ghosting",32,488,536,48,"refresh",nil,"clean")
 self:button(bb,"Care guide",32,558,262,48,"nav","help","book")
 self:button(bb,"Favourite berries",306,558,262,48,"nav","snacks","berry")
 self:button(bb,"Reading rewards",32,628,262,48,"nav","reading","book")
 self:button(bb,"Backups",306,628,262,48,"nav","backups")
 self:backButton(bb)
end
function View:paintReading(bb)
 local r=self.state.reading or {enabled=true,seconds=0,carry=0}
 self:title(bb,"Reading","Keep reading your book.")
 self:button(bb,"Check again",398,97,170,40,"rescan")
 self:text(bb,math.floor(r.seconds/60).." minutes read",32,211,28,536,true,true)
 self:progress(bb,62,267,476,r.carry%900,900)
 self:text(bb,math.ceil((900-r.carry%900)/60).." min to the next reward",32,304,20,536,false,true)
 self:text(bb,"15 minutes = 1 berry + 3 XP",32,347,17,536,false,true)
 self:button(bb,"Expeditions",32,411,262,54,"nav","explore","boot")
 self:button(bb,self.state.egg and self.engine.eggLeft(self.state)==0 and "Hatch your egg" or "Your egg",306,411,262,54,"nav","egg")
 self:button(bb,"Weekly goal",32,487,262,54,"nav","weekly")
 self:button(bb,"Last visit",306,487,262,54,"nav","recap",nil,not self.owner.recap)
 self:button(bb,r.enabled and "Rewards: On" or "Rewards: Off",32,570,262,48,"reading",nil,"book",false,r.enabled)
 self:button(bb,"Reading history",306,570,262,48,"nav","readinghistory")
 local status=self.owner.reading_status or {"Kindle: checked when you open PokePal","KOReader: tracks while you read"}
 for i,line in ipairs(status) do self:text(bb,line,32,643+(i-1)*30,16,536) end
 self:backButton(bb)
end
function View:paintHelp(bb)
 self:title(bb,"Care guide","Two or three brief visits a day are enough.")
 local help={{"Feed","One berry restores 24 food. The basket refills daily."},{"Play","Follow a 3-step berry trail. Ready every 30 minutes."},
  {"Train","Practice a move each hour to earn XP and bond."},{"Rest and clean","Rest restores energy. Clean to keep the nest tidy."},
  {"Read and explore","Reading advances trips and helps eggs hatch."},{"Grow together","Every 20 XP is a level. Evolve from Profile."}}
 for i,h in ipairs(help) do local y=190+(i-1)*78;self:text(bb,h[1],32,y,20,536,true);self:text(bb,h[2],32,y+31,16,536) end
 self:backButton(bb)
end
function View:onTap(_,ges)
 if self.closed or self.suspended then return true end
 local x=(ges.pos.x-self.ox)/self.scale;local y=(ges.pos.y-self.oy)/self.scale
 for _,b in ipairs(self.buttons) do if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then
  if b.action=="exit" then self:leave()
  elseif self.owner.backups and self.owner.backups.blocked then return true
  elseif self.owner.reading_busy and b.action~="nav" and b.action~="page" then return true
  elseif b.disabled then return true
  elseif self:companionTap(b.action,b.arg) then return true
  elseif b.action=="starter" then
   self.starter_index=(self.starter_index-1+b.arg)%#self.engine.starters+1
   self:freeImages();UIManager:setDirty(self,"ui")
  elseif b.action=="nav" then
   self:go(b.arg);if b.arg=="home" then self.message=self.engine.act(self.state,"check",nil,os.time()) end
  elseif b.action=="entry" then
   self.entry_from=self.screen
   self:go("entry");self.detail_id=b.arg;self.preview_pose="idle"
  elseif b.action=="preview" then self.preview_pose=b.arg;self:animate("preview");UIManager:setDirty(self,"ui")
  elseif b.action=="hello" then self.message=self.engine.act(self.state,"check",nil,os.time());self:animate("hello");UIManager:setDirty(self,"ui")
  elseif b.action=="startplay" then self:startPlay()
  elseif b.action=="hidepath" then self.play_phase="pick";UIManager:setDirty(self,"ui")
  elseif b.action=="pickbush" then self:pickBush(b.arg)
  elseif b.action=="refresh" then self:stopAnimation();UIManager:setDirty(self,"full")
  elseif b.action=="tripmode" then self.trip_mode=b.arg;UIManager:setDirty(self,"ui")
  elseif b.action=="decorate" then
   self.decor_message=self.engine.act(self.state,"decorate",b.arg,os.time());self.owner:save();UIManager:setDirty(self,"ui")
  elseif b.action=="nickkey" then
   if #(self.engine.companion.text.chars(self.nickname_text) or {})<12 then self.nickname_text=self.nickname_text..b.arg end;UIManager:setDirty(self,"ui")
  elseif b.action=="nickcase" then self.uppercase=not self.uppercase;UIManager:setDirty(self,"ui")
  elseif b.action=="nickdelete" then self.nickname_text=self.engine.companion.text.pop(self.nickname_text);UIManager:setDirty(self,"ui")
  elseif b.action=="nickclear" then self.nickname_text="";UIManager:setDirty(self,"ui")
  elseif b.action=="nicksave" then
   self.message=self.engine.act(self.state,"nickname",self.nickname_text,os.time());self.owner:save();self:go("profile")
  elseif b.action=="makebackup" then
   local ok,err=self.owner.backups:create(self.state)
   if ok then self.owner.save_error=nil end
   self.backup_message=ok and "Backup saved." or tostring(err or "Could not save the backup.")
   self:loadBackups();UIManager:setDirty(self,"ui")
  elseif b.action=="previewbackup" then
   self.restore_preview=self.backup_info[b.arg];self:go("restore")
  elseif b.action=="restorebackup" then
   local ok,err=self.owner.backups:restore(self.state,self.restore_preview)
   if ok then
    self.owner.save_error=nil;self.owner.recap=nil;self.restore_preview=nil;self.message="Backup restored. Your previous game was kept.";self:go("home")
   else self.backup_message=tostring(err or "Could not restore the backup.");self:go("backups") end
  elseif b.action=="page" then
   local count=self.screen=="history" and #self.state.log or (self.journal_count or self.engine.count(self.state.seen))
   self:freeImages();self.page=math.max(1,math.min(math.max(1,math.ceil(count/6)),self.page+b.arg));UIManager:setDirty(self,"ui")
  elseif b.action=="animation" or b.action=="background" or b.action=="goal" then self.engine.act(self.state,b.action,b.arg,os.time());self.owner:save();UIManager:setDirty(self,"ui")
  elseif b.action=="reading" then
   if self.owner.toggleReading then self.owner:toggleReading() end
   UIManager:setDirty(self,"ui")
  else self:act(b.action,b.arg) end
  return true
 end end
 return true
end
function View:onSwipe() return true end
function View:onBack()
 if self.screen=="home" or (self.owner.backups and self.owner.backups.blocked) then self:leave()
 elseif self.screen=="companions" then self:go("profile")
 elseif self.screen=="allcompanions" then self:go(self.state.species==0 and "home" or "companions")
 elseif self.screen=="entry" and self.entry_from and self.entry_from~="journal" then self:go(self.entry_from)
 else self:go("home") end
 return true
end
function View:onClose() self:leave();return true end
function View:leave()
 if self.closed then return end
 self:stopAnimation();self.closed=true;local ok=self.owner:save();UIManager:close(self,"full")
 if not ok then UIManager:show(require("ui/widget/infomessage"):new{text=self.owner.backups and self.owner.backups.blocked
  and "Reopen PokePal to finish restoring your backup." or "PokePal could not save. Check free space on the Kindle before playing again."}) end
end
function View:onCloseWidget()
 self:stopAnimation();self.closed=true;self:freeImages();self.owner.view=nil
 if self.owner.onPetClosed then self.owner:onPetClosed() end
end
function View:onSuspend()
 if self.suspended or self.closed then return end;self.suspended=true;self:stopAnimation();self.engine.companion.suspend(self.state,self.engine,os.time());self.owner:save()
end
function View:onResume()
 if not self.suspended or self.closed then return end
 self.engine.companion.resume(self.state,self.engine,os.time());self.owner:save()
 self.suspended=false;self:freeImages();self:geometry();self.message=self.engine.act(self.state,"check",nil,os.time());UIManager:setDirty(self,"full")
end
function View:onSetDimensions() self:stopAnimation();self:freeImages();self:geometry();UIManager:setDirty(self,"full");return true end
dofile(debug.getinfo(1,"S").source:sub(2):match("^(.*)/").."/companion_view.lua")(View,UIManager,BB)
return View
