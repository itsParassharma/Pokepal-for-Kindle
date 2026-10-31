-- Exercise story controls with either real KOReader widgets or the native host.
return function(v,tap)
 local E=v.engine;local S=E.story
 v.state.story=nil;v.state.animation='off';v:go('story')
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
 -- Resume a multi-Pokemon Gym fight on its second opponent as well.
 t.battle=nil;t.encounter=nil;t.opponent=nil;t.map='VioletGym';t.x=5;t.y=2;t.hp=40;t.egg=false
 t.flags.EVENT_BEAT_RIVAL_1=true;t.flags.EVENT_GAVE_MYSTERY_EGG_TO_ELM=true;t.flags.POKEPAL_REACHED_VIOLET=true
 t.node='challenge_falkner';assert(E.valid(v.state));tap('storynext',1)
 t.battle.hp=1;tap('storyturn',2);assert(t.opponent==2 and t.battle.turn==2)
 saved=E.companion.encode(t);v:onSuspend();v:onResume();assert(E.companion.encode(t)==saved)
 tap('nav','home');v:go('story');assert(t.opponent==2 and t.battle.turn==2)
 assert(v.owner:save());return t
end
