# DOINK - Triple K

Private Discord-channel edition of [DOINK](https://github.com/ryan-flan/DOINK), by Ryan Flanagan (MIT). Windows Companion + WoW Forever addon.

## Install once

Download `DOINK-Triple-K-X.Y.Z.zip` from this repository's **Releases**. Close WoW and the Companion. Place the `DOINK` folder inside `_forever_/Interface/AddOns/`. Put the Companion in a writable folder outside Program Files and run `DOINK - Triple K.exe`. Existing members: keep your config.toml and state.json; replace the executable and addon files. Never delete DOINKDB/SavedVariables.

The Discord channel and `kevintm1011/boink` update source are built in. Open Companion settings, **Check for updates**, then **Update both** with WoW closed. First-run discovery requires logging into WoW with the addon enabled, then logging out to write SavedVariables. Updates verify SHA-256, stage both components and retain rollback backups. Existing settings and character progress are preserved. Installation does not run unattended.

## Achievements in 0.19.0

Open the journal with the gold achievement button on the right edge of the character panel, or `/doink achievements`.

- Level achievements stay in the journal; no duplicate achievement announcements.
- Playtime includes 100, 250, 500 and 1,000 hours, alongside the existing milestones.
- Collect 10 distinct mounts; learn 300 base Unarmed skill (the level-60 cap, not the lower level-dependent cap).
- Full-clear entries for the 19 original dungeon locations and nine new Forever dungeons. Separate wings combine into their parent location.
- Barrow Deeps, Hyjal Summit and Onyxia's Lair are listed as upcoming (December 9, 2026).
- Sharing is opt-in, with category and screenshot controls. Old progress discovered on sync is not posted.

Full clears require a successful encounter event for **every boss in the complete client-provided encounter roster**. Kills persist across visits; arriving at an already-cleared lockout does not count. With missing client encounter data the journal says **Awaiting complete client boss roster** and does not guess. New Forever encounter coverage needs live validation; English instance-name matching is used for new dungeons, with map-ID matching for original instances. These are custom achievements, not Blizzard account achievements. Historical boss kills before this version cannot reliably be backfilled.

The mount journal is authoritative where available. On item-based clients, distinct mount item IDs observed in bags or loot are remembered; duplicate items do not add to the total. Previously owned banked mounts need to be moved into bags to be discovered. Playtime uses `/played` and does not accrue while offline.

## Maintainer setup

See [release instructions](docs/TRIPLE-K-RELEASES.md). The update source is configured, but the first GitHub release must be published before online update checks have a feed to read.

Automated tests run in GitHub Actions. The addon UI and Windows replacement/restart flow still require live game and Windows validation.
