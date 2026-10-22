# Next features

Reading expeditions would be the best next addition. PokePal already has three routes, encounters and rewards; the new reading counter could move your partner along a trail as you read. Existing timed trips should keep working until they finish.

| Idea | What it adds | What it needs |
| --- | --- | --- |
| Reading expeditions | Your partner covers a little more ground after each reading session. | Store the reading total when a trip starts, then use its increase for progress. Keep current route rewards. |
| Eggs that hatch as you read | A surprise partner after a few hours of reading. | One egg slot, a clear progress bar and a saved hatch result so reopening cannot reroll it. Reuse the existing Pokémon roster. |
| A weekly reading goal | A small bonus for a goal you choose, with no penalty for missed days. | A weekly total and one claimed-reward flag. Award it on the next visit, without notifications or background timers. |
| Backup and restore buttons | Recover progress without hunting for save files. | Back up the game and reading counter together. Preview the partner and date before restoring, and keep the replaced save. |
| A finished-book journal | Remember books you finished with each partner. | Reliable book identifiers and a completion event, with a manual confirmation when unavailable. |

The first four ideas can use the shared save and reading totals already in 1.0.5. They do not need another tracker or more sprite downloads. Eggs would add the most pet-game character; expeditions would fit the existing game with less new code.

Book completion needs more work. KOReader exposes a book summary status, but the [Kindle read-state investigation](https://github.com/zevisvei/kindle-reading-dashboard/blob/main/docs/read-state-storage.md) found firmware-dependent storage and temporary event records. Reaching the last page alone should not award a completion bonus.

