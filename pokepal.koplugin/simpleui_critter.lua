-- A one-way image export through SimpleUI's custom-critter format.
-- No SimpleUI settings, game saves, timers, or plugin hooks are installed.
local M = { id = "pokepal_partner" }
M.moods = {"neutral","happy","party","sleepy","cheer","love","sad","surprised","curious","grumpy","shy","playful"}
-- Existing animation stills, not twelve newly drawn facial expressions.
M.poses = {
 neutral="idle-1", happy="hop-2", party="hop-3", sleepy="sleep-1",
 cheer="hop-2", love="idle-2", sad="sleep-1", surprised="hop-2",
 curious="rotate-2", grumpy="charge-1", shy="idle-1", playful="walk-2",
}
local marker = ".pokepal-owned"
local header = "PokePal Tiny Critter 1\n"
local function read(path)
 local f=io.open(path,"rb");if not f then return nil end
 local data=f:read(1048577);f:close();return data
end
-- A data-only manifest detects user edits; it is never executed as Lua.
local function checksum(data)
 local a,b=1,0
 for i=1,#data do a=(a+data:byte(i))%65521;b=(b+a)%65521 end
 return string.format("%08x",b*65536+a)
end
local names={}
for _,mood in ipairs(M.moods) do names[#names+1]=mood..".png" end
local function manifest(files)
 local lines={header}
 for _,name in ipairs(names) do lines[#lines+1]=name.." "..checksum(files[name]).."\n" end
 return table.concat(lines)
end
local function inspect(path,fs,incomplete)
 if fs.mode(path)~="directory" or fs.mode(path.."/"..marker)~="file" then return nil end
 local data=read(path.."/"..marker)
 if not data or data:sub(1,#header)~=header then return nil end
 local expected={};local body={header}
 for name,hash in data:sub(#header+1):gmatch("([^\n ]+) (%x+)\n") do
  if expected[name] then return nil end
  expected[name]=hash;body[#body+1]=name.." "..hash.."\n"
 end
 if table.concat(body)~=data then return nil end
 local allowed={[marker]=true}
 for _,name in ipairs(names) do
  if not expected[name] or #expected[name]~=8 then return nil end
  allowed[name]=expected[name];expected[name]=nil
 end
 if next(expected) then return nil end
 local entries=fs.list(path);if not entries then return nil end
 for _,name in ipairs(entries) do
  if not allowed[name] or fs.mode(path.."/"..name)~="file" then return nil end
  if name~=marker and incomplete~="stage" then
   local data=read(path.."/"..name)
   if not data or checksum(data)~=allowed[name] then return nil end
  end
 end
 if not incomplete and #entries~=#names+1 then return nil end
 return true
end
local function removeOwned(path,fs,incomplete)
 if not fs.mode(path) then return true end
 -- An interrupted cleanup may already have removed the marker last.
 if incomplete and fs.mode(path)=="directory" then
  local entries=fs.list(path)
  if entries and #entries==0 then return fs.rmdir(path) end
 end
 if not inspect(path,fs,incomplete) then return nil,"Existing critter files were left unchanged: "..path end
 for _,name in ipairs(names) do
  if fs.mode(path.."/"..name) and not os.remove(path.."/"..name) then return nil,"Could not remove an old critter image." end
 end
 if not os.remove(path.."/"..marker) or not fs.rmdir(path) then return nil,"Could not remove the old critter folder." end
 return true
end
local function directory(path,fs)
 local mode=fs.mode(path)
 if mode=="directory" then return true end
 if mode or not fs.mkdir(path) then return nil,"Could not create critter folder: "..path end
 return true
end
local function write(path,data,syncfile)
 local f,err=io.open(path,"wb");if not f then return nil,err end
 local ok;ok,err=f:write(data)
 if ok then ok,err=f:flush() end
 if ok and syncfile then
  local called,result,why=pcall(syncfile,f)
  if not called or result==false then ok=nil;err=why or result end
 end
 local closed,why=f:close()
 return ok and closed,err or why
end
local function syncDirectory(path,syncdir)
 if not syncdir then return true end
 local ok,result,err=pcall(syncdir,path)
 if not ok or result==false then return nil,err or result end
 return true
end
local function copy(t)
 local out={};for k,v in pairs(t) do out[k]=type(v)=="table" and copy(v) or v end;return out
end
function M.mood(state,engine,now)
 -- Advance only a copy, so displaying a mood never earns rewards or saves a game.
 local s=copy(state);engine.advance(s,now)
 if s.trip>0 then return "playful" end
 if s.resting then return "sleepy" end
 if s.food<40 then return "sad" end
 if s.energy<20 then return "sleepy" end
 if s.dirt>70 then return "grumpy" end
 if s.joy<40 then return "sad" end
 if s.bond>=60 then return "love" end
 return "happy"
end
function M.images(plugin,id,mood)
 local packdir=plugin.."/assets/simpleui"
 local index=dofile(packdir.."/index.lua")[id]
 if not index then return nil,"Choose a PokePal partner first." end
 local f,err=io.open(packdir.."/sprites.bin","rb");if not f then return nil,err end
 local files={}
 for _,face in ipairs(M.moods) do
  local entry=index[mood or face]
  if not entry or not f:seek("set",entry[1]) then f:close();return nil,"Invalid Tiny Critter image index." end
  local data=f:read(entry[2])
  if not data or #data~=entry[2] or data:sub(1,8)~="\137PNG\r\n\26\n" then
   f:close();return nil,"Damaged Tiny Critter image pack. Reinstall PokePal."
  end
  files[face..".png"]=data
 end
 f:close();return files
end
function M.export(opts)
 if not opts.state or not opts.engine.species[opts.state.species] then return nil,"Choose a PokePal partner first." end
 local mood=opts.follow_mood and M.mood(opts.state,opts.engine,opts.now or os.time()) or nil
 local files,err=M.images(opts.plugin,opts.state.species,mood)
 if not files then return nil,err end
 local fs=opts.fs
 local root=opts.settings.."/simpleui/sui_critters"
 for _,path in ipairs({opts.settings.."/simpleui",root}) do
  local ok;ok,err=directory(path,fs);if not ok then return nil,err end
 end
 local unlock;unlock,err=fs.lock(root.."/.pokepal_partner.lock")
 if not unlock then return nil,err end
 local published=false
 local function install()
  local target=root.."/"..M.id
  local stage=root.."/.pokepal_partner.next"
  local old=root.."/.pokepal_partner.old"
  -- Recover a directory swap interrupted after moving the previous export aside.
  if fs.mode(old) then
   if not fs.mode(target) then
    if not inspect(old,fs) then return nil,"Previous critter export was modified; files left unchanged." end
    local ok,why=os.rename(old,target);if not ok then return nil,why end
   elseif not inspect(target,fs) then return nil,"Critter folder was modified; files left unchanged."
   else
    local ok,why=removeOwned(old,fs,"cleanup");if not ok then return nil,why end
   end
  end
  local exists=fs.mode(target)
  if exists and not inspect(target,fs) then return nil,"Critter folder already exists or was edited; files left unchanged: "..target end
  local ok,why=removeOwned(stage,fs,"stage");if not ok then return nil,why end
  local stamp=manifest(files)
  if exists and read(target.."/"..marker)==stamp then return true,false end
  if not fs.mkdir(stage) then return nil,"Could not stage the critter export." end
  -- Mark ownership first so an interrupted write can be cleaned on the next run.
  ok,why=write(stage.."/"..marker,stamp,opts.syncfile)
  if not ok then
   os.remove(stage.."/"..marker);fs.rmdir(stage)
   return nil,why
  end
  for _,name in ipairs(names) do
   ok,why=write(stage.."/"..name,files[name],opts.syncfile)
   if not ok then removeOwned(stage,fs,"stage");return nil,why end
  end
  ok,why=syncDirectory(stage.."/"..marker,opts.syncdir);if not ok then return nil,why end
  if exists then ok,why=os.rename(target,old);if not ok then return nil,why end end
  ok,why=os.rename(stage,target)
  if not ok then
   if exists then os.rename(old,target) end
   return nil,why
  end
  published=true
  ok,why=syncDirectory(target.."/neutral.png",opts.syncdir);if not ok then return nil,why end
  ok,why=syncDirectory(target,opts.syncdir);if not ok then return nil,why end
  ok,why=removeOwned(old,fs);if not ok then return nil,why end
  return true,true
 end
 local called,ok,detail=pcall(install)
 unlock()
 if not called then return nil,tostring(ok),published end
 return ok,detail,published
end
-- Optional cache notification. Never require SimpleUI, replace its functions,
-- set its preferences, or request a screen repaint. Reopening works without it.
function M.refreshLoadedAssets(settings)
 local assets=package.loaded["modules/critter/assets"]
 if type(assets)=="table" and type(assets.userDir)=="function" and type(assets.rescan)=="function" then
  local ok,path=pcall(assets.userDir)
  if ok and path==settings.."/simpleui/sui_critters" then pcall(assets.rescan) end
 end
end
return M
