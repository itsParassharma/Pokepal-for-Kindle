-- Exercise story controls with either real KOReader widgets or the native host.
return function(v,tap)
 local E=v.engine;local S=E.story
 v.state.story=nil;v.story_panel=nil;v.state.animation='off';v:go('story')
 tap('storynext',1)
 local m=S.maps.PlayersHouse2F;local p=m.warps[1]
 tap('storytile',p[2]*m.width+p[1]);assert(v.state.story.node=='mom')
 tap('storynext',1);tap('storynext',1)
 local t=v.state.story;assert(t.flags.ENGINE_POKEGEAR)
 -- Rule tests traverse every intervening map. Here seed each UI event location.
 t.map='ElmsLab';t.x=5;t.y=3;t.node='elm';assert(E.valid(v.state))
 tap('storynext',1);tap('storynext',1);assert(t.node=='directions' and t.partner==v.state.species)
 tap('storynext',1)
 t.map='CherrygroveCity';t.x=33;t.y=6;t.egg=true;t.node='rival'
 t.flags.EVENT_GOT_MYSTERY_EGG_FROM_MR_POKEMON=true;t.flags.ENGINE_POKEDEX=true
 assert(E.valid(v.state));tap('storynext',1);tap('storyturn',2)
 assert(t.battle.turn==2 and E.valid(v.state))
 local saved=E.companion.encode(t)
 v:onSuspend();v:onResume();assert(E.companion.encode(t)==saved)
 tap('nav','home');v:go('story');assert(v.state.story.battle.turn==2)
 -- Encounter, catch, switch and use the Centre box through the real controls.
 t.battle=nil;t.encounter=nil;t.opponent=nil;t.node=nil;t.hp=40;t.map='Route29';t.grace=0;t.seed=100
 m=S.maps[t.map]
 for y=1,m.height-2 do for x=1,m.width-2 do
  if S.tile(t.map,x,y)=='G' and S.tile(t.map,x-1,y)=='G' then t.x=x-1;t.y=y end
 end end
 tap('storydir','right');assert(t.encounter=='wild' and not v.world_path and not v.world_tick)
 -- Use a sourced species different from any current care companion.
 t.battle.wildid=t.origin==16 and 19 or 16;t.battle.hp=1;t.seed=1;assert(E.valid(v.state))
 local caught=t.battle.wildid;local balls=t.balls;local care=v.state.species
 tap('storypanel','bag');tap('storycatch');assert(t.battle.status=='befriended' and t.balls==balls-1 and #t.party==2)
 saved=E.companion.encode(t);v:onSuspend();v:onResume();assert(E.companion.encode(t)==saved)
 tap('storyfinish');tap('storypanel','party');tap('storylead',caught)
 assert(t.partner==caught and v.state.species==care)
 tap('storypanel','party');tap('storylead',t.origin)
 t.map='CherrygrovePokecenter1F';t.x=4;t.y=5
 tap('storypanel','party');tap('storydeposit',caught);assert(#t.party==1)
 tap('storypanel','box');tap('storywithdraw',caught);assert(#t.party==2)
 tap('storyback');assert(E.valid(v.state))
 -- Resume a multi-Pokemon Gym fight on its second opponent as well.
 t.battle=nil;t.encounter=nil;t.opponent=nil;t.map='VioletGym';t.x=5;t.y=2;t.hp=40;t.egg=false
 t.flags.EVENT_BEAT_RIVAL_1=true;t.flags.EVENT_GAVE_MYSTERY_EGG_TO_ELM=true;t.flags.POKEPAL_REACHED_VIOLET=true
 t.node='challenge_falkner';assert(E.valid(v.state));tap('storynext',1)
 t.battle.hp=1;tap('storyturn',2);assert(t.opponent==2 and t.battle.turn==2)
 saved=E.companion.encode(t);v:onSuspend();v:onResume();assert(E.companion.encode(t)==saved)
 tap('nav','home');v:go('story');assert(t.opponent==2 and t.battle.turn==2)
 assert(v.owner:save());return t
end
