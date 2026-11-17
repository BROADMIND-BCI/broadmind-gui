// TEMP demo recorder: writes raw RGB frames, which are far cheaper than PNG.
import java.io.*;
int zzW = 1280, zzH = 960;
int zzN = 0, zzStart = -1, zzLast = 0;
boolean zzSession = false;
OutputStream zzOut; PrintWriter zzLog;

void zzCaptureInit() {
    try {
        zzOut = new BufferedOutputStream(new FileOutputStream("/Users/admin/Downloads/DeepSeek work/.tools/demo-raw/frames.rgb"), 1 << 20);
        zzLog = createWriter("/Users/admin/Downloads/DeepSeek work/.tools/demo-raw/timestamps.txt");
    } catch (Exception e) { println("ZZCAPTURE init failed: " + e); }
    println("ZZCAPTURE ready");
}

void zzTick() {
    int t = millis();
    if (zzStart < 0) { zzStart = t; zzLast = t - 90; }
    int el = t - zzStart;
    boolean recording = (el < 13000) || (el > 19500 && el < 35000);
    if (recording && zzOut != null && t - zzLast >= 90) {
        PImage f = get();
        if (f != null) {
            f.resize(zzW, zzH);
            f.loadPixels();
            try {
                for (int p : f.pixels) {
                    zzOut.write((p >> 16) & 0xFF);
                    zzOut.write((p >> 8) & 0xFF);
                    zzOut.write(p & 0xFF);
                }
                zzLog.println(zzN + "," + t);
                zzLog.flush();
                zzN++; zzLast = t;
            } catch (Exception e) { println("ZZCAPTURE write failed: " + e); }
        }
    }
    if (!zzSession && el > 14000) {
        try {
            playbackData_fname = dataFile("EEG_Sample_Data/OpenBCI_GUI-v6-meditation.txt").getAbsolutePath();
            controlPanel.initBox.initButtonPressed();
            zzSession = true;
            println("ZZCAPTURE session requested");
        } catch (Exception e) { println("ZZCAPTURE session failed: " + e); }
    }
}
