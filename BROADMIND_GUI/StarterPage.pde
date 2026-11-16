// BROADMIND starter page: a black-and-white outline schematic of the headset being put on
// and connected by USB-C. Drawn as vector geometry rather than an image asset, so it stays
// crisp at any density and cannot drift from the palette.
//
// The design and its four keyframes live in docs/design/. Geometry below is the same
// 600x600 coordinate space used there, so the two can be compared side by side.

final float[][] BM_HEAD = {
    {358, 100, 392, 148, 396, 200},
    {398, 224, 390, 236, 388, 246},
    {388, 256, 404, 266, 414, 274},
    {420, 280, 414, 288, 402, 290},
    {394, 292, 398, 302, 400, 308},
    {402, 316, 394, 322, 386, 326},
    {380, 330, 386, 342, 380, 352},
    {372, 364, 352, 368, 338, 372},
    {332, 384, 332, 404, 332, 428},
    {-1, 0, -1, 0, 332, 452},   // sentinel -1 = straight line
    {-1, 0, -1, 0, 262, 452},
    {262, 404, 264, 386, 264, 372},
    {252, 336, 242, 300, 240, 266},
    {236, 214, 240, 148, 300, 100}
};

// quadratic band across the skull: p0, control, p2
final float[] BM_BAND = {250, 208, 300, 150, 392, 206};

// cable: two cubics from the band to the laptop port
final float[][] BM_CABLE = {
    {210, 236, 190, 320, 214, 392},
    {234, 446, 300, 480, 486, 504}
};

final int BM_CYCLE_MS = 12000;   // 12 s loop

// Draw the starter page. It is centred in the window and drawn *underneath* the interface:
// the control panel simply covers whatever part of it it needs to. That way the page never
// slides sideways or shrinks when a data-source sub-panel opens - the panel comes to it.
void drawStarterPage() {
    float cx = width / 2.0;                       // the schematic is centred on the window itself
    float copyW = min(400, width - 720);          // copy lives right of the widest panel
    if (copyW < 240) return;
    float blockX = width - 30 - copyW;            // right-aligned, so it cannot be covered

    float t = millis() % BM_CYCLE_MS;

    // one phase variable drives all three lines, so caption and body can never disagree
    int phase = t < 2700 ? 0 : (t < 5400 ? 1 : (t < 8100 ? 2 : 3));
    String[] kickers   = {"01 - PUT IT ON", "02 - CONTACT", "03 - CONNECT", "READY"};
    String[] headlines = {"Put the headset on.", "Let it settle.", "Connect the cable.", "Start recording."};
    String[] bodies = {
        "Eight dry contacts settle on the sensorimotor set.",
        "No gel, no paste. The band finds its own pressure.",
        "USB-C to the machine you record on.",
        "The device is on and connected."
    };

    // ---- copy -------------------------------------------------------------
    float copyY = 108;
    noStroke();
    fill(BM_TEXT_GREY); textFont(p4); textAlign(LEFT, BASELINE);
    text(kickers[phase], blockX, copyY);

    fill(BLACK); textFont(p0);
    text(headlines[phase], blockX, copyY + 44);

    fill(BM_TEXT_GREY); textFont(p4);
    text(bodies[phase], blockX, copyY + 76);

    for (int i = 0; i < 3; i++) {
        stroke(BLACK); strokeWeight(1.5);
        fill((t > 2700 * i) ? BLACK : WHITE);
        ellipse(blockX + 6 + i * 18, copyY + 108, 8, 8);
    }
    noStroke();

    // ---- schematic, centred under the copy ---------------------------------
    // schematic centred under everything, sized to the window height
    float availH = height - 330;
    float schW = min(620, availH);
    if (schW < 200) return;
    float scale = schW / 620.0;

    pushMatrix();
    // the drawing's own centre sits near x=440 in its 600-unit space
    translate(cx - 440 * scale, 260);
    scale(scale);

    stroke(BLACK); strokeWeight(2.2); noFill();
    beginShape();
    vertex(300, 100);
    for (float[] seg : BM_HEAD) {
        if (seg[0] < 0) vertex(seg[4], seg[5]);
        else bezierVertex(seg[0], seg[1], seg[2], seg[3], seg[4], seg[5]);
    }
    endShape(CLOSE);

    strokeWeight(1.6);
    beginShape();
    vertex(298, 292);
    bezierVertex(316, 289, 326, 303, 324, 317);
    bezierVertex(322, 333, 309, 341, 296, 338);
    bezierVertex(286, 335, 283, 320, 286, 308);
    bezierVertex(288, 300, 291, 293, 298, 292);
    endShape(CLOSE);

    float lift = t < 2700 ? map(t, 0, 2700, -34, 0) : 0;
    pushMatrix();
    translate(0, lift);
    stroke(BLACK); strokeWeight(2.6); noFill();
    beginShape();
    vertex(BM_BAND[0], BM_BAND[1]);
    quadraticVertex(BM_BAND[2], BM_BAND[3], BM_BAND[4], BM_BAND[5]);
    endShape();

    for (int i = 0; i < 8; i++) {
        // quadratic bezier point on the band: B(u) = (1-u)^2 P0 + 2(1-u)u C + u^2 P2
        float u = i / 7.0, a = 1 - u;
        float bx = a*a*BM_BAND[0] + 2*a*u*BM_BAND[2] + u*u*BM_BAND[4];
        float by = a*a*BM_BAND[1] + 2*a*u*BM_BAND[3] + u*u*BM_BAND[5];
        boolean inked = t > 2700 + i * 95;
        stroke(BLACK); strokeWeight(2);
        fill(inked ? BLACK : WHITE);
        ellipse(bx, by, 13, 13);
    }
    popMatrix();

    if (t > 5400) {
        float prog = constrain(map(t, 5400, 8100, 0, 1), 0, 1);
        stroke(BLACK); strokeWeight(1.8); noFill();
        drawPartialBezier(250, 208, BM_CABLE[0][0], BM_CABLE[0][1], BM_CABLE[0][2], BM_CABLE[0][3], BM_CABLE[0][4], BM_CABLE[0][5], prog);
        if (prog > 0.55) {
            float p2 = map(prog, 0.55, 1, 0, 1);
            drawPartialBezier(BM_CABLE[0][4], BM_CABLE[0][5], BM_CABLE[1][0], BM_CABLE[1][1], BM_CABLE[1][2], BM_CABLE[1][3], BM_CABLE[1][4], BM_CABLE[1][5], p2);
        }
    }

    if (t > 7000) {
        stroke(BLACK); strokeWeight(2.2); noFill();
        rect(506, 432, 140, 68);
        strokeWeight(1.4);
        rect(522, 448, 108, 38);
        strokeWeight(2.2);
        rect(496, 500, 160, 16);
        fill(WHITE); rect(460, 494, 32, 20);
        noStroke(); fill(BLACK); rect(448, 499, 12, 10);
    }

    popMatrix();
}

// stroke a cubic bezier up to `progress` (0..1) so the cable can draw itself on.
void drawPartialBezier(float x0, float y0, float x1, float y1, float x2, float y2, float x3, float y3, float progress) {
    int steps = max(2, int(40 * progress));
    beginShape();
    for (int i = 0; i <= steps; i++) {
        float u = (i / 40.0);
        if (u > progress) u = progress;
        vertex(bezierPoint(x0, x1, x2, x3, u), bezierPoint(y0, y1, y2, y3, u));
        if (u >= progress) break;
    }
    endShape();
}
