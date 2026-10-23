You can now change your companion from Profile and choose any of the 160 Pokémon, including ones you haven't discovered. This release also fixes oversized text and overflowing buttons in KOReader.

### Choose any companion

- Open **Profile > Change companion > Choose from all 160 Pokémon** to browse the full list.
- Starting a new game offers the same full list alongside the eight quick starters.
- Tap a Pokémon to see its details, then confirm. Browsing or cancelling leaves your current companion alone.
- Each companion keeps its XP, bond and nickname when you switch. Wake your partner or finish its trip before changing companions.

### KOReader screen fix

Text was being scaled twice, which made labels too large and pushed them outside buttons. Font sizes now use KOReader's scaling once. Button labels are centred and kept within their padding, including with larger text, custom DPI and landscape layouts.

### More to do with your partner

- Optional rest when the Kindle sleeps. KOReader can also show a still scene of your sleeping partner on its sleep screen. KUAL keeps the Kindle's normal sleep screen.
- Search your journal, filter by type, save favourites and find recent encounters or companions ready to evolve.
- Discover traits and favourite berries, make choices during trail stories, and watch your partner settle beside a cushion, plant or bookshelf.
- Record books you've finished together under **More > Books together**. Titles are saved locally after you confirm.
- Eight new badges bring the total to 14. Reading rewards also have a home-screen recap, eight weeks of KOReader history and an optional footer showing your partner's name and egg progress.
- Larger text, stronger contrast and support for accented nicknames. The KUAL font supports accented Latin, Greek and Cyrillic; other characters may appear as a replacement symbol.

New preferences start off. See the [companion guide](https://github.com/itsParassharma/Pokepal-for-Kindle/blob/v1.0.7/docs/companion-update.md) for setup and edition differences.

### Less waiting and flashing

Your partner appears before the library scan finishes. Scans run in batches and reuse unchanged timing files. KUAL navigation uses fewer flashing refreshes, and its renderer reuses sprites and redraws smaller areas. Unchanged saves no longer rewrite the file; changes still save immediately.

### Install or update

Back up the whole `pokepal` folder on your Kindle before updating. If you only have an older save, also back up `extensions/pokepal/data` and KOReader's settings folder. Keep those saves when replacing app files. If you use both editions, update both: older builds cannot read the new save fields.

**KUAL:** Download and unzip **PokePal-v1.0.7-kual.zip**. Copy `extensions` onto the Kindle drive, next to `documents`. Merge folders and replace matching files. Eject, then open **KUAL > PokePal > Play PokePal**.

**KOReader:** Download and unzip **PokePal-v1.0.7-koreader.zip**. Merge `koreader` with the folder on your Kindle and replace matching files. Eject and restart KOReader, then open **Tools > More tools > PokePal**.

The downloads also include corresponding source and SHA-256 checksums. KUAL needs a jailbroken touchscreen Kindle; the KOReader edition needs KOReader installed.

Automated desktop checks cover game rules, saves, all 160 choices, touch dispatch and layouts. Physical Kindle checks are still needed for touch alignment, ghosting, sleep events and battery use.

Changes: [companion features #2](https://github.com/itsParassharma/Pokepal-for-Kindle/pull/2), [screen fix #3](https://github.com/itsParassharma/Pokepal-for-Kindle/pull/3), [choose any companion #4](https://github.com/itsParassharma/Pokepal-for-Kindle/pull/4). [Full comparison](https://github.com/itsParassharma/Pokepal-for-Kindle/compare/v1.0.6...v1.0.7).
