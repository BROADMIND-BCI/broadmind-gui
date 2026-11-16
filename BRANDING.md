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

The restyle **builds** with Processing 4 and the bundled libraries. It has **not** been run against
real hardware, and the visual result has not been reviewed by a designer on every screen. Treat the
first pass as a brand application to review, not a finished redesign.

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
