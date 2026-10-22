# Standalone PokePal

The KUAL edition loads the shared Lua game and view through a local drawing/input host. It does not load KOReader.

The executable contains Lua, FBInk and musl. It targets ARMv7 Linux touchscreen Kindles. A static runtime avoids relying on the firmware's soft-float or hard-float C library. Device support still depends on the screen, touchscreen and power-event interfaces; the app does not restrict tracking to particular model names.

## Build

With Python, Git and Zig 0.13.0 installed, run from the repo root:

```sh
python tools/build_native.py --zig /path/to/zig --deps /path/to/build-cache
python tools/package_release.py --deps /path/to/build-cache
```

The build fetches pinned Lua and FBInk revisions and the pinned stb submodule. Output goes under `native/build/`. The package tool includes exact dependency sources in a corresponding-source ZIP. Keep that ZIP alongside any redistributed executable.

Add `--headless` to build the renderer smoke-test executable on Linux or Windows. From `native/build/extension`, run:

```sh
./pokepal-headless ../../../tests/test_native.lua native-test.pgm
```

This tests native text/image drawing, the Lua bridge, actions, partner switching, save reload and suspend cancellation. It cannot test Linux input or e-ink updates.

On Windows the executable is named `pokepal-headless.exe`. The renderer caches decoded sprites and glyphs, uses UTF-8 text and repaints only the stage during animation. Ordinary navigation does not request a flashing refresh. Idle input waits have no timeout.

## Device check still needed

Use a backed-up save. Check starter selection and touch alignment, feed once, exit and reopen, then start an animation and press power. Wake the Kindle and reopen PokePal from KUAL. Also check a magnetic cover, automatic sleep, repeated launching and exiting after an error. Kindle Home and its status bar should work afterward.

PokePal saves and exits on `goingToScreenSaver`. The launcher temporarily pauses `awesome` and disables the Pillow status bar, restoring them on exit. It does not change firmware files or prevent sleep. A failed power listener closes the app.

The touch reader handles single-touch and slot-zero multitouch, scales reported axis ranges and applies FBInk's axis/mirror information. Device-specific calibration and rotation have not been checked on hardware. Use portrait orientation for this preview.

Both editions use `/mnt/us/pokepal/pokepal.dat`. The first launch copies the most recently used legacy save from `extensions/pokepal/data` or the default KOReader settings folder, leaving the originals intact. On a desktop or a non-Kindle KOReader installation, the previous local save location is used. Release archives contain no test save.

Reading rewards inspect local book counters in small batches after the game opens. KOReader exports its page-turn time to the same folder, so either edition can collect it. [Formats, limits and tests](../docs/reading-rewards.md).

The optional auto-rest preference starts a power-event listener after PokePal closes. It calls `--suspend` and `--resume` without opening the framebuffer or grabbing touch input. KUAL keeps the normal Kindle sleep screen; no screensaver add-on is needed. [Setup and limits](../docs/companion-update.md#sleep-screen).

## License

The native host and launcher are GPL-3.0-or-later; the shared game remains MIT. FBInk, Lua, stb, DejaVu and Bitstream Vera retain their original notices. Pokemon assets have separate terms in `game/CREDITS.txt`.
