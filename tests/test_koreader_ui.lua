-- KOReader v2026.07.1 (9192014): UIManager.show puts non-modal windows
-- below modal ones. InputDialog is non-modal; its keyboard is modal.
local Dialog={}
function Dialog:new(o) return setmetatable(o,{__index=self}) end
function Dialog:getInputText() return self.input end
function Dialog:onShowKeyboard()
 self.keyboard={modal=true,onCloseWidget=function() end};U:show(self.keyboard)
end
function Dialog:onCloseWidget()
 self.closed=true
 if self.keyboard then U:close(self.keyboard);self.keyboard=nil end
end
local original_dialog=package.loaded['ui/widget/inputdialog']
local show,close=U.show,U.close
local stack={}
function U:show(widget)
 for i=#stack,0,-1 do
  if widget.modal or i==0 or not stack[i].modal then table.insert(stack,i+1,widget);return end
 end
end
function U:close(widget)
 if widget.onCloseWidget then widget:onCloseWidget() end
 for i=#stack,1,-1 do if stack[i]==widget then table.remove(stack,i) end end
end
package.loaded['ui/widget/inputdialog']=Dialog
local passed,failed=0,0
local views={}
local function check(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name)
 else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
 for _,v in ipairs(views) do pcall(v.leave,v) end
 views={};stack={};U.queue={};U.dirty={}
end
local function view()
 local v=newView(4);v.state.animation='off';views[#views+1]=v;U:show(v);return v
end
check('KOReader text dialogs stay above the game and below their keyboard',function()
 local v=view();v:go('journal');v:editText('search','')
 local dialog=stack[#stack-1]
 assert(dialog~=v and dialog.getInputText,'the game hides the text dialog')
 assert(stack[#stack]==dialog.keyboard)
 v:editText('nickname','Ignored');assert(#stack==3 and v.input_kind=='search')
 dialog.input='Pikachu';dialog.buttons[1][2].callback()
 assert(v.screen=='journal' and v.journal_query=='Pikachu' and #stack==1 and stack[1]==v)
 v:editText('memory','The Hobbit');dialog=stack[#stack-1]
 dialog.buttons[1][1].callback();assert(#stack==1 and #v.state.companion.memories==0)
 v:editText('nickname','  Évoli  ');dialog=stack[#stack-1]
 dialog.buttons[1][2].callback()
 assert(v.screen=='profile' and E.displayName(v.state)=='Évoli' and v.owner.saved==1)
end)
check('closing the game closes its dialog and ignores old callbacks',function()
 local v=view();v:editText('nickname','Ember')
 local dialog
 for _,widget in ipairs(stack) do if widget.getInputText then dialog=widget end end
 assert(dialog);local confirm=dialog.buttons[1][2].callback
 v:leave();assert(dialog.closed and #stack==0,'a text dialog or keyboard survived the game')
 local saved=v.owner.saved;confirm()
 assert(v.owner.saved==saved and not v.state.nicknames,'a closed dialog changed the saved game')
end)
check('a dismissed text dialog can be opened again',function()
 local v=view();v:editText('memory','A book')
 local dialog
 for _,widget in ipairs(stack) do if widget.getInputText then dialog=widget end end
 U:close(dialog);assert(not v.input_dialog)
 v:editText('memory','Another book');dialog=stack[#stack-1]
 assert(dialog~=v and dialog.input=='Another book')
 dialog.buttons[1][2].callback()
 assert(v.screen=='bookconfirm' and v.input_text=='Another book' and not v.input_dialog)
end)
check('a delayed sleep screen restores landscape geometry and touch targets',function()
 D.w=800;D.h=600
 local v=view();v:go('more');v:onSuspend()
 -- Screensaver.show switches to portrait; Resume precedes dismissal when locked.
 D.w=600;D.h=800;Device.screen_saver_mode=true;v:onResume()
 -- ScreenSaverWidget restores rotation, then broadcasts OutOfScreenSaver.
 D.w=800;D.h=600
 if v.onOutOfScreenSaver then v:onOutOfScreenSaver() end
 Device.screen_saver_mode=false
 assert(v.dimen.w==800 and v.dimen.h==600,'portrait layout remained after unlocking')
 v:paintTo(bb,0,0);tapButton(v,'nav','reading');assert(v.screen=='reading')
 local dirty=#U.dirty;v:onOutOfScreenSaver();assert(#U.dirty==dirty,'unchanged geometry caused another redraw')
end)
D.w=600;D.h=800;Device.screen_saver_mode=false
check('journal filters include every type in the expanded roster',function()
 local v=view();v:go('filters');v:paintTo(bb,0,0)
 local filters={};for _,b in ipairs(v.buttons) do if b.action=='filter' then filters[b.arg]=true end end
 for _,species in ipairs(E.species) do
  for kind in species.types:gmatch('%a+') do assert(filters[kind],'missing '..kind..' filter') end
 end
 v.state.seen['197']=true;tapButton(v,'filter','Dark');v:paintTo(bb,0,0)
 assert(v.journal_count==1 and v.journal_filter=='Dark')
end)
package.loaded['ui/widget/inputdialog']=original_dialog;U.show=show;U.close=close
assert(failed==0,tostring(failed)..' KOReader UI regressions failed')
print('KOREADER UI: '..passed..' dialog, sleep geometry and filter checks passed')
