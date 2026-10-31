# Crystal story preview: through Violet City

Open **Explore → Story**. Your current PokePal companion joins you automatically, with its nickname. There is no separate starter selection.

Chapter 1 follows Mom and Professor Elm's errand: visit Mr. Pokémon and Oak, face the rival and return the Mystery Egg. Chapter 2 continues along Routes 30 and 31 to Violet City. Climb Sprout Tower, meet the rival and Elder Li, then challenge Falkner for the **Zephyr Badge**. If you finished the earlier preview, leave Elm's lab and take Route 30's western path north.

![Desktop renders from the playable Violet City chapter](crystal-story-preview.png)

The preview contains 17 original map layouts, including all three Sprout Tower floors, Violet Gym and its Pokémon Centre. Fourteen trainers have their original species rosters, including repeated Pokémon. Tap a trainer to battle. Defeated trainers step aside; Li and Falkner remain to talk. Falkner can also be challenged before the tower.

## Playing

Tap a destination to walk or a person to talk. Use the directional buttons at a map edge to enter the next route. **Help** repeats the controls. Unsupported doors and routes explain the current boundary.

Mom, the nurses and Mr. Pokémon restore story HP and refill five **Super Potions**. This refill is a PokePal adaptation. A Super Potion restores up to 50 HP, capped by the story's 40 HP maximum, and uses a turn: the opponent can still hit back. These supplies belong to the story and do not spend care-mode berries. Rest between trainer battles when needed.

A trainer sends out each Pokémon in order. Your HP and remaining Potions carry through the team. Losing or drawing sends you to a Pokémon Centre without a victory flag; the trainer's full team is ready for a retry. The opening rival encounter still lets you continue after either outcome.

Elder Li awards a saved **HM Flash** milestone. Falkner awards the saved **Zephyr Badge**, completing chapter 2. Flash's field action, TM Mud-Slap and the subsequent Togepi handoff are not implemented yet. These milestones do not add Explore badges or change care XP.

## Your companion and saves

Changing or evolving your companion in care mode updates the story partner the next time you enter Story. It preserves story HP, supplies, location and quest progress. An active fight keeps the Pokémon that started it until that fight ends; the current companion then joins for the next encounter. Nicknames are read from the same companion record.

Chapter 1 preview saves migrate when you open Story, including saves at the old starter menu or during the rival fight. The old starter is replaced by your care companion. Location, events, Mystery Egg, HP, battle turn and enemy HP are preserved. A paused starter menu resumes at Elm's directions. Migration does not reset a completed chapter.

Story data is stored within PokePal's existing atomic save. **Pause**, closing PokePal and sleeping stop movement. Returning resumes the same conversation or battle opponent and turn. Failed saves block further actions, including spending Potions, until **Retry save** succeeds. Existing backup and restore tools include story progress. Care, reading totals, berries, XP and the separate Explore party are preserved.

## Installation

This is an unreleased source preview; v1.1.0 downloads do not contain it. Close PokePal before replacing its plugin folder and restart KOReader afterward. For native KUAL builds, the same Lua files and assets belong under `extensions/pokepal/game/`; use a complete matching build.

Copy your PokePal save folder off the device before installing. On Kindle it is `/mnt/us/pokepal/`, shared by KOReader and KUAL; on other KOReader devices use KOReader's settings directory. Opening this story upgrades the shared save to **version 10**. If you use both editions, update both together: older builds, including the chapter 1 preview, cannot read version 10 saves and may recover an older snapshot. Keep the original backup if you plan to downgrade.

## Adaptation and limits

Map layouts, terrain, doors, route connections and trainer species rosters come from [pret/pokecrystal at 5c877ef](https://github.com/pret/pokecrystal/tree/5c877ef55197039c9676e8e3eec6d254b1c40fe8). Events use explicit Lua scripts with condensed dialogue. The rival's Pokémon is chosen once from the Johto starters, preferring a type advantage against your initial companion.

Battles use PokePal's existing two-move rules and artwork, with no guard or charging system. They use fixed story HP rather than care-mode levels and XP. A Ghost partner whose two attacks cannot hit a Normal opponent receives the existing Swift move in its second slot for that encounter. Trainer teams and type matchups are adapted; Crystal's exact levels, stats, PP, accuracy, status rules and AI are not implemented.

Later towns, Team Rocket events, wild encounters, catching, shops, scripted NPC movement, the original phone system and the rest of Johto/Kanto remain outside this preview. The story reference is not a complete executable port.

## Verification

- Rule tests walk both chapters and the tower's connected floors, saving and reloading after each step and event. They cover five real legacy snapshots, all 386 companions, partner changes, team replacements, losses, draws, Potions, repeat rewards, route boundaries and corrupt saves.
- Battle simulations cover all 5,404 companion/trainer combinations from full story HP and stocked Potions. This verifies that every companion can win with suitable move and healing choices; it does not guarantee victory from any saved HP or inventory.
- UI tests cover touch actions, pause, sleep, stale callbacks, migration during reading sync and failed saves. Maps, dialogue and battles are rendered at four screen sizes, two DPI settings and both text sizes. All 296 packed story images are decoded and checked.
- Native desktop and Linux KOReader tests exercise the shared story UI, multi-Pokémon fights and sleep lifecycle. Physical Kindle touch, refresh speed, ghosting and sleep/wake behaviour still need device testing. The images above are desktop renders.

Rebuild the maps and teams with `python tools/import_story.py /path/to/pokecrystal` at the pinned revision. Source hashes are in `pokepal.koplugin/assets/story/sources.json`. Original game artwork, layouts and story are credited separately from PokePal's code in `CREDITS.txt`.
