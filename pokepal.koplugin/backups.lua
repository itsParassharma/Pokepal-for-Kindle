-- A backup holds the game and KOReader counter together. Restore uses a journal.
local B={};B.__index=B
local source=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
local S=dofile(source.."/storage.lua")
local function integer(n) return type(n)=="number" and n==n and n>=0 and n<=1e12 and n%1==0 end
local function read(path)
 local f=io.open(path,"rb");if not f then return end
 local data=f:read(1048705);f:close();return data
end
function B.new(path,engine,reading,fs,syncfile,syncdir)
 return setmetatable({path=path,engine=engine,reading=reading,fs=fs,syncfile=syncfile,syncdir=syncdir},B)
end
function B:encode(state,ko,at)
 if not self.engine.valid(state) or not integer(ko) or not integer(at) then return end
 local game=S.encode(state)
 return string.format("POKEPAL_BACKUP_1\n%.0f\n%.0f\n%d\n",at,ko,#game)..game
end
function B:decode(data)
 if not data or #data>1048704 then return end
 local at,ko,size,pos=data:match("^POKEPAL_BACKUP_1\n(%d+)\n(%d+)\n(%d+)\n()")
 at,ko,size=tonumber(at),tonumber(ko),tonumber(size)
 if not integer(at) or not integer(ko) or not size or size>1048576 or #data-pos+1~=size then return end
 local state=S.decode(data:sub(pos),self.engine)
 if state then return {state=state,ko=ko,at=at,data=data} end
end
function B:write(path,data)
 if not self:decode(data) then return nil,"Backup is unreadable." end
 local f,err=io.open(path..".tmp","wb");if not f then return nil,err end
 local ok;ok,err=f:write(data)
 if ok then ok,err=f:flush() end
 if ok and self.syncfile then
  local called,result,why=pcall(self.syncfile,f)
  if not called or result==false then ok=nil;err=why or result end
 end
 local closed,why=f:close();if not ok or not closed then return nil,err or why end
 if self:decode(read(path)) then
  ok,err=os.rename(path,path..".old");if not ok then return nil,err end
 end
 ok,err=os.rename(path..".tmp",path);if not ok then return nil,err end
 if self.syncdir then
  local called,result,why=pcall(self.syncdir,path)
  if not called or result==false then return nil,why or result end
 end
 return true
end
function B:preview(slot)
 if slot~="backup" and slot~="before-restore" then return nil,"Unknown backup." end
 local path=self.path.."."..slot;local data=read(path);local backup=self:decode(data)
 if not backup then
  backup=self:decode(read(path..".old"))
  if backup then backup.previous=true end
 end
 if backup then backup.slot=slot;return backup end
 return nil,(data or self.fs.mode(path) or self.fs.mode(path..".old")) and "This backup could not be read." or "No backup yet."
end
function B:create(state)
 if self.blocked or self.fs.mode(self.path..".restore") then return nil,"Reopen PokePal to finish restoring first." end
 local unlock,err=self.fs.lock(self.path..".reading.session");if not unlock then return nil,err end
 local ko;ko,err=self.reading.counter(self.path..".reading")
 local ok
 if ko then
  ok,err=S.save(self.path,state,self.engine,self.syncfile,self.syncdir)
  if ok then ok,err=self:write(self.path..".backup",self:encode(state,ko,os.time())) end
 end
 unlock();return ok,err
end
function B:apply(backup)
 local ok,err=self.reading.saveCounter(self.path..".reading",backup.ko,self.syncfile,self.syncdir)
 if not ok then return nil,err end
 ok,err=S.save(self.path,backup.state,self.engine,self.syncfile,self.syncdir)
 if not ok then return nil,err end
 ok,err=os.remove(self.path..".restore");if not ok then return nil,err end
 if self.syncdir then
  local called,result,why=pcall(self.syncdir,self.path)
  if not called or result==false then return nil,why or result end
 end
 return true
end
function B:recover()
 if not self.fs.mode(self.path..".restore") then self.blocked=false;return true end
 local unlock,err=self.fs.lock(self.path..".reading.session");if not unlock then return nil,err end
 local pending=self:decode(read(self.path..".restore"));local ok
 if pending then ok,err=self:apply(pending) else err="Restore record is unreadable. Existing saves were kept." end
 self.blocked=not ok;unlock();return ok,err
end
function B:restore(state,preview)
 if self.blocked or self.fs.mode(self.path..".restore") then return nil,"Reopen PokePal to finish restoring first." end
 local backup,err=self:preview(preview and preview.slot)
 if not backup or backup.data~=preview.data then return nil,err or "The backup changed. Preview it again first." end
 local unlock;unlock,err=self.fs.lock(self.path..".reading.session");if not unlock then return nil,err end
 local ko;ko,err=self.reading.counter(self.path..".reading")
 local ok
 if ko then
  ok,err=self:write(self.path..".before-restore",self:encode(state,ko,os.time()))
  if ok then
   ok,err=self:write(self.path..".restore",backup.data)
   -- Once the journal exists, old in-memory state must never overwrite either file.
   self.blocked=self.fs.mode(self.path..".restore")~=nil
   if ok then
    ok,err=self:apply(backup)
    if ok then
     for key in pairs(state) do state[key]=nil end
     for key,value in pairs(backup.state) do state[key]=value end
     self.blocked=false
    end
   end
  end
 end
 unlock();return ok,err
end
return B
