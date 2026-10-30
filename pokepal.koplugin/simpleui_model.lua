-- Read-only presentation of the committed game. Never collects rewards or saves.
local M={}
local function copy(t)
 local out={};for k,v in pairs(t) do out[k]=type(v)=="table" and copy(v) or v end;return out
end
local function percent(n) return math.max(0,math.min(100,math.floor(n+0.5))) end
local function minutes(n) return math.max(0,math.ceil(n/60)) end
function M.snapshot(p,cache,now)
 now=now or os.time()
 if not p or not p.savepath then return {message="Open PokePal to choose a partner."} end
 if p.fs.mode(p.savepath..".restore") then return {message="Open PokePal to finish restoring."} end
 local saved,notice=p.storage.load(p.savepath,p.engine,cache)
 if not saved then return {message=notice or "Tap to choose your first partner."} end
 if saved.species==0 then return {message="Tap to choose your first partner."} end
 local E=p.engine
 local current=copy(saved)
 -- advance also discovers trail rewards. Suppress those in this display-only
 -- copy so neither the displayed XP nor care includes an unclaimed reward.
 current.finds=nil;E.advance(current,now)
 local level=E.level(saved)
 local s={species=saved.species,name=E.displayName(saved),level=level,xp=saved.xp,
  xp_fraction=level==100 and 1 or saved.xp%20/20,
  xp_label=level==100 and "Max level" or (20-saved.xp%20).." XP to next level",
  mood=E.mood(current,now),animation=saved.animation,
  care={{"Food",percent(current.food)},{"Energy",percent(current.energy)},
   {"Joy",percent(current.joy)},{"Clean",percent(100-current.dirt)},{"Bond",percent(saved.bond)}},
  pose="idle",notice=notice}
 if current.trip>0 and E.tripLeft(current,now)>0 then s.pose="walk"
 elseif current.resting or current.energy<20 then s.pose="sleep"
 elseif current.dirt>70 then s.pose="charge" end
 local day=os.date("%Y-%m-%d",now)
 local c=saved.companion or {};local recorded=c.days and c.days[day] or {}
 local today=(recorded.ko or 0)+(recorded.kindle or 0)
 local pending=0
 if saved.reading and saved.reading.enabled and saved.reading.ko_ready and p.reading then
  local total,err,_,days=p.reading.counter(p.savepath..".reading")
  if total then
   pending=math.max(0,total-saved.reading.ko)
   today=today+math.max(0,(days and days[day] or 0)-(c.ko_days and c.ko_days[day] or 0))
  elseif err then s.notice=err end
 end
 s.pending=pending
 s.reading="Read today: "..math.floor(today/60).." min"
 s.reading_short="Today "..math.floor(today/60).."m"
 if pending>0 then s.reading=s.reading.." / "..minutes(pending).." min to collect" end
 if pending>0 then s.reading_short=s.reading_short.." / pending "..minutes(pending).."m" end
 s.adventure="No expedition / "..saved.berries.." berries"
 s.adventure_short=saved.berries.." berries / no trip"
 if current.trip>0 then
  local route=E.routes[current.trip];local left=E.tripLeft(current,now)
  s.adventure=route.name..": "..(left==0 and "ready to collect" or
   minutes(left)..(current.trail~=nil and " reading min left" or " min left"))
  s.adventure_short=route.name..": "..(left==0 and "ready" or minutes(left)..(current.trail~=nil and "m reading" or "m left"))
 end
 s.milestone=E.ready(saved) and "Ready to evolve / tap to open" or "Tap to open PokePal"
 if saved.egg then
  local left=E.eggLeft(saved)
  s.milestone=left==0 and "Egg ready to hatch / tap to open" or
   "Egg: "..math.floor(100*(1-left/E.egg_seconds)).."% / "..minutes(left).." reading min left"
 elseif current.week then
  s.milestone=s.milestone=="Tap to open PokePal" and
   "Weekly reading: "..math.floor(current.week.seconds/60).." / "..math.floor(current.week.target/60).." min" or s.milestone
 end
 s.summary=s.notice or (pending>0 and s.reading) or (saved.trip>0 and s.adventure) or s.milestone
 s.summary_short=s.notice or (pending>0 and s.reading_short) or (saved.trip>0 and s.adventure_short) or s.milestone
 local parts={s.species,s.name,s.level,s.xp,s.mood,s.animation,s.reading,s.adventure,s.milestone,s.notice or ""}
 for _,row in ipairs(s.care) do parts[#parts+1]=row[2] end
 s.signature=table.concat(parts,"|")
 return s
end
return M
