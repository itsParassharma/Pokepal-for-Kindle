-- Map and battle controls use the existing scaling, sprite cache and sleep lifecycle.
return function(View,UIManager,BB,Device)
 local WHITE,GRAY,LIGHT=BB.COLOR_WHITE,BB.Color8(150),BB.Color8(238)
 local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
 local Art=dofile(dir.."/world_art.lua")
 local MAP_X,MAP_Y,TILE=36,174,48
 function View:saveWorld()
  local ok=self.owner:save()
  self.world_save_failed=not ok
  if ok then self.world_dirty=nil end
  return ok
 end
 function View:stopWorldWalk()
  if self.world_tick then UIManager:unschedule(self.world_tick) end
  self.world_tick=nil;self.world_path=nil;self.world_target=nil
 end
 function View:walkWorld(x,y)
  local W=self.engine.world;local w=self.state.world
  if not w or w.battle or self.world_save_failed or self.owner.save_error then return end
  self:stopAnimation()
  local path=W.path(w,x,y)
  if not path then self.world_message="That way is blocked. Choose a path or a doorway.";UIManager:setDirty(self,"ui");return end
  if #path==0 then return end
  self.world_path=path;self.world_target={x=x,y=y}
  local index=1
  local function step()
   if self.world_tick~=step then return end
   if self.closed or self.suspended or Device.screen_saver_mode or self.screen~="explore"
    or self.owner.reading_busy or (self.owner.backups and self.owner.backups.blocked) then self:stopWorldWalk();return end
   local next_tile=path[index];local previous={x=w.x,y=w.y};local oldmap=w.map
   local changed,event,message=W.step(self.state,next_tile.x,next_tile.y)
   if not changed then self:stopWorldWalk();return end
   self.world_dirty=true;self.world_message=message
   self.world_follow=w.map==oldmap and previous or nil
   if oldmap~=w.map then self:freeImages() end
   index=index+1
   if event or index>#path then
    self:stopWorldWalk();self:saveWorld()
    if event=="battle" then self:go("battle")
    elseif event=="guide" then self:go("worldquests")
    elseif event=="party" then self:go("worldparty")
    elseif event=="lessons" then self:go("worldmoves")
    elseif event=="wares" then self:go("worldshop")
    elseif event=="gymdesk" then self:go("worldgym")
    elseif event=="towerdesk" then self:go("worldtower")
    elseif event=="expeditions" then self:go("expeditions") end
   elseif self.state.animation~="off" then UIManager:scheduleIn(self.state.animation=="eco" and 0.3 or 0.2,self.world_tick) end
   UIManager:setDirty(self,"ui")
  end
  self.world_tick=step
  if self.state.animation=="off" then
   -- At most 88 tiles; the same collisions and events apply without animation.
   while self.world_path do step() end
  else step() end
 end
 function View:paintWorld(bb)
  local W=self.engine.world
  local w=self.state.world or {map="town",x=6,y=6,facing="up",step=0,hp=W.battle.max_hp,cleared=0}
  local map=W.maps[w.map]
  local wins=0;for i=1,#W.encounters do if W.cleared(w,i) then wins=wins+1 end end
  self:title(bb,map.name,"Battle HP "..w.hp.." / "..W.battle.max_hp.."   /   Route wins "..wins.." / "..#W.encounters)
  self:classic(bb,"map-"..w.map,MAP_X,MAP_Y,528,384)
  for y,row in ipairs(map.rows) do for x=1,#row do
   local px,py=MAP_X+(x-1)*TILE,MAP_Y+(y-1)*TILE
   self.buttons[#self.buttons+1]={x=px,y=py,w=TILE,h=TILE,action="worldtile",arg=(y-1)*11+x}
   local tile=row:sub(x,x)
   local role=({D="lass",N="nurse",P="scientist"})[tile]
   if w.map~="town" then role=role or ({J="sage",S="clerk",O="ranger",G="champion"})[tile] end
   if role then Art.trainer(self,bb,px+8,py+8,"down",0,role) end
   if tile=="L" and not W.town.has(w.camp.quests,2) then Art.pokemon(self,bb,25,px+6,py+6) end
  end end
  self:outline(bb,MAP_X-2,MAP_Y-2,11*TILE+4,8*TILE+4)
  for i,e in ipairs(W.encounters) do if e.map==w.map then
   local x,y=MAP_X+(e.x-1)*TILE,MAP_Y+(e.y-1)*TILE
   if e.trainer then Art.trainer(self,bb,x+8,y+8,"down",0,e.map=="cave" and "sage" or "youngster")
   else Art.pokemon(self,bb,(w.camp.wild and w.camp.wild[tostring(i)] or W.battle.foes[i].id),x+6,y+6) end
   if W.cleared(w,i) then self:rect(bb,x+38,y+38,7,7);self:rect(bb,x+40,y+40,3,3,WHITE) end
  end end
  local follow=self.world_follow
  if not follow then
   local d=W.directions[w.facing];local x,y=w.x-d[1],w.y-d[2]
   if W.walkable(w.map,x,y) and not W.event(w.map,x,y,w) then follow={x=x,y=y} end
  end
  if follow and (follow.x~=w.x or follow.y~=w.y) and self.state.trip==0 and not self.state.resting then
   Art.pokemon(self,bb,w.partner or self.state.species,MAP_X+(follow.x-1)*TILE+6,MAP_Y+(follow.y-1)*TILE+6,
    w.facing,self.world_path and w.step or 0)
  end
  Art.trainer(self,bb,MAP_X+(w.x-1)*TILE+8,MAP_Y+(w.y-1)*TILE+8,w.facing,self.world_path and w.step or 0,nil,w.camp and w.camp.outfit)
  if self.world_target then
   self:outline(bb,MAP_X+(self.world_target.x-1)*TILE+1,MAP_Y+(self.world_target.y-1)*TILE+1,46,46,GRAY)
  end
  local hint=W.hints[w.map]
  self:wrapped(bb,self.world_message or hint,565,16)
  self:button(bb,"Party",32,614,120,42,"nav","worldparty")
  self:button(bb,"Bag",448,614,120,42,"nav","worldbag")
  if not w.camp or w.camp.dpad then
  self:button(bb,"Up",261,614,78,42,"worlddir","up")
  self:button(bb,"Left",171,662,78,42,"worlddir","left")
  self:button(bb,"Down",261,662,78,42,"worlddir","down")
  self:button(bb,"Right",351,662,78,42,"worlddir","right")
  end
  self:button(bb,"Help",32,662,120,42,"nav","worldhelp")
  self:button(bb,"Trips",448,662,120,42,"nav","expeditions")
  if self.world_save_failed or self.owner.save_error then self:button(bb,"Retry save",32,717,536,44,"worldretry")
  else self:backButton(bb) end
 end
 function View:paintWorldHelp(bb)
  self:title(bb,"Out for a walk","Your town, your party and routes to discover.")
  local tips={
   {"Move","Tap a clear tile, a doorway or a Pokemon. The arrows move one tile at a time."},
   {"Meet your neighbours","The town guide offers quests. Visit the Centre, dojo, shop, Gym and Tower."},
   {"Read the opponent","Quick moves interrupt charges. Bursts break guards. Withdraw blocks a hit."},
   {"Two moves","Learn moves at the dojo. Equip two for each partner. Switches use a turn; replacing a fainted partner is free."},
   {"Take a break","Pause or close PokePal at any turn. Explore resumes the battle when you return."},
   {"Trainer teams","Trainers bring a fresh team each fight. Your chosen party stays the same. First route wins give rewards."},
  }
  for i,t in ipairs(tips) do
   local y=190+(i-1)*83;self:text(bb,t[1],32,y,20,536,true);self:wrapped(bb,t[2],y+30,16)
  end
  self:button(bb,self.state.world and self.state.world.camp and self.state.world.camp.dpad and "Hide directional pad" or "Show directional pad",32,684,536,28,"campdpad")
  self:button(bb,"Back to Explore",32,717,536,44,"nav","explore")
 end
 function View:paintBattleStage(bb)
  local B=self.engine.world.battle;local w=self.state.world;local b=w and w.battle
  if not b then return end
  self:rect(bb,32,200,536,215,WHITE)
  local id=B.opponent(b)
  self:text(bb,self.engine.name(id),44,207,21,270,true)
  self:text(bb,b.hp.." / "..B.maxFoeHP(b).." HP",44,239,16,250)
  self:progress(bb,44,265,220,b.hp,B.maxFoeHP(b))
  self:outline(bb,36,200,248,94)
  local offset=self.animating and self.frame%2*6 or 0
  if b.team and b.turn==1 and b.status=="active" then
   local trainer=b.floor and (b.floor==6 and "champion" or "gentleman") or b.practice and "blackbelt_t"
    or ({[6]="bug_catcher",[9]="swimmer_m",[12]="hiker",[21]="bug_catcher",[22]="swimmer_m",[23]="hiker"})[b.foe]
   self:classic(bb,"portrait-"..trainer,304,210,80)
  end
  self:classic(bb,id.."-front",404-offset,200,112)
  self:classic(bb,b.ally.."-back",76+offset,270,144)
  self:outline(bb,294,314,266,99)
  self:text(bb,self.engine.displayName(self.state,b.ally),308,321,21,240,true)
  self:text(bb,w.hp.." / "..B.max_hp.." HP",308,353,16,240)
  self:progress(bb,308,382,236,w.hp,B.max_hp)
  local function ball(x,y,fainted)
   self:rect(bb,x+2,y,8,12);self:rect(bb,x,y+2,12,8)
   self:rect(bb,x+2,y+7,8,3,WHITE);self:rect(bb,x+4,y+4,4,4,WHITE)
   if fainted then self:rect(bb,x,y+5,12,2,GRAY) end
  end
  if b.team then for i=1,#b.team do ball(44+(i-1)*17,280,i<b.opponent or b.status=="won") end end
  if w.camp then for i,member in ipairs(w.camp.party) do ball(448+(i-1)*17,356,self.engine.world.town.hp(w,member)==0) end end

 end
 function View:paintBattle(bb)
  local W=self.engine.world;local B=W.battle;local w=self.state.world;local b=w and w.battle
  if not b then self:paintWorld(bb);return end
  self:title(bb,b.floor and "Tower / battle "..b.floor.." of 6" or b.gym and W.town.leaders[b.gym].name.." / Gym battle" or b.practice and "Dojo practice" or W.encounters[b.foe] and W.encounters[b.foe].trainer and "Trainer battle" or "Wild encounter",b.status=="active" and "Turn "..b.turn.." / Your partner moves first." or "Encounter finished")
  self:text(bb,b.status=="active" and B.intentText(self.engine,b) or b.status=="befriended" and "A new friend!" or b.status=="won" and "You won!" or b.status=="lost" and "Time to visit the Pokemon Centre." or "You left the encounter.",32,176,17,536,true,true)
  self:paintBattleStage(bb)
  self:outline(bb,32,419,536,90)
  for i,line in ipairs(b.log) do self:text(bb,line,44,425+(i-1)*21,15,512) end
  local blocked=self.world_save_failed or self.owner.save_error or self.state.resting or w.hp==0
  if b.status=="active" then
   for slot=1,2 do
    local dealt,move=B.preview(self.engine,b,slot);local y=515+(slot-1)*76
    local detail=B.hint(self.engine,b,slot)
    self:outline(bb,32,y,536,70,blocked and GRAY or nil)
    self:text(bb,move.name..(move.power>0 and " / "..dealt.." damage" or ""),48,y+9,21,504,true)
    self:text(bb,detail,48,y+44,16,504)
    self.buttons[#self.buttons+1]={x=32,y=y,w=536,h=70,action="battleturn",arg=slot,disabled=blocked}
   end
   if w.camp and #w.camp.party>1 then self:button(bb,"Switch",32,669,262,42,"nav","worldswitch") end
   if w.camp and not b.floor then self:button(bb,"Berry bag",306,669,262,42,"nav","worldbag",nil,blocked) end
   if not self.world_save_failed and not self.owner.save_error then
    self:button(bb,"Pause",32,717,262,44,"nav","home")
    self:button(bb,"Leave battle",306,717,262,44,"battleflee",nil,nil,self.world_save_failed or self.owner.save_error or self.state.resting)
   end
  else
   self:wrapped(bb,b.status=="lost" and "Your partner will wait at the centre. Speak to the nurse to heal."
    or b.status=="won" and (b.floor and (b.floor==6 and "Run complete! Continue to claim your rank, outfit and 6 berries." or "Continue to choose one benefit for your next battle.") or b.practice and "Practice complete. Tell Ari at the town guide." or "You can battle again. Trainers bring a fresh team each time.")
    or b.recruited and "Saved in your box. Add it to your party now, or use the PC later." or "Your place on the map is saved.",529,19)
   if b.recruited and #w.camp.party<6 and not W.town.member(w.camp,B.opponent(b)) then
    self:button(bb,"Add to empty party slot",32,634,536,48,"campaddrecruit",nil,nil,blocked)
   elseif W.town.canRecruit(self.state,self.engine) then
    self:button(bb,"Offer 3 berries / Befriend",32,634,536,48,"camprecruit",nil,nil,blocked)
   end
   if not self.world_save_failed and not self.owner.save_error then self:button(bb,"Continue",32,717,536,44,"battlefinish",nil,nil,self.world_save_failed or self.owner.save_error or self.state.resting) end
  end
  if self.world_save_failed or self.owner.save_error then self:button(bb,"Retry save",32,717,536,44,"worldretry")
  elseif self.state.resting then self:text(bb,"Pause, then wake your partner at home.",32,692,16,536,false,true) end
 end
 function View:worldTap(action,arg)
  if self:townTap(action,arg) then return true end
  if action=="worldretry" then self:saveWorld();UIManager:setDirty(self,"ui");return true end
  if action=="worldtile" then self:walkWorld((arg-1)%11+1,math.floor((arg-1)/11)+1)
  elseif action=="worlddir" then
   local w=self.state.world;local d=self.engine.world.directions[arg]
   if w and d then self:walkWorld(w.x+d[1],w.y+d[2]) end
  elseif action=="battleturn" or action=="battleflee" or action=="battlefinish" then
   local w=self.state.world;local b=w and w.battle
   if not b or self.world_save_failed or self.owner.save_error or self.state.resting then return true end
   self:stopAnimation()
   local changed
   if action=="battleturn" then changed=self.engine.world.turn(self.state,self.engine,arg,os.time())
   elseif action=="battleflee" and b.status=="active" then b.status="fled";b.log={"You left safely. No rewards were collected."};changed=true
   elseif action=="battlefinish" then changed=self.engine.world.finish(self.state) end
   if changed then
    self.world_dirty=true;local saved=self:saveWorld()
    if not w.battle then self.world_message=nil;self:go("explore")
    elseif saved and action=="battleturn" then self:animate("battle") end
    UIManager:setDirty(self,"ui")
   end
  else return false end
  return true
 end
end
