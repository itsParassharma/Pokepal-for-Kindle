# Explore prototype

Open Explore to walk around Fern Town with your partner. Tap a destination or use the arrows to move one tile. The Pokemon Centre is on the left, the trail board is on the right, and the north path leads to the meadow.

Walk up to the nurse to restore battle HP. The trail board and the Trips button open the existing timed and reading expeditions.

| Town | Battle |
| --- | --- |
| ![Fern Town](explore-town.png) | ![Pikachu facing Caterpie](explore-battle.png) |

Screenshots from the KOReader desktop runtime.

## Battles

Tap Caterpie, Rattata or Geodude in the meadow to start an encounter. Your partner acts first, and the opponent shows its next action before you choose a move.

- Quick moves interrupt a charge. Bursts deal extra damage through a guard.
- Pikachu's family uses Quick Attack and Thunder Shock.
- Squirtle's family uses Water Gun and Withdraw. Blocking a hit strengthens the next attack.
- Bulbasaur's family uses Vine Whip and Leech Seed, which drains HP over three turns.
- Other partners use Quick strike and a burst of their primary type. All 386 can enter battles, but these move pairs still need balancing.

Battle HP starts at 40. Levels and care stats do not affect damage in this prototype. Move damage previews include type advantages, guards and any stored boost. These are PokePal rules, separate from the existing training moves.

The first win against each opponent gives 1 berry, 3 XP and 1 bond, and records that Pokemon in the journal. Rematches give no extra rewards. Losing takes you to the centre; the nurse heals for free. Leave battle ends an encounter without a reward.

Pause returns to your companion. Explore resumes the saved turn, including after closing PokePal or putting the Kindle to sleep. Time spent playing does not count towards reading rewards.

## Trying this branch

Copy your `pokepal` folder to your computer first. Opening Explore upgrades the save to version 5. Existing progress carries over, but older builds cannot read that save. Update both editions if you use both; restore your backup before returning to 1.0.9.

This prototype has one town, a centre and a meadow. The Battle Tower, party switching, shops and more towns are later work. Trainer sprites face four directions; the following Pokemon currently uses the existing front-facing frames.

The map and battle code is shared by KUAL and KOReader. Checks cover save reloads, rewards, failed saves, backup restoration, touch controls and larger text. The KOReader runtime test includes map and battle screens in its sleep/wake checks. Physical Kindle refresh speed and touch response still need a device test.
