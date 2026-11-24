# Mobile app — plan

The companion app for the BROADMIND Research Kit: discover the device, subscribe to its stream,
inspect what is actually arriving, and ship it somewhere. Developer-facing first, not a consumer
wellness app.

This plan is built around three inputs: the [engine contract](ENGINE-CONTRACT.md) (what every client
must compute identically), the [BLE plan](../broadmind-pr/sdk/BLE-DEVELOPMENT-PLAN.md) (the wire
protocol and its open workstreams), and the "stream is the product" design (three screens, counters
before charts).

---

## 1. What the app is

The design brief puts it sharply: **developers judge a device on what is in the frame, how late it
arrives, and how fast it is running.** So the app leads with counters and a packet inspector, and
treats "copy a working snippet" as the primary action — not a documentation link.

Three screens:

| Screen | Content | The point |
|---|---|---|
| **01 · Device & services** | Discovered devices, signal strength, firmware, service tree with DATA / CONTROL / STATUS / INFO characteristics, MTU, pair & read, simulated device toggle | *Say what a client can address* — no invented fifth characteristic; the tree shows the draft, labelled as a draft |
| **02 · Stream inspector** | Sequence / dropped / latency counters above the payload; last frames as table, JSON and CSV; waveform below | *Three counters and a table* — drops are reported, not hidden; the rule "dropped-but-reported beats a clean-looking lie" |
| **03 · Build & keys** | Provisioning key, quickstart snippet (from `broadmind` import `Moosket`), endpoints with GET/PUT, bundled sample data | *Four lines to a first frame* — scopes visible where the key is minted; host endpoints as slots until the API is fixed |

Two rules from the brief that shape the work:

- **No undocumented slots.** Where the spec is unknown, the UI says so rather than inventing a
  UUID or a byte count. That is a data-model requirement, not a copy decision.
- **Simulator is co-equal.** Every step must work without hardware, because that is how the SDK gets
  tried. The simulator is a first-class transport, not a debug toggle.

## 2. Architecture

One shared core, two thin shells. The engine rules live in `ENGINE-CONTRACT.md`; the mobile clients
must not re-derive them.

```
        ┌──────────────── shared core ────────────────┐
        │ transport iface · session/counters · DSP    │
        │ band power · export (CSV/EDF) · simulator   │
        └───────┬──────────────────────────┬──────────┘
        Android shell                 iOS shell
        (GATT, permissions)          (CoreBluetooth, background rules)
```

**Recommendation: Kotlin Multiplatform for the core and Compose Multiplatform for the UI**, with
platform BLE via `expect/actual` (Android `BluetoothGatt`, iOS CoreBluetooth through Swift interop).
Rationale: the shared parts are exactly the parts the contract pins — counters, gap accounting,
band power, export — and the three screens are lists, counters and a sparkline, which Compose MP
handles well. One implementation of the contract, not two.

**Decision point after M1:** if Compose iOS shows friction with the BLE callbacks or background
behaviour, keep the shared core and swap the iOS shell to SwiftUI. That costs ~1 extra week and does
not touch the core — which is the point of putting the contract in shared code.

## 3. Milestones

| # | Milestone | Deliverable | Effort |
|---|---|---|---|
| **M1** | Shared core + Android inspector | Transport iface, session/counters per contract §7, simulator transport, screens 01 and 02 on Android, CSV export | 4–5 wk |
| **M2** | iOS inspector | CoreBluetooth `expect/actual`, screens 01 and 02 on iOS, same counters and semantics | 4–5 wk |
| **M3** | Build & keys (03) | Provisioning key, snippet generation, endpoints (slots clearly labelled), bundled sample recording | 2–3 wk |
| **M4** | Real BLE transport | Freeze-candidate protocol v1: GATT service, DATA framing with sequence + CRC, batch sizing, connection parameters | 4–5 wk |
| **M5** | Ship | TestFlight + Play internal track, crash reporting, permissions and privacy copy, support notes | 2 wk |

**Total 16–20 weeks for one engineer**, or ~9–11 calendar weeks with two. M1–M3 need **no hardware**:
the simulator is the device. M4 is the only milestone that cannot start before the protocol is frozen
and needs hardware for characterisation.

### M1 detail — Shared core + Android inspector

The milestone that proves the architecture. Nothing here needs hardware: the simulator is the device.

**Shared core (Kotlin Multiplatform, commonMain)**

