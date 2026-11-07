# Publish updates for your members

## One-time setup

1. Open https://github.com/kevintm1011/boink/settings/secrets/actions/new .
2. Create a repository secret named `DOINK_CHANNEL_WEBHOOK`, with your existing Discord webhook URL as its value. Do not commit the URL into a file.
3. Open **Actions → Release Triple K → Run workflow**, select `main`, and run it.
4. The workflow tests the code, builds both components, and publishes the member ZIP, the update ZIP and `update.json` as the latest release. Companion reads `https://github.com/kevintm1011/boink/releases/latest/download/update.json`.

The GitHub connection used to prepare this repository cannot set Actions secrets or dispatch workflows. Those two setup steps must be done by the repository owner. No release is published merely by pushing to main.

This repository and its release assets are public. Although the webhook is absent from source and masked in build logs, the channel credential is embedded in the distributed executable and can be extracted. An Actions secret does not hide it from recipients of the compiled app. Use a server-side relay if you later need to keep that credential private.

## Future versions

Edit the addon/Companion source, update both `companion/VERSION` and the Version line of `addon/DOINK/DOINK.toc` to the same higher X.Y.Z version, and update `RELEASE-NOTES.md`. Run the release workflow again, or push the matching `vX.Y.Z` tag. Existing releases are never overwritten. Members can then select **Update both**; keep WoW closed while installing. They only need to install an updater-enabled Companion manually once.

Local builds: install Go 1.26 and Python 3, set `DOINK_CHANNEL_WEBHOOK` privately in the process environment, and run `python scripts/build_release.py`. Output goes to `dist/`. The script generates SHA-256 from the finished update archive. Never put config.toml, state.json or SavedVariables into an update payload.

Before publishing, live-test a dungeon roster, a character-panel button click, and a Windows update from the prior version. Backups are retained beside the updated folders/executable. Rollback handles replacement/start failures, but a power loss or a crash after startup can require restoring those backups manually.

Content references checked November 7, 2026:
- https://worldofwarcraft.blizzard.com/en-us/news/24301455/ (nine new dungeons)
- https://worldofwarcraft.blizzard.com/en-gb/news/24315820/ (raids open December 9)
