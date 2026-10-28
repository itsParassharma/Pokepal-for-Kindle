-- Map and battle controls use the existing scaling, sprite cache and sleep lifecycle.
return function(View,UIManager,BB,Device)
 local WHITE,GRAY,LIGHT=BB.COLOR_WHITE,BB.Color8(150),BB.Color8(238)
 local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
 local Art=dofile(dir.."/world_art.lua")
 local MAP_X,MAP_Y,TILE=58,181,44
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
  for y,row in ipairs(map.rows) do for x=1,#row do
   Art.tile(self,bb,row:sub(x,x),MAP_X+(x-1)*TILE,MAP_Y+(y-1)*TILE,{WHITE,GRAY,LIGHT})
   self.buttons[#self.buttons+1]={x=MAP_X+(x-1)*TILE,y=MAP_Y+(y-1)*TILE,w=TILE,h=TILE,action="worldtile",arg=(y-1)*11+x}
  end end
  self:outline(bb,MAP_X-1,MAP_Y-1,11*TILE+2,8*TILE+2)
  for i,e in ipairs(W.encounters) do if e.map==w.map then
    local x,y=MAP_X+(e.x-1)*TILE,MAP_Y+(e.y-1)*TILE
    self:rect(bb,x+3,y+3,38,38,WHITE)
    if e.trainer then Art.trainer(self,bb,x+10,y+7,"down",0,false,WHITE) else self:sprite(bb,W.battle.foes[i].id,x,y,44,1,"idle") end
    if W.cleared(w,i) then self:rect(bb,x+34,y+34,9,9);self:rect(bb,x+36,y+36,5,5,WHITE) end
   end
  end
  if w.map=="town" then
   self:rect(bb,MAP_X+TILE+6,MAP_Y+TILE+9,TILE*3-12,24,WHITE)
   self:rect(bb,MAP_X+TILE*7+6,MAP_Y+TILE+9,TILE*3-12,24,WHITE)
   self:text(bb,"CENTRE",MAP_X+TILE,MAP_Y+TILE+10,14,TILE*3,true,true)
   self:text(bb,"TRIPS",MAP_X+TILE*7,MAP_Y+TILE+10,14,TILE*3,true,true)
   for _,sign in ipairs({{2,"DOJO"},{8,"SHOP"},{10,"TOWER"}}) do self:text(bb,sign[2],MAP_X+(sign[1]-1)*TILE-8,MAP_Y+TILE*6+5,9,60,true,true) end
  end
  local follow=self.world_follow
  if not follow then
   local d=W.directions[w.facing];local x,y=w.x-d[1],w.y-d[2]
   if W.walkable(w.map,x,y) and not W.event(w.map,x,y) then follow={x=x,y=y} end
  end
  if follow and (follow.x~=w.x or follow.y~=w.y) and self.state.trip==0 and not self.state.resting then
   self:sprite(bb,w.partner or self.state.species,MAP_X+(follow.x-1)*TILE,MAP_Y+(follow.y-1)*TILE,44,
    self.world_path and w.step+1 or 1,"walk_"..w.facing)
  end
  Art.trainer(self,bb,MAP_X+(w.x-1)*TILE+10,MAP_Y+(w.y-1)*TILE+8,w.facing,self.world_path and w.step or 0,false,WHITE,w.camp and w.camp.outfit)
  if self.world_target then
   self:outline(bb,MAP_X+(self.world_target.x-1)*TILE+1,MAP_Y+(self.world_target.y-1)*TILE+1,42,42,GRAY)
  end
  local hint=W.hints[w.map]
  self:wrapped(bb,self.world_message or hint,551,17)
  if not w.camp or w.camp.dpad then
  self:button(bb,"Up",261,602,78,42,"worlddir","up")
  self:button(bb,"Left",171,651,78,42,"worlddir","left")
  self:button(bb,"Down",261,651,78,42,"worlddir","down")
  self:button(bb,"Right",351,651,78,42,"worlddir","right")
  end
  self:button(bb,"Help",32,651,120,42,"nav","worldhelp")
  self:button(bb,"Trips",448,651,120,42,"nav","expeditions")
  if self.world_save_failed or self.owner.save_error then self:button(bb,"Retry save",32,717,536,44,"worldretry")
  else self:backButton(bb) end
 end
 function View:paintWorldHelp(bb)
  self:title(bb,"Out for a walk","Your town, your party and routes to discover.")
  local tips={
   {"Move","Tap a clear tile, a doorway or a Pokemon. The arrows move one tile at a time."},
   {"Meet your neighbours","The town guide offers quests. Visit the Centre, dojo, shop and Battle Tower."},
   {"Read the opponent","Quick moves interrupt charges. Bursts break guards. Withdraw blocks a hit."},
   {"Two moves","Learn moves at the dojo. Equip two for each partner. Switching in battle uses your turn."},
   {"Take a break","Pause or close PokePal at any turn. Explore resumes the battle when you return."},
   {"First wins","Each meadow opponent gives 1 berry, 3 XP and 1 bond once. Rematches are for practice."},
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
  local id=B.foes[b.foe].id
  self:text(bb,self.engine.displayName(self.state,b.ally),32,204,21,252,true,true)
  self:text(bb,self.engine.name(id),316,204,21,252,true,true)
  self:text(bb,w.hp.." / "..B.max_hp.." HP",32,234,17,252,false,true)
  self:text(bb,b.hp.." / "..B.maxFoeHP(b).." HP",316,234,17,252,false,true)
  self:progress(bb,63,262,190,w.hp,B.max_hp);self:progress(bb,347,262,190,b.hp,B.maxFoeHP(b))
  local move=B.equipped(self.engine,b)[b.last_move]
  local pose=self.animating and (move and move.kind=="guard" and "charge" or "attack") or "idle"
  Art.trainer(self,bb,45,340,"right",self.animating and 1 or 0,false,WHITE,w.camp and w.camp.outfit,self.animating)
  self:sprite(bb,b.ally,84,280,132,self.animating and self.frame or 1,pose)
  self:sprite(bb,id,364,280,132,1,"idle")
 end
 function View:paintBattle(bb)
  local W=self.engine.world;local B=W.battle;local w=self.state.world;local b=w and w.battle
  if not b then self:paintWorld(bb);return end
  self:title(bb,b.floor and "Tower / battle "..b.floor.." of 6" or b.practice and "Dojo practice" or W.encounters[b.foe] and W.encounters[b.foe].trainer and "Trainer battle" or "Wild encounter",b.status=="active" and "Turn "..b.turn.." / Your partner moves first." or "Encounter finished")
  self:text(bb,b.status=="active" and B.intentText(self.engine,b) or b.status=="won" and "You won!" or b.status=="lost" and "Time to visit the Pokemon Centre." or "You left the encounter.",32,176,17,536,true,true)
  self:paintBattleStage(bb)
  for i,line in ipairs(b.log) do self:text(bb,line,32,421+(i-1)*23,16,536,false,true) end
  local blocked=self.world_save_failed or self.owner.save_error or self.state.resting or w.hp==0
  if b.status=="active" then
   for slot=1,2 do
    local dealt,move=B.preview(self.engine,b,slot);local y=515+(slot-1)*76
    local detail=move.kind=="quick" and "Interrupts a charge" or move.kind=="break" and "Breaks a guard"
     or move.kind=="guard" and "Blocks damage; strengthens your next hit" or move.kind=="seed" and "Drains up to 3 HP for three turns" or "Restores 3 HP when it hits"
    self:outline(bb,32,y,536,70,blocked and GRAY or nil)
    self:text(bb,move.name..(move.power>0 and " / "..dealt.." damage" or ""),48,y+9,21,504,true)
    self:text(bb,detail,48,y+44,16,504)
    self.buttons[#self.buttons+1]={x=32,y=y,w=536,h=70,action="battleturn",arg=slot,disabled=blocked}
   end
   if w.camp and #w.camp.party>1 then self:button(bb,"Switch",32,669,262,42,"nav","worldswitch") end
   if w.camp and w.camp.potions>0 and not b.floor then self:button(bb,"Potion / uses turn",306,669,262,42,"camppotion",nil,nil,blocked) end
   if not self.world_save_failed and not self.owner.save_error then
    self:button(bb,"Pause",32,717,262,44,"nav","home")
    self:button(bb,"Leave battle",306,717,262,44,"battleflee",nil,nil,self.world_save_failed or self.owner.save_error or self.state.resting)
   end
  else
   self:wrapped(bb,b.status=="lost" and "Your partner will wait at the centre. Speak to the nurse to heal."
    or b.status=="won" and (b.floor and (b.floor==6 and "Run complete! Continue to claim your rank, outfit and 6 berries." or "Continue to choose one benefit for your next battle.") or b.practice and "Practice complete. Tell Ari at the town guide." or "You can meet this Pokemon again. Rematches do not give extra rewards.")
    or "Your place on the map is saved.",563,20)
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
