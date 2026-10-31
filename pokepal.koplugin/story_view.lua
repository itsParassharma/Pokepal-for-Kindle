-- Story walking shares the existing finite timer and save-failure lifecycle.
return function(View,UIManager,BB,Device)
 local X,Y,TILE,COLS,ROWS=44,174,32,16,12
 function View:storyImage(bb,name,x,y,w,h)
  self.story_sprites=self.story_sprites or dofile(self.path.."/assets/story/sprites.lua")
  self:packedImage(bb,self.story_sprites,"assets/story",name..".png",x,y,w,h or w)
 end
 function View:walkStory(path)
  local S=self.engine.story;local t=self.state.story
  if not t or t.node or self.world_save_failed or self.owner.save_error then return end
  self:stopAnimation()
  if not path or #path==0 then return end
  self.world_path=path
  local index=1
  local function step()
   if self.world_tick~=step then return end
   if self.closed or self.suspended or Device.screen_saver_mode or self.screen~="story"
    or self.owner.reading_busy or (self.owner.backups and self.owner.backups.blocked) then self:stopWorldWalk();return end
   local oldmap,x,y=t.map,t.x,t.y;local d=path[index]
   local changed=S.step(t,d[1],d[2])
   if changed then self.world_dirty=true end
   index=index+1
   if not changed or t.node or oldmap~=t.map or x==t.x and y==t.y or index>#path then
    self:stopWorldWalk();self:saveWorld()
    if oldmap~=t.map then self:freeImages() end
   elseif self.state.animation~="off" then UIManager:scheduleIn(self.state.animation=="eco" and 0.3 or 0.2,step) end
   UIManager:setDirty(self,"ui")
  end
  self.world_tick=step
  if self.state.animation=="off" then while self.world_path do step() end else step() end
 end
 function View:paintStoryBattle(bb,t)
  local E=self.engine;local B=E.story.battle;local b=t.battle;local blocked=self.world_save_failed or self.owner.save_error
  self:title(bb,"Rival battle",b.status=="active" and "Turn "..b.turn.." / Choose a move." or "The battle is over.")
  self:outline(bb,36,200,248,94)
  self:text(bb,E.name(B.opponent(b)),44,207,21,230,true)
  self:text(bb,b.hp.." / "..B.maxFoeHP(b).." HP",44,239,16,230)
  self:progress(bb,44,265,220,b.hp,B.maxFoeHP(b))
  self:classic(bb,B.opponent(b).."-front",404,200,112)
  self:classic(bb,t.starter.."-back",76,270,144)
  self:outline(bb,294,314,266,99)
  self:text(bb,E.name(t.starter),308,321,21,240,true)
  self:text(bb,t.hp.." / 40 HP",308,353,16,240)
  self:progress(bb,308,382,236,t.hp,40)
  self:outline(bb,32,419,536,90)
  for i,line in ipairs(b.log) do self:text(bb,line,44,425+(i-1)*21,15,512) end
  if b.status=="active" then
   for slot=1,2 do
    local damage,move=B.preview(E,b,slot);local y=521+(slot-1)*80
    self:outline(bb,32,y,536,70)
    self:text(bb,move.name..(move.power>0 and " / "..damage.." damage" or ""),48,y+9,21,504,true)
    self:text(bb,B.hint(E,b,slot),48,y+44,16,504)
    self.buttons[#self.buttons+1]={x=32,y=y,w=536,h=70,action="storyturn",arg=slot,disabled=blocked}
   end
  else
   self:wrapped(bb,b.status=="won" and "You won! Continue your journey back to Elm." or "The stranger leaves. Your journey continues.",536,19)
   self:button(bb,"Continue",32,622,536,48,"storyfinish",nil,nil,blocked)
  end
 end
 function View:paintStory(bb)
  local S=self.engine.story;local t=self.state.story
  if not t then
   self:title(bb,"Crystal story","Save and finish syncing before starting your journey.")
   self:button(bb,"Start story",32,614,536,48,"nav","story",nil,self.owner.reading_busy or self.world_save_failed or self.owner.save_error)
  elseif t.battle then self:paintStoryBattle(bb,t)
  else
   local m=S.maps[t.map];local n=t.node and S.nodes[t.node]
   self:title(bb,m.name,t.starter==0 and "Chapter 1 / A favour for Professor Elm" or self.engine.name(t.starter).." / "..t.hp.." HP"..(t.egg and " / Mystery Egg" or ""))
   local cx=math.max(0,math.min(m.width-COLS,t.x-math.floor(COLS/2)))
   local cy=math.max(0,math.min(m.height-ROWS,t.y-math.floor(ROWS/2)))
   local ox=X+math.max(0,(COLS-m.width)*TILE/2);local oy=Y+math.max(0,(ROWS-m.height)*TILE/2)
   for y=cy,math.min(m.height-1,cy+ROWS-1) do for x=cx,math.min(m.width-1,cx+COLS-1) do
    local px,py=ox+(x-cx)*TILE,oy+(y-cy)*TILE
    self:storyImage(bb,"tile-"..m.tiles[y*m.width+x+1],px,py,TILE)
    if not n then self.buttons[#self.buttons+1]={x=px,y=py,w=TILE,h=TILE,action="storytile",arg=y*m.width+x} end
   end end
   for _,p in ipairs(S.npcs(t)) do if p[1]>=cx and p[1]<cx+COLS and p[2]>=cy and p[2]<cy+ROWS then
    self:storyImage(bb,p[3].."-down",ox+(p[1]-cx)*TILE,oy+(p[2]-cy)*TILE,TILE)
   end end
   self:storyImage(bb,"chris-"..t.facing,ox+(t.x-cx)*TILE,oy+(t.y-cy)*TILE,TILE)
   self:outline(bb,X-2,Y-2,COLS*TILE+4,ROWS*TILE+4)
   if n then
    self:rect(bb,32,408,536,301,BB.COLOR_WHITE);self:outline(bb,32,408,536,301)
    self:text(bb,n.who,48,423,22,504,true,true)
    for i,line in ipairs(n.lines) do self:text(bb,line,48,462+(i-1)*30,17,504,false,true) end
    local blocked=self.world_save_failed or self.owner.save_error
    for i,choice in ipairs(n.choices or {{"Continue"}}) do
     self:button(bb,choice[1],48,570+(i-1)*44,504,40,"storynext",i,nil,blocked)
    end
   else
    self:wrapped(bb,S.objective(t),568,16)
    self:button(bb,"Up",261,614,78,42,"storydir","up")
    self:button(bb,"Left",171,662,78,42,"storydir","left")
    self:button(bb,"Down",261,662,78,42,"storydir","down")
    self:button(bb,"Right",351,662,78,42,"storydir","right")
    self:button(bb,"Help",32,662,120,42,"storyhelp")
   end
  end
  if self.world_save_failed or self.owner.save_error then self:button(bb,"Retry save",32,717,536,44,"worldretry")
  else self:button(bb,"Pause",32,717,536,44,"nav","home") end
 end
 function View:storyTap(action,arg)
  if not action:match("^story") then return false end
  local S=self.engine.story;local t=self.state.story
  if self.screen~="story" or not t or self.world_save_failed or self.owner.save_error then return true end
  local changed
  if action=="storytile" then local m=S.maps[t.map];self:walkStory(S.path(t,arg%m.width,math.floor(arg/m.width)))
  elseif action=="storydir" and S.directions[arg] then self:walkStory({S.directions[arg]})
  elseif action=="storynext" then changed=S.advance(t,arg)
  elseif action=="storyturn" then changed=S.turn(t,self.engine,arg)
  elseif action=="storyfinish" then changed=S.finishBattle(t)
  elseif action=="storyhelp" and not t.node then self:stopAnimation();t.node="sign";changed=true end
  if changed then self.world_dirty=true;self:saveWorld();UIManager:setDirty(self,"ui") end
  return true
 end
end
