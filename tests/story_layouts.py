"""Story UI checks with the shared KOReader desktop renderer."""
def run(c):
    g, paint, lua, out = c['g'], c['paint'], c['lua'], c['OUT']
    count=0
    for width,height in [(600,800),(758,1024),(1072,1448),(800,600)]:
        for large in (False,True):
            for dpi in (160,300):
                g.D.dpi=dpi
                v=g.newView(25);v.state.animation='off';v.go(v,'story')
                if large:
                    g.E.act(v.state,'preference','large_text',int(v.state.last))
                    g.E.act(v.state,'preference','high_contrast',int(v.state.last))
                t=v.state.story
                def check(name):
                    nonlocal count
                    image=paint(v,width,height)
                    assert not c['truncated'],(name,width,height,large,dpi,c['truncated'])
                    for b in v.buttons.values():
                        r=v.region(v,b.x,b.y,b.w,b.h)
                        labels=[]
                        for text,x,y,right,bottom in c['painted_ink']:
                            if max(x,r.x)<min(right,r.x+r.w) and max(y,r.y)<min(bottom,r.y+r.h):
                                assert x>=r.x and right<=r.x+r.w and y>=r.y and bottom<=r.y+r.h,(name,'text crosses button',text)
                                labels.append(text)
                        assert len(labels)<=(2 if b.action=='storyturn' else 1),(name,labels)
                    if width==600 and not large and dpi==160:image.save(out/f'story-{name}.png')
                    count+=1
                for node,n in g.E.story.nodes.items():
                    if n.op in ('text','choice'):
                        t.node=node;check(node)
                t.node=None
                for name,m in g.E.story.maps.items():
                    t.map=name
                    if len(m.warps):t.x,t.y=m.warps[1][1],m.warps[1][2]
                    check(name)
                t.partner=25;t.rival=155;t.encounter='rival';t.opponent=1;t.hp=40;t.battle=g.E.story.battle.new(25,1);t.battle.wildid=155;t.node='fight'
                check('battle');g.E.story.turn(t,g.E,1);check('battle-turn')
                v.state.nicknames=lua.table_from({'25':'W'*12});check('battle-nickname');v.state.nicknames=None
                t.battle.hp=1;g.E.story.turn(t,g.E,1);check('battle-result')
                v.owner.save_error=True;check('save-error');v.owner.save_error=None
                t.encounter='falkner';t.opponent=1;t.node='battle_falkner';t.battle=g.E.story.battle.new(25,1);t.battle.wildid=16
                check('gym-first');t.battle.hp=1;g.E.story.turn(t,g.E,2);check('gym-next')
                t.battle.hp=1;g.E.story.turn(t,g.E,2);check('gym-won')
                t.battle.status='lost';t.hp=0;check('gym-lost')
                t.hp=40;t.battle=g.E.story.battle.new(25,1);t.battle.wildid=16
                v.story_panel='bag';check('trainer-bag')
                t.encounter='wild';t.node='wild';check('wild-bag')
                v.story_panel=None;check('wild-battle')
                t.battle.hp=1;t.seed=1;g.E.story.catch(t,g.E);check('caught')
                g.E.story.finishBattle(t)
                t.party=lua.table_from([25,16,10,69,13,187])
                t.box=lua.table_from({str(i):True for i in [25,16,10,69,13,187,92]})
                t.health=lua.table_from({'16':30})
                t.map='VioletPokecenter1F';t.node=None;v.story_panel='party';check('party-centre')
                v.state.nicknames=lua.table_from({'25':'W'*12});check('party-nickname');v.state.nicknames=None
                v.story_panel='box';check('box-first');v.story_box_page=2;check('box-last');v.story_box_page=1
                t.map='Route31';v.story_panel='party';check('party-field')
                t.encounter='wild';t.node='wild';t.battle=g.E.story.battle.new(25,1);t.battle.wildid=16
                check('party-battle');t.hp=0;v.story_panel=None;check('forced-switch')
                v.owner.save_error=True;check('party-save-error');v.owner.save_error=None
                v.leave(v)
    g.D.dpi=None;g.D.w=600;g.D.h=800
    print(f'STORY LAYOUTS: {count} map/dialogue/battle size, DPI and text-mode combinations passed')
