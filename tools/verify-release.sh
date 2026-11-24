#!/usr/bin/env bash
# BROADMIND GUI - release verification for a new version.
#
# Every check here exists because it caught a real, shipping defect in this repository.
# Run from the repository root:
#
#   tools/verify-release.sh
#   PROCESSING_APP="/path/to/Processing.app" tools/verify-release.sh
#
# Exit code 0 = every check passed. 1 = at least one failed. 2 = a required tool is missing.
#
# Checks that cannot run (no Processing install, no app run) report SKIP, never PASS.

set -u   # deliberately no pipefail: grep -q closes early and would fail pipelines

PASS=0; FAIL=0; SKIP=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }
skip() { printf '  \033[33mSKIP\033[0m  %s\n' "$1"; SKIP=$((SKIP+1)); }
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

[ -f BROADMIND_GUI/BROADMIND_GUI.pde ] || { echo "run this from the repository root"; exit 2; }
SKETCH="$PWD/BROADMIND_GUI"

# ---------------------------------------------------------------- 1. licensing
section "1. Licensing"
if git ls-files | grep -qi 'geometria'; then
  bad "a Geometria font file is tracked - it is commercial and must not ship"
else
  ok "no licensed Geometria files in the tree"
fi
if git log --all --oneline -- '*Geometria*' 2>/dev/null | grep -q .; then
  bad "Geometria appears in history - see BRANDING.md section 7.1"
else
  ok "no Geometria files in any reachable commit"
fi

