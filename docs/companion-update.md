# Companion update

Version 1.0.7 includes these companion features. New preferences start off. Existing saves load with their current partner, rewards and trips intact.

## Sleep screen

Turn on **More > Preferences > Sleeping partner screen**. Your partner appears asleep against your chosen background, with its nickname and egg. The preview uses a still frame. The screen stays still during sleep; continuous animation would keep waking the device.

KOReader shows it through its existing screensaver, including its normal wake and gesture-lock handling. Poweroff and reboot screens keep their usual behaviour.

The KUAL edition keeps the Kindle's normal sleep screen. It does not need a screensaver add-on. The sleeping-partner preview is still available inside PokePal.

**Rest when the device sleeps** is a separate preference. Energy recovers at the normal resting rate until wake. A partner already resting stays asleep; expeditions carry on. The KUAL power listener starts after you close PokePal. Open PokePal again after restarting the Kindle to start it for that session. The listener waits for sleep and wake events without a polling timer.

## Where to find things

| Improvement | What changed |
| --- | --- |
| 1. Sleeping partner | Static sleep scene and preview; KOReader uses its built-in screensaver. KUAL keeps the normal Kindle sleep screen. |
| 2. Auto-rest | Optional sleep/wake recovery. Repeated events cannot add energy twice. |
| 3. Fewer flashes | Ordinary KUAL navigation uses a non-flashing refresh. Opening, waking, manual refresh and periodic cleanup still flash. |
| 4. Startup | Your partner appears before the library scan finishes. Scans yield between batches and cache unchanged timing files. **Reading rewards > Check again** clears the cache. |
| 5. Drawing caches | The native renderer keeps bounded sprite and glyph caches. |
| 6. Smaller redraws | Native animation repaints the stage and scales only the dirty rectangle. The backdrop is reused. |
| 7. Journal tools | Search, type filters, favourites, recent encounters, evolution readiness and a shortcut to your partner. |
| 8. Home recap | A dismissible reading summary opens the full recap. |
| 9. Traits and berries | Journal entries show a trait. **More > Favourite berries** lets you try three berries. Finding a favourite adds one bond when feeding succeeds. |
| 10. Trail stories | Each new trip saves one of three events. Choose an outcome on return, or carry on with the usual rewards. |
| 11. Decorations | Resting partners use a placed cushion; awake partners spend time beside a plant or bookshelf. |
| 12. Books together | **More > Books together** records a title, partner and date after confirmation. KOReader can fill in the current title. |
| 13. Achievements | Eight new permanent badges for reading, hatching, exploring and caring. No streak penalties. |
| 14. Reading footer | An optional KOReader footer shows the partner's name and egg progress. Page events update it. |
| 15. Reading history | Eight weeks of dated KOReader sessions and separately labelled Kindle collection totals. |
| 16. Accessibility | Larger text, bolder labels, marked disabled controls and UTF-8 nicknames. The native font covers accented Latin, Greek and Cyrillic; unsupported glyphs use a replacement character. KOReader can use its own keyboard. |
| 17. Save writes | Identical game saves skip the file rewrite. Changed state still saves immediately through the existing atomic write path. |

Reading-dependent actions wait until the scan finishes. You can browse or exit while it runs. Interrupted scans do not move the Kindle reward baseline. Cache entries expire after an hour; recently modified files are always read again.

## Saves

Back up the whole `pokepal` folder before installing 1.0.7, and update both editions together. Older builds cannot read the new companion fields or dated reading counter. Backups now include those dates; older backups still restore.

Book memories are stored locally because you chose to save their titles. Reward tracking still uses hashed book identities, not titles or book text.

## A stock Kindle image appears briefly on sleep or wake

This reported transition is still unverified on the affected device. The
v1.0.8 crash fix does not establish that the image flicker is fixed.

In the KOReader edition, PokePal replaces the prepared sleep image before
KOReader displays it. It does not display the original image first, draw
directly to the Kindle framebuffer, or change the Kindle power service.
When **Sleeping partner screen** is off, rendering fails, or the event is
poweroff/reboot, the normal KOReader screen is retained. Regression checks
cover those handoffs, without simulating Kindle firmware timing.

KOReader's [screensaver](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/ui/screensaver.lua)
performs an e-ink cleanup refresh for image sleep screens.
Its [Kindle wake handler](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/device/kindle/device.lua)
also redraws after closing the screen because the native framework can repaint
during the transition. A brief black/white cleanup flash and a stock image
appearing are different symptoms. A native/custom-screen timing conflict is a
possible explanation for the latter, not a confirmed diagnosis of this report.

To isolate it on KOReader, keep the same sleep-screen and launcher settings:

1. Update PokePal and restart KOReader. Test power-button sleep and wake.
2. Turn **More > Preferences > Sleeping partner screen** off. PokePal's game
   and reading rewards remain available with KOReader's usual sleep screen.
3. Disable PokePal in KOReader's plugin management, restart, and repeat. If the
   transition remains, compare the launcher, KOReader and any separate
   screensaver add-on. If it occurs only with the partner screen, keep that
   option off until the device-specific interaction is understood.
4. Record the Kindle model, firmware, KOReader/PokePal versions, launcher,
   screensaver add-ons and whether the cover or power button triggered sleep.
   Include a video and the relevant KOReader log, with personal book paths removed.

The KUAL edition retains the system sleep screen and hands the display back to
the Kindle when the game exits for sleep. Another add-on's custom image is
outside PokePal's control. **Rest when the device sleeps** changes game state;
it does not replace that screen. There is no verified universal no-flash
workaround. Do not disable the power service or normal e-ink cleanup refreshes
to hide the symptom.

## Validation

The automated suite covers game rules, old-save loading, Unicode names, sleep/wake recovery, duplicate events, dated counters, interrupted writes, backup recovery, journal filters, reader hooks and screen layouts. The native smoke test checks drawing caches and partial redraws. Both the desktop test host and static ARM host build with Zig 0.13.0.

A physical Kindle check is still needed for touch alignment, ghosting, power events, KOReader's sleep screen and battery use. Desktop tests cannot establish those results.
