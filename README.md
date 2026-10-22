# PokePal for Kindle

A Pokémon pet you can check on between chapters. Pick a starter, feed it, play a memory game, and send it out to find more Pokémon while you read.

The full Kanto roster is here: Bulbasaur through Mew, plus the nine Johto starter forms. Once you meet a Pokémon, you can choose it from the journal. Each one keeps its XP and bond when you switch.

![PokePal on the home screen](docs/kindle-preview.png)

## Download

[Get the release](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/tag/v0.4.0).

| Download | What you need |
| --- | --- |
| **PokePal-v0.4.0-kual-preview.zip** | A jailbroken touchscreen Kindle with KUAL. KOReader is not needed. |
| **PokePal-v0.4.0-koreader.zip** | KOReader installed on your Kindle. |

The standalone KUAL build is a **preview**, initially targeting ARMv7 touchscreen Kindles such as the 2021 Paperwhite. It builds and passes desktop checks, but has not been tested on a physical Kindle. Touch alignment, screen refresh and sleep handling still need that check. Older button-only Kindles are not supported.

## Install from KUAL

1. Unzip the **kual-preview** download.
2. Connect your Kindle by USB. Copy the `extensions` folder to the top level of the Kindle drive, merging folders if asked.
3. Safely eject, then open **KUAL → PokePal → Play PokePal**.

You should have `extensions/pokepal/pokepal` on the Kindle. Copy the whole folder: the game, sprites, fonts and launcher are all included. There is no separate WAD to find.

Exit returns to Kindle Home. Going to sleep saves and closes PokePal; open it from KUAL again to carry on. Keep `extensions/pokepal/data/` when updating.

## Install in KOReader

Unzip the **koreader** download and copy its `koreader` folder to the top level of the Kindle drive. Restart KOReader, then open **Tools → More tools → PokePal**.

Existing 0.1–0.3 saves still work. Back up `pokepal.dat` and `pokepal.dat.old` in KOReader's settings folder first. The editions have separate saves. To move to KUAL, close both editions and copy those files into `extensions/pokepal/data/` before starting it there.

## Playing

- Start with Bulbasaur, Charmander, Squirtle, Pikachu, Eevee, Chikorita, Cyndaquil or Totodile.
- Feed, clean, nap, play the three-bush memory game, or practise moves.
- Explore three trails. They choose Pokémon you haven't met, then repeat encounters once you've found everyone on that trail.
- Tap a journal entry to see its types, preview its poses, or make it your partner.
- Evolve from the partner profile. Eevee has three Kanto choices.

Food, energy, berries and cooldowns are shared when you switch. XP and bond stay with each Pokémon. Finish a trip or wake your partner before switching. Progression and practice moves use PokePal's own rules.

Nothing runs while the game is closed, and your partner won't die if you forget to check in. Expeditions use elapsed time when you next open the game. Battery use has not been measured on a Kindle.

## Animations

All 160 Pokémon have idle, sleep, walk and attack poses. There are eating poses for 33; the others use idle when fed. Persian and Arcanine have still idle poses in the source sheets, but their other actions animate.

These are short, front-facing samples for e-ink, not every direction and animation from a Pokémon game. **Eco** uses two frames, **Gentle** uses up to four, and **Off** keeps the picture still. Nothing animates between actions.

The previews here are desktop renders of the game, not footage of a Kindle.

## Building and checking

The shared game and UI are in `pokepal.koplugin/`. The standalone host in `native/` uses Lua and [FBInk](https://github.com/NiLuJe/FBInk), with its own drawing and touch input. It does not start or load KOReader.

```sh
python -m pip install -r requirements-dev.txt
python tests/test_and_render.py
python tools/build_native.py --zig /path/to/zig --deps /path/to/build-cache
python tools/package_release.py --deps /path/to/build-cache
```

The native build uses Zig 0.13.0 and pinned dependencies. See [native/README.md](native/README.md) for build details and device checks, and [INSTALL.txt](pokepal.koplugin/INSTALL.txt) for controls and saves.

## Credits

This is an unofficial fan project. Pokémon belongs to its respective owners.

Sprites come from [PMDCollab's SpriteCollab](https://github.com/PMDCollab/SpriteCollab). Artist credits, source revisions and conversion details are included with the game. Keep those credits with copies of the assets; sprite terms are separate from code licenses.

The shared game is MIT licensed. The standalone host is GPL-3.0-or-later and links FBInk; its corresponding source is included in the release. See [CREDITS.txt](pokepal.koplugin/CREDITS.txt).
