# KOReader checks

Run `tests/test_koreader_runtime.lua` from an unpacked official KOReader
Linux build, inside its `lib/koreader` directory. It was checked with
v2026.07.1. Use a new data directory:

```sh
KO_HOME="$(mktemp -d)" \
SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software \
./luajit /path/to/Pokepal-for-Kindle/tests/test_koreader_runtime.lua \
  /path/to/Pokepal-for-Kindle/pokepal.koplugin
```

The test creates two books and a game in that directory. It loads PokePal
and KOReader's statistics and gesture plugins through the real plugin loader, then uses
the book reader, screensaver, window manager, image buffers and file syncs.
Reading and sleep intervals use a controlled clock; the display uses SDL's
dummy driver.

- The welcome appears once; all three buttons work, and closing a browser
  cancels a pending welcome. Existing gesture and QuickMenu choices stay intact.
- Tools, the dispatcher action and QuickMenu open the game from the browser
  and a book. Shortcut help fits portrait and landscape screens. Time spent
  at the welcome does not count as reading.
- Page turns and scrolling each collect 900 seconds across two books.
  Both advance the egg and reading trip and award 1 berry and 3 XP once.
- Waiting five minutes at an image or lock-only screensaver earns no
  reading time. The first minute after unlocking still counts.
- Disabled sleep features make no game-save calls during suspend.
- Walking and battles save their position and turn. Pausing, closing or sleeping
  does not count game time as reading. Cancelled walking callbacks stay cancelled after waking.
- Party selection and Tower switching run through real widgets, preserve the
  saved turn after reopening, and exclude playing from reading time.
- 504 sleep/wake cycles cover 21 views, including the Centre, party, box,
  unfinished box text, dojo, shop, Gym, bag, switching and resting battles.
  Each runs in two orientations, all four combinations of sleep preferences,
  and immediate, gesture and timed unlocks. The checks compare the screen
  pixels after waking and closing against a fresh repaint, preserve unfinished
  text and battle state, and check that no game window remains over the reader.
  Closing the reader or browser removes both sleep hooks.

The v1.0.7 download reproduces the original error: PokePal calls game methods
on KOReader's book view, and the queued wake callback fails on `freeImages`.
The same wake sequence passes with v1.0.8 and this branch. v1.0.8 still
misses scroll-mode reading and counts time waiting for an unlock.

These checks do not measure Kindle power-button or cover timing. Desktop
sleep timings include rendering and save I/O, but cannot establish whether
the reported 10–20 second delay is gone on the affected device.
