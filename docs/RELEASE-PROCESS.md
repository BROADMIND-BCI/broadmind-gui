# Release process and version control

How a BROADMIND GUI version is identified, built, published and verified — and the traps this
project has already fallen into. Written after a cleanup that removed a working install and broke
the app, so the next session does not repeat it.

---

## 1. One source of truth per artifact

| Artifact | Canonical location | Never do this |
|---|---|---|
| **Source** | `BROADMIND-BCI/broadmind-gui`, branch **`main`** | keep build output in the repo (`dist/` is gitignored) |
| **Version string** | `BROADMIND_GUI/BROADMIND_GUI.pde` → `localGUIVersionString` | hardcode a version anywhere else |
| **Bundle version** | derived by `tools/build-standalone.sh` from the sketch string | edit `Info.plist` by hand |
| **Release** | GitHub release + tag `v<version>-alpha.N` / `-beta.N` | delete a release that a cask may still point at |
| **Install recipe** | `packaging/homebrew/Casks/broadmind-gui.rb` **and** the tap repo `BROADMIND-BCI/homebrew-broadmind-gui` | let the two copies drift |
| **Landing page** | `docs/site/gui/index.html` (source of truth) → deployed to `broadmind.me/gui/` | edit the live page only |
| **Install docs** | `README.md`, page, tap README, release notes | update one and not the others |
| **Installed app** | exactly one: `/Applications/BROADMIND GUI.app` | keep `dist/`, `dmg-stage/` or downloaded copies around |

Current release: **v0.3.0-alpha.1**, cask version `0.3.0`, sha256 `dfb1b872…`.

## 2. Version scheme

- Sketch string: `v0.3.0-alpha.1` (drives window title, splash, bundle version "0.3.0 Alpha1")
- Cask: `version "0.3.0"` — the pre-release suffix lives only in the tag (`v#{version}-alpha.1`)
- Release title: "BROADMIND GUI 0.3.0 Alpha — Cyton over USB"
- README/CHANGELOG heading: `0.3.0 Alpha — November 2026`

**Alpha** while interfaces, file formats or supported hardware can still change. **Beta** only when
the feature set is frozen for the next release. Never label the same build both ways — the repository
was squashed on 24 Nov partly because two labels (beta, then alpha) existed for one build.

## 3. Release checklist

```bash
# 1. version + notes
#    edit BROADMIND_GUI/BROADMIND_GUI.pde (localGUIVersionString)
#    edit CHANGELOG.md and the README header

# 2. verify before shipping
PROCESSING_APP="/path/to/Processing.app" ./tools/verify-release.sh    # must end READY (19/19)

# 3. build the bundle and the disk image
PROCESSING_APP=… ./tools/build-standalone.sh
STAGE=$(mktemp -d); cp -R "dist/BROADMIND GUI.app" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "BROADMIND GUI" -srcfolder "$STAGE" -ov -format UDZO \
  /tmp/BROADMIND-GUI-<version>.dmg
hdiutil verify /tmp/BROADMIND-GUI-<version>.dmg
shasum -a 256 /tmp/BROADMIND-GUI-<version>.dmg

# 4. publish — asset name MUST be BROADMIND-GUI-<version>.dmg (the cask builds that exact name)
gh release create "v<version>-alpha.N" /tmp/BROADMIND-GUI-<version>.dmg \
  --repo BROADMIND-BCI/broadmind-gui --title "…" --notes "…install, sha256…"
gh release edit "v<version>-alpha.N" --repo BROADMIND-BCI/broadmind-gui --latest

# 5. cask — both copies
#    version, sha256, url …/v#{version}-alpha.N/BROADMIND-GUI-#{version}.dmg
git -C <tap clone> commit -am "…" && git push

# 6. docs + page, then deploy
tar -czf - -C docs/site gui | tools/ssh-relay/wfssh.sh 'tar -xzf - -C ~/public_html/broadmind.me'
tools/cloudflare/purge-broadmind.sh          # full purge — per-URL purges do not work on this zone
```

## 4. Verification (run these, do not assume)

