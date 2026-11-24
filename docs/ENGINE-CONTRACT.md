# Engine contract v1

The behavioural contract that every BROADMIND client must implement: the desktop GUI, the Android
client and the iOS client. It exists so that three implementations cannot drift apart in the places
users notice — units, filtering, band power and the files a recording turns into.

Scope is deliberately narrow. Everything about how a client *looks* is out of scope (§11).

**Status:** draft, Phase 0. The Python SDK (`broadmind-eeg`) is the reference implementation, and
`tests/test_engine_contract.py` pins it to the golden vectors in `tests/vectors/engine_v1.json`.

Pinned so far: framing, scaling, ring buffer, band power, CSV dialect, the session/event model and
the EDF layout (22 conformance tests). **Still to pin:** the BDF variant (§6.3), and the actual
filter coefficients for bandpass and notch — the DSP chain is specified but its numerical behaviour
is not yet frozen, which is the largest remaining gap for a port that must produce identical numbers.

---

## 1. Transport interface

A transport moves bytes. It does not parse, buffer, filter or scale.

| Member | Contract |
|---|---|
| `start()` | Begin acquisition. Idempotent. Returns once the link is open, not once data flows. Raises `TransportError` if the link cannot be opened. |
| `stop()` | Stop acquisition and release the link. Idempotent. Safe to call from any state. |
| `read_available(timeout_s)` | Return **complete frames only**, possibly an empty list. Must not block longer than `timeout_s` (0 = non-blocking). Never returns a partial frame. |
| `is_running` | True between a successful `start()` and any `stop()`, including while reconnecting. |

Rules that apply to every implementation:

1. **Framing is the transport's problem.** A transport may deliver arbitrary chunk boundaries
   (BLE notifications, serial reads of 1–4096 bytes, Web Bluetooth events). The layer above never
   sees a byte stream — only whole 33-byte packets (§2). Implementations use a small reassembly
   buffer with a hard cap; on overflow they drop the buffer and emit `ProtocolReset`.
2. **No silent sample duplication.** Reconnection may replay a frame already delivered; the
   sample-number rule (§2.3) is how the consumer detects it.
3. **Disconnect is an event, not an exception** (§8). `read_available` returns `[]` and the session
   layer learns about the loss.
4. **Backpressure:** if the consumer is slower than the source, the transport drops the *oldest*
   unread frames and counts them. It never blocks the radio thread indefinitely.

### 1.1 Transports in scope

| Transport | Platforms | Notes |
|---|---|---|
| `serial` | macOS, Windows, Linux | Cyton via FTDI. 115200 baud, 8N1. |
| `ble` | macOS, Windows, Linux, **iOS, Android** | BroadMind GATT service; see `BLE-DEVELOPMENT-PLAN.md` §3. |
| `playback` | all desktop | Replays a recording file at the original rate. |
| `synthetic` | all | Deterministic test signal; used by CI and the starter screen. |
| `websocket` | all | External streaming source (`STREAMING`). |

`serial` is **not** available on iOS at all, and on Android only over USB-OTG. A client that cannot
provide a transport must say so and hide the option; it must not offer it and fail later.

---

## 2. Framing

One packet = one sample across all 8 channels.

| Byte | Field | Value |
|---|---|---|
| 0 | start | `0xA0` |
| 1 | sample number | 0–255, wraps |
| 2–25 | 8 × 24-bit signed channel value, big-endian two's complement | ADC counts |
| 26–31 | auxiliary (6 bytes) | accelerometer / other, transport-dependent |
| 32 | stop | `0xC0` |

Total length **33 bytes**.

### 2.1 Channel order

Device channel order, unchanged to the file. Labels are presentation; the array order is the
contract. Default montage for the Research Kit is CP1, CP2, C3, C4, CP5, CP6, FT7, FT8
(`broadmind.montage`).

### 2.2 Counts → microvolts

```
factor = VREF / (gain * (2**(bits-1) - 1)) * 1e6     # µV per count
µV     = counts * factor
```

Defaults: `VREF = 4.5 V`, `bits = 24`.

**Gain is not optional and must be explicit.** It differs by kit and getting it wrong scales every
number a researcher publishes:

| Source | Gain | µV/count |
|---|---|---|
| BroadMind Research Kit (default) | 5 | 0.1070 |
| OpenBCI Cyton, documented default | 24 | 0.0223 |

Any value ≥ 2^23 saturates; saturated samples are clamped, not wrapped, and counted (§8).

### 2.3 Sample numbering and loss

`sample_number` increments by one per packet and wraps at 256. A gap of `n` means `n-1` samples were
lost; a repeat of the previous number means a replayed frame and must be dropped. Counters are
reported per session (§8). The BLE transport carries an extended 32-bit sequence in its own header;
the desktop serial path relies on the 8-bit field.

