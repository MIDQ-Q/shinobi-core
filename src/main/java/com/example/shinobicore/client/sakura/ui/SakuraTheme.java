package com.example.shinobicore.client.sakura.ui;

/** Design tokens: sakura palette, metrics, animation timings. */
public final class SakuraTheme {
    private SakuraTheme() {}

    // palette (ARGB)
    public static final int BG_TOP    = 0xE0171119;
    public static final int BG_BOTTOM = 0xE6100B12;
    public static final int WINDOW    = 0xF0171119;
    public static final int EDGE      = 0xFF3A2A3E;
    public static final int PANEL     = 0xFF1E1624;
    public static final int SAKURA    = 0xFFFF9EC4;
    public static final int SAK_DIM   = 0xFF8A4A66;
    public static final int INK       = 0xFFF2EAF0;
    public static final int INK_DIM   = 0xFF9A8FA6;
    public static final int SLOT_BG   = 0xFF2A1F2E;
    public static final int SLOT_EDGE = 0xFF4A3A50;
    public static final int SLOT_HOVER= 0x55FF9EC4;

    // glass architecture
    public static final int GLASS_BG      = 0x991E1624;
    public static final int GLASS_EDGE    = 0x44FF9EC4;
    public static final int GLASS_HILIGHT = 0x1AFFFFFF;

    // extra accents
    public static final int GOLD          = 0xFFFFD75E;
    public static final int CHAKRA_BLUE   = 0xFF7EC8FF;
    public static final int CHAKRA_PURPLE = 0xFFB48AFF;
    public static final int UNLOCK_GLOW   = 0x55FF9EC4;
    public static final int AVAIL_PULSE   = 0xFF8A4A66;

    // tree nodes / connections (legacy refs)
    public static final int NODE_BG       = 0xFF1E1624;
    public static final int NODE_EDGE     = 0xFF3A2A3E;
    public static final int NODE_UNLOCKED = 0xFF3A2A3E;
    public static final int NODE_GLOW     = 0x33FF9EC4;
    public static final int NODE_AVAIL    = 0xFF8A4A66;
    public static final int CONN_DONE     = 0xCCFF9EC4;
    public static final int CONN_AVAIL    = 0x888A4A66;
    public static final int CONN_LOCKED   = 0x443A2A3E;

    // scroll gallery metrics
    public static final int SCROLL_W   = 96;
    public static final int SCROLL_GAP = 44;
    public static final int ROLLER_H   = 7;
    public static final int HEADER_H   = 34;
    public static final int FOOTER_H   = 20;
    public static final int NODE_ROW   = 34;
    public static final int NODE_R     = 11;
    public static final int BEAM_H     = 10;
    public static final int CORD_H     = 16;

    // scroll gallery palette
    public static final int PAPER      = 0xFFE7D9BC;
    public static final int PAPER_EDGE = 0xFFB9A88C;
    public static final int PAPER_SHADE= 0x228A7A5C;
    public static final int ROLLER     = 0xFF6B4A33;
    public static final int ROLLER_DARK= 0xFF3E2A1D;
    public static final int CORD_RED   = 0xFFB3222E;
    public static final int INK_LINE   = 0xFF2A2130;

    // metrics
    public static final int BAR_H  = 24;
    public static final int PANEL_R = 5;

    // animation timings (ms)
    public static final int OPEN_MS    = 220;
    public static final int TAB_MS     = 180;
    public static final int STAGGER_MS = 6;
    public static final int UNLOCK_MS  = 350;
    public static final int PULSE_MS   = 1200;
    public static final int UNROLL_MS  = 300;
}