```bash
gh release view v<tag> --json assets --jq '.assets[] | "\(.name) \(.size)"'   # asset present, size
curl -sIL "https://github.com/BROADMIND-BCI/broadmind-gui/releases/download/v<tag>/BROADMIND-GUI-<version>.dmg" | grep -i content-length
gh api repos/BROADMIND-BCI/homebrew-broadmind-gui/contents/Casks/broadmind-gui.rb --jq .content | base64 -d | grep -E 'version|sha256|url'
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/BROADMIND GUI.app/Contents/Info.plist"
xattr -p com.apple.quarantine "/Applications/BROADMIND GUI.app"     # must print nothing
```

**Known-good baseline:** `v0.3.0-alpha.1` (tag) is the build that worked end-to-end on 23–27 Nov:
Cyton-only scope, BrainFlow 5.13.3, buffer pacer, readable controls. If a later build misbehaves,
compare against that tag before debugging.

## 5. Traps this project has already hit

| Trap | What happens | Rule |
|---|---|---|
| **Homebrew 7 trust** | `Refusing to load cask … from untrusted tap` | install recipe is `brew tap` → **`brew trust --tap`** → `brew install` |
| **Agent sandbox vs brew** | an automated session gets *Operation not permitted* writing `/opt/homebrew` or `~/Library/Caches/Homebrew`, which is the **sandbox**, not ownership. `brew info` still works, so verify state with read-only commands | run `brew install`/`reinstall`/`tap` yourself in a normal terminal. Only if *your* terminal also reports ownership problems does `sudo chown -R $(whoami) /opt/homebrew` apply |
| **Deleting the app bundle** | Caskroom entry is only a *symlink* to `/Applications/BROADMIND GUI.app`; deleting the bundle leaves brew "installed" but nothing to launch | delete only via `brew uninstall --cask`, never by hand |
| **Restoring from DMG by hand** | copy carries `com.apple.quarantine` → macOS **SIGKILLs** the app | `xattr -dr com.apple.quarantine` after any manual copy, or use `brew reinstall` |
| **Dangling data symlink** | `~/Documents/BROADMIND GUI/app/data` points into an old build; assets go missing and the UI half-loads | repoint to `/Applications/BROADMIND GUI.app/Contents/Resources/sketch/data`; launcher now repairs it (`cce2c5a7`) |
| **Deleting a release too early** | cached taps still point at the old tag → `curl: (56) 404` | keep the previous release for one cycle |
| **Asset name mismatch** | release asset named `…-alpha.dmg` while the cask expects `…-0.3.0.dmg` | always upload as `BROADMIND-GUI-<version>.dmg` |
| **Leftover build copies** | `dist/`, `dmg-stage/`, downloaded DMGs pile up as "multiple apps" | one app, in `/Applications`; repo keeps no binaries |
| **Per-URL Cloudflare purge** | returns success but the edge keeps serving old HTML | always full purge |
| **SSH relay flakiness** | long uploads truncate silently (`tar: Write error`) | upload to a side directory, verify sizes, then swap |
| **Repo recreated 24 Nov** | default branch is `main`, history squashed, fork link dropped | push to `main`; the fork lineage lives only in `PROVENANCE.md` |

## 6. Current state (2026-11-27)

- Release `v0.3.0-alpha.1` — Latest, asset 398,838,690 B, sha `dfb1b872…`
- Cask `0.3.0` in both repo and tap, pointing at the alpha tag
- `/Applications/BROADMIND GUI.app` — 0.3.0 Alpha1, quarantine clear
- Landing page: v0.3.0 alpha, safety section, BLE marked as coming
- Verified 2026-11-27: `brew info --cask broadmind-gui` → **0.3.0, installed, from the tap**;
  Caskroom symlink → `/Applications/BROADMIND GUI.app` (0.3.0 Alpha1, quarantine clear);
  Homebrew's cached DMG sha256 equals the cask sha256, so the tap is serving the right asset
- Open items: `~/Documents` data link should point at `/Applications` (currently resolved through a
  temporary shim in the repo folder), notarisation (deferred), BLE transport (in development)
