-- Fixed-size card with deferred data reads and bounded, visible-only animation.
local InputContainer=require("ui/widget/container/inputcontainer")
local U=require("ui/uimanager")
local Device=require("device")
local Geom=require("ui/geometry")
local GestureRange=require("ui/gesturerange")
local TextWidget=require("ui/widget/textwidget")
local ImageWidget=require("ui/widget/imagewidget")
local RenderImage=require("ui/renderimage")
local Font=require("ui/font")
local BB=require("ffi/blitbuffer")
local Card=InputContainer:extend{}
local pack,poses
local function sc(n) return Device.screen:scaleBySize(n) end
local BLACK,GRAY,LIGHT=BB.COLOR_BLACK,BB.Color8(100),BB.Color8(210)
function Card:init()
 self.narrow=self.width<sc(300)
 self.dimen=Geom:new{w=self.width,h=sc((self.detailed and 290 or 120)+(self.narrow and 90 or 0))}
 self.texts={};self.images={};self.frame=1
 self.snapshot={message="Loading your partner..."}
 self.ges_events.TapPokePal={GestureRange:new{ges="tap",range=function() return self.dimen end}}
 self.refresh_task=function()
  self.refresh_pending=nil
  if not self:visible() then self:pause();return end
  local s=self.module.snapshot()
  local signature=s.signature or s.message
  local mode=self.module.animation(s)
  local changed=signature~=self.signature or mode~=self.mode
  local animate=self.arriving or s.species~=self.snapshot.species or s.pose~=self.snapshot.pose or s.mood~=self.snapshot.mood
  self.arriving=false
  if changed then
   self:stopAnimation();self:freeContent()
   self.snapshot,self.signature,self.mode=s,signature,mode
   self:loadImages()
  end
  if animate then self:startAnimation() end
  if changed then self:repaint() end
  if not self.poll_pending then self.poll_pending=true;U:scheduleIn(60,self.poll_task) end
 end
 self.poll_task=function() self.poll_pending=nil;self:queueUpdate() end
 self.animation_task=function()
  if not self:visible() then self:pause();return end
  self.frame=self.frame+1
  if self.frame>#self.images then self.frame=1;self.animating=false
  else U:scheduleIn(self.mode=="gentle" and 0.45 or 0.8,self.animation_task) end
  self:repaint(true)
 end
end
function Card:visible()
 if self.dead or Device.screen_saver_mode or not self.host then return false end
 local p=self.module.owner()
 if not p or p.closed or p.suspended then return false end
 if self.host.isActive and not self.host:isActive() then return false end
 return U:getTopmostVisibleWidget()==self.host
end
function Card:queueUpdate()
 if self.refresh_pending or not self:visible() then return end
 self.refresh_pending=true;U:scheduleIn(0.05,self.refresh_task)
end
function Card:stopAnimation()
 U:unschedule(self.animation_task);self.animating=false;self.frame=1
end
function Card:pause()
 self:stopAnimation();U:unschedule(self.refresh_task);U:unschedule(self.poll_task)
 self.refresh_pending=nil;self.poll_pending=nil;self.active=false
end
function Card:onSuspend() self:pause() end
function Card:onShowingReader() self:pause() end
Card.onSetupShowReader=Card.onShowingReader
function Card:onResume() self.active=false;self:queueUpdate() end
function Card:onTapPokePal()
 if not self:visible() then return end
 self:pause();self.module.open();return true
end
function Card:startAnimation()
 self:stopAnimation()
 if self.mode=="off" or #self.images<2 or not self:visible() then return end
 self.animating=true;U:scheduleIn(self.mode=="gentle" and 0.45 or 0.8,self.animation_task)
end
function Card:repaint(sprite_only)
 if not self:visible() then return end
 local region=sprite_only and self.sprite_region or self.dimen
 if self.dirty then self.dirty(region)
 else U:setDirty(self.host,"ui",region) end
end
function Card:freeContent()
 for _,t in pairs(self.texts) do t:free() end;self.texts={}
 for _,img in ipairs(self.images) do img:free() end;self.images={}
end
function Card:free()
 if self.dead then return end
 self.dead=true;self:pause();self:freeContent();self.host=nil;self.dirty=nil
