# PokePal for Kindle

A Pokémon pet for your Kindle. Check in between chapters, feed your partner or send it exploring.

![PokePal](docs/kindle-preview.png)

[Download 1.0.5](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/tag/v1.0.5) · [Watch the trailer](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/download/v1.0.5/PokePal-trailer.mp4)

## Features

- 160 Pokémon to discover, with eight starters to choose from.
- Feed your partner berries, clean up after it and let it rest.
- Read in Kindle's reader or KOReader to earn berries and XP. Both editions share your progress.
- Play a memory game or practise moves to earn XP and build your bond.
- Level up and evolve. Each partner keeps its XP and bond when you switch.
- Explore three routes for berries and new Pokémon. Expeditions keep time while the game is closed.
- Browse your journal to check types, choose a partner or try its animations.
- Every Pokémon has idle, eating, sleeping, walking and attack animations. Choose **Eco**, **Gentle** or **Off** under **More**.
- Earn six badges and look back through your activity log. Everything works offline.

## Install with KUAL

You need a jailbroken touchscreen Kindle with KUAL installed. KOReader is not required.

1. Download and unzip **PokePal-v1.0.5-kual.zip**.
2. Connect your Kindle by USB. Copy the `extensions` folder onto the Kindle drive, next to `documents`. Merge folders if asked.
3. Eject your Kindle, then open **KUAL > PokePal > Play PokePal**.

## Install with KOReader

You need KOReader installed on your Kindle.

1. Download and unzip **PokePal-v1.0.5-koreader.zip**.
2. Copy the `koreader` folder onto the Kindle drive. Merge it with the existing folder.
3. Restart KOReader, then open **Tools > More tools > PokePal**.

## Reading rewards

Open PokePal once, then read as usual. Every 15 recorded minutes earns **1 berry and 3 XP** when you return. Leftover minutes carry over. Check progress or turn rewards off under **More > Reading rewards**.

Kindle rewards use the timing data saved with books, where available. KOReader tracks page turns, pauses during sleep and limits long pauses to two minutes per page. Keep the PokePal plugin enabled. [How tracking works](docs/reading-rewards.md).

## Saves

Both editions now use `pokepal/pokepal.dat` on the Kindle drive. Existing saves are copied across automatically and the originals are kept. Update both editions if you use both, and back up the `pokepal` folder before updating.

[Save help](pokepal.koplugin/INSTALL.txt) · [Build and device notes](native/README.md) · [Credits](pokepal.koplugin/CREDITS.txt)

Unofficial fan project. Sprites by [SpriteCollab contributors](https://github.com/PMDCollab/SpriteCollab). Pokémon belongs to its respective owners. Shared game code is MIT; the standalone host is GPL-3.0-or-later.
