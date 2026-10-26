# KOReader checks

Run `tests/test_koreader_runtime.lua` from an unpacked official KOReader
Linux build. It was checked with v2026.07.1. Use a new data directory:

```sh
KO_HOME="$(mktemp -d)" \
SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software \
./luajit /path/to/Pokepal-for-Kindle/tests/test_koreader_runtime.lua \
  /path/to/Pokepal-for-Kindle/pokepal.koplugin
```

The test creates two books and a game in that directory. It loads PokePal
and KOReader's statistics plugin through the real plugin loader, then uses
the book reader, screensaver, window manager, image buffers and file syncs.
Reading and sleep intervals use a controlled clock; the display uses SDL's
dummy driver.

- Page turns and scrolling each collect 900 seconds across two books.
  Both advance the egg and reading trip and award 1 berry and 3 XP once.
- Waiting five minutes at an image or lock-only screensaver earns no
  reading time. The first minute after unlocking still counts.
- Disabled sleep features make no game-save calls during suspend.
- 72 sleep/wake cycles cover bookshelf, book and game views, two
  orientations, all four combinations of sleep preferences, and immediate,
  gesture and timed unlocks. Closing a view removes both sleep hooks.

The v1.0.7 download reproduces the original error: PokePal calls game methods
on KOReader's book view, and the queued wake callback fails on `freeImages`.
The same wake sequence passes with v1.0.8 and this branch. v1.0.8 still
misses scroll-mode reading and counts time waiting for an unlock.

These checks do not measure Kindle power-button or cover timing. Desktop
sleep timings include rendering and save I/O, but cannot establish whether
the reported 10–20 second delay is gone on the affected device.
