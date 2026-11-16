# Starter page — design

Replaces the bare "System Control Panel" list as the first thing a user sees. The point is that
the device arrives before the software does: show what to put on, then how to connect it, then let
them start.

Files:

| File | What it is |
|---|---|
| `starter-page.html` | The animation, self-contained. Open it in a browser. |
| `starter-1.png` … `starter-4.png` | Frames of the same sequence, for review and for docs. |

---

## 1. Structure

Two columns on a 16:10 stage. A 1px rule at `x=96` separates them.

**Left, fixed:** kicker (`01 — SET UP`), a serif headline in sentence case, two lines of body copy
in text grey, three progress dots, and one ink CTA.

**Right, the schematic:** a head in profile, facing right, drawn only in outline — 2.4px ink for the
silhouette, 1.8px for secondary geometry. Over it, the device: a band following the skull with
**eight contacts**, because that is what the hardware has and the number is a specification, not
decoration.

Line only, no fills except ink. That is deliberate: it matches the brand's restraint, it survives
being printed, and it cannot drift from the palette.

---

## 2. The sequence (9 s, loops)

| Time | State | What moves |
|---|---|---|
| 0.0–2.0 s | **Put it on** | The band sits above the head at 35% opacity and lowers 34px onto it. |
| 2.0–3.0 s | **Contact** | The eight contacts ink in, left to right. |
| 4.0–6.0 s | **Connect** | The cable draws itself (`stroke-dashoffset`) from the band into the laptop. |
| 5.0 s | | The machine fades up. |
| 6.0 s onwards | **Ready** | Everything settles; the CTA is the only affordance. |

Captions move with the states:

1. `01 — PUT IT ON` / **Put the headset on.** / Eight dry contacts settle on CP1, CP2, C3, C4, CP5, CP6, FT7 and FT8.
2. `02 — CONTACT` / **Let it settle.** / No gel, no paste. The band finds its own pressure against the skull.
3. `03 — CONNECT` / **Connect the cable.** / USB-C to the machine you record on. Battery only: no mains in the recording path.
4. `READY` / **Start recording.** / The device is on and connected. Every sample at full rate, saved where you point it.

Motion is one thing at a time, ease-in-out, nothing bounces. If a step cannot be understood from a
still, the animation is not doing its job.

---

## 3. Brand compliance

- Ink `#000000` and paper `#FFFFFF` only; rules in `#D5D5D5`; secondary copy in `#595959`. Text grey is
  never a fill.
- Square corners on the CTA and the machine. No gradients, no shadows, no second colour.
- Sentence case; the kicker is the only uppercase text.
- The logotype is not redrawn. When the mark appears it is the supplied file.

---

## 4. Porting it into the GUI

The schematic is plain geometry, so it survives into Processing without an image asset:

1. Add the paths to a `StarterPage.pde` tab as `beginShape()` / `bezierVertex()` calls, one function
   per state, so the silhouette is code rather than a PNG.
2. Drive it from `millis()` with a single normalised clock (`t = (millis() - start) % 9000`), then
   `lerp()` the band's offset for the first two seconds. One clock, not four animations.
3. Contacts: draw the circle, then `fill(INK)` once `t > 2600 + i * 60`.
4. Cable: approximate `stroke-dashoffset` by drawing the flattened path only up to `t` of its length —
   `bezierPoint()` + a partial polyline is enough at 60fps.
5. The CTA becomes the existing `START SESSION` button; keep the real control-panel list one step
   behind it ("Choose a data source") rather than on the same screen.

The four numbers a reviewer will actually check are Arial/Geometria sizing, the rule position, the
contact count and the cable path — everything else can move.