# ---------------------------------------------------------------- 2. version
section "2. Version consistency"
VER=$(grep -oE 'localGUIVersionString *= *"v?[0-9]+\.[0-9]+\.[0-9]+[^"]*"' BROADMIND_GUI/BROADMIND_GUI.pde | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
DATE=$(grep -oE 'localGUIVersionDate *= *"[^"]+"' BROADMIND_GUI/BROADMIND_GUI.pde | sed 's/.*"\(.*\)"/\1/')
if [ -z "${VER:-}" ]; then
  bad "could not read localGUIVersionString"
else
  ok "sketch version: v$VER (${DATE:-no date})"
  if head -20 CHANGELOG.md | grep -qF "$VER"; then
    ok "CHANGELOG mentions $VER"
  else
    bad "CHANGELOG has no entry for $VER"
  fi
  if grep -q "v$VER" README.md; then ok "README shows v$VER"; else bad "README does not show v$VER"; fi
  if [ -n "${DATE:-}" ] && head -20 CHANGELOG.md | grep -qiF "$(echo "$DATE" | awk '{print $2}')"; then
    ok "CHANGELOG carries the same month/year ($DATE)"
  else
    bad "CHANGELOG month/year does not match '$DATE'"
  fi
fi

# ---------------------------------------------------------------- 3. native libraries
section "3. Native libraries (Apple Silicon)"
if [ -n "$(find BROADMIND_GUI/libraries -name 'jna*.jar' -print -quit 2>/dev/null)" ]; then
  bad "a bundled jna*.jar is present - it ships an x86_64-only native and kills startup on arm64"
else
  ok "no bundled JNA (Processing's arm64 JNA is used)"
fi
JSC=$(find BROADMIND_GUI/libraries -name 'jSerialComm*.jar' -print -quit 2>/dev/null)
if [ -z "${JSC:-}" ]; then
  bad "jSerialComm jar not found"
elif unzip -l "$JSC" 2>/dev/null | grep -q 'OSX/aarch64'; then
  ok "jSerialComm ships OSX/aarch64"
else
  bad "jSerialComm has no OSX/aarch64 native - starting any session will crash on Apple Silicon"
fi

# ---------------------------------------------------------------- 4. brand
section "4. Brand palette"
if grep -q 'BM_GREY\|BM_TEXT_GREY' BROADMIND_GUI/BROADMIND_GUI.pde; then
  ok "brand ramp is defined"
else
  bad "brand ramp (BM_GREY / BM_TEXT_GREY) is missing"
fi
if grep -rnE 'color\(31, *69, *110|color\(1, *18, *41|color\(57, *128, *204' --include=*.pde. BROADMIND_GUI | grep -v '//' | grep -q .; then
  bad "an OpenBCI-blue literal survives outside a comment"
else
  ok "no legacy OpenBCI blue literals"
fi
if grep -q 'localGUIVersionString' BROADMIND_GUI/BROADMIND_GUI.pde && \
   grep -q 'BROADMIND build' BROADMIND_GUI/TopNav.pde; then
  ok "upstream update check is disabled (fork version line)"
else
  bad "upstream update check may be live - it reports a false 'Update Available' for a 0.x fork"
fi

# ---------------------------------------------------------------- 5. hygiene
section "5. Repository hygiene"
if grep -rq 'ZZCapture' --include='*.pde' BROADMIND_GUI; then
  bad "a temporary capture hook is still in the sketch"
else
  ok "no temporary capture hooks"
fi
BREAKEN=$(python3 - <<'PY'
import re, pathlib
root = pathlib.Path('.')
bad = []
for md in root.glob('*.md'):
    txt = md.read_text(encoding='utf-8', errors='ignore')
    for m in re.finditer(r'!?\[[^\]]*\]\(([^)]+)\)', txt):
        t = m.group(1).split('#')[0].strip()
        if not t or t.startswith(('http', 'mailto:', '#', '../')): continue
        if not (root / t).exists(): bad.append(f"{md.name} -> {t}")
print("\n".join(sorted(set(bad))))
PY
)
if [ -z "$BREAKEN" ]; then ok "relative links in top-level markdown resolve"; else bad "broken relative links: $BREAKEN"; fi

# ---------------------------------------------------------------- 6. build
section "6. Build"
APP="${PROCESSING_APP:-}"
if [ -z "$APP" ]; then
  for c in "/Applications/Processing.app" "$HOME/Applications/Processing.app" "$PWD/.tools/Processing.app"; do
    [ -x "$c/Contents/MacOS/Processing" ] && APP="$c" && break
  done
fi
if [ -z "$APP" ]; then
  skip "no Processing install found - set PROCESSING_APP to compile"
else
  TMPH=$(mktemp -d); OUTD=$(mktemp -d)/build
  mkdir -p "$TMPH/Library/Processing/sketchbook" "$TMPH/Documents/Processing"
  printf 'sketchbook.path=%s\n' "$TMPH/Documents/Processing" > "$TMPH/Library/Processing/preferences.txt"
  ln -sfn "$SKETCH/libraries" "$TMPH/Documents/Processing/libraries"
  if _JAVA_OPTIONS="-Duser.home=$TMPH" "$APP/Contents/MacOS/Processing" cli \
       --sketch="$SKETCH" --output="$OUTD" --build > /tmp/bm-build.log 2>&1; then
    ok "sketch compiles"
  else
    bad "sketch failed to compile - see /tmp/bm-build.log"
  fi

  # ------------------------------------------------------------ 7. run smoke
  section "7. Run smoke test (no samples required)"
  RUNLOG=/tmp/bm-run.log
  # Processing launches the sketch with a JDWP agent on a fixed port (8845). A second
  # instance cannot bind it and dies silently, so clear any stray BROADMIND_GUI first.
  pkill -f 'BROADMIND_GUI' 2>/dev/null; sleep 1
  rm -rf "$OUTD" "$RUNLOG"
  export BROADMIND_TEST_PLAYBACK=1   # arms TestHarness.pde; inert in a normal run
  _JAVA_OPTIONS="-Duser.home=$TMPH" "$APP/Contents/MacOS/Processing" cli \
      --sketch="$SKETCH" --output="$OUTD" --run > "$RUNLOG" 2>&1 &
  RUNPID=$!
  # Wait for the sketch to finish setup rather than a fixed sleep: startup varies with the
  # network reachability check and a cold JNA cache. Hard stop at 75 s.
  # Wait for setup, then for the playback harness to report a live stream - that is the
  # regression this suite exists to catch.
  for _ in $(seq 1 60); do
    grep -q 'Setup is complete' "$RUNLOG" 2>/dev/null && break
    sleep 1
  done
  for _ in $(seq 1 45); do
    grep -q 'BROADMIND TEST: streaming OK' "$RUNLOG" 2>/dev/null && break
    sleep 1
  done
  # Snapshot before killing: terminating the JVM produces its own ThreadDeath fatal-error
  # dump, which must not be mistaken for an application exception.
  cp "$RUNLOG" "$RUNLOG.pre" 2>/dev/null
  kill "$RUNPID" 2>/dev/null; pkill -f "BROADMIND_GUI" 2>/dev/null; sleep 2

  SCAN="${RUNLOG}.pre"
  [ -s "$SCAN" ] || SCAN="$RUNLOG"
  if grep -q 'UnsatisfiedLinkError' "$SCAN"; then
    bad "native library failure on start - see $RUNLOG"
  else
    ok "no native library failures on start"
  fi
  if grep -E 'Exception|fatal error' "$SCAN" | grep -v 'ThreadDeath' | grep -q .; then
    bad "an exception was thrown at startup - see $RUNLOG"
  else
    ok "no exceptions at startup"
  fi
  if grep -qE 'Setup is complete|Welcome to the Processing-based' "$RUNLOG"; then
    ok "setup reached completion"
  else
    bad "setup did not complete - see $RUNLOG"
  fi

  # The regression this check exists for: a playback session that starts but never streams,
  # leaving a frozen clock and 0.00 uV on every channel.
  section "8. Playback streaming"
  if grep -q 'BROADMIND TEST: streaming OK' "$SCAN"; then
    ok "a playback session starts streaming on its own"
  else
    bad "playback did not start streaming - the frozen-clock bug is back (see $RUNLOG)"
  fi
  if grep -q 'Data stream started' "$SCAN"; then
    ok "the data stream reports started"
  else
    bad "no 'Data stream started' in the log"
  fi
fi

# ---------------------------------------------------------------- summary
printf '\n\033[1mSummary\033[0m\n'
printf '  passed: %d   failed: %d   skipped: %d\n' "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then
  printf '\n\033[31mNOT READY TO RELEASE\033[0m\n'; exit 1
fi
if [ "$SKIP" -gt 0 ]; then
  printf '\n\033[33mPASSED WITH SKIPS\033[0m - set PROCESSING_APP to compile and run\n'; exit 0
fi
printf '\n\033[32mREADY\033[0m\n'
