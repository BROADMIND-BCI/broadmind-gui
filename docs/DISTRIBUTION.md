# Building and shipping the standalone app

`tools/build-standalone.sh` produces a single `.app` that runs on a Mac with **no Processing
install and no repository checkout**. This document records what goes in it, how big it is, and
what has to be true before it can be handed to someone outside the company.

```bash
tools/build-standalone.sh                                   # /Applications/Processing.app
PROCESSING_APP=/path/to/Processing.app tools/build-standalone.sh
```

Output: `dist/BROADMIND GUI.app` — currently **673 MB**, ad-hoc signed.

---

## 1. What is inside

| Contents | Size | Why |
|---|---|---|
| `Resources/jdk` | 309 MB | Java 17 runtime (Eclipse Temurin). The app cannot run without it |
| `Resources/libraries` | 217 MB | The sketch libraries, **unmodified and replaceable** (see §4) |
| `Resources/sketch/data` | 134 MB | Images, fonts, audio files and sample EEG recordings the app loads |
| `Resources/java` | 10 MB | Processing runtime core + the serial/net mode libraries |
| `Resources/classes` | 2 MB | The compiled sketch |
| `Resources/LICENSES` | 152 KB | Every licence text, `THIRD-PARTY.md`, and the LGPL relink notice |

The bundle is read-only once installed. Everything the app *writes* — settings, console log,
recordings, screenshot captures — goes to `~/Documents/BROADMIND GUI/`, and the bundled `data/`
directory is exposed to the sketch through a symlink so nothing is written inside the bundle.

**Redirecting that:** set `BROADMIND_GUI_HOME` to move all written data elsewhere (used for sandbox
testing, and handy for keeping recordings on an external volume):

```bash
BROADMIND_GUI_HOME=/Volumes/EEG "BROADMIND GUI.app/Contents/MacOS/BROADMIND GUI"
```

---

## 2. Verifying that it is genuinely standalone

The build was tested with `Processing.app` **renamed away**, and it still reached
`Setup is complete` with zero exceptions:

```bash
mv .tools/Processing.app .tools/Processing.app.hidden
BROADMIND_GUI_HOME=/tmp/test "dist/BROADMIND GUI.app/Contents/MacOS/BROADMIND GUI"
# expect: BROADMIND GUI::Setup: Setup is complete!
mv .tools/Processing.app.hidden .tools/Processing.app
```

If that directory is missing, the app will hang in setup — so it is worth keeping this check in the
release routine.

---

## 3. Size reduction, if distribution matters

673 MB is the honest cost of shipping a Java runtime plus 217 MB of libraries.

- **`jlink`** the runtime to the modules the app uses (`java.base`, `java.desktop`, `java.logging`,
  `jdk.unsupported`, `java.naming`) — typically **309 MB → ~70 MB**. Removes ~240 MB.
- **Prune `data/`**: most of the 134 MB is audio and sample recordings. Shipping without the
  auditory-neurofeedback audio is possible if that widget is disabled.
- **Prune `libraries/`**: the sketch imports most of them, but `junit`/`hamcrest` are test-only and
  already excluded; anything else must be verified by compiling and running without it.

A ~350 MB bundle is realistic. Nothing here is done yet — the build is correctness-first.

---

## 4. Legal position

Full inventory and per-component obligations: [`packaging/THIRD-PARTY.md`](../packaging/THIRD-PARTY.md).
Summary of what the build already does:

- **LGPL components** (Processing core, controlP5, minim, grafica, oscP5) are shipped as
  **unmodified jars in a path the user can reach**, with licence texts, a written source offer, and
  instructions telling the user they may drop in their own build. That is what the LGPL requires for
  a combined executable.
- **The Processing IDE is not bundled** — only its runtime core. This matters: the IDE is GPL, and
  bundling it would impose GPL terms on the whole application.
- **Geometria is not included.** It is a commercial typeface; the app falls back to Arial.
- **Java runtime** is GPL v2 + Classpath Exception, which permits distribution with a proprietary
  application. Licence, Assembly Exception and additional notices are included.

### Not ready for public distribution as-is

Four jars inherited from upstream carry **no licence file** and their terms are unconfirmed:
`GifAnimation`, `udp`, `ssdp_client`, `openbci_gui_helpers`. `packaging/THIRD-PARTY.md` §2 lists
them. Until each is confirmed (or the dependency removed), this bundle is for **internal use only**.

Also outstanding: code signing and notarisation. The bundle is ad-hoc signed, so macOS will warn
recipients on first launch. A Developer ID certificate + `notarytool` is needed for clean distribution.

---

## 5. Release checklist

- [ ] `tools/verify-release.sh` passes
- [ ] Standalone bundle built and tested with `Processing.app` hidden (§2)
- [ ] Resolve or remove the four unverified libraries (§4)
- [ ] Apache `NOTICE` file aggregated for Apache-2.0 components
- [ ] Decide on Developer ID signing and notarisation
- [ ] Counsel review if this ships commercially
