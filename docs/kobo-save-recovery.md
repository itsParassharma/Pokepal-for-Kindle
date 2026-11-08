# Kobo save loading: preserve the files first

Applies to PokePal 1.2.0 and the save-loading investigation of 7 November 2026.
The exact message `Could not read the save; existing files were left unchanged`
does not prove corruption. It can also mean an empty file, a directory where a
file should be, a broken link, or a file access/read failure.

## For the affected reader

1. Exit KOReader completely. Before another update, reinstall, or recovery
   attempt, connect the Kobo by USB and copy its **whole KOReader settings
   folder** to a computer. Keep one untouched copy and a separate working copy.
   Show hidden folders if needed. The usual location is
   `.adds/koreader/settings`; installations with a custom `KO_HOME` may differ.
   Saves are outside `plugins/pokepal.koplugin`.
2. Keep **every file and folder beginning with `pokepal.dat`**, including empty
   files, `.old`, `.tmp`, `.old.tmp`, `.reading*`, `.backup*`, `.before-restore*`,
   `.before-story*`, and `.restore*`. Keep the installed plugin and KOReader log
   too if available. If copying fails, record the exact error and stop changes
   to the source until it has been preserved.
3. Report the Kobo model, KOReader and PokePal versions, whether the manual
   update helped, the settings location, and the names/types/sizes of those
   files. A directory named `pokepal.dat` is different from a regular file.
   Share only the relevant error lines initially; logs and saves can contain
   personal information.
4. Do not delete the main file or `.old`, create a replacement game, rename a
   backup over the main file, or downgrade yet. Launching PokePal after a
   successful load normally saves immediately, so preserve copies first.

## What can be recovered

| Candidate | How to assess it | Progress implications |
| --- | --- | --- |
| `pokepal.dat` | Read the copied bytes and validate with this build's `storage.decode(data, engine)`. | If valid, fix access or the selected settings path first; the save itself may contain all progress. |
| `pokepal.dat.old` | Validate separately with `storage.decode`. | The last retained valid snapshot, not necessarily the latest progress. Current PokePal already tries it automatically. |
| `.backup`, `.before-restore`, `.before-story`, and each `.old` | Validate with `backups:decode` or inspect via `backups:preview` on the working copy. | These wrap a game and its reading counter together. Compare their recorded times and contents. A pre-story backup deliberately predates Story progress. |
| `.tmp` and `.old.tmp` | Validate separately as raw game data; do not promote automatically. | They may hold an interrupted newer save, but may instead be partial or stale. |
| Backup `.tmp` files and `.restore*` | Inspect using the backup decoder, retaining all originals. | A pending restore is a transaction record, not proof that it is the newest game. |
| `.reading*` | Preserve alongside the game and inspect on a copy. | They contain reading totals/dates, not the whole game. |

A valid `.old` or manual backup can recover only the progress it contains.
There is no guarantee that the latest progress exists in a recoverable file.
A zero-byte file contains no game data, but its other snapshots may still help.
File modification times alone do not establish which candidate is best.

## Controlled recovery after validation

- If the current save is valid, keep its bytes intact and resolve the actual
  file access/path problem. Check the real settings directory, regular-file
  type, readable storage, and correct USB disconnection. Do not apply blanket
  permission changes or treat a plugin replacement as a save repair.
- If the primary is readable but invalid/empty, and `.old` validates, PokePal
  can normally load that snapshot. Agree to any loss since that snapshot before
  opening the live copy. Retain the original current file off-device.
- When only a wrapped backup validates, use a matching PokePal build and its
  paired game/counter restore procedure after testing on the working copy.
  **Do not rename `.backup` to `pokepal.dat`**: their formats differ. The in-app
  Backups menu is unavailable when opening the game fails, so this case needs
  maintainer-assisted recovery on copies first, not starting a new game just
  to reach the menu.
- Inspect any `.restore` record before a trial launch. Startup runs pending
  restore recovery before normal loading and may write both game and counter.
  Read-only inspection means decoding bytes or previewing backups; do not call
  `storage.open`, `backups:recover`, `backups:restore`, or `storage.save` on the
  only copy during diagnosis.
- After a candidate has been validated, agree on the chosen snapshot, test the
  paired result on an isolated copy, and only then replace live files while
  KOReader is fully closed. Keep the untouched original folder so the operation
  can be undone. If all candidates fail, retain them for further investigation.

## Save-read safeguards

The storage change distinguishes missing files from I/O failures, reports the
failing path and OS error, treats empty files as existing data, and refuses to
overwrite a primary or automatic snapshot that cannot be read. It does not
repair file permissions, damaged storage, or missing bytes. A transient read
failure no longer silently selects an older game. Readable invalid saves can
still recover from a valid `.old`.

This is a safeguard and diagnostic fix. It has not been tested on the affected
Kobo.
