# BROADMIND branding notes

This fork of [`OpenBCI/OpenBCI_GUI`](https://github.com/OpenBCI/OpenBCI_GUI) applies the
**BROADMIND brand guidelines, 2026-27 edition**. It is a visual and typographic restyle, not a
functional fork: no acquisition, protocol or board-support code was changed.

Upstream is MIT licensed and remains so — see [LICENSE](LICENSE). Every upstream author credit in
the source headers is untouched.

---

## 1. The rules being implemented

The guidelines allow **one mark, three colours, one typeface**. Nothing else is a brand colour.

| Token | Hex | Permitted use |
|---|---|---|
| Black | `#000000` | Ink, solid surfaces, primary text |
| White | `#FFFFFF` | Surfaces, text on black |
| Grey | `#D5D5D5` | Secondary surfaces, separators, inactive states |
| Text grey | `#595959` | Secondary text on white or grey — **never a fill** |

Contrast pairs that are allowed, from the guidelines: black on white (21:1), black on grey
(14.3:1), white on black (21:1), grey on black (14.3:1), text grey on white (7:1), text grey on
grey (4.8:1). **White on grey and grey on white are 1.5:1 and are forbidden for text.** The restyle
never produces either pairing.

Typeface: **Geometria**. Medium (500) for headings and labels, Light (300) for body copy.
Where a weight is missing, the guidelines fall back to Arial rather than to another family.

**Geometria is a commercially licensed typeface and is not distributed with this repository.**
The TTFs are not in git history either. Drop `Geometria-Medium.ttf` and `Geometria-Light.ttf`
into `OpenBCI_GUI/data/fonts/` if you hold a licence for the build you are shipping; without
them the sketch uses Arial, which is the documented brand fallback.

---

## 2. Where it is implemented

Everything routes through a small number of choke points, so a future brand revision is cheap.

| What | Where |
|---|---|
| Palette | `OpenBCI_GUI/OpenBCI_GUI.pde` — the `BM_GREY` / `BM_TEXT_GREY` block. The legacy `OPENBCI_*` names are re-pointed at brand values so the rest of the sketch compiles untouched. |
| Colour scheme default | `colorScheme = COLOR_SCHEME_DEFAULT` — white nav bar, black ink, grey sub-nav. |
| Typeface | `bmPFont()` in `OpenBCI_GUI.pde` — resolves Geometria from `data/fonts/` when the licensed files are present, Arial otherwise. Every `f1..f5`, `h1..h5`, `p0..p6` goes through it. |
| Splash | `introAnimation()` — black surface, white lockup, ratio preserved (2.25:1). |
| Top nav mark | `TopNav.pde` — mark height bounded by the 32 px bar, width derived from the asset ratio so it is never stretched. |
| Loading spinner | `data/broadmind-loader-ink.gif` — the upstream blue cog, recoloured to ink. |
| Window title | `BROADMIND GUI <version>`. |

The logo rules are followed literally: the supplied files are used as-is, at their own aspect
ratio. Nothing is stretched, rotated, recoloured, outlined, or given a shadow.

**The nav bar uses the mark, not the lockup.** A 32 px bar cannot carry a 2.25:1 lockup at a legible
size, and stretching it to the old 128x29 box would break the logo rule. The guidelines say *change
the layout, not the logo*, so the bar gets the mark and the lockup is used at full size on the
splash screen, where there is room for it.

---

## 3. Deliberate deviations

Three families of colour are **not** monochrome. Each is functional, not decorative, and each would
lose information if forced onto the brand ramp:

| Kept | Why |
|---|---|
| `channelColors[8]` | Encodes which trace is which. Eight greys would make the time-series and FFT plots unreadable, and channel identity is the point of those views. |
| `ACCEL_X/Y/Z_COLOR` | Same reason, for the accelerometer axes. |
| `BOLD_RED`, `SIGNAL_CHECK_*` | Error and signal-quality states. A monochrome error banner is indistinguishable from a neutral one in a tool used during a recording session. |

Everything that is *chrome* — bars, buttons, panels, borders, dropdowns, text, the splash, the
spinner — is strictly black / white / grey / text grey.

---

## 4. What was not restyled

- **Layout, spacing and control sizes.** Unchanged, deliberately: the goal was brand, and moving
  controls would need a design review that cannot be done from source alone.
- **Widget internals** (time series, FFT, head plot, focus, EMG). They draw with the brand palette
  now, but their individual compositions are upstream's.
- **Channel and electrode status hues** in `CytonElectrodeStatus.pde` — these encode impedance
  state.

---

## 5. Status

The restyle **builds and runs** with Processing 4. It has been run on macOS arm64, and both the
control panel and a live session are captured for [docs/screenshots](docs/screenshots) - the session
capture streams all eight channels from a bundled recording, so the waveforms are real. It has
**not** been run against real hardware.

Build:

```bash
# Processing 4.5.x, then either the PDE editor or:
processing-java --sketch="$PWD/OpenBCI_GUI" --build --force
```

---

## 6. Attribution

Forked from `OpenBCI/OpenBCI_GUI`, MIT. The BROADMIND mark and lockup are BROADMIND brand assets,
not covered by the upstream MIT licence; they are included because this build is BROADMIND's own
product — do not redistribute them separately. **Geometria is not included** (see §1): it is a
commercial license, and shipping it is a decision for whoever holds it.

---

## 7. Fixes applied on top of upstream

These are defects found by actually running the build, not by reading it.

### 7.1 The application died on startup on Apple Silicon

`libraries/LSLLink/library/jna.jar` bundled a JNA from 2018 whose `libjnidispatch.jnilib` is an
**i386 + x86_64 fat binary with no arm64 slice**. Because sketch libraries precede the Processing
runtime on the classpath, that stale copy won, and the app crashed on first use of native code:

```
UnsatisfiedLinkError: ... (fat file, but missing compatible architecture
(have 'i386,x86_64', need 'arm64e' or 'arm64e.v1' or 'arm64'))
A library used by this sketch relies on native code that is not available.
```

An unmodified upstream checkout at `d8543aa` fails the same way, so this is inherited, not caused by
the restyle. Fixed here by **removing the bundled JNA jars** (`LSLLink/library/` and
`LSLLink/bin/library/`), so the application uses Processing's own JNA 5.19.1, which ships a
`darwin-aarch64` native. Verify with:

```bash
file OpenBCI_GUI/libraries/*/library/jna.jar   # should not exist any more
```

### 7.2 Starting any session crashed on Apple Silicon too

`libraries/jSerialComm` bundled **jSerialComm 2.6.0 (2020)**, whose macOS native exists only for
`OSX/x86_64`. Enumerating serial ports - which happens when a session starts - threw:

```
UnsatisfiedLinkError: ... (macho file, but is an incompatible architecture
(have 'x86_64', need 'arm64e' or 'arm64e.v1' or 'arm64'))
```

Fixed by replacing it with **jSerialComm 2.11.0**, which ships `OSX/aarch64`. Check with:

```bash
unzip -l OpenBCI_GUI/libraries/jSerialComm/library/jSerialComm.jar | grep OSX
unzip -p OpenBCI_GUI/libraries/jSerialComm/library/jSerialComm.jar META-INF/MANIFEST.MF | grep Version
```

### 7.3 Visual defects introduced by the first palette pass, then fixed

| Defect | Cause | Fix |
|---|---|---|
| Entire workspace rendered black | `background(OPENBCI_DARKBLUE)` became black once that token was mapped to ink | `background(WHITE)` |
| "System Control Panel" and hovered rows were white-on-grey (1.5:1) | button hover/pressed backgrounds were mapped to the brand grey while their captions stayed white | hover `#595959` (6.4:1), pressed black (21:1) |
| Footer still sent people to `docs.openbci.com` | upstream help text | reads `BROADMIND GUI - broadmind.me` |
| "Shop" opened the OpenBCI store | upstream nav button | relabelled "Kit", opens `broadmind.me` |
| Selected data-source row and the 8/16-channel buttons became **solid black bars with no label** | the highlight used `TURN_ON_GREEN` (mapped to ink) while `MenuList` draws its items in ink, and black pressed buttons carried ink captions | list highlight is now the brand grey (ink on `#D5D5D5` = 14:1) |

The rule that came out of this: **the brand grey is a surface colour for dark text only. Any control
that draws white captions must sit on ink.**

### 7.4 One documented deviation from the palette

Active and selected button backgrounds are `#595959`, which the guidelines describe as *secondary
text on white or grey* and explicitly say should never fill a surface.

The reason is mechanical: controlP5 gives a button one caption colour for every state, and this
application has two button families - white captions on dark chrome, and ink captions on white
panels. No single active background gives both families an accessible pairing: ink forces a light
surface, white forces a dark one. `#595959` is the one value that clears 3:1 for both
(white 6.4:1, ink 3.9:1), so it is used as a functional state colour in the same spirit as the error
red, not as a brand colour. If the buttons were ever unified onto one caption colour, this could
become pure ink and the deviation would disappear.

### 7.5 Window and button style pass

The window frame is now one continuous ink band: the top navigation and the sub-navigation share
`BLACK`, with white ink on it (21:1). Previously the two rows were a white bar over a grey bar, which
read as two unrelated strips. The workspace beneath stays white, so the frame reads as a frame.

Button hierarchy:

| Role | Style |
|---|---|
| Chrome actions (top nav, sub-nav, collapsers) | ink fill, white label |
| Panel actions (`START SESSION`, channel count, streamer choices) | white fill, 1px ink border, ink label |
| State colour | `#595959` active surface - see §7.4 |

### 7.6 The "Start Data Stream" button was invisible

`createToggleDataStreamButton` was called with `TURN_ON_GREEN` as the fill and
`OPENBCI_DARKBLUE` as the label colour. Once both tokens resolved to ink, the button rendered as an
empty black rectangle. It now takes `WHITE` as the label colour.

That button is not cosmetic: `startRunning()` is called from exactly one place, its release handler.
A user who could not see it could start a session and get a frozen clock with every channel at
`0.00 uV`, which is indistinguishable from a broken instrument. Fixing the label is what made a live
session possible.

### 7.7 Version line, and the upstream update check

This build is **v0.2.0 Beta, November 2026**, its own version line. `guiVersionIsUpToDate()` compared
that against OpenBCI's latest release (6.0.0-beta.1) and therefore always reported "Update Available",
with a yellow banner pointing at a different product. The upstream check is now disabled and the
button reports the BROADMIND build instead. Re-enable it against this repository's own releases when
there are any.
