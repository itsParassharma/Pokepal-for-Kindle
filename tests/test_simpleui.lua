-- Run by the desktop suite and the real KOReader suite, using temporary data.
local C=dofile(BASE..'/simpleui_critter.lua')
local E=dofile(BASE..'/engine.lua')
local S=dofile(BASE..'/storage.lua')
local F=dofile(BASE..'/filesystem.lua')
local now=1800000000
local passed,serial=0,0
local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local function write(path,data) local f=assert(io.open(path,'wb'));assert(f:write(data));assert(f:close()) end
local function check(name,fn)
 serial=serial+1
 local dir=TESTDIR..'/simpleui-'..serial;assert(F.mkdir(dir))
 local s=E.new(now);E.act(s,'choose',25,now)
 local opts={plugin=BASE,settings=dir,state=s,engine=E,fs=F,now=now}
 local root=dir..'/simpleui/sui_critters'
 local saved,settings,rename,open={},G_reader_settings,os.rename,io.open
 local function mock(key,value)
  if not saved[key] then saved[key]={package.loaded[key]} end
  package.loaded[key]=value
 end
 local t={dir=dir,root=root,target=root..'/pokepal_partner',opts=opts,s=s,mock=mock}
 function t.install() assert(C.export(opts)) end
 function t.player()
  mock('datastorage',{getSettingsDir=function() return dir end})
  mock('device',{screen_saver_mode=false})
  mock('ffi/util',{})
  local settings={}
  G_reader_settings={isTrue=function(_,key) return settings[key]==true end,
   saveSetting=function(_,key,value) settings[key]=value end}
  local P=dofile(BASE..'/main.lua')
  local p=setmetatable({path=BASE,engine=E,storage=S,fs=F,savepath=dir..'/pokepal.dat',state=s},{__index=P})
  assert(S.save(p.savepath,s,E))
  return p,settings
 end
 local ok,err=pcall(fn,t)
 os.rename,io.open,G_reader_settings=rename,open,settings
 for key,value in pairs(saved) do package.loaded[key]=value[1] end
 assert(ok,name..': '..tostring(err));passed=passed+1;print('PASS simpleui: '..name)
