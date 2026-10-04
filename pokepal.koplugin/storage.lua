-- Strict data-only saves, with a previous snapshot and atomic promotion.
local S={}
local numeric={"version","species","food","joy","energy","bond","xp","berries","last","gift","trained","played","cleaned","dirt","trip","due","trips","seed","care","started"}
local function read(path)
 local f=io.open(path,"rb");if not f then return nil end
 local data=f:read(65537);f:close();return data
end
function S.encode(s)
 local lines={}
 for _,k in ipairs(numeric) do lines[#lines+1]=k.."="..string.format("%.12g",s[k]) end
 lines[#lines+1]="resting="..tostring(s.resting)
 lines[#lines+1]="animation="..s.animation
 local ids={};for id,v in pairs(s.seen) do if v then ids[#ids+1]=tonumber(id) end end;table.sort(ids)
 for _,id in ipairs(ids) do lines[#lines+1]="seen="..id end
 local badges={};for badge,v in pairs(s.badges) do if v then badges[#badges+1]=badge end end;table.sort(badges)
 for _,b in ipairs(badges) do lines[#lines+1]="badge="..b end
 for _,v in ipairs(s.log) do lines[#lines+1]="log="..v:gsub("[\r\n]"," ") end
 return table.concat(lines,"\n").."\n"
end
function S.decode(data,engine)
 if not data or #data>65536 then return nil end
 local s={seen={},badges={},log={}};local numbers={};local used={}
 for _,k in ipairs(numeric) do numbers[k]=true end
 for line in data:gmatch("[^\n]+") do
  local k,v=line:match("^([a-z]+)=(.*)$")
  if not k then return nil end
  if numbers[k] or k=="resting" or k=="animation" then
   if used[k] then return nil end;used[k]=true
  end
  if numbers[k] then s[k]=tonumber(v)
  elseif k=="resting" then if v~="true" and v~="false" then return nil end;s.resting=v=="true"
  elseif k=="animation" then s.animation=v
  elseif k=="seen" then
   local id=tonumber(v);if not id or not engine.species[id] then return nil end;s.seen[tostring(id)]=true
  elseif k=="badge" then if #v>40 then return nil end;s.badges[v]=true
  elseif k=="log" then if #v>200 or #s.log>=24 then return nil end;s.log[#s.log+1]=v
  else return nil end
 end
 if engine.valid(s) then return s end
end
function S.load(path,engine)
 local primary=read(path);local backup=read(path..".old")
 local state=S.decode(primary,engine)
 if state then return state end
 state=S.decode(backup,engine)
 if state then return state,"Recovered the previous saved snapshot." end
 if primary or backup then return nil,"Save is unreadable; existing files were left unchanged." end
 return nil
end
function S.save(path,s,engine,syncfile,syncdir)
 if not engine.valid(s) then return nil,"Invalid game state." end
 local data=S.encode(s)
 if not S.decode(data,engine) then return nil,"Could not serialize game state." end
 local f,err=io.open(path..".tmp","wb");if not f then return nil,err end
 local ok;ok,err=f:write(data)
 if ok then ok,err=f:flush() end
 if ok and syncfile then pcall(syncfile,f) end
 local closed,cerr=f:close();if not ok or not closed then return nil,err or cerr end
 -- Keep a good backup if we recovered from a damaged primary.
 if S.decode(read(path),engine) then
  local moved;moved,err=os.rename(path,path..".old")
  if not moved then return nil,err end
 end
 ok,err=os.rename(path..".tmp",path)
 if not ok then return nil,err end
 if syncdir then pcall(syncdir,path) end
 return true
end
return S
