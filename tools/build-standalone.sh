#!/usr/bin/env bash
# Build a standalone macOS app: dist/BROADMIND GUI.app
#
# The bundle contains the compiled sketch, the Processing runtime core, the sketch libraries, a
# Java runtime and the licence texts, so a recipient needs neither Processing nor this repository.
#
#   tools/build-standalone.sh
#   PROCESSING_APP=/Applications/Processing.app tools/build-standalone.sh
#
# Licensing: see packaging/THIRD-PARTY.md. The LGPL components are shipped as unmodified,
# replaceable jars in Contents/Resources/libraries, with licence texts in Contents/Resources/LICENSES.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SKETCH="$REPO/BROADMIND_GUI"
NAME="BROADMIND GUI"
APP="$REPO/dist/$NAME.app"

PROC="${PROCESSING_APP:-}"
if [ -z "$PROC" ]; then
  for c in "/Applications/Processing.app" "$REPO/../.tools/Processing.app"; do
    [ -x "$c/Contents/MacOS/Processing" ] && PROC="$c" && break
  done
fi
[ -n "$PROC" ] || { echo "Processing 4.5.x not found - set PROCESSING_APP"; exit 2; }
RES="$PROC/Contents/app/resources"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAKEHOME="$TMP/home"
mkdir -p "$FAKEHOME/Library/Processing" "$FAKEHOME/Documents/Processing"
printf 'sketchbook.path=%s\n' "$FAKEHOME/Documents/Processing" > "$FAKEHOME/Library/Processing/preferences.txt"
ln -sfn "$SKETCH/libraries" "$FAKEHOME/Documents/Processing/libraries"

echo "1/5 compiling sketch"
_JAVA_OPTIONS="-Duser.home=$FAKEHOME" "$PROC/Contents/MacOS/Processing" cli \
  --sketch="$SKETCH" --output="$TMP/build" --build > "$TMP/build.log" 2>&1 \
  || { tail -20 "$TMP/build.log"; exit 1; }

echo "2/5 assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"/{java,libraries,classes,sketch,LICENSES}
cp -R "$TMP/build/." "$APP/Contents/Resources/classes/"
rm -rf "$APP/Contents/Resources/classes/source"          # generated Java, not needed to run

# Processing runtime: core library + the java-mode libraries the sketch imports
cp "$RES/core/library"/*.jar "$APP/Contents/Resources/java/"
cp "$RES/modes/java/libraries/serial/library"/*.jar "$APP/Contents/Resources/java/"
cp "$RES/modes/java/libraries/net/library"/*.jar "$APP/Contents/Resources/java/"

# sketch libraries, unmodified and replaceable (LGPL requirement)
cp -R "$SKETCH/libraries/." "$APP/Contents/Resources/libraries/"

# sketch data: media the app loads. Kept in the bundle; linked into a writable sketch path at run
# time, so the bundle itself is never written to.
cp -R "$SKETCH/data" "$APP/Contents/Resources/sketch/data"

echo "3/5 copying runtime"
cp -R "$RES/jdk" "$APP/Contents/Resources/jdk"

echo "4/5 licences"
cp "$REPO/packaging/licenses/"* "$APP/Contents/Resources/LICENSES/"
cp "$REPO/packaging/THIRD-PARTY.md" "$APP/Contents/Resources/LICENSES/THIRD-PARTY.md"
cp "$REPO/LICENSE" "$APP/Contents/Resources/LICENSES/BROADMIND-GUI-LICENSE.txt"
cat > "$APP/Contents/Resources/LICENSES/README-LGPL.txt" <<'LGPL'
This application uses libraries licensed under the GNU Lesser General Public License
(Processing core, controlP5, minim, grafica, oscP5) and the GNU General Public License
version 2 with the Classpath Exception (the Java runtime).

The LGPL libraries are distributed here unmodified, as ordinary jar files in:

    BROADMIND GUI.app/Contents/Resources/libraries/<component>/library/<component>.jar

You may replace any of them with your own build of the same library: drop the rebuilt jar at the
same path and the application will use it. This is the mechanism by which the LGPL's requirement to
be able to modify and relink the library is satisfied.

Corresponding source for each unmodified library is available from its upstream project:

  Processing       https://github.com/processing/processing4
  controlP5        https://github.com/sojamo/controlp5
  minim            https://github.com/ddf/Minim
  grafica          https://github.com/jagracar/grafica
  oscP5            https://github.com/sojamo/oscp5

Full licence texts are in this directory. No warranty is given on behalf of the licensors.
LGPL

echo "5/5 writing bundle metadata and launcher"
cp "$REPO/packaging/app.icns" "$APP/Contents/Resources/app.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>BROADMIND GUI</string>
  <key>CFBundleDisplayName</key><string>BROADMIND GUI</string>
  <key>CFBundleExecutable</key><string>BROADMIND GUI</string>
  <key>CFBundleIdentifier</key><string>me.broadmind.gui</string>
  <key>CFBundleIconFile</key><string>app.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2.2</string>
  <key>CFBundleVersion</key><string>0.2.2</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

cat > "$APP/Contents/MacOS/$NAME" <<'LAUNCH'
#!/bin/bash
# BROADMIND GUI - standalone launcher. No Processing install, no repository needed.
BUNDLE="$(cd "$(dirname "$0")/../.." && pwd)"
RES="$BUNDLE/Contents/Resources"
JAVA="$RES/jdk/bin/java"

# The bundle is read-only once installed, so the sketch path lives in Documents and links to the
# bundled data directory. Only files the app itself writes go there.
# BROADMIND_GUI_HOME redirects everything the app writes (settings, recordings, console log),
# which is how the bundle is tested in a sandbox and lets a user keep its data on another volume.
GUEST_HOME="${BROADMIND_GUI_HOME:-$HOME}"
USER_SKETCH="$GUEST_HOME/Documents/BROADMIND GUI/app"
mkdir -p "$USER_SKETCH"
[ -e "$USER_SKETCH/data" ] || ln -s "$RES/sketch/data" "$USER_SKETCH/data"
mkdir -p "$USER_SKETCH"
[ -e "$USER_SKETCH/data" ] || ln -s "$RES/sketch/data" "$USER_SKETCH/data"

CP="$RES/classes"
while IFS= read -r j; do CP="$CP:$j"; done < <(find "$RES/java" "$RES/libraries" "$RES" -maxdepth 4 -name '*.jar' 2>/dev/null)
LIBPATH="$(find "$RES/libraries" -type d -name library | tr '\n' ':')$RES/java"

if [ ! -x "$JAVA" ]; then
  osascript -e 'display alert "BROADMIND GUI" message "The bundled Java runtime is missing." as critical' >/dev/null 2>&1
  exit 1
fi

exec "$JAVA" -Xdock:name="BROADMIND GUI" -Duser.home="$GUEST_HOME" \
  -Djava.library.path="$LIBPATH" \
  -cp "$CP" processing.core.PApplet --display=-1 \
  --sketch-path="$USER_SKETCH" BROADMIND_GUI
LAUNCH
chmod +x "$APP/Contents/MacOS/$NAME"

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 && echo "   ad-hoc signed" || echo "   (codesign skipped)"

printf '\nbuilt: %s\nsize:  %s\n' "$APP" "$(du -sh "$APP" | awk '{print $1}')"
printf 'run:   open "%s"\n' "$APP"
