-- No polling timer: page turns and reader lifecycle events supply elapsed time.
local T={}
function T.new() return {pending=0} end
function T.resume(t,page,now) t.page=page;t.since=now end
function T.pause(t,now)
 if t.since then
  local elapsed=now-t.since
  if elapsed>=5 then t.pending=t.pending+math.min(120,math.floor(elapsed)) end
 end
 t.since=nil
end
function T.page(t,page,now)
 if page==t.page then return end
 if t.since then T.pause(t,now);T.resume(t,page,now) else t.page=page end
end
return T
