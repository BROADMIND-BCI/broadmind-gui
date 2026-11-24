#!/usr/bin/env python3
"""A Cyton board on a pseudo-terminal, for testing the GUI with no hardware.

Creates a PTY pair, prints the slave path, and speaks enough of the OpenBCI dongle protocol for
BrainFlow to open a CYTON_BOARD on it:

  'v'  -> firmware version string
  'b'  -> start streaming
  's'  -> stop streaming
  others -> logged and ignored

While streaming it emits real 33-byte frames at 250 Hz:
  0xA0 | sample number | 8 x 24-bit big-endian channels | 6 aux bytes | 0xC0

Usage:
    python3 tools/cyton-emulator.py                  # prints "EMULATOR PORT /dev/ttysNNN"
    python3 tools/cyton-emulator.py --channels 3 --signal sine

Then start the GUI with the port pinned:
    BROADMIND_CYTON_PORT=/dev/ttysNNN open "BROADMIND GUI.app"

The GUI reads BROADMIND_CYTON_PORT in initSystem() and forces serial + that path, which is what makes
the whole Cyton path testable without a dongle.
"""
from __future__ import annotations

import argparse
import math
import os
import pty
import select
import sys
import termios
import time
import tty

SAMPLE_RATE = 250.0
FRAME_INTERVAL = 1.0 / SAMPLE_RATE
START_BYTE = 0xA0
STOP_BYTE = 0xC0
DEFAULT_FW_VERSION = "v3.1.2\n"


def encode_frame(sample_number: int, channels: list[int]) -> bytes:
    body = b"".join(int(c).to_bytes(3, "big", signed=True) for c in channels)
    aux = b"\x00" * 6
    return bytes([START_BYTE, sample_number & 0xFF]) + body + aux + bytes([STOP_BYTE])


def self_test() -> int:
    """Validate the protocol without a PTY. Runs anywhere, including sandboxes that block ptys."""
    frame = encode_frame(7, [1, -1, 8388607, -8388608, 0, 123456, -123456, 42])
    ok = True
    def check(label, condition):
        nonlocal ok
        print(f"  {'PASS' if condition else 'FAIL'}  {label}")
        ok = ok and condition

    check("length is 33 bytes", len(frame) == 33)
    check("start byte 0xA0", frame[0] == 0xA0)
    check("stop byte 0xC0", frame[32] == 0xC0)
    check("sample number at byte 1", frame[1] == 7)
    counts = [int.from_bytes(frame[2 + 3 * i:5 + 3 * i], "big", signed=True) for i in range(8)]
    check("8 channel values round-trip", counts == [1, -1, 8388607, -8388608, 0, 123456, -123456, 42])
    check("aux is 6 bytes", len(frame[26:32]) == 6)
    check("sample number wraps", encode_frame(256, [0] * 8)[1] == 0)
    # 250 Hz means 250 frames per second of stream
    check("250 frames = 1 s at 250 Hz", abs(SAMPLE_RATE * FRAME_INTERVAL - 1.0) < 1e-12)
    print("self-test:", "OK" if ok else "FAILED")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--channels", type=int, default=8)
    ap.add_argument("--amplitude", type=int, default=20000, help="ADC counts")
    ap.add_argument("--signal", choices=("sine", "square", "zeros"), default="sine")
    ap.add_argument("--seconds", type=float, default=0, help="exit after N seconds (0 = forever)")
    ap.add_argument("--self-test", action="store_true", help="validate framing without a pty")
    ap.add_argument("--version-string", default="v3.1.2\n",
                    help="exact reply to the host's 'v' probe (Python escape sequences honoured)")
    ap.add_argument("--auto-stream", action="store_true",
                    help="stream frames without waiting for the 'b' command (some hosts wait for data "
                         "before they send it)")
    args = ap.parse_args()
    if args.self_test:
        return self_test()

    master, slave = pty.openpty()
    # Raw line discipline on the pair: without this the terminal echoes our own frames back to us
    # (seen as bogus commands) and translates bytes, corrupting the binary framing.
    tty.setraw(slave)
    attrs = termios.tcgetattr(slave)
    attrs[3] &= ~(termios.ECHO | termios.ECHONL | termios.ICANON | termios.ISIG)
    termios.tcsetattr(slave, termios.TCSANOW, attrs)
    port = os.ttyname(slave)
    print(f"EMULATOR PORT {port}", flush=True)

    streaming = bool(args.auto_stream)
    sample_number = 0
    started_at = time.monotonic()
    next_frame = started_at
    total_frames = 0

    while True:
        now = time.monotonic()
        if args.seconds and now - started_at > args.seconds:
            print(f"EMULATOR DONE frames={total_frames}", flush=True)
            return 0

        timeout = max(0.0, next_frame - now) if streaming else 0.05
        readable, _, _ = select.select([master], [], [], timeout)

        if readable:
            try:
                data = os.read(master, 512)
            except OSError:
                return 0
            for byte in data:
                char = chr(byte)
                if char == "b":
                    streaming = True
                    next_frame = time.monotonic()
                    print("EMULATOR START", flush=True)
                elif char == "s":
                    streaming = bool(args.auto_stream)
                    print(f"EMULATOR STOP frames={total_frames}", flush=True)
                elif char == "v":
                    os.write(master, args.version_string.encode().decode("unicode_escape").encode())
                    print("EMULATOR VERSION sent", flush=True)
                elif char not in "\r\n":
                    print(f"EMULATOR CMD {char!r}", flush=True)

        if streaming and time.monotonic() >= next_frame:
            t = sample_number / SAMPLE_RATE
            channels = []
            for ch in range(args.channels):
                if args.signal == "zeros":
                    value = 0
                elif args.signal == "square":
                    value = args.amplitude * (1 if math.sin(2 * math.pi * 10 * t + ch) >= 0 else -1)
                else:
                    value = int(args.amplitude * math.sin(2 * math.pi * 10 * t + ch * math.pi / 4))
                channels.append(value)
            try:
                os.write(master, encode_frame(sample_number, channels))
            except OSError:
                return 0
            sample_number = (sample_number + 1) % 256
            total_frames += 1
            next_frame += FRAME_INTERVAL


if __name__ == "__main__":
    sys.exit(main())
