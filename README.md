# PokePal for Kindle

A Pokémon pet for your Kindle. Feed it, play together and watch it grow.

![PokePal](docs/kindle-preview.png)

[Download 1.0.6](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/tag/v1.0.6) · [Watch the trailer](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/download/v1.0.6/PokePal-trailer.mp4)

## Features

- 160 Pokémon to discover, with eight starters to choose from.
- Feed, play, train and rest. Give your partner a nickname and watch its reactions change with its mood.
- Explore three trails with discoveries along the way. Trips can run on a timer or advance as you read.
- Track XP and bond toward evolution. Each partner keeps its progress when you switch.
- Choose from six backgrounds and decorate with a cushion, plant, lamp or bookshelf.
- Browse your Pokémon journal, try five animations, collect badges and check your activity log.
- Reading is an optional way to earn berries and XP, hatch eggs and work toward weekly goals. Kindle's reader and KOReader share your progress.
- Back up your game and reading records, with a preview before restoring. Everything works offline.

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

## Looking after your partner

Feed, play, train, rest and clean from the home screen. **Basket** has your daily berries. **Profile** shows evolution progress and lets you choose a nickname. Open **More** to change the background or buy decorations.

## Reading rewards

Reading rewards are optional. Open PokePal once, then read as usual. Every 15 recorded minutes earns **1 berry and 3 XP** when you return. Leftover minutes carry over. Open **More > Reading rewards** to check progress, see your last recap or turn rewards off.

Under **Explore**, choose **As you read** and pick a trail. Open **More > Reading rewards > Your egg** to pick up an egg. The same reading time advances both, and you still earn berries and XP. Hatchlings join your journal without replacing your current partner. Timed trips are the default.

Keep reading your book, then return to see what happened. Your egg sits beside your partner and starts to crack as it gets closer to hatching.

Choose a 60, 120 or 180 minute target under **More > Reading rewards > Weekly goal**. Reaching it adds 5 berries and 10 XP. The week starts on Monday and counts minutes collected during your visits.

Kindle rewards use the timing data saved with books, where available. KOReader tracks page turns, pauses during sleep and limits long pauses to two minutes per page. Keep the PokePal plugin enabled. [How tracking works](docs/reading-rewards.md).

## Saves

Both editions use `pokepal/pokepal.dat` on the Kindle drive. Existing saves are copied across automatically and the originals are kept. Update both editions if you use both, and back up the `pokepal` folder before updating. Older builds cannot read saves with the new features.

Under **More > Backups**, tap **Save a backup now**. To restore, tap **Preview**, check the partner and date, then confirm. Your current game is kept under **Before last restore**. Backups stay on the Kindle, so copy the `pokepal` folder to your computer to protect against losing the device.

[Save help](pokepal.koplugin/INSTALL.txt) · [Build and device notes](native/README.md) · [Credits](pokepal.koplugin/CREDITS.txt)

Unofficial fan project. Sprites by [SpriteCollab contributors](https://github.com/PMDCollab/SpriteCollab). Pokémon belongs to its respective owners. Shared game code is MIT; the standalone host is GPL-3.0-or-later.