---

## 3. Ring buffer

A fixed-capacity, multi-channel, sample-major store at the client's native rate (250 Hz).

| Member | Contract |
|---|---|
| `append(block)` | `block` is `(channels, samples)` in µV. Appends in order; overflow discards the oldest samples, never partial blocks silently. |
| `newest(n)` | The last `n` samples as `(channels, n)`, oldest-first. Short input returns what exists. |
| `all()` | Everything currently held, oldest-first. |
| `total_appended` | Monotonic count of samples ever appended (not affected by overflow). |

Capacity: **5 s at 250 Hz = 1250 samples** for display, plus whatever the DSP window needs. The
client must state its capacity; a 2 s buffer and a 10 s buffer are both valid, silently truncating
is not.

Threading: `append` is called from the acquisition thread, readers from the render thread. An
implementation may lock, or may hand out immutable snapshots — it must not tear.

---

## 4. DSP chain

Order is fixed: **scale → bandpass → notch → (analysis)**. Filtering happens on µV, never on counts.

### 4.1 Bandpass

Butterworth IIR, SOS form, per-channel state, applied forward only (no zero-phase pass — that would
double latency and cannot run in real time).

Defaults, and the recommended presets:

| Preset | Low | High | Order | Use |
|---|---|---|---|---|
| `eeg` (default) | 1.0 Hz | 40.0 Hz | 4 | general EEG |
| `raw` | — | — | — | no filtering; exports stay raw |
| `slow` | 0.5 Hz | 15.0 Hz | 4 | sleep, slow cortical |

The GUI exposes order and type per channel (BrainFlow `DataFilter`); the SDK applies the preset
above. **A recording's metadata must record the filter settings applied** — the data is already
filtered, and the file cannot recover it.

### 4.2 Notch

50 Hz or 60 Hz IIR notch, order 4, per channel, off by default. The mains frequency is a site
property, not a device property: record it in metadata.

### 4.3 Spectral analysis (band power, FFT display)

- One-sided periodogram, per channel, mean removed.
- Window: **Hann**, length 256 samples (1.024 s at 250 Hz), 50 % overlap when computed continuously.
- Bands (inclusive low, exclusive high): delta 0.5–4, theta 4–8, alpha 8–13, beta 13–30, gamma 30–45 Hz.
- Band power is **absolute µV²**, integrated over the bins in the band, and is the number written to
  files. Relative power is derived, never stored.

**Known divergence, must be resolved before v1 is frozen.** The GUI computes its FFT with a
**Hamming** window (`DataProcessing.pde`), the SDK with **Hann** (`broadmind.features`). For a pure
tone the difference in band power is small (single-digit %), for broadband EEG it is not
negligible. Decision for v1: **Hann everywhere**, GUI to be changed; until then any GUI band-power
number is provisional. This is recorded rather than hidden because a researcher comparing the two
clients will hit it.

---

## 5. Artefact labels

Labels describe data; they never modify it.

- Detectors: blink, jaw clench. Thresholds are per kit and must be frozen per kit type (§ `artifacts.py`).
- Each label has an onset, a duration, a type and a confidence.
- A label is exported as a **marker column** (`csv`) or as EDF annotations; the samples themselves
  are untouched, so a user can ignore our labels entirely.
- Detector settings travel in metadata (`thresholds`, `detector version`) — a label with no
  threshold record is not reproducible.

---

## 6. Recording formats

Three writers are in scope. All carry units in the header, not by convention.

### 6.1 CSV — tagged, the archival text format (SDK)

```
# BROADMIND CSV v1
# meta: {"sampling_rate":250.0,"channel_names":[...], ...}
time_s,CP1,CP2,C3,C4,CP5,CP6,FT7,FT8,marker
0.000000000,-12.5,...
```

- `time_s` relative to the first sample, 9 decimals.
- Channel values in µV, 9 decimals.
- `marker` = 0 or an artefact code; codes are stable (§5).
- The `# meta:` line is required for a lossless round-trip; a plain CSV still loads with names from
  the header.

### 6.2 CSV — GUI legacy (ODF)

The desktop GUI writes a different dialect: a `%Board = …` first line, comma-space separated columns
(note the trailing space), and a formatted timestamp as the **last** column. It remains supported for
reading; new files should use §6.1. A client that only reads §6.1 is conformant; one that cannot read
§6.2 loses existing users' archives, so the desktop maintains both.

### 6.3 EDF

- `data_record_duration` default 1.0 s → 250 samples per record at 250 Hz.
- Physical range derived per channel from the data, so quantisation is ≈0.001–0.01 µV; the range is
  recorded in the header.
- Annotations carry artefacts; the EDF `+` variant.
- EDF is the interchange format for MNE/EEGLAB; BDF (24-bit) is written by the GUI for the same
  audience and is read into the same model.