end
function Card:loadImages()
 local s=self.snapshot
 if not s.species then return end
 pack=pack or dofile(self.path.."/assets/sprites.lua")
 poses=poses or dofile(self.path.."/assets/poses.lua")
 local pose=s.pose or "idle"
 local count=poses[s.species] and poses[s.species][pose] or 1
 local frames={1}
 if self.mode=="eco" and count>1 then frames[2]=math.floor(count/2)+1
 elseif self.mode=="gentle" then for i=2,math.min(4,count) do frames[#frames+1]=i end end
 self.sprite_size=math.max(8,math.floor(math.min(sc(self.narrow and 80 or 128),self.width*(self.narrow and 0.7 or 0.28))))
 for _,frame in ipairs(frames) do
  local ok,img=pcall(function()
   local name=s.species.."-"..pose.."-"..frame..".png"
   if not pack.index[name] then name=s.species.."-idle-1.png" end
   local data=pack.read(self.path.."/assets",name)
   local raw=assert(RenderImage:renderImageData(data,#data,false))
   -- All existing PokePal animation frames share this grounded 80px box.
   local crop=BB.new(80,80,raw:getType());crop:blitFrom(raw,0,0,8,10,80,80);raw:free()
   local scaled=crop
   if self.sprite_size~=80 then scaled=crop:scale(self.sprite_size,self.sprite_size);crop:free() end
   return ImageWidget:new{image=scaled,image_disposable=true,alpha=true,
    width=self.sprite_size,height=self.sprite_size,scale_for_dpi=false}
  end)
  if not ok then
   require("logger").warn("PokePal card sprite:",img);break
  end
  self.images[#self.images+1]=img
 end
end
function Card:text(bb,value,x,y,size,width,bold,color)
 if width<1 then return end
 value=tostring(value)
 local key=table.concat({value,size,width,bold and 1 or 0,color and color==GRAY and 1 or 0},"|")
 local t=self.texts[key]
 if not t then
  t=TextWidget:new{text=value,face=Font:getFace(bold and "tfont" or "cfont",size),bold=bold,
   max_width=width,padding=0,fgcolor=color or BLACK};self.texts[key]=t
 end
 t:paintTo(bb,x,y)
end
function Card:bar(bb,x,y,w,value)
 if w<1 then return end
 local h=math.max(2,sc(5));bb:paintRect(x,y,w,h,LIGHT)
 local fill=math.floor(w*math.max(0,math.min(1,value)))
 if fill>0 then bb:paintRect(x,y,fill,h,BLACK) end
end
function Card:paintTo(bb,x,y)
 self.dimen.x,self.dimen.y=x,y
 local pad=sc(10);local s=self.snapshot
 local side=self.sprite_size or sc(80)
 local sx=x+(self.narrow and math.floor((self.width-side)/2) or pad)
 local sy=y+(self.narrow and pad or math.floor((self.dimen.h-side)/2))
 self.sprite_region=Geom:new{x=sx,y=sy,w=side,h=side}
 local img=self.images[self.frame] or self.images[1]
 if img then img:paintTo(bb,sx,sy) end
 local tx=self.narrow and x+pad or x+math.max(side+2*pad,math.floor(self.width*0.32))
 local ty=y+pad+(self.narrow and sc(90) or 0)
 local tw=x+self.width-pad-tx
 if not s.species then
  tx=x+pad;tw=self.width-2*pad;ty=y+pad
  self:text(bb,"PokePal",tx,ty,22,tw,true)
  self:text(bb,s.message,tx,ty+sc(34),14,tw,false,GRAY)
 else
  self:text(bb,s.name,tx,ty,22,tw,true)
  self:text(bb,"Lv "..s.level.." / "..s.xp_label,tx,ty+sc(29),14,tw)
  self:text(bb,s.mood,tx,ty+sc(50),13,tw,false,GRAY)
  self:bar(bb,tx,ty+sc(73),tw,s.xp_fraction)
  if self.detailed then
   for i,row in ipairs(s.care) do
    local ry=ty+sc(92+(i-1)*22)
    self:text(bb,row[1].." "..row[2].."%",tx,ry,13,math.min(tw,sc(100)),false,GRAY)
    self:bar(bb,tx+sc(103),ry+sc(7),tw-sc(103),row[2]/100)
   end
   for i,line in ipairs({self.narrow and s.reading_short or s.reading,
    self.narrow and s.adventure_short or s.adventure,s.notice or s.milestone}) do
    self:text(bb,line,tx,ty+sc(210+(i-1)*20),12,tw,false,GRAY)
   end
  else self:text(bb,self.narrow and s.summary_short or s.summary,tx,ty+sc(89),12,tw,false,GRAY) end
 end
 -- Start only when actually painted on the foreground home screen. A layout
 -- measurement or preview must never start background work.
 if self:visible() then
  if not self.active then self.active=true;self.arriving=true;self:queueUpdate() end
 else self:pause() end
end
return Card
