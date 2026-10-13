# Ultimatatro

Balatro is the playable host. Choose from one hero Joker and matching starting deck for every hero in the player's installed Overwatch 2 build. The local build currently exposes 54 heroes across Damage, Tank, and Support. Their signature ability names, descriptions, and icons are generated from the player's own game files. Their abilities add poker bonuses; boss blinds act as short team encounters, and clearing one pays a mission bonus.

Every hero has an individually authored poker effect based on their Overwatch ultimate, including hand leveling, Boss Blind shutdowns, and bonuses tied to specific hands and scoring cards. Support abilities scale by 25% per additional Hero Joker held; Damage and Tank abilities scale by 25% per additional same-role Joker. Rarities range from Common to Legendary, with costs scaled to rarity. D.Va, Tracer, Winston, Reinhardt, and Bastion are Legendary. Echo copies the Joker to her right, including Jokers that opt out of normal Blueprint copying. Five themed decks start with random Eternal Hero Jokers, including role-specific squads, a balanced one-per-role team, and an All-Stars deck whose five random Heroes are Eternal and Negative. Hero Packs offer three pack sizes and can contain Legendary heroes. Five themed Boss Blinds add face-card, first-hand, hand-size, five-card-hand, and Hero-Joker challenges. Every hero retains their own Overwatch signature ability text and extracted icon. Rerunning the setup after updating Overwatch automatically includes heroes in the new local build.

The first version is solo and uses no Overwatch 2 network session. It never launches or modifies Overwatch 2. The Overwatch reader runs before Balatro starts and writes extracted local data only to `%LOCALAPPDATA%\Ultatro`; no Overwatch files or assets are included in this project or release archive.

## Requirements

- Balatro (Steam), running through Lovely and Steamodded.
- The player's own Overwatch 2 installation.
- Windows 10 or later.

## Local development

Run `prepare-overwatch.ps1` with `-OverwatchPath` set to the player's Overwatch install root and `-OutputPath` set to a private local cache. Copy `heroes.json` as `data/heroes.data`, and copy the generated `assets` folder into the mod's `data` folder. Then install the mod in Balatro's `Mods` directory and launch through the existing Lovely/Steamodded setup. The setup writes icon files for both 1x and 2x texture scaling.

## Third-party components

- Steamodded, GPL-3.0-or-later, by the Steamodded contributors.
- DataTool / OWLib, MIT, by the OverTools contributors. It reads the player's local Overwatch 2 installation.
- json.lua, MIT, by rxi.

The public source does not bundle the DataTool toolchain, Overwatch 2 game files, extracted hero metadata, or extracted hero icons. To prepare a local install, provide a compatible DataTool executable or toolchain archive that you obtained separately; `prepare-overwatch.ps1` reads the player's own installation and generates the local cache.
