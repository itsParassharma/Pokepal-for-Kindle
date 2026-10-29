# PokePal for Kindle

A Pokémon pet for your Kindle. Feed it, play together and watch it grow.

![PokePal](docs/kindle-preview.png)

[Download 1.0.9](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/tag/v1.0.9) · [Watch the trailer](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/download/v1.0.9/PokePal-trailer.mp4)

This branch adds [Fern Town and Explore](docs/explore-prototype.md): a saved Pokémon box, a party of up to six, berry recruitment and supplies, Gym badges, four outdoor areas and a six-battle Tower run. All 386 Pokémon have directional walking frames. These features are not included in the 1.0.9 download.

Maps and trainers now use Crystal artwork. Battles show front and back sprites, and trainer teams change with each fight. Your chosen party stays the same. Hoenn battle sprites come from Emerald, converted to the same four shades.

Check party HP and moves from the map, follow quest progress at the town guide, and preview Tower opponents before choosing a benefit. Battle buttons explain the current opening, and switching previews the damage your next partner will take. There are 20 more starting move pairs across Pokémon families and evolution branches.

## Features

- Choose any of the 386 Pokémon from Kanto, Johto and Hoenn, with 11 quick starters.
- Feed, play, train, rest and clean. Collect daily berries, give your partner a nickname and watch it react to its mood.
- Every Pokémon has ten animations, including hops, spins and training moves. Preview them in the journal, or choose Eco or Off in settings.
- Earn berries and XP, hatch eggs and reach weekly goals as you read.
- Explore three different trails, find Pokémon and choose what happens on the way home.
- Help your partner evolve by building XP and bond.
- Discover favourite berries and watch your partner settle beside its decorations.
- Search your journal, save favourites and find friends ready to evolve. Earn 14 badges.
- Turn the screen off and let your Pokémon rest. KOReader can show your partner curled up beside its egg on the sleep screen.
- Choose larger text, stronger contrast or a small reading footer in settings.
- Everything works offline.

More:
[Reading rewards guide](docs/reading-rewards.md)
[Sleep screen setup](docs/companion-update.md#sleep-screen).

See [what changed in 1.0.9](docs/release-v1.0.9.md).

## Install with KUAL

You need a jailbroken touchscreen Kindle with KUAL installed. KOReader is not required.

1. Download and unzip **PokePal-v1.0.9-kual.zip**.
2. Connect your Kindle by USB. Copy the `extensions` folder onto the Kindle drive, next to `documents`. Merge folders if asked.
3. Eject your Kindle, then open **KUAL > PokePal > Play PokePal**.

## Install with KOReader

You need KOReader installed on your Kindle.

1. Download and unzip **PokePal-v1.0.9-koreader.zip**.
2. Copy the `koreader` folder onto the Kindle drive. Merge it with the existing folder.
3. Restart KOReader. Choose **Open PokePal** in the welcome, or open **Tools > PokePal**.

With [Bookshelf](https://github.com/AndyHazz/bookshelf.koplugin) 6.0 or later, your partner can also sit on the home screen: open the layout editor, tap **Add** and choose **PokePal**. Tap it to play.

You can assign **Open PokePal** to a gesture or QuickMenu. Hold **PokePal** in Tools for help, or read the [shortcut guide](docs/koreader-shortcuts.md).

## Saves

Both editions share your save. Use **More > Backups** to save or restore, and copy the `pokepal` folder to your computer before updating.

[Save help](pokepal.koplugin/INSTALL.txt) · [Build and device notes](native/README.md) · [Credits](pokepal.koplugin/CREDITS.txt)

Unofficial fan project. Sprites by [SpriteCollab contributors](https://github.com/PMDCollab/SpriteCollab).
Pokémon belongs to its respective owners. Shared game code is MIT; the standalone host is GPL-3.0-or-later.
