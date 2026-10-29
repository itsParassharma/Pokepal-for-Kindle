PokePal now has a town to explore between reading sessions. Tap **Explore** to start in Fern Town, then pick up where you left off on later visits.

- Walk through the meadow, Fern Woods, Coast and Moon Cave. Pokémon are visible on the map, so you can approach a battle or walk past it. Small quests open shortcuts and give you berries, outfits and decorations.
- Start with your chosen Pokémon and build a party of up to six. Empty slots stay empty. The Centre's PC keeps your collection, with search, type filters, favourites, nicknames and an “In party” marker.
- Weaken a wild Pokémon or win its encounter, then offer three berries to befriend it. New friends go to the box unless you add them to an empty party slot. All 386 species can appear across the four wild areas.
- Equip two moves and respond to the opponent's next action. Voluntary switching uses a turn; replacing a fainted Pokémon is free. Trainers bring as many Pokémon as you do and draw fresh teams for rematches. Your party stays saved.
- Challenge three Gym leaders to earn badges and open routes and services. The Battle Tower has five trainers and a boss, with a choice of temporary benefits between fights. Turns and Tower progress are saved.
- Spend berries on supplies, move lessons, recruitment, outfits, decorations and Tower entry. Healing, box storage, Gym challenges and dojo practice are free. Reading rewards, expeditions and the daily basket still provide berries, and playing stays separate from reading time.
- Explore uses Crystal maps and trainer artwork, rear-view battle sprites and four walking directions for all 386 Pokémon. The existing care animations remain available.

With [Bookshelf](https://github.com/AndyHazz/bookshelf.koplugin) 6.0 or later, your partner can sit on the KOReader home screen. Add **PokePal** in the layout editor and tap it to play. Wider spaces show its name, level, mood and care bars. Thanks to [AndyHazz](https://github.com/AndyHazz) for the module.

This release also fixes town messages overlapping controls, old messages following you into another screen, resting partners getting stuck after a battle, and incomplete home backgrounds after waking. Bookshelf widgets now release callbacks when closed, update together, and notice quick saves even when their size and timestamp match.

Back up your `pokepal` folder before updating. Opening Explore upgrades the save to version 8, which 1.0.9 cannot read. Update both editions if you use both, and restart KOReader after copying the files. Existing Explore battles keep their opponent, turn and HP during migration.

The box currently holds one of each species. Harbour town and mountain village are still planned. Automated checks passed, including 504 KOReader sleep/wake cycles, 14 Bookshelf regression checks and the standalone runtime; physical Kindle touch and e-ink behaviour still need testing.

Includes [PR #9](https://github.com/itsParassharma/Pokepal-for-Kindle/pull/9), [PR #10](https://github.com/itsParassharma/Pokepal-for-Kindle/pull/10) and [PR #11](https://github.com/itsParassharma/Pokepal-for-Kindle/pull/11).

Choose **PokePal-v1.1.0-kual.zip** for KUAL or **PokePal-v1.1.0-koreader.zip** for KOReader. The corresponding-source ZIP and SHA-256 checksums are included below.
