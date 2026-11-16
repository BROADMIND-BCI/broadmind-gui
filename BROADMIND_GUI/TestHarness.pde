// Automated test harness. Completely inert unless BROADMIND_TEST_PLAYBACK is present in the
// environment, which tools/verify-release.sh sets. It exists because the playback bug could not
// be caught by a compile check: the session started, but nothing streamed, and the only symptom
// was a frozen clock and 0.00 uV on every channel.
//
// Markers the verify script greps for:
//   BROADMIND TEST: playback session requested
//   BROADMIND TEST: streaming OK

boolean bmTestPlayback = false;
boolean bmTestSessionRequested = false;
boolean bmTestStreamOK = false;

void bmTestInit() {
    bmTestPlayback = System.getenv("BROADMIND_TEST_PLAYBACK") != null;
    if (bmTestPlayback) {
        println("BROADMIND TEST: playback harness armed");
    }
}

void bmTestTick() {
    if (!bmTestPlayback) return;

    // Request a playback session once the control panel exists and no session is running.
    if (!bmTestSessionRequested && systemMode < SYSTEMMODE_POSTINIT
        && controlPanel != null && millis() > 12000) {
        eegDataSource = DATASOURCE_PLAYBACKFILE;
        playbackData_fname = dataFile("EEG_Sample_Data/OpenBCI_GUI-v6-meditation.txt").getAbsolutePath();
        controlPanel.initBox.initButtonPressed();
        bmTestSessionRequested = true;
        println("BROADMIND TEST: playback session requested");
    }

    // The regression this guards: a playback session that never starts streaming.
    if (bmTestSessionRequested && !bmTestStreamOK
        && currentBoard != null && currentBoard.isStreaming()) {
        bmTestStreamOK = true;
        println("BROADMIND TEST: streaming OK (" + nf(millis() / 1000.0, 1, 1) + " s)");
    }
}
