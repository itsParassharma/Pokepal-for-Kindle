# PokePal for Kindle

A Pokémon pet for your Kindle. Feed it, play together and watch it grow.

![PokePal](docs/kindle-preview.png)

[Download 1.0.6](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/tag/v1.0.6) · [Watch the trailer](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/download/v1.0.6/PokePal-trailer.mp4)

## Features

- Choose from eight starters and discover 160 Pokémon.
- Feed, play, train, rest and clean. Collect daily berries, give your partner a nickname and watch it react to its mood.
- Explore three trails, with discoveries along the way. Trips run on a timer or advance as you read.
- Help your partner evolve by building XP and bond. Each Pokémon keeps its progress when you switch.
- Make a home for your partner with six backgrounds and decorations.
- Browse your Pokémon journal, try five animations, collect badges and check your activity log.
- Earn berries and XP, hatch eggs and reach weekly goals as you read. Reading rewards are optional, and progress is shared across Kindle's reader and KOReader.
- Back up your game and reading records, with a preview before restoring. Everything works offline.

See the [reading rewards guide](docs/reading-rewards.md) to get started.

## Install with KUAL

You need a jailbroken touchscreen Kindle with KUAL installed. KOReader is not required.

1. Download and unzip **PokePal-v1.0.6-kual.zip**.
2. Connect your Kindle by USB. Copy the `extensions` folder onto the Kindle drive, next to `documents`. Merge folders if asked.
3. Eject your Kindle, then open **KUAL > PokePal > Play PokePal**.

## Install with KOReader

You need KOReader installed on your Kindle.

1. Download and unzip **PokePal-v1.0.6-koreader.zip**.
2. Copy the `koreader` folder onto the Kindle drive. Merge it with the existing folder.
3. Restart KOReader, then open **Tools > More tools > PokePal**.

## Saves

Both editions use `pokepal/pokepal.dat` on the Kindle drive. Existing saves are copied across automatically and the originals are kept. Update both editions if you use both, and back up the `pokepal` folder before updating. Older builds cannot read saves with the new features.

Under **More > Backups**, tap **Save a backup now**. To restore, tap **Preview**, check the partner and date, then confirm. Your current game is kept under **Before last restore**. Backups stay on the Kindle, so copy the `pokepal` folder to your computer to protect against losing the device.

[Save help](pokepal.koplugin/INSTALL.txt) · [Build and device notes](native/README.md) · [Credits](pokepal.koplugin/CREDITS.txt)

Unofficial fan project. Sprites by [SpriteCollab contributors](https://github.com/PMDCollab/SpriteCollab). Pokémon belongs to its respective owners. Shared game code is MIT; the standalone host is GPL-3.0-or-later.
