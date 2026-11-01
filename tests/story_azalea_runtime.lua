-- Shared controls exercised by the desktop renderer, KOReader and native host.
return function(v,tap)
 local E=v.engine;local S=E.story;local Store=dofile(v.path..'/storage.lua')
 local dir=debug.getinfo(1,'S').source:match('^@(.*/)')
 local fixtures=dofile(dir..'story_collection_fixtures.lua')
 local restored=assert(Store.decode(fixtures.badge,E))
 v.state.story=restored.story;v.state.version=math.max(v.state.version,restored.version)
 v.story_panel=nil;v.state.animation='off';v:go('story');tap('storynext',1)
 local t=v.state.story;t.map='VioletPokecenter1F';t.x=4;t.y=5
 local function tile(x,y) tap('storytile',y*S.maps[t.map].width+x) end
 tile(4,3);tap('storynext',1);assert(t.node=='egg_full');tap('storynext',1)
 tap('storypanel','party');tap('storydeposit',187);tap('storyback')
 tile(4,3);tap('storynext',1);assert(t.node=='egg_taken' and S.partySize(t)==6);tap('storynext',1)
 tap('storypanel','party');assert(t.togepi_steps==0);tap('storyback')
 local saved=E.companion.encode(t);v:onSuspend();v:onResume();assert(E.companion.encode(t)==saved)
 t.x=4;t.y=5;t.togepi_steps=S.egg_steps-1;tap('storydir','right')
 assert(t.node=='hatched' and t.box['175'] and #t.party==6 and not v.world_tick);tap('storynext',1)
 t.flags.POKEPAL_REACHED_AZALEA=true;t.flags.EVENT_AZALEA_TOWN_SLOWPOKETAIL_ROCKET=true
 t.map='SlowpokeWellB1F';t.x=5;t.y=3;tile(5,2);assert(t.node=='challenge_rocket1')
 tap('storynext',1);t.battle.hp=1;tap('storyturn',2);tap('storyfinish')
 assert(t.node=='well_saved' and t.map=='KurtsHouse' and t.flags.EVENT_CLEARED_SLOWPOKE_WELL)
 saved=E.companion.encode(t);v:onSuspend();v:onResume();assert(E.companion.encode(t)==saved)
 tap('nav','home');v:go('story');assert(t.node=='well_saved');tap('storynext',1)
 t.map='AzaleaGym';t.x=5;t.y=8;tile(5,7);assert(t.node=='challenge_bugsy')
 tap('storynext',1);t.battle.hp=1;tap('storyturn',2)
 assert(t.opponent==2 and t.battle.wildid==14 and t.battle.turn==2)
 saved=E.companion.encode(t);v:onSuspend();v:onResume();assert(E.companion.encode(t)==saved)
 assert(v.owner:save());return t
end
