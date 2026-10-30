# SimpleUI Tiny Critter

PokePal can export its selected Pokémon as a SimpleUI custom critter. This is an
optional, one-way image integration. It uses existing PokePal animation stills
for all 386 Pokémon, with twelve transparent 64 × 64 PNGs per export.

![Sleeping Squirtle rendered by SimpleUI 3.0.1 in the KOReader Linux runtime](simpleui-preview.png)

This preview uses SimpleUI's own dialogue; the speech text is not from PokePal.

## Install and choose the critter

1. Install the PokePal build containing this integration in
   `koreader/plugins/pokepal.koplugin/`, then restart KOReader. The existing
   v1.1.0 release does not include this addition.
2. Use a SimpleUI build that includes **Tiny Critter**. The tested release is
   **3.0.1**. The repository's `3.0.0` tag does not contain the critter module.
3. Choose a partner in PokePal. Open **Tools > PokePal: SimpleUI Tiny Critter >
   Export selected Pokémon**.
4. Add **Tiny Critter** in SimpleUI's home-screen layout editor and choose
   **Pokepal partner** in its **Critter** picker. In 3.0.1 this is in the module's
   settings; current main has shared **Settings > Tiny Critter** controls.
5. Reopen the home screen. If an older cached picture remains, reopen the
   Critter picker or restart KOReader.

PokePal does not enable the module or change your chosen SimpleUI critter.
You choose it yourself, and can switch back to any other critter at any time.

The exporter uses `DataStorage:getSettingsDir()`, not a hard-coded Kindle path:

| Destination below the KOReader settings directory | Content |
| --- | --- |
| `simpleui/sui_critters/pokepal_partner/neutral.png` | Required default image |
| `simpleui/sui_critters/pokepal_partner/<mood>.png` | Eleven optional mood images |
| `simpleui/sui_critters/pokepal_partner/.pokepal-owned` | Data-only ownership and image checksums |

Only the selected Pokémon is exported. There are no symlinks, external image
paths, executable phrase loaders or dependencies on the PokePal install path
inside this folder. It remains a usable static critter with PokePal disabled.

## What synchronizes

| Option | Behavior |
| --- | --- |
| **Export selected Pokémon** | Copies a snapshot of the committed PokePal save's selected partner. SimpleUI chooses its expressions. |
| **Keep Pokémon in sync** | Off by default. Updates the export after successful PokePal game saves and when KOReader starts or resumes while awake. |
| **Use PokePal mood image** | Off by default. Puts PokePal's current care/rest/trip pose into every mood image, so SimpleUI's dialogue cannot replace that pose. Applies immediately; subsequent updates require sync or another manual export. |

The selected partner follows PokePal's saved `species`, including evolution and
companion changes. With mood images enabled, an expedition maps to `playful`,
rest or low energy to `sleepy`, hunger or low joy to `sad`, dirt to `grumpy`,
high bond to `love`, and otherwise to `happy`. Elapsed care is calculated on a
copy of the save and never writes rewards, XP or progress back into the game.

The images are stills, not animated PNGs. Several moods share a pose; these are
existing Pokémon poses, not twelve separately drawn facial expressions.

The integration does **not** synchronize SimpleUI's conversational mood score,
dialogue, challenges, reading totals, XP or level. There is no two-way companion
selection and tapping the critter still opens SimpleUI's conversation. Those
features would need an agreed API or additional upstream hooks.

There is no background polling or forced screen refresh. A running standalone
KUAL game does not push updates into KOReader; export manually, restart, or
resume KOReader after the standalone game saves. A suspended/closed PokePal
instance does no automatic export. Time-based mood changes appear on the next
export trigger. The exported files are the compatibility contract; a guarded
call to an already-loaded SimpleUI `Assets.rescan()` also clears its image
cache, including two updates within the same filesystem timestamp second.

## Saves, settings and custom files

- PokePal reads its existing save through the normal validated loader. It does
  not change the save format, backup files, reading counters or save locks.
- SimpleUI preferences, stored mood, critters and decorations stay untouched.
  Two new PokePal-owned KOReader preferences remember sync and mood-image choices.
- An existing `pokepal_partner` folder without a valid ownership manifest, an
  edited generated image, an extra file, or a symlink blocks replacement. The
  error appears on manual export or under **About this integration**.
- Updates are staged beside the destination, then promoted as a directory.
  The previous export is retained until the promotion is synced. Interrupted
  swaps and cleanup are recovered on the next export. Neither plugin's saves
  are part of this transaction. Actual power-loss durability still depends on
  the device and filesystem.
- Turning sync off leaves the last image pack in place. To remove it, disable
  sync, choose another critter in SimpleUI and remove only `pokepal_partner`.
  For hand edits, first copy the pack to a differently named custom-critter
  folder and select that copy.

## Phrases and upstream versions

The [custom-critter documentation](https://github.com/doctorhetfield-cmd/simpleui.koplugin/blob/257c26d6685ced4fc2e895f98287b5f16f1d4f5e/docs/CRITTER.md)
describes a `phrases.lua` beside a critter's images. However, both tested sources
load custom phrases from the shared `simpleui/sui_critters/phrases.lua`, through
`Assets.phrasesFile()`. PokePal therefore writes **no phrase file** and leaves
your existing phrases intact. Per-critter dynamic dialogue is not claimed.

Compatibility was checked against upstream SimpleUI
[`3.0.1` / `e5cd6dc`](https://github.com/doctorhetfield-cmd/simpleui.koplugin/tree/e5cd6dcb31fa759b9831223d4719f61126367cff)
and [`257c26d` on main](https://github.com/doctorhetfield-cmd/simpleui.koplugin/tree/257c26d6685ced4fc2e895f98287b5f16f1d4f5e).

## Validation

`python tests/test_and_render.py` includes the exporter and game-save regressions.
`python tests/test_simpleui_assets.py` rebuilds and compares the packed assets,
decodes all 4,632 mood entries, checks size, grayscale and transparency, and
writes `tests/rendered/simpleui-moods.png` for inspection. Existing sprite
attribution and licences in `pokepal.koplugin/SPRITE-*` apply to these derivatives.
Regenerate the pack with `python tools/build_simpleui_assets.py`.

The real KOReader suite also runs the export regressions. In an unpacked
KOReader Linux v2026.07.1 runtime, the upstream test uses SimpleUI's actual
asset discovery, PNG decoder, sprite cache and complete critter row:

```sh
KO_HOME="$(mktemp -d)" SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software \
./luajit /path/to/PokePal/tests/test_simpleui_runtime.lua \
  /path/to/PokePal/pokepal.koplugin /path/to/simpleui.koplugin \
  /tmp/simpleui-preview.png
```

Physical Kindle testing is still needed for home-screen return after a partner
change, quick-settings reuse on newer SimpleUI builds, suspend/unlock ordering,
e-ink refresh/ghosting, and interruption by USB storage mode or power loss.
The desktop checks do not establish those hardware behaviors.