| Component | Contents | Definition of done |
|---|---|---|
| `Transport` | `start/stop/readAvailable(timeout)` per contract §1, complete frames only | unit tests with a fake transport |
| `FrameCodec` | 33-byte framing, 8 × int24 big-endian, 8-bit sample counter | passes the frozen `decode` vectors |
| `SessionTracker` | gap/replay/wrap accounting, saturation, stop summary (§7) | passes the frozen `events` vectors |
| `RingBuffer` | 5 s at 250 Hz, append/newest/all (§3) | passes the `ringbuffer` vectors |
| `BandPower` | Hann periodogram, δ θ α β γ, absolute µV² | passes the `bands` vectors within 1e-6 |
| `CsvExport` | tagged dialect (§6.1) | byte-identical to the `csv` vector |
| `SimulatorTransport` | deterministic 250 Hz source, scriptable drops/latency | drives every screen in CI |

**Android shell (Jetpack Compose)**

- **Screen 01 — Device & services.** Simulator device card; service tree with DATA / CONTROL /
  STATUS / INFO characteristics, each labelled `notify` / `read` / `write`; MTU and connection
  parameters shown; unknown fields render as explicit `draft` / `not shipping yet`, never a guess.
- **Screen 02 — Stream inspector.** Sequence / dropped / latency counters pinned above the payload;
  last frames as table, JSON and CSV tabs; waveform under the table; pause and copy.
- Permissions scaffolding (API 31+ `BLUETOOTH_SCAN`/`CONNECT`, scoped storage) even though the
  simulator needs none — the denial paths must exist before the real transport arrives.

**Explicitly not in M1:** real BLE, iOS, provisioning keys/endpoints (screen 03), EDF export.

**Exit criteria**

1. All shared-core vector tests green in CI (same JSON the desktop and Python reference use).
2. Android app runs screens 01–02 against the simulator with no hardware attached.
3. Counters match the desktop session tracker on the same synthetic drop pattern.
4. APK build reproducible in CI; no crash on rotation, backgrounding, or permission denial.

## 4. Acceptance criteria

Tied to the contract, so the mobile app and the desktop GUI can be diffed rather than eyeballed:

1. **Same numbers.** Decoding, µV conversion, band power and export match the golden vectors in
   `tests/vectors/engine_v1.json`; the shared core runs those vectors as unit tests in CI.
2. **Counters are honest.** Sequence gaps, drops and latency are computed the same way as the
   desktop session tracker, and a dropped frame is *reported*, not smoothed away.
3. **Simulator parity.** Every screen works with the simulator; CI runs the screens against it.
4. **No invented specs.** Unknown fields render as explicit "draft"/"not shipped" labels.
5. **Background behaviour is stated.** iOS background BLE is restricted; the app says what stops when
   it is backgrounded instead of silently truncating a recording.
6. **Copyable snippet.** The screen-03 snippet runs unmodified against the published SDK.

## 5. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Protocol not frozen (BLE plan v2, freeze candidate v1.0) | Rework in M4 | M1–M3 run on the simulator; only M4 touches real BLE |
| Compose Multiplatform on iOS | UI risk | Shared core + SwiftUI fallback (decision point after M1) |
| iOS background restrictions | Recordings stop when backgrounded | Document; foreground-only capture in v1 |
| Android permissions / storage scoping | Install friction | Target API 33+ scoped storage from the start |
| Two BLE stacks, one contract | Divergent behaviour | Counters and session events in the shared core only |
| No hardware during M1–M3 | Late surprises | M4 is a characterisation milestone with its own soak tests |

## 6. Open decisions

1. **Platform order** — Android first (proposed: faster iteration, no App Store review) or iOS first
   (the design mock is iPhone-framed)?
2. **UI stack** — Compose Multiplatform (proposed) or Flutter; both need native BLE anyway.
3. **Product scope** — developer inspector only, or does it grow a consumer "record my session" mode?
   The latter changes onboarding, export and support load considerably.
4. **App identity** — separate bundle ids from the desktop app, and whether both share the
   `broadmind.me` domain for universal links.

## 7. What exists already

- `ENGINE-CONTRACT.md` — the behavioural spec this app must implement
- `tests/vectors/engine_v1.json` — frozen vectors with a Python reference implementation passing them
- `tools/cyton-emulator.py` — the pattern the mobile simulator follows (real framing, scriptable)
- BLE wire protocol draft — `BLE-DEVELOPMENT-PLAN.md` §3, freeze candidate v1.0
