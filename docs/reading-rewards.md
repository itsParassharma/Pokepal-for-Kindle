# Reading rewards

Open PokePal once before you start reading. Return after a session to collect one berry and 3 XP for every 15 recorded minutes. Minutes from both readers add together, and unfinished quarters of an hour carry over. XP goes to your current partner, even while it is resting or exploring. Evolution still needs enough XP and bond.

Use **More > Reading rewards** to see recorded time, check which sources are available or turn rewards off. Free daily berries are unchanged.

## Kindle's built-in reader

PokePal reads the cumulative `timer.model` counter in the book's `.sdr` folder. It checks `.azw3f`, `.yjf`, `.mbs`, `.tas` and `.pdt` files, covering several Kindle reader formats. A file extension alone does not guarantee that a usable counter exists.

The first successful scan establishes a starting point. Later visits credit increases. Copies and reader profiles with the same book-folder name share one counter. A new book can contribute time after that first scan, but imported time is limited to the interval since the last scan. Existing records are never edited.

Kindle's timer estimates reading speed and can miss reading intervals. A reset counter must pass its previous high value before earning more rewards, which prevents restored files from paying out twice. Renaming a book can change its identity. Synced or imported history cannot always be distinguished from local reading.

The parser accepts new object names and ignores their contents. It rejects unknown binary types, malformed records and oversized files. An unreadable library leaves its baseline untouched; KOReader rewards can still work. Scans are limited to 10,000 tracked books, 100,000 directory entries, 20 folder levels, 1 MiB per timing file and 64 MiB in total. Links are not followed.

## KOReader

Keep the PokePal plugin enabled. Its tracker uses page-turn, pause, sleep and document-close events, independently of KOReader's Reading statistics plugin. It counts page intervals of at least five seconds, with a two-minute limit per page. Sleep, reader pauses and visits to PokePal are excluded. Leaving a page open can still contribute up to two minutes; this is an estimate of activity.

Time is saved after at least a minute accumulates and when reading pauses or closes. There is no polling timer. A crash can lose the current unsaved interval. Stored time is collected by either PokePal edition on the next visit.

## Saves and updates

Both editions use `/mnt/us/pokepal/`. `pokepal.dat` contains the game and credited counters; `pokepal.dat.reading` contains the KOReader total. Each has a previous snapshot ending in `.old`. Back up this folder as a unit.

On first launch, PokePal copies the most recently used legacy save it finds. Original files remain in place. If KOReader lives in a custom folder, open its PokePal edition first to migrate that save. Separate old games are not merged. Install 1.0.5 in both readers before switching between them.

A process lock prevents both game windows from writing the save at once. Damaged saves are recovered from their previous snapshot or left alone if neither copy is readable. Book names, text and annotations are not written to the reward ledger; it keeps filename hashes and counters. Nothing is uploaded.

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
