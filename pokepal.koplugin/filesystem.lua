-- The same small filesystem API is supplied by KOReader and the native host.
local F={}
local ok,lfs=pcall(require,"libs/libkoreader-lfs")
if not ok then ok,lfs=pcall(require,"lfs") end
function F.mode(path)
 if host_fs then return host_fs("mode",path) end
 if ok then return lfs.symlinkattributes(path,"mode") end
end
function F.mkdir(path)
 if host_fs then return host_fs("mkdir",path) end
 if ok then return lfs.mkdir(path) end
end
function F.mtime(path)
 if host_fs then return host_fs("mtime",path) end
 if ok then return lfs.symlinkattributes(path,"modification") end
end
function F.size(path)
 if host_fs then return host_fs("size",path) end
 if ok then return lfs.symlinkattributes(path,"size") end
end
function F.rmdir(path)
 if host_fs then return host_fs("rmdir",path) end
 if ok then return lfs.rmdir(path) end
end
function F.list(path)
 if host_listdir then return host_listdir(path) end
 if not ok then return nil end
 local success,names=pcall(function()
  local result={}
  for name in lfs.dir(path) do
   if name~="." and name~=".." then result[#result+1]=name end
   if #result>20000 then error("Directory too large") end
  end
  return result
 end)
 if success then return names end
end
function F.pid()
 if host_fs then return host_fs("pid","") end
 local f=io.open("/proc/self/stat","r");if not f then return nil end
 local pid=f:read(32):match("^(%d+)");f:close();return pid
end
function F.lock(path)
 local pid=F.pid()
 if not pid then return nil,"Could not lock the save." end
 if not F.mkdir(path) then
  local f=io.open(path.."/pid","r");local previous=f and f:read(32);if f then f:close() end
  local valid=previous and previous:match("^%d+$")
  local modified=F.mtime(path)
  if (valid and not F.mode("/proc/"..previous)) or (not valid and modified and os.time()-modified>60) then
   os.remove(path.."/pid");F.rmdir(path)
   if not F.mkdir(path) then return nil,"PokePal is already open." end
  else return nil,"PokePal is already open. Close the other copy first." end
 end
 local f=io.open(path.."/pid","w")
 if not f then F.rmdir(path);return nil,"Could not write the save lock." end
 local written=f:write(tostring(pid));local closed=f:close()
 if not written or not closed then os.remove(path.."/pid");F.rmdir(path);return nil,"Could not write the save lock." end
 return function() os.remove(path.."/pid");F.rmdir(path) end
end
return F
