# DOINK

## [v0.16.0](https://github.com/ryan-flan/DOINK/tree/v0.16.0) (2026-11-04)
[Full Changelog](https://github.com/ryan-flan/DOINK/compare/v0.15.0...v0.16.0) 

- build: release v0.16.0  
    Addon and companion both ship: the first release under the split  
    scheme, carrying the new update checker to every installed companion.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- docs: describe split releases  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- ci: release addon and companion independently on one tag namespace  
    A vX.Y.Z tag ships the addon when the TOC version equals X.Y.Z and the  
    companion when companion/VERSION does, either or both. Releases without  
    the companion are not marked Latest, which the installed updaters poll.  
    Workflow tokens are read-only except for the release job.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- feat(companion): find the newest companion release in the release list  
    The update check used releases/latest and treated every tag as a  
    companion version. It now reads the 20 newest releases and takes the  
    first one that carries DOINK-<tag>.zip and its checksum, so addon-only  
    releases never show as a companion update.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- build(companion): version the companion from companion/VERSION  
    The release workflow ships the companion only when this file equals  
    the tag, so the addon can release on its own without flagging a  
    companion update.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- docs: reload and rejection rules for the companion  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- refactor(companion): small idiom cleanups  
    Exit 0 on -h, accept ptb/canary Discord webhook hosts, stop shadowing  
    the sync package name in the screenshot decoder, and drop dead code.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- fix(companion): stop re-rotating doink.log after a failed rename  
    If something holds the old log open, rotation is retried after another  
    megabyte instead of on every line.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- fix(companion): apply the 14-day screenshot filter to folders that appear later  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- fix(companion): warn about unknown config.toml keys  
    A typo like webhook-url used to be ignored without a word.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- fix(companion): warn when state.json can't be saved  
    A silent save failure meant every restart re-posted the backlog with  
    nothing in the log. The first failure (and each new one) is now a  
    warning.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- fix(companion): skip embeds Discord rejects instead of retrying forever  
    An HTTP 400 means the message itself is wrong, and retrying it blocked  
    every later event of that character behind it. Such a batch is now  
    logged and dropped. Titles, descriptions, field values and footers are  
    also clipped to Discord's limits so a long name can't cause one.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- fix(companion): keep start-up-only settings across a live reload  
    dry\_run, wowhead, update\_check and update\_notify are consumed when the  
    companion starts; a live edit used to half-apply (the log said  
    "printed" while posts still went out). They now keep their start-up  
    value and a warning says to restart.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- docs: record the lint tooling and repo settings  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- docs: security policy, contributing guide, issue and PR templates  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- ci: luacheck for the addon  
    The whitelist in .luacheckrc is every WoW API the addon reads; anything  
    else luacheck flags is a bug.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- ci: lint, race tests and govulncheck  
    gofmt, go mod tidy, golangci-lint and the race detector on Linux; vet  
    then test on Windows as separate steps; govulncheck on push and  
    weekly. Least-privilege token, concurrency and timeouts.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- refactor(companion): satisfy golangci-lint  
    Wrap errors with %w, compare sentinel errors with errors.Is, stop  
    shadowing max/new, and mark best-effort file cleanups as such.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- ci: dependabot for Go modules and actions  
    Weekly, grouped into one PR per ecosystem.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- build(companion): require go 1.26 and unpin x/sys  
    Go 1.23 is out of support; x/sys was held at v0.35.0 only because  
    later releases need a newer Go.  
    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>  
- docs: describe WowUp Hub publishing  
    Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>  
- ci: attach the addon zip to GitHub releases for WowUp Hub  
    WowUp Hub lists addons from GitHub releases and needs a zip with the  
    addon folder at its root. The release now also carries the packager's  
    addon-only zip and release.json. A failed store upload no longer blocks  
    the GitHub release the companion self-update depends on.  
    Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>  
