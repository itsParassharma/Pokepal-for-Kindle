# Crystal opening chapter preview

Open **Explore → Story**. Meet Mom and Professor Elm, choose Chikorita, Cyndaquil or Totodile, visit Mr. Pokémon and Professor Oak, face the rival on the way back and deliver the Mystery Egg to Elm.

![Three desktop renders from the playable opening chapter](crystal-story-preview.png)

The playable area contains nine original map layouts: both floors of home, New Bark Town, Elm's lab, Route 29, Cherrygrove City, its Pokémon Centre, Route 30 and Mr. Pokémon's house. Other doors and exits explain that the next area is not open yet.

Tap a destination to walk or a person to talk. The view scrolls around you. Use the directional buttons at the edge of a map to enter the next route. **Help** repeats the controls. Mom, the nurse and Mr. Pokémon restore your story partner's HP. Winning or losing the first rival battle both allow the journey to continue.

## Saves and installation

This is an unreleased source preview. The v1.1.0 downloads do not contain it. Close PokePal before replacing its plugin folder and restart KOReader afterward. For native KUAL builds, the same Lua files and assets belong under `extensions/pokepal/game/`; use a complete matching build.

Before trying the preview, copy your PokePal save folder off the device. On Kindle that is `/mnt/us/pokepal/`, shared by KOReader and KUAL. On other KOReader devices it is the KOReader settings directory. If you use both editions, update both together: older builds cannot read the new version 9 saves and may recover an older snapshot. Keep the original backup if you plan to return to v1.1.0.

Story state is a separate record inside the existing atomic save. Starting the chapter preserves your current Pokémon, XP, berries, reading totals and Explore party. Older Explore data receives its normal migration before the story is added. Reading rewards and ordinary companion care continue to work as before; story choices and battles do not grant or spend those rewards.

Your story starter, HP, location, conversations, flags, Mystery Egg and active battle are saved. **Pause**, closing PokePal and sleeping stop movement. Returning to **Explore → Story** resumes the same event or turn. A failed save blocks further story actions until **Retry save** succeeds. Existing backup and restore tools include story progress.

## What is adapted

Map layouts, terrain, doors and route connections are imported from [pret/pokecrystal at 5c877ef](https://github.com/pret/pokecrystal/tree/5c877ef55197039c9676e8e3eec6d254b1c40fe8). The opening event sequence is implemented as explicit Lua events with shorter dialogue and menus suitable for the Kindle. The rival chooses the starter with the type advantage over yours.

The rival fight currently uses PokePal's two-move battle rules and existing battle artwork. It has no guard, charge meter or guard-breaking system. Crystal's exact stats, levels, PP, accuracy, status rules, battle AI and complete move effects are not implemented here. The story has its own starter; it does not replace the reading companion or give it story XP.

Later towns, Gyms, Team Rocket events, wild encounters, catching, scripted NPC movement, the original phone system and the rest of Johto/Kanto are not playable in this chapter. The extracted full story reference is not an executable port or a general interpreter for Crystal's script commands.

## Verification

- Rule tests complete the chapter on foot with all three starters, serializing and reloading after every step and event. They also cover losing the rival battle, one-way ledges, route gates, closed doors, corrupt saves and older save migration.
- UI checks cover real touch dispatch, pause/resume, sleep cancellation, stale callbacks and save/restore/reading locks. Map, dialogue and battle layouts are checked at four screen sizes, two DPI settings and both text sizes.
- Packed map tiles and character images are decoded and checked for size and grayscale values. The native desktop host and Linux KOReader tests exercise the shared story UI and sleep lifecycle.
- Physical Kindle touch, refresh speed, ghosting and sleep/wake behaviour still require device testing. Desktop renders are not Kindle captures.

Rebuild the map assets with `python tools/import_story.py /path/to/pokecrystal` at the pinned revision. Source hashes are in `pokepal.koplugin/assets/story/sources.json`. The imported game artwork, layouts and story remain credited separately from PokePal's code in `CREDITS.txt`.
