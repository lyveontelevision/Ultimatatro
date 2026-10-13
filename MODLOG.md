# Mod log

## Intake
- Project: new Balatro × Overwatch 2 mashup; solo first playable.
- Host: Balatro (LÖVE), using its established Lovely + Steamodded mod route.
- Companion: player's Overwatch 2 copy. Do not launch or modify the online client.
- Design: select a hero Joker deck; use hero signature abilities as scoring effects; boss blinds are short encounters and pay a mission reward.
- Publishing: MIT for original code; remix allowed. Third-party licenses kept with their files.

## Recon
- Balatro is installed at `C:\Program Files (x86)\Steam\steamapps\common\Balatro`.
- Overwatch 2 is installed at `C:\Program Files (x86)\Overwatch` (Battle.net root with `.build.info` and `data`).
- DataTool 2.25.0.0 reads this local Overwatch build 2.25.0.0.154088; hero and ability metadata and ability icons were extracted locally for the prototype. Extraction did not launch Overwatch 2.
- Universal Modder repository cloned in `work/universal-modder`; Balatro knowledge base confirms Lovely 0.10.0 and Steamodded support.
- Route: Steamodded plugin in Balatro, with locally generated Overwatch ability metadata/icons read from the player's own install by the bundled DataTool. Do not ship the extracted output.

## Build journal
- The user's installed Overwatch build exposes 54 heroes: 23 Damage, 16 Support, and 15 Tank. Setup now enumerates every hero and extracts their ultimate metadata and icon.
- Six hand-tuned Joker effects remain; the rest receive role-themed effects. Every hero gets a Joker and matching starting deck.
- Added 2x icon assets and normalized the Windows asset path after resolving the user's startup crash.
- Hero metadata is stored as `heroes.data` inside the mod to keep the loader from treating it as a mod manifest.
- Version 0.3.0 adds varied role effects across Chips, Mult, XMult, and money rewards; rarity and shop cost vary from Common to Rare.
- Version 0.4.0 adds the Hero Check boss blind and makes D.Va, Tracer, Winston, Reinhardt, and Bastion Legendary with boosted abilities.
- Version 0.5.0 adds D.Va's last-hand Self-Destruct, hero-count scaling for selected Support Jokers, and Echo's expanded Blueprint-style copying.
- Version 0.6.0 briefly added a local Mauga voice callout; this feature has been removed in 0.8.0 after it caused audio startup errors.
- Version 0.7.0 replaces role templates with hero-specific, ultimate-inspired abilities and adds 25% scaling for Tank and Damage Jokers alongside Support scaling.
- Version 0.8.0 renames the displayed mod title to Ultimatatro, adds role-themed Eternal squad decks, three Hero Pack sizes, and three additional themed Boss Blinds.
- Version 0.9.0 makes the All-Stars squad start with five Eternal Negative Heroes, adds a balanced Role Queue Deck, and adds the No Limits five-card Boss Blind.
