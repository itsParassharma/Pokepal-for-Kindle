# Standalone PokePal

The KUAL edition loads the shared Lua game and view through a local drawing/input host. It does not load KOReader.

The executable contains Lua, FBInk and musl. It targets ARMv7 Linux, initially the 2021 Paperwhite. A static runtime avoids relying on the firmware's soft-float or hard-float C library. Device support still depends on the screen, touchscreen and power-event interfaces.

## Build

With Python, Git and Zig 0.13.0 installed, run from the repo root:

```sh
python tools/build_native.py --zig /path/to/zig --deps /path/to/build-cache
python tools/package_release.py --deps /path/to/build-cache
```

The build fetches pinned Lua and FBInk revisions and the pinned stb submodule. Output goes under `native/build/`. The package tool includes exact dependency sources in a corresponding-source ZIP. Keep that ZIP alongside any redistributed executable.

On Windows, add `--headless` to build the renderer smoke-test executable. From `native/build/extension`, run:

```sh
pokepal-headless.exe ../../../tests/test_native.lua native-test.pgm
```

This tests native text/image drawing, the Lua bridge, actions, partner switching, save reload and suspend cancellation. It cannot test Linux input or e-ink updates.

## Device check still needed

Use a backed-up save. Check starter selection and touch alignment, feed once, exit and reopen, then start an animation and press power. Wake the Kindle and reopen PokePal from KUAL. Also check a magnetic cover, automatic sleep, repeated launching and exiting after an error. Kindle Home and its status bar should work afterward.

PokePal saves and exits on `goingToScreenSaver`. The launcher temporarily pauses `awesome` and disables the Pillow status bar, restoring them on exit. It does not change firmware files or prevent sleep. A failed power listener closes the app.

The touch reader handles single-touch and slot-zero multitouch, scales reported axis ranges and applies FBInk's axis/mirror information. Device-specific calibration and rotation have not been checked on hardware. Use portrait orientation for this preview.

Saves live in `data/`, separately from KOReader saves. Release archives contain no test save.

## License

The native host and launcher are GPL-3.0-or-later; the shared game remains MIT. FBInk, Lua, stb and Bitstream Vera retain their original notices. Pokemon assets have separate terms in `game/CREDITS.txt`.
