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
# The published cask lives in the tap repo BROADMIND-BCI/homebrew-broadmind-gui; this copy is the
# source of truth in the app repo. The image is hosted on the GitHub release below.
#
# Still open: notarisation, and four inherited libraries whose licences are unconfirmed
# (packaging/THIRD-PARTY.md §2). Installing through brew clears quarantine, which is why the cask
# is the supported route while the build is unnotarised.

cask "broadmind-gui" do
  version "0.3.0"
  sha256 "dfb1b872339e54e709284844db6fd3e70e244ba8cced39abc4157a8673156a63"

  url "https://github.com/BROADMIND-BCI/broadmind-gui/releases/download/v#{version}-alpha.1/BROADMIND-GUI-#{version}.dmg"
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
