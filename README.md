# PokePal for Kindle

A Tamagotchi-style Pokémon pet for your Kindle. Feed it, play together and watch it grow.

![PokePal](docs/kindle-preview.png)

[Download 1.1.0](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/tag/v1.1.0) · [Watch the care demo](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/download/v1.0.9/PokePal-trailer.mp4)

## Features

- Choose any of the 386 Pokémon from Kanto, Johto and Hoenn, with 11 quick starters.
- Feed, play, train, rest and clean. Collect daily berries, give your partner a nickname and watch it react to its mood.
- Earn berries and XP, hatch eggs and reach weekly goals as you read.
- Explore three different trails, find Pokémon and choose what happens on the way home.
- Help your partner evolve by building XP and bond.
- Discover favourite berries and watch your partner settle beside its decorations.
- Search your journal, save favourites and find friends ready to evolve. Earn 14 badges.
- Turn the screen off and let your Pokémon rest. KOReader can show your partner curled up beside its egg on the sleep screen.
- Choose larger text, stronger contrast or a small reading footer in settings.
- Explore Fern Town and four wild areas, recruit Pokémon with berries.
- Earn Gym badges and take on trainers.
- Everything works offline.

More:
[Reading rewards guide](docs/reading-rewards.md)
[Sleep screen setup](docs/companion-update.md#sleep-screen).

See [what changed in 1.1.0](docs/release-v1.1.0.md).

## Screenshots

| Feed your partner | Keep the nest clean |
| --- | --- |
| <img src="docs/care-feeding-squirtle.png" alt="Feed Squirtle a berry" width="400"> | <img src="docs/care-cleaning.png" alt="Clean Pikachu's nest" width="400"> |

| Rest while you read | A walk through Fern Town |
| --- | --- |
| <img src="docs/care-resting.png" alt="Eevee sleeping while you read" width="400"> | <img src="docs/explore-town-preview.png" alt="Explore Fern Town" width="400"> |

## Install with KOReader

You need KOReader installed on your Kindle.

1. Download and unzip **PokePal-v1.1.0-koreader.zip**.
2. Copy the `koreader` folder onto the Kindle drive. Merge it with the existing folder.
3. Restart KOReader. Choose **Open PokePal** in the welcome, or open **Tools > PokePal**.

For KoStore installation and discovery, see the [KoStore guide](docs/kostore.md).

**Kobo and other KOReader devices (experimental):** copy `pokepal.koplugin`
from the KOReader ZIP into your existing KOReader `plugins` directory, usually
`.adds/koreader/plugins` on Kobo. Reading rewards use KOReader sessions; the
native Kobo reader is not integrated. Saves use KOReader's settings folder.
Physical touch, sleep/wake and display behaviour still need device testing.

---

### Bookshelf home screen

With [Bookshelf](https://github.com/AndyHazz/bookshelf.koplugin), your partner can sit on the KOReader home screen. Add **PokePal** in the layout editor and tap it to play.

<a href="https://github.com/user-attachments/assets/bbb8af21-3727-4d49-bba2-a6acde8727bd"><img src="https://github.com/user-attachments/assets/bbb8af21-3727-4d49-bba2-a6acde8727bd" alt="Charizard on the Bookshelf home screen" width="300"></a><br>
<sub>Credit: <a href="https://github.com/AndyHazz">AndyHazz</a></sub>

### SimpleUI home screen (preview)

With [SimpleUI](docs/simpleui-tiny-critter.md), choose **Add module → PokePal** in its home-screen layout editor. Your selected partner follows automatically, with level, XP, optional care bars and short animations. Tap the card to play. A separate Tiny Critter image export is also available. Tested with SimpleUI 3.0.1 and pinned main; these additions are not in the existing v1.1.0 download.

<a href="docs/simpleui-home-mockup.png"><img src="docs/simpleui-home-mockup.png" alt="Illustrative SimpleUI home screen with Squirtle's PokePal stats above six sample books" width="300"></a><br>
<sub>Illustrative mockup with sample book covers and reading percentages. Actual layout depends on your SimpleUI settings.</sub>

### KOReader shortcuts

You can assign **Open PokePal** to a gesture or QuickMenu. Hold **PokePal** in Tools for help, or read the [shortcut guide](docs/koreader-shortcuts.md).

## Install with KUAL

You need a jailbroken touchscreen Kindle with KUAL installed. KOReader is not required.

1. Download and unzip **PokePal-v1.1.0-kual.zip**.
2. Connect your Kindle by USB. Copy the `extensions` folder onto the Kindle drive, next to `documents`. Merge folders if asked.
3. Eject your Kindle, then open **KUAL > PokePal > Play PokePal**.

## Saves

Both editions share your save. Use **More > Backups** to save or restore, and copy the `pokepal` folder to your computer before updating.

[Save help](pokepal.koplugin/INSTALL.txt) · [Build and device notes](native/README.md) · [Credits](pokepal.koplugin/CREDITS.txt)

Unofficial fan project. Sprites by [SpriteCollab contributors](https://github.com/PMDCollab/SpriteCollab).
Pokémon belongs to its respective owners. Shared game code is MIT; the standalone host is GPL-3.0-or-later.
