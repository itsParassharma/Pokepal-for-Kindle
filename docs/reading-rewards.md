# Reading rewards

Open PokePal once before you start reading. Return after a session to collect one berry and 3 XP for every 15 recorded minutes. Minutes from both readers add together, and unfinished quarters of an hour carry over. XP goes to your current partner, even while it is resting or exploring. Evolution still needs enough XP and bond.

Open **More > Reading rewards** to see recorded time, check which sources are available or turn rewards off. The daily berry basket is on the home screen.

PokePal opens on your pet, with a small recap you can tap or dismiss. **More > Reading rewards > Last visit** shows the minutes, rewards, expedition progress and egg progress collected on this visit. The recap may cover several reading sessions and stays available while PokePal is open.

## Weekly goals

Pick 60, 120 or 180 minutes under **More > Reading rewards > Weekly goal**. Reaching the target adds 5 berries and 10 XP once that week. You can change the target without losing progress or collecting a second bonus. There are no streaks or missed-day penalties.

Weeks start on Monday using the Kindle's clock. Minutes count in the week you collect them, so both readers use the same weekly goal rule. Starting a goal does not count earlier reading. Turning reading rewards off pauses goal progress too.

## Trips and eggs

Expeditions default to **On a timer**, which uses elapsed time. Choose **Explore > As you read** for a reading trip. Meadow takes 30 recorded minutes, Coast takes 120 and Moon Cave takes 240. Each keeps its usual energy cost, berries, XP and encounters. Trips already in progress keep their original timing.

New trips have three stops: a berry patch at 25%, footprints at 50% and a campsite at 75%. They give 1 berry, 3 XP and up to 8 energy, respectively. Each stop pays once, including after reopening. Older trips finish with their original rewards. New trips also save a short story with two choices. Make your choice on return, then collect; the extra reward is paid once.

An egg costs three berries and hatches after 120 recorded minutes. You can carry one at a time, including while resting or exploring. The egg's Pokémon is chosen when you pick it up and saved, with first forms you have not met favoured. Tap **Hatch your egg** when it is ready. The hatchling joins your journal; your current partner and its progress stay with you.

Only minutes recorded after starting the trip or picking up the egg count. The same minutes advance both and still earn the usual reading rewards. Turning rewards off pauses both reading goals. Extra minutes do not carry into the next egg or trip, but still count toward berries and XP. Nothing hatches or finishes a reading trip just because time has passed.

## Kindle's built-in reader

PokePal reads the cumulative `timer.model` counter in the book's `.sdr` folder. It checks `.azw3f`, `.yjf`, `.mbs`, `.tas` and `.pdt` files, covering several Kindle reader formats. A file extension alone does not guarantee that a usable counter exists.

The first successful scan establishes a starting point. Later visits credit increases. Copies and reader profiles with the same book-folder name share one counter. A new book can contribute time after that first scan, but imported time is limited to the interval since the last scan. Existing records are never edited.

Kindle's timer estimates reading speed and can miss reading intervals. A reset counter must pass its previous high value before earning more rewards, which prevents restored files from paying out twice. Renaming a book can change its identity. Synced or imported history cannot always be distinguished from local reading.

The parser accepts new object names and ignores their contents. It rejects unknown binary types, malformed records and oversized files. An unreadable library leaves its baseline untouched; KOReader rewards can still work. Scans are limited to 10,000 tracked books, 100,000 directory entries, 20 folder levels, 1 MiB per timing file and 64 MiB in total. Links are not followed.

## KOReader

Keep the PokePal plugin enabled. Its tracker uses page-turn, pause, sleep and document-close events, independently of KOReader's Reading statistics plugin. It counts page intervals of at least five seconds, with a two-minute limit per page. Sleep, reader pauses and visits to PokePal are excluded. Leaving a page open can still contribute up to two minutes; this is an estimate of activity.

Time is saved after at least a minute accumulates and when reading pauses or closes. Each bounded interval is split at midnight when needed, preserving the actual reading date. There is no polling timer. A crash can lose the current unsaved interval. Stored time is collected by either PokePal edition on the next visit.

## History and books

**Reading rewards > Reading history** keeps eight weeks of records. KOReader minutes appear on the day you read. Kindle totals appear on the day you collected them because the source counter has no session dates. Older KOReader totals still earn rewards but cannot fill in past dates.

**More > Books together** lets you remember a finished book with its title, partner and date. You confirm each entry. KOReader can suggest the current title; KUAL uses the on-screen keyboard. Memories do not award XP or berries.

**More > Preferences > Reading footer** adds the partner's name and egg progress to KOReader's footer. It updates with page events and can be turned off at any time.

The pet appears while the Kindle scan runs in batches. Unchanged timing files are cached for up to an hour; recently modified files are always read. Use **Reading rewards > Check again** to bypass the cache. Closing or suspending during a scan leaves the reward baseline unchanged.

## Saves and updates

Both editions use `/mnt/us/pokepal/`. `pokepal.dat` contains the game and credited counters; `pokepal.dat.reading` contains the KOReader total and recent daily counters. Each has a previous snapshot ending in `.old`. Back up this folder as a unit.

On first launch, PokePal copies the most recently used legacy save it finds. Original files remain in place. If KOReader lives in a custom folder, open its PokePal edition first to migrate that save. Separate old games are not merged. Use matching versions in both readers before switching between them. Older builds cannot read the new companion fields or dated reading counter, so back up the whole save folder before updating.

A process lock prevents both game windows from writing the save at once. Damaged saves are recovered from their previous snapshot or left alone if neither copy is readable. The reward ledger keeps filename hashes and counters. Book titles are stored only when you confirm a book memory; text and annotations are never copied. Nothing is uploaded.

**More > Backups** saves the game and KOReader counter in one file, `pokepal.dat.backup`. Before a restore, the current pair is kept in `pokepal.dat.before-restore`. Preview either one before confirming. A damaged backup can fall back to its previous complete copy, which is labelled in the preview list.

Restoring uses `pokepal.dat.restore` as a temporary record. If a write is interrupted, PokePal finishes the restore before loading a game on the next launch. KOReader leaves its pending reading time alone until that recovery finishes. If recovery cannot finish, the game stays closed and the files are kept. A backup on the Kindle does not protect against losing the device; copy the whole `pokepal` folder elsewhere too.

## Compatibility and validation

The format references below describe a 10th-generation Kindle on 5.18.1 and a Colorsoft on 5.19.6. Firmware 5.17.1 is a target, not a verified hardware result. PokePal detects records instead of assuming support from the model or firmware number.

Automated checks use synthetic KRDS fixtures based on those public format descriptions, plus reader-event simulations. They cover unknown fields, corrupt files, all five filename extensions, copied profiles, clock changes, counter rollback, repeated collection, save migration, write failures and pause/resume behavior. Native rendering and ARM compilation are checked separately. Physical Kindle tracking and touch calibration have not been verified.

Finished-book bonuses are not included. A completion flag is less consistent across firmware than the timing counter.

## References

- [KRDS format and device observations](https://github.com/zevisvei/kindle-reading-dashboard/blob/main/docs/KRDS-format.md)
- [Reading Log's timing limitations](https://github.com/huangziwei/readinglog/releases/tag/v0.3.2)
- [KOReader's reading statistics and lifecycle events](https://github.com/koreader/koreader/blob/master/plugins/statistics.koplugin/main.lua)
- [How Kindle stores read status](https://github.com/zevisvei/kindle-reading-dashboard/blob/main/docs/read-state-storage.md)

The PokePal parser and tracker are original Lua implementations. No code from these projects is bundled.
