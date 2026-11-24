// Smooths the displayed signal when samples arrive in bursts.
//
// Why this exists: the FTDI dongle (and BLE notifications on the wireless path) deliver samples in
// chunks - typically ~4 samples every 16 ms at 250 Hz - so a frame that happens to catch a chunk
// jumps forward by 4 samples and the next frame by 0. On a 60 fps display that reads as a jittery,
// "choppy" trace even though no data is missing.
//
// The pacer sits between the board and the display buffers. Every frame it takes everything the
// board produced, then releases only the samples whose time has come at the nominal sample rate.
// Nothing is dropped and nothing is duplicated:
//
//   board.update()  -> getFrameData()   (bursty, exact)
//        -> SamplePacer.queue
//        -> due samples only -> dataProcessingRawBuffer   (smooth, display only)
//
// Recording is untouched: DataLogger writes getFrameData() straight to the file, so a paced display
// can never change what a recording contains.

class SamplePacer {
    private ArrayDeque<float[]> pending;
    private final int channels;
    private final int windowSamples;
    private final float fs;

    private double deficit = 0.0;   // fractional samples owed to the display
    private long lastMs = -1;
    private boolean primed = false;

    SamplePacer(int _channels, int _windowSamples, float _fs) {
        channels = _channels;
        windowSamples = _windowSamples;
        fs = (_fs > 0) ? _fs : 250.0;
        pending = new ArrayDeque<float[]>(Math.max(64, _windowSamples));
    }

    int channelCount() { return channels; }
    int windowSamples() { return windowSamples; }

    // Take everything the board produced this frame. Called once per frame, before dueNow().
    void push(double[][] frame, int[] exgChannels, int channelCount) {
        if (frame == null || frame.length == 0 || frame[0] == null) return;
        int nSamples = frame[0].length;
        for (int i = 0; i < nSamples; i++) {
            float[] row = new float[Math.min(channels, channelCount)];
            for (int c = 0; c < row.length; c++) {
                row[c] = (float) frame[exgChannels[c]][i];
            }
            pending.addLast(row);
        }
    }

    // How many samples the display is allowed to advance by this frame.
    int dueNow() {
        long now = millis();
        if (lastMs < 0) lastMs = now;
        double dt = (now - lastMs) / 1000.0;
        lastMs = now;

        int available = pending.size();
        if (available == 0) {
            return 0;
        }

        // First fill: hand over a whole window at once so the trace appears immediately instead of
        // crawling in over the first two seconds of a session.
        if (!primed) {
            if (available >= windowSamples) {
                primed = true;
                deficit = 0;
                return windowSamples;
            }
            return available;
        }

        deficit += fs * Math.max(dt, 0.0);
        int due = (int) Math.floor(deficit);

        // Never fall hopelessly behind: if the queue exceeds one second of data, catch up.
        int backlogLimit = (int) fs;
        if (available > backlogLimit) {
            due = Math.max(due, available - backlogLimit);
        }
        due = Math.max(0, Math.min(due, available));
        deficit -= due;
        // Guard against a large negative deficit after a long stall (window hidden, GC pause).
        if (deficit < -fs) deficit = -fs;
        return due;
    }

    float[] pop() { return pending.pollFirst(); }
    int size() { return pending.size(); }
}