### 6.4 JSON

Metadata plus optional data; the round-trip format for tooling. Not for large recordings.

---

## 7. Session model

States, and the only legal transitions:

```
idle → connecting → streaming ⇄ paused → stopping → idle
                        ↘ lost → reconnecting → streaming | idle
```

| Event | When | Payload |
|---|---|---|
| `SessionStarted` | after first packet | transport, gain, fs, channels, filter settings |
| `SessionStopped` | user stop, normal | duration, samples, bytes |
| `TransportLost` | disconnect or silence > 2 s | reason, last sample number |
| `TransportReconnected` | link back | gap estimate |
| `ProtocolReset` | framing lost, buffer dropped | bytes discarded |
| `SamplesDropped` | overflow or gaps | count |
| `Saturation` | clamped samples | per-channel count |

The event stream is how the UI, the logger and the file writer stay consistent: all three consume
the same events, so a dropped sample is reported once and written once.

---

## 8. Platform capabilities and permissions

| Capability | macOS | Windows | Linux | iOS | Android |
|---|---|---|---|---|---|
| BLE | ✅ | ✅ | ✅ | ✅ | ✅ |
| USB serial | ✅ | ✅ | ✅ | ❌ | ⚠️ OTG only |
| Filesystem export | ✅ | ✅ | ✅ | ⚠️ document picker | ⚠️ scoped storage |
| Background streaming | ⚠️ | ✅ | ✅ | ⚠️ limited | ⚠️ foreground service |

Permissions each client must request and handle denial for:

- **iOS:** `NSBluetoothAlwaysUsageDescription`; background mode only if streaming in background is claimed.
- **Android:** `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (API 31+), `FOREGROUND_SERVICE` for long recordings.
- **macOS:** Bluetooth (TCC), and the app must be signed/notarised or the TCC grant does not persist.
- **All:** write access to the recording directory; never assume the app bundle is writable.

A client that cannot satisfy a capability hides the feature. It never presents a control that fails.

---

## 9. Conformance

The vectors live in the SDK at `tests/vectors/engine_v1.json`, generated by
`tools/make_engine_vectors.py` from the reference implementation and then **frozen** — the generator
is not run in CI.

| Vector set | Pins |
|---|---|
| `decode` | byte layout, sample numbers, aux, error cases |
| `scaling` | µV per count at gain 5 and 24, saturation clamp |
| `ringbuffer` | ordering, overflow, `newest(n)` short-read |
| `bands` | band power of a known tone, per band |
| `csv` | header lines and first rows of §6.1 |
| `events` | gap/replay/wrap counting, saturation accounting, stop summary (§7) |
| `edf` | record layout, physical ranges, padding, read-back values (§6.3) |
| `bdf` | 24-bit variant — **pending**, written by the GUI only |

The vectors are generated by `tools/make_engine_vectors.py`, committed, and frozen: the generator
is **not** run in CI, so a behaviour change has to be a deliberate edit to the vectors. Every vector
that pins a computed number also carries an analytic value to check against — the band-power vector
asserts that a 10 Hz tone of amplitude A yields exactly A²/2 µV² in alpha, which is the same answer
from physics rather than from our code.

Filters are the next thing to freeze: a port that implements a Butterworth bandpass with a
different topology or initial condition will match every vector above and still show different
waveforms. That gap is deliberate in draft v1 — it is called out here rather than left implicit.

A port is conformant when its output matches every vector within the stated tolerance:
`1e-9` for time axis, `1e-6` relative for band power, exact for integers and identifiers.

---

## 10. What the mobile clients must share

The point of the contract is the parts a user would notice as "different app":

1. Same µV numbers for the same bytes.
2. Same band definitions and the same window.
3. Same CSV dialect as the SDK (not the GUI's legacy text).
4. Same marker codes.
5. Same gain recorded in metadata.

Everything else — widgets, layout, animation, even which panels exist — is free.

---

## 11. Non-goals

Explicitly **not** in this contract:

- **UI and rendering.** No widget set, layout, colour, animation or typography. The starter-page
  schematic, the brand palette and the control panel are desktop presentation decisions.
- **Packaging and distribution.** Bundles, notarisation, installers, Homebrew.
- **Networking adapters.** LSL, UDP, OSC and the WebSocket source wrap samples after this layer;
  they are not part of the engine and may not alter its numbers.
- **Hardware.** Firmware, radio parameters, the bridge rule (`BLE-DEVELOPMENT-PLAN.md` §2.2).
- **Storage policy.** Where recordings are placed, retention, sync, cloud.
- **Exact UI strings.** Labels are free; identifiers (`transport="ble"`, band names, marker codes,
  CSV tags) are not.

Anything that wants to be shared between clients and is not listed here should be added to this
document before it is implemented twice.
