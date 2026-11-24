#!/usr/bin/env bash
# Start the Cyton emulator and point the GUI at it - the C1 integration run, one command.
#
#   tools/run-cyton-emulator.sh                 # emulator + GUI
#   tools/run-cyton-emulator.sh --gui-src       # GUI from the repo (compiles first)
#
# Requires a machine where PTYs work (a normal Terminal, not a sandbox that blocks /dev/ptmx).
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="${BROADMIND_APP:-$REPO/dist/BROADMIND GUI.app}"
LOG="${BROADMIND_EMU_LOG:-/tmp/broadmind-cyton.log}"

python3 "$REPO/tools/cyton-emulator.py" --seconds 600 "$@" > "$LOG.emu" 2>&1 &
EMU_PID=$!
trap 'kill $EMU_PID 2>/dev/null || true' EXIT

for _ in $(seq 1 40); do
  PORT=$(grep -m1 "EMULATOR PORT" "$LOG.emu" 2>/dev/null | awk '{print $3}' || true)
  [ -n "${PORT:-}" ] && break
  sleep 0.25
done
[ -n "${PORT:-}" ] || { echo "emulator did not report a port:"; cat "$LOG.emu"; exit 1; }
echo "emulator on $PORT"

if [ ! -d "$APP" ]; then
  echo "no app at: $APP"
  echo "build one with tools/build-standalone.sh, or set BROADMIND_APP"
  exit 1
fi

echo "launching GUI with BROADMIND_CYTON_PORT=$PORT"
BROADMIND_TEST_CYTON=1 BROADMIND_CYTON_PORT="$PORT" \
  "$APP/Contents/MacOS/BROADMIND GUI" > "$LOG" 2>&1 &
GUI_PID=$!
echo "GUI pid $GUI_PID - logs: $LOG"
echo "watch: grep -E 'BROADMIND TEST|streaming OK' $LOG"
wait $GUI_PID || true
