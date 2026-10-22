-- No polling timer: page turns and reader lifecycle events supply elapsed time.
local T={}
function T.new() return {pending=0,days={}} end
function T.resume(t,page,now) t.page=page;t.since=now end
function T.pause(t,now)
 if t.since then
  local elapsed=now-t.since
  if elapsed>=5 then
   local n=math.min(120,math.floor(elapsed));t.pending=t.pending+n
   local at=now-n
   while at<now do
    local d=os.date("*t",at);local nextday=os.time{year=d.year,month=d.month,day=d.day+1,hour=0}
    local part=math.min(now,nextday)-at;local day=os.date("%Y-%m-%d",at)
    t.days=t.days or {};t.days[day]=(t.days[day] or 0)+part;at=at+part
   end
  end
 end
 t.since=nil
end
function T.page(t,page,now)
 if page==t.page then return end
 if t.since then T.pause(t,now);T.resume(t,page,now) else t.page=page end
end
return T
