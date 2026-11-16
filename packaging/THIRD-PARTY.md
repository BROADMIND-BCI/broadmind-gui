# Third-party components in the BROADMIND GUI standalone bundle

Inventory of everything redistributed inside `BROADMIND GUI.app`, with the licence that governs it
and what that licence obliges us to do. **Status** says whether the licence has been verified from
the component's own source, or is still unconfirmed.

Verified on 16 November 2026. This is an engineering inventory, not legal advice.

## 1. Components we ship

| Component | Version | Licence | Status | Obligation |
|---|---|---|---|---|
| BROADMIND GUI (this fork) | 0.2.2 | MIT | ✅ ours | Ship `LICENSE` |
| OpenBCI GUI (upstream) | `d8543aa` | MIT | ✅ `LICENSE` in repo | Attribution, ship `LICENSE` |
| Processing core | 4.5.7 | LGPL 2.1 | ✅ stated in source headers | Ship LGPL 2.1 text; keep replaceable; source offer |
| Eclipse Temurin JDK | 17.0.20.1 | GPL v2 + Classpath Exception | ✅ `legal/java.base/LICENSE` | Ship licence + Assembly Exception |
| controlP5 | 2.3.6 | LGPL 2.1 or later | ✅ source headers | Ship LGPL 2.1 text |
| minim | 3.x | LGPL 3.0 | ✅ `libraries/minim/license.txt` | Ship LGPL 3.0 text; source offer |
| grafica | — | LGPL | ✅ project README | Ship LGPL text |
| oscP5 | — | LGPL 3.0 | ✅ project licence page | Ship LGPL 3.0 text |
| BrainFlow | 5.10.0 | MIT | ✅ `META-INF/LICENSE` in jar | Attribution |
| jSerialComm | 2.11.0 | Apache 2.0 | ✅ Maven POM | Ship Apache 2.0 + NOTICE |
| Apache HttpComponents | 4.1.2 | Apache 2.0 | ✅ `META-INF/LICENSE.txt` in jar | Ship Apache 2.0 + NOTICE |
| ProcessingSansPro (font) | — | OEM font licence | ✅ text inside core jar | Ship font licence text |

## 2. Components shipped but **licence not yet verified**

These four jars come from the upstream OpenBCI GUI bundle and carry no licence file. They are
included because the sketch imports them. **Do not distribute this bundle publicly until each is
confirmed** — or the feature that needs it is removed.

| Component | Used for | Action needed |
|---|---|---|
| `GifAnimation` | animated loading indicators | Find upstream licence (extrapixel). Its `GIFEncoder`/`GIFDecoder` are by Kevin Weiner with separate notices. |
| `udp` | UDP networking widget | Find upstream licence |
| `ssdp_client` | network device discovery | Find upstream licence |
| `openbci_gui_helpers` | OpenBCI helper classes | Confirm MIT with OpenBCI |

Also worth confirming: **JOGL / GlueGen** (bundled inside Processing's core library) are BSD-2/3
clause upstream; the jars here are Processing's build and should be treated as BSD.

## 3. What we deliberately do **not** ship

- **Geometria** (commercial typeface). Not in the source tree, not in any bundle. The app falls back
  to Arial, per the brand guidelines. See `BRANDING.md` §1.
- **The Processing IDE** (GPL). Only the runtime core library is redistributed; the IDE is not
  needed to run the app. This matters: bundling the IDE would impose GPL terms on the whole bundle.
- **JUnit / Hamcrest** — test-only, excluded from the bundle.

## 4. LGPL obligations, and how this bundle meets them

The LGPL components (Processing core, controlP5, minim, grafica, oscP5) are redistributed as
**unmodified jars in a directory the user can access**:

```
BROADMIND GUI.app/Contents/Resources/libraries/<component>/library/<component>.jar
```

That satisfies the "work that uses the library" route of LGPL §4/§6 for a combined executable, on
the following conditions, all met here:

1. **Licence texts are included** in `Contents/Resources/LICENSES/`.
2. **The user is told the libraries are replaceable** — this file, plus `README-LGPL.txt` in the
   bundle, explains that dropping a rebuilt jar in the same path replaces the component.
3. **Source is offered.** LGPL requires that the corresponding source be available. We ship the
   libraries unmodified, so the source is the upstream release of each component; the offer and
   URLs are in `README-LGPL.txt`.
4. **No warranty is added on their behalf.**

## 5. Before public distribution — checklist

- [ ] Resolve the four unverified libraries in §2 (or remove the dependency)
- [ ] Confirm JOGL/GlueGen licence text is included via Processing's build
- [ ] Add an Apache `NOTICE` file aggregating the Apache-2.0 attributions
- [ ] Decide on code signing and notarisation (currently ad-hoc signed only)
- [ ] Have counsel review this bundle if it ships commercially
