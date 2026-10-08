# PokePal for Kindle

PokePal is a small Tamagotchi style game for KOReader on a jailbroken Kindle. Choose Bulbasaur, Charmander, Squirtle, Pikachu, Eevee, Chikorita, Cyndaquil or Totodile. Feed your partner, play a three-bush memory game, practise moves, or send it on an expedition. With enough XP and bond, evolve it from its partner profile. Eevee can become Vaporeon, Jolteon or Flareon.

The screen stays still most of the time. Charmander has short idle, sleeping, walking, and attack animations; they stop when the Kindle sleeps. Care and expeditions use elapsed time when you next open the game, so there is no background polling or wake alarm..

![A brief idle animation](docs/idle-preview.gif) ![A brief sleeping animation](docs/sleep-preview.gif)

![Choose a partner, including Chikorita](docs/starter-picker.png)

## Install

You need a working [KOReader](https://github.com/koreader/koreader) installation. KUAL can start KOReader, but PokePal itself lives in KOReader's menu.

1. Download [PokePal-v0.3.0-kindle.zip](dist/PokePal-v0.3.0-kindle.zip?raw=true).
2. Connect the Kindle by USB. Open the ZIP and merge its `koreader` folder into the top level of the Kindle drive. The resulting file should be `koreader/plugins/pokepal.koplugin/main.lua`.
3. Safely eject the Kindle and restart KOReader.
4. In KOReader, open **Tools → More tools → PokePal – Pokemon companion**. If it is missing, check **Tools → More tools → Plugin management** and restart KOReader.

The longer [install and play guide](pokepal.koplugin/INSTALL.txt) covers controls, evolution, saves, and troubleshooting. Existing 0.1 and 0.2 saves remain readable and keep their current partner. The picker appears for a new adventure. Your save lives in KOReader's settings directory as `pokepal.dat`; back it up before changing devices. To start again with another partner, close KOReader and rename both `pokepal.dat` and `pokepal.dat.old` to backup names first. This begins separate progress; it does not transfer the old partner's progress.

## In the game

- **Care:** feed, clean, rest, and wake your partner. The Play, Train, and Basket buttons show their cooldowns.
- **Partners:** browse eight starters, confirm your choice, and see the correct evolution family and requirements in Profile.
- **Play and train:** finish the berry-trail memory game or practise moves to earn XP and bond.
- **Explore:** choose an offline trail, then collect its berries, XP, and Pokémon sighting later.
- **Keep track:** browse the field journal, badges, and 24 recent activities.
- **Choose the pace:** Eco animation is the default for new saves; Gentle and Off are in Settings.

The game is forgiving about time away. Your partner does not die, and nothing needs to run while the Kindle is asleep.

## Source and testing

The KOReader plugin is in [`pokepal.koplugin`](pokepal.koplugin). It is plain Lua plus grayscale sprite frames; it needs no network connection after installation. The ZIP in [`dist`](dist) is ready to copy to a Kindle.

To run the desktop checks, install Python 3, then run:

```sh
python -m pip install -r requirements-dev.txt
python tests/test_and_render.py
```

These checks cover game rules, save recovery, animation scheduling, and several screen sizes using mocked KOReader APIs. They do not replace a test on the Kindle. The images above are renders of the game's view code with desktop fonts, not photographs of the device.

After the checks pass, `python tools/package_release.py` rebuilds the Kindle ZIP and SHA-256 file from the plugin folder. To reproduce the nine Johto species' assets, download their pinned GIF URLs from `assets/sources.json` in the plugin, then run `python tools/import_johto_sprites.py /path/to/gifs`. Neither tool is needed on the Kindle.

## Art and license

This is an unofficial fan project. The game code and original UI drawings are MIT licensed under [`LICENSE-CODE.txt`](pokepal.koplugin/LICENSE-CODE.txt). Pokémon names and sprites belong to their respective rights holders. The Charmander line uses adapted PMDCollab pose sheets; other Pokémon use sampled Gen V sprites. Sources, artist records, and applicable sprite terms are in [`CREDITS.txt`](pokepal.koplugin/CREDITS.txt) and the included sprite license files. The code license does not cover those assets.