end
check('exports a discoverable critter with all twelve 64px PNG moods',function(t)
 t.install();assert(#F.list(t.target)==13)
 for _,mood in ipairs(C.moods) do
  local png=read(t.target..'/'..mood..'.png')
  assert(png:sub(1,8)=='\137PNG\r\n\26\n')
  assert(png:sub(17,24)=='\0\0\0\64\0\0\0\64')
 end
 assert(not F.mode(t.root..'/.pokepal_partner.lock'))
end)
check('no partner creates no export and changes no state',function(t)
 t.opts.state=E.new(now);local before=S.encode(t.opts.state)
 assert(not C.export(t.opts));assert(not F.mode(t.root));assert(S.encode(t.opts.state)==before)
end)
check('preserves saves, backups, settings, phrases and unrelated critters',function(t)
 assert(F.mkdir(t.dir..'/simpleui'));assert(F.mkdir(t.root));assert(F.mkdir(t.root..'/suey'))
 local keep={t.dir..'/pokepal.dat',t.dir..'/pokepal.dat.old',t.dir..'/settings.reader.lua',
  t.dir..'/simpleui/sui_settings.lua',t.root..'/phrases.lua',t.root..'/suey/neutral.png'}
 for _,path in ipairs(keep) do write(path,'untouched:'..path) end
 local before=S.encode(t.s);t.install()
 assert(S.encode(t.s)==before)
 for _,path in ipairs(keep) do assert(read(path)=='untouched:'..path) end
end)
check('unchanged exports do not rewrite image files or rename directories',function(t)
 t.install();local old=io.open
 io.open=function(path,mode)
  if not path:match('/pid$') then assert(not mode:find('w'),'unnecessary write '..path) end
  return old(path,mode)
 end
 os.rename=function() error('unnecessary rename') end
 local ok,changed=C.export(t.opts);assert(ok and changed==false)
end)
check('partner changes replace every mood together',function(t)
 t.install();E.act(t.s,'choose',7,now);t.s.species=7
 t.install();local expected=assert(C.images(BASE,7))
 for name,png in pairs(expected) do assert(read(t.target..'/'..name)==png) end
end)
check('PokePal mood is a read-only image snapshot, and SimpleUI faces can be restored',function(t)
 t.s.resting=true;t.opts.follow_mood=true;local before=S.encode(t.s);t.install()
 assert(S.encode(t.s)==before)
 local expected=C.images(BASE,25,'sleepy')['neutral.png']
 for _,mood in ipairs(C.moods) do assert(read(t.target..'/'..mood..'.png')==expected) end
 t.opts.follow_mood=false;t.install()
 assert(read(t.target..'/happy.png')~=read(t.target..'/sleepy.png'))
end)
check('care thresholds and elapsed time map without mutating game state',function(t)
 local s=t.s;s.food=80;s.energy=80;s.joy=80;s.dirt=0;s.bond=0
 assert(C.mood(s,E,now)=='happy');s.bond=70;assert(C.mood(s,E,now)=='love')
 s.joy=10;assert(C.mood(s,E,now)=='sad');s.dirt=80;assert(C.mood(s,E,now)=='grumpy')
 s.energy=10;assert(C.mood(s,E,now)=='sleepy');s.food=10;assert(C.mood(s,E,now)=='sad')
 s.resting=true;assert(C.mood(s,E,now)=='sleepy')
 s.trip=1;s.due=now+100;assert(C.mood(s,E,now)=='playful')
 local before=S.encode(s);C.mood(s,E,now+900);assert(S.encode(s)==before)
end)
check('edited images and added user files block replacement',function(t)
 t.install();local path=t.target..'/neutral.png';write(path,'my custom image')
 assert(not C.export(t.opts));assert(read(path)=='my custom image')
 write(path,C.images(BASE,25)['neutral.png']);write(t.target..'/phrases.lua','return {{text="Mine"}}')
 t.s.species=7;assert(not C.export(t.opts));assert(read(t.target..'/phrases.lua')=='return {{text="Mine"}}')
end)
check('a colliding unowned folder is never adopted',function(t)
 assert(F.mkdir(t.dir..'/simpleui'));assert(F.mkdir(t.root));assert(F.mkdir(t.target))
 write(t.target..'/neutral.png','my own critter')
 assert(not C.export(t.opts));assert(read(t.target..'/neutral.png')=='my own critter')
end)
check('a partial image write leaves the previous export intact and releases the lock',function(t)
 t.install();local before=read(t.target..'/neutral.png');t.s.species=7
 local old=io.open
 io.open=function(path,mode)
  if path:match('%.next/cheer%.png$') and mode=='wb' then return nil,'disk full' end
  return old(path,mode)
 end
 assert(not C.export(t.opts));assert(read(t.target..'/neutral.png')==before)
 assert(not F.mode(t.root..'/.pokepal_partner.lock'))
 io.open=old;t.install();assert(read(t.target..'/neutral.png')~=before)
end)
check('failed promotion rolls back and the next export can retry',function(t)
 t.install();local before=read(t.target..'/neutral.png');t.s.species=7
 local old=os.rename
 os.rename=function(a,b) if a:match('%.next$') then return nil,'rename failed' end;return old(a,b) end
 assert(not C.export(t.opts));assert(read(t.target..'/neutral.png')==before)
 os.rename=old;t.install();assert(read(t.target..'/neutral.png')~=before)
end)
check('interrupted swaps and incomplete staging recover on the next export',function(t)
 t.install();assert(os.rename(t.target,t.root..'/.pokepal_partner.old'))
 local nextdir=t.root..'/.pokepal_partner.next';assert(F.mkdir(nextdir))
 write(nextdir..'/.pokepal-owned',read(t.root..'/.pokepal_partner.old/.pokepal-owned'))
 write(nextdir..'/neutral.png','partial data');t.s.species=7;t.install()
 assert(read(t.target..'/neutral.png')==C.images(BASE,7)['neutral.png'])
 assert(not F.mode(nextdir) and not F.mode(t.root..'/.pokepal_partner.old'))
end)
check('sync failure retains recovery data and never touches game saves',function(t)
 t.install();local before=S.encode(t.s);t.s.species=7
 t.opts.syncdir=function() return false,'sync failed' end
 assert(not C.export(t.opts));assert(F.mode(t.target)=='directory')
 assert(not F.mode(t.root..'/.pokepal_partner.lock'))
 t.opts.syncdir=nil;t.install();t.s.species=25;assert(S.encode(t.s)==before)
end)
check('interrupted backup cleanup keeps the complete export usable',function(t)
 t.install()
 local old=t.root..'/.pokepal_partner.old';assert(F.mkdir(old))
 write(old..'/.pokepal-owned',read(t.target..'/.pokepal-owned'))
 write(old..'/neutral.png',read(t.target..'/neutral.png'))
 t.install();assert(not F.mode(old))
 assert(F.mkdir(old));t.install();assert(not F.mode(old))
end)
check('symlinked images and parent folders leave external files untouched',function(t)
 local link=host_symlink or function(a,b) return require('libs/libkoreader-lfs').link(a,b,true) end
 t.install();local outside=t.dir..'/mine.png';write(outside,'mine')
 assert(os.remove(t.target..'/neutral.png'));assert(link(outside,t.target..'/neutral.png'))
 assert(not C.export(t.opts));assert(read(outside)=='mine')
 local other=t.dir..'/elsewhere';assert(F.mkdir(other));assert(link(t.dir..'/simpleui',other..'/simpleui'))
 t.opts.settings=other;assert(not C.export(t.opts));assert(read(outside)=='mine')
end)
check('post-promotion sync errors report the published images for cache refresh',function(t)
 t.install();t.s.species=7;local calls=0
 t.opts.syncdir=function() calls=calls+1;if calls==2 then return false,'sync failed' end end
 local ok,err,published=C.export(t.opts)
 assert(not ok and err=='sync failed' and published)
 assert(read(t.target..'/neutral.png')==C.images(BASE,7)['neutral.png'])
 assert(F.mode(t.root..'/.pokepal_partner.old')=='directory')
 t.opts.syncdir=nil;t.install();assert(not F.mode(t.root..'/.pokepal_partner.old'))
end)
check('cached same-second images are invalidated without loading SimpleUI',function(t)
 t.mock('modules/critter/assets',nil);C.refreshLoadedAssets(t.dir)
 assert(package.loaded['modules/critter/assets']==nil)
 local calls=0
 t.mock('modules/critter/assets',{userDir=function() return t.root end,rescan=function() calls=calls+1 end})
 C.refreshLoadedAssets(t.dir);assert(calls==1)
 C.refreshLoadedAssets(t.dir..'/elsewhere');assert(calls==1)
end)
check('automatic export is off by default and uses committed saves when enabled',function(t)
 local p,settings=t.player();assert(p:save());assert(not F.mode(t.root))
 settings.pokepal_simpleui_sync=true;assert(p:save());assert(F.mode(t.target)=='directory')
 p.state.species=7 -- not committed yet
 assert(p:syncSimpleUI());assert(read(t.target..'/neutral.png')==C.images(BASE,25)['neutral.png'])
 assert(p:save());assert(read(t.target..'/neutral.png')==C.images(BASE,7)['neutral.png'])
end)
check('a failed game save never exports and export errors never fail game saves',function(t)
 local p,settings=t.player();settings.pokepal_simpleui_sync=true
 p.storage={save=function() return nil,'save failed' end};assert(not p:save());assert(not F.mode(t.root))
 p.storage=S;p.exportSimpleUI=function() error('export failed') end
 assert(p:save());assert(S.load(p.savepath,E));assert(p.simpleui_error:find('export failed'))
end)
check('suspend and close skip export, and turning sync off keeps the snapshot',function(t)
 local p,settings=t.player();settings.pokepal_simpleui_sync=true
 p.suspended=true;p:syncSimpleUI();assert(not F.mode(t.root))
 p.suspended=false;require('device').screen_saver_mode=true;p:syncSimpleUI();assert(not F.mode(t.root))
 require('device').screen_saver_mode=false;p.closed=true;p:syncSimpleUI();assert(not F.mode(t.root))
 p.closed=false;assert(p:syncSimpleUI());local before=read(t.target..'/neutral.png')
 settings.pokepal_simpleui_sync=false;p.state.species=7;assert(p:save())
 assert(read(t.target..'/neutral.png')==before)
end)
check('manual export detects pending save restoration',function(t)
 local p=t.player();assert(F.mkdir(p.savepath..'.restore'))
 assert(not p:syncSimpleUI(true));assert(not F.mode(t.root))
end)
print('SIMPLEUI: '..passed..' checks passed')
