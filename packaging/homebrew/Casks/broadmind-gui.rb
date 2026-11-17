# Homebrew cask for the BROADMIND GUI standalone app.
#
# This is the agent-friendly install path: `brew` fetches the signed disk image, verifies it
# against the sha256 below, mounts it and copies the app to /Applications. No admin scripts, no
# quarantine workaround.
#
# Publishing a new version
#   1. build the bundle       tools/build-standalone.sh
#   2. build the disk image   see docs/DISTRIBUTION.md §6
#   3. upload the .dmg to the URL below and update `version` + `sha256`
#   4. push the cask to the tap repo BROADMIND-BCI/homebrew-broadmind-gui (Casks/broadmind-gui.rb)
#
# NOT live yet: the disk image is internal-only until the four unresolved third-party libraries in
# packaging/THIRD-PARTY.md are cleared and the app is notarised. Until then recipients cannot
# install with these commands; the page at https://broadmind.me/gui says so.

cask "broadmind-gui" do
  version "0.2.2"
  sha256 "d7756fe2dc6065958cea9758f57b94e5d81cc9c5b601801cbf26c70d7d12d3c1"

  url "https://broadmind.me/downloads/BROADMIND-GUI-#{version}.dmg"
  name "BROADMIND GUI"
  desc "Desktop app for the BROADMIND Research Kit"
  homepage "https://broadmind.me/gui"

  livecheck do
    url :homepage
    regex(/0\.\d+\.\d+/)
  end

  app "BROADMIND GUI.app"

  caveats <<~EOS
    BROADMIND GUI stores its settings, console log and recordings in
    ~/Documents/BROADMIND GUI.

    BROADMIND is a research instrument, not a medical device.
  EOS
end
