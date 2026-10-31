# Installing through KoStore

[KoStore](https://github.com/ThePixelPro366/KoStore) discovers repositories with
the GitHub topic `koreader-plugin`. Repository topics are set in GitHub's
**About > Edit** panel; a README keyword does not enable discovery. After the
topic is added, GitHub indexing and KoStore's cache may delay the listing.

Choose PokePal in KoStore's plugin browser, install it into your KOReader
directory, then restart KOReader and open **Tools > PokePal**. If it is not
listed yet, use the KOReader ZIP from the [latest release](https://github.com/itsParassharma/Pokepal-for-Kindle/releases/latest)
and copy `pokepal.koplugin` into your existing KOReader `plugins` directory.
The KUAL ZIP is a separate Kindle application and is not a KoStore plugin.

KoStore downloads the latest release's tagged source archive when a release
exists. That does not include features or fixes in an unmerged pull request.
Its installer finds the nested `pokepal.koplugin` folder and keeps that name;
the repository does not need renaming.

Close PokePal before updating and keep a backup. On Kindle, saves are in
`/mnt/us/pokepal`; elsewhere they are in KOReader's settings directory.
Those saves are outside the plugin folder replaced by the installer. Files
you manually add inside `pokepal.koplugin` may be replaced during an update.

## Compatibility check

The USB/local installer from [KoStore commit 8da6adc](https://github.com/ThePixelPro366/KoStore/blob/8da6adc4e4076e9816353b74c513d257e788a979/services/plugin_installer.py)
was exercised against both the actual v1.1.0 tagged source ZIP and the
v1.1.0 KOReader release ZIP, with fresh and repeat installations into isolated
folders. All four cases installed the same 827 plugin files as their archive
sources. Obsolete plugin files were removed on update. Fixture saves, reading
counters, backups, KOReader settings, another plugin and a custom SimpleUI
critter remained byte-for-byte unchanged.

This validates the package layout and local installer. It does not establish
live store search visibility, wireless installation, update notifications or
physical Kindle/Kobo behaviour.
