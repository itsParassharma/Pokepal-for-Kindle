local v=newView(4)
v.state.animation='off'
v:go('more');tapButton(v,'nav','preferences')
tapButton(v,'preference','large_text');assert(E.companion.option(v.state,'large_text'))
tapButton(v,'preference','high_contrast');assert(E.companion.option(v.state,'high_contrast'))
v:go('journal');tapButton(v,'nav','filters');tapButton(v,'filter','favourites')
assert(v.screen=='journal' and v.journal_filter=='favourites')
tapButton(v,'entry',4);tapButton(v,'favourite',4);v:go('journal');v:paintTo(bb,0,0)
assert(v.journal_count==1)
v:go('memories');tapButton(v,'newmemory');assert(v.screen=='textentry')
tapButton(v,'inputkey','A');tapButton(v,'inputsave');assert(v.screen=='bookconfirm')
assert(#v.state.companion.memories==0);tapButton(v,'savememory');assert(#v.state.companion.memories==1)
v.owner.recap={seconds=900,berries=1,xp=3};v:go('home');tapButton(v,'dismissrecap')
assert(v.recap_dismissed);v:leave()

-- The reader remains usable while scanning. Closing cancels the scan callback.
local P=dofile(BASE..'/main.lua')
local reader=P:new{path=BASE,ui={menu={registerToMainMenu=function() end}}}
reader.savepath=TESTDIR..'/async-ui.dat';reader.counterpath=reader.savepath..'.reading';reader.backups.path=reader.savepath
reader:openPet();assert(reader.pet_view and reader.reading_busy and reader.scan_step)
local scan=reader.scan_step;reader.pet_view:leave();assert(not reader.reading_busy)
for _,item in ipairs(U.queue) do assert(item.f~=scan) end

-- Register exactly one footer callback and detach it when the reader closes.
local footer={added=0,removed=0}
function footer:addAdditionalFooterContent(fn) self.added=self.added+1;self.fn=fn end
function footer:removeAdditionalFooterContent(fn) assert(fn==self.fn);self.removed=self.removed+1 end
reader.document_open=true;reader.ui.view={footer=footer};reader.state=E.new(os.time());E.act(reader.state,'choose',4,os.time())
E.act(reader.state,'preference','footer',os.time())
reader:updateCompanion();reader:updateCompanion();assert(footer.added==1 and footer.fn()=='Charmander')
reader:onCloseDocument();assert(footer.removed==1)

-- Sleep hooks preserve the normal setup for poweroff and detach on plugin close.
local active_ui=reader.ui
local screensaver={calls=0,setup=function(self) self.calls=self.calls+1;self.ui=active_ui;self.screensaver_type='disable' end}
package.loaded['ui/screensaver']=screensaver
local original=screensaver.setup
reader:installSleepScreen();assert(screensaver.setup~=original)
local installed=screensaver.setup;reader:installSleepScreen();assert(screensaver.setup==installed)
screensaver:setup('poweroff');assert(screensaver.calls==1 and screensaver.screensaver_type=='disable')
-- The normal sleep scene replaces only the image and preserves wake handling.
local BB=require('ffi/blitbuffer');local newBuffer,paintSleep=BB.new,reader.View.paintSleep
local buffers={};BB.new=function()
 local image={freed=0};function image:free() self.freed=self.freed+1 end
 buffers[#buffers+1]=image;return image
end
reader.View.paintSleep=function(_,image) image.painted=true end
E.act(reader.state,'preference','sleep_screen',os.time());reader.session={}
local oldImage={freed=0,free=function(self) self.freed=self.freed+1 end}
screensaver.image=oldImage;screensaver.wake_lock='unchanged'
screensaver:setup();assert(oldImage.freed==1 and screensaver.image==buffers[1])
assert(buffers[1].painted and buffers[1].freed==0 and screensaver.screensaver_type=='cover')
assert(screensaver.wake_lock=='unchanged')
active_ui={};screensaver:setup();assert(#buffers==1 and screensaver.screensaver_type=='disable')
active_ui=reader.ui
reader.View.paintSleep=function() error('test drawing failure') end
screensaver:setup();assert(buffers[2].freed==1 and screensaver.image==buffers[1])
local newView=reader.View.new
reader.View.new=function() error('test initialization failure') end
screensaver:setup();assert(buffers[3].freed==1 and screensaver.image==buffers[1])
reader.View.new=newView
local allocate=BB.new;BB.new=function() error('test allocation failure') end
screensaver:setup();assert(#buffers==3 and screensaver.image==buffers[1])
BB.new=allocate
reader.session=nil
local load=reader.storage.load;reader.storage.load=function() error('test save read failure') end
screensaver:setup();assert(#buffers==3 and screensaver.image==buffers[1])
reader.storage.load=load;reader.session={}
E.act(reader.state,'preference','sleep_screen',os.time());screensaver:setup();assert(#buffers==3)
reader.session=nil;BB.new=newBuffer;reader.View.paintSleep=paintSleep
reader:detachCompanion();assert(screensaver.setup==original)
-- Another plugin may wrap setup after us. Closing must keep that hook intact
-- while making our captured callback inactive.
reader:installSleepScreen();local wrapped=screensaver.setup
local other_calls=0
local other=function(...) other_calls=other_calls+1;return wrapped(...) end
screensaver.setup=other;reader:detachCompanion();assert(screensaver.setup==other)
local closed_calls=0;reader.sleepImage=function() closed_calls=closed_calls+1 end
screensaver:setup();assert(other_calls==1 and closed_calls==0)
package.loaded['ui/screensaver']=nil
print('NEW UI: preferences, journal, memories, recap, scan cancellation and reader hooks passed')
