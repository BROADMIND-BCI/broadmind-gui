# C0 baseline — Cyton over USB on macOS

What the Cyton path actually does in this build, what is verified and what is not, and the criteria
the hardware pass has to meet. Written at the start of the 0.3.0 cycle, before any hardware testing.

**Scope:** Cyton only, Apple Silicon only. The Ganglion is no longer offered in this build.

---

## 1. The stack, as shipped

| Layer | Version | Notes |
|---|---|---|
| Processing | 4.5.7 | builds the sketch, ships the runtime |
| Java | 17.0.20.1 (arm64) | Eclipse Temurin, bundled |
| BrainFlow | **5.13.3** | upgraded from 5.10.0 this cycle |
| BrainFlow macOS natives | universal (x86_64 + arm64) | `libBoardController.dylib`, `libDataHandler.dylib` |
| jSerialComm | 2.11.0 | aarch64 natives present |
| Platform | macOS 26.2, arm64 | the machine the build was verified on |

The BrainFlow upgrade carries the upstream Cyton fixes: impedance-check board configuration,
analog-read values, and impedance accuracy at low resistances. Those are exactly the areas that were
wrong in 5.10.0, so the upgrade is a prerequisite for hardware validation, not a nice-to-have.

## 2. How a Cyton connection works

1. The board's switch is set to **PC**, the FTDI dongle is plugged in.
2. macOS exposes the dongle as `/dev/cu.usbserial-XXXXXXXX` (Apple's built-in FTDI driver; a
   third-party FTDI VCP driver installed by the user can conflict and hold the port).
3. The GUI lists serial ports in the control panel (`ControlPanel.pde`, `serialList`); the chosen
   path is handed to `BoardCytonSerial(String serialPort)`.
4. `BoardBrainflow` puts it on `BrainFlowInputParams.serial_port` and BrainFlow's native
   `BoardShim` opens the device at 115200 8N1.
5. The board is started with the **`b`** command and stopped with **`s`**; while streaming it emits
   33-byte frames at 250 Hz: `0xA0`, sample number, 8 x 24-bit big-endian channels, 6 aux bytes,
   `0xC0`.
6. BrainFlow parses the frames; the sketch consumes the resulting samples.

**Documented divergence from the SDK contract (§2.3):** the contract specifies an 8-bit wrapping
sample number and gap accounting. The desktop GUI does **not** yet count gaps or replays for the
Cyton path — it relies on BrainFlow's own buffering. This is the first thing the emulator (C1) is
meant to expose, and C2 is where it either gets fixed or the contract gets amended.

## 3. Verified today (no hardware)

| Check | Result |
|---|---|
| Sketch compiles with BrainFlow 5.13.3 | ✅ |
| GUI starts, reaches `Setup is complete` | ✅ (release suite) |
| Synthetic and playback sources stream | ✅ (release suite) |
| BrainFlow natives load on arm64 | ✅ universal dylibs, arm64 slice used |
| Ganglion removed from the UI, BLE scan no longer runs | ✅ |
| Saved session pointing at Ganglion falls back with a message | ✅ |

## 4. Not verified — the actual hardware work

Nothing below has been tested against a physical Cyton. This is the gap C2 closes.

- port enumeration and naming on a real dongle
- connect, start, stop, and the resulting sample rate
- sample loss over a long session (target: **zero over 30 minutes**)
- unplug while streaming, and recovery after replug without restarting
- laptop sleep/wake with the board attached
- USB hub vs direct port
- two FTDI devices attached at once
- impedance check correctness (the reason for the BrainFlow upgrade)
- analog read values
- a third-party FTDI VCP driver already installed on the machine

## 5. Acceptance criteria

A Cyton session is considered supported when, on an Apple Silicon Mac:

