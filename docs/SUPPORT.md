# Support and documentation

Everything the application links to. These are BROADMIND pages first; where a detail genuinely lives
in upstream OpenBCI documentation, the upstream reference is marked as such.

## Getting started

1. Install: `brew tap broadmind-bci/broadmind-gui` → `brew trust --tap broadmind-bci/broadmind-gui`
   → `brew install --cask broadmind-gui` (see the [install section](../README.md#installing)).
2. Put the headset on, connect USB-C, press **START SESSION**.
3. Record to `~/Documents/BROADMIND GUI/Recordings`; export CSV, EDF or BDF from the session box.

Landing page: <https://broadmind.me/gui>

## Cyton connection

- The board's switch must be on **PC**; the FTDI dongle must be plugged into the Mac.
- macOS exposes the dongle as `/dev/cu.usbserial-…`. If no port appears, check the cable and that no
  other application holds the port.
- The reference for this build's Cyton behaviour, including **what has and has not been verified on
  hardware**, is [CYTON-BASELINE.md](CYTON-BASELINE.md).

## Impedance testing

The impedance check runs from the control panel once a Cyton session is open. It reports an estimate
derived from the channel RMS and the on-board lead-off drive current, minus the series resistor — it
is a plausibility check, not a calibrated measurement.

Upstream background (marked as upstream): the OpenBCI impedance guide at
<https://docs.openbci.com/Software/OpenBCISoftware/GUIDocs/#impedance-testing>.

## Troubleshooting

### Data looks "choppy"

This build paces the display at the nominal sample rate, so bursty USB arrival is smoothed for you.
If the trace still stutters:

- close other applications using the serial port;
- check for a **third-party FTDI VCP driver** — it conflicts with Apple's built-in driver and causes
  exactly this symptom;
- try a different USB port or a powered hub.

### The application does not open (macOS)

- If macOS says the app is damaged or blocked, it was downloaded directly rather than through
  Homebrew: run `xattr -dr com.apple.quarantine "/Applications/BROADMIND GUI.app"`, or reinstall with
  `brew reinstall --cask broadmind-gui`.
- Apple Silicon only: the bundled runtime is arm64. Intel Macs cannot run this build.

### Missing data / sample loss

- The status footer reports the data stream state; a dropped USB device stops the stream explicitly.
- Recordings live in `~/Documents/BROADMIND GUI/Recordings`. If the app cannot write there, macOS may
  be withholding Documents access — grant it in System Settings → Privacy & Security → Files and
  Folders.

Upstream background (marked as upstream): <https://docs.openbci.com/Troubleshooting/GUI_Troubleshooting/>

## Networking outputs

UDP, OSC, LSL and Serial outputs are configured in the **Networking** widget. Each output has its own
host/port; the widget also includes a local test receiver.

Upstream background (marked as upstream):
<https://docs.openbci.com/Software/OpenBCISoftware/GUIWidgets/#networking>

## Custom widgets

The widget framework is unchanged from the upstream GUI: copy `W_Template.pde`, add the class to the
widget list, and it appears in the widget menu.

Upstream background (marked as upstream):
<https://docs.openbci.com/Software/OpenBCISoftware/GUIWidgets/#custom-widget>

## Reporting a problem

- Bugs and feature requests: <https://github.com/BROADMIND-BCI/broadmind-gui/issues>
- Releases and changelog: <https://github.com/BROADMIND-BCI/broadmind-gui/releases>
- Hardware and kits: <https://broadmind.me>

When reporting a connection problem, include the macOS version, the app version (Help → the window
title shows it), the dongle port name, and whether the footer reported a stream stop.