1. plugging the dongle makes the port appear in the GUI within a few seconds, named recognisably;
2. selecting it and pressing **Start Session** streams 8 channels at 250 Hz;
3. a 30-minute session loses **zero** samples, measured by the frame counter, not by eye;
4. unplugging mid-stream reports the loss and stops cleanly; replugging recovers without a restart;
5. sleep/wake recovers, or the failure is explicit and documented;
6. a CSV and an EDF from the session load back with the expected channel count, rate and duration;
7. the impedance check returns plausible values against a known resistor;
8. all of the above with a second FTDI device attached.

## 6. Known risks

| Risk | Why it matters | Mitigation |
|---|---|---|
| FTDI VCP driver conflict | port busy / no data, with a generic error | detect a VCP kext and say so |
| BrainFlow owns the port | our own serial probing must never open the same device | single owner rule |
| Sleep/wake | native handle survives but the radio/USB path does not | explicit reconnect, not assumed |
| Apple Silicon only | an Intel Mac fails with a raw JVM error today | launch guard (C3) |
| No notarisation yet | Gatekeeper friction outside Homebrew | C4, last step |

## 7. C1 — emulator status

Built and in the tree:

| Piece | What it does |
|---|---|
| `tools/cyton-emulator.py` | PTY-backed Cyton: answers `v`/`b`/`s` and streams real 33-byte frames at 250 Hz |
| `--self-test` | validates framing (length, start/stop, sample number, 8 channels round-trip, wrap, rate maths) — 8 checks, passes anywhere |
| `BROADMIND_CYTON_PORT` | `initSystem()` pins the serial device and forces serial protocol, so the GUI can be pointed at any device |
| `BROADMIND_TEST_CYTON` | harness mode: selects Cyton, presses Start Session, prints `BROADMIND TEST: cyton streaming OK` |
| `tools/run-cyton-emulator.sh` | one command: starts the emulator, passes the port to the GUI, tails the logs |

### Result of the first end-to-end runs

The runs were executed with elevated sandbox permissions (PTY creation is blocked otherwise). What
they established:

| Step | Result |
|---|---|
| PTY creation and the GUI opening `/dev/ttys001` | ✅ works |
| `BROADMIND_CYTON_PORT` pinning + harness auto-start | ✅ works (`cyton session requested`) |
| BrainFlow opens the device | ✅ `opening port /dev/ttys001` |
| BrainFlow sends the version probe | ✅ `sending v to the board` |
| Emulator answers the probe | ✅ `EMULATOR VERSION sent` |
| BrainFlow parses the answer | ❌ fails silently, then `BOARD_NOT_READY_ERROR` |
| `b` (start streaming) is sent | ❌ never reached |

**Two real bugs were found and fixed on the way:** the PTY initially echoed frames back as commands
(fixed by putting the pair in raw mode), and the port pinning originally ran inside `initSystem()`,
after `initButtonPressed()` had already rejected the session for having no transfer protocol (fixed by
moving it into the button handler).

**Remaining blocker, precisely stated:** BrainFlow's `prepare_session` for `CYTON_BOARD` sends `v`
and then gives up with `BOARD_NOT_READY`, whatever we answer. A sweep of reply variants —
`v3.1.2\n`, `3.1.2\n`, `v3.0.0\n`, `OpenBCI\n`, bare newline, and a continuously streaming board —
all produce the identical failure, so the version string is **not** the gate. BrainFlow never sends
`b`, so it gives up before the streaming handshake.

The next step is a capture from a physical dongle: what it emits **on connection** (before any
command), what it answers to `v`, and whether BrainFlow sends anything else we never observe. That
needs the hardware, so C1 and C2 converge here. Until then the emulator proves the GUI-side
plumbing (port pinning, harness, raw framing) but cannot stand in for a board.

Everything else in the harness works, so once the handshake string is known the emulator run is a
one-line change.

## 8. Next

- **C2** — hardware pass against your board, using the acceptance criteria in §5, plus the C1
  emulator run on a machine where PTYs are available.
