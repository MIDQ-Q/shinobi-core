package com.example.shinobicore.modules.visual.util;

public final class ParticleColors {
    public static final int FIRE = 0xFFFF4400;
    public static final int WATER = 0xFF0088FF;
    public static final int WIND = 0xFF88FFCC;
    public static final int EARTH = 0xFFAA7744;
    public static final int LIGHTNING = 0xFFFFEE00;
    public static final int ICE = 0xFFAAEEFF;
    public static final int LAVA = 0xFFFF2200;
    public static final int POISON = 0xFF88FF00;
    public static final int HEAL = 0xFF00FF88;
    public static final int DARK = 0xFF440066;
    public static final int LIGHT = 0xFFFFDDAA;
    public static final int WHITE = 0xFFFFFFFF;
    public static final int GOLD = 0xFFFFD700;
    public static final int BLUE = 0xFF4499FF;
    public static final int RED = 0xFFFF3333;
    public static final int GREEN = 0xFF33FF33;
    public static final int BROWN = 0xFF8B6914;
    public static final int GRAY = 0xFFAAAAAA;

    public static int getElementColor(String elementId) {
        if (elementId == null) return WHITE;
        switch (elementId.toLowerCase()) {
            case "fire": case "katon": return FIRE;
            case "water": case "suiton": return WATER;
            case "wind": case "fuuton": return WIND;
            case "earth": case "doton": return EARTH;
            case "lightning": case "raiton": return LIGHTNING;
            case "ice": case "hyouton": return ICE;
            case "lava": case "youton": return LAVA;
            case "poison": return POISON;
            case "heal": case "medical": return HEAL;
            case "dark": case "shadow": return DARK;
            case "light": return LIGHT;
            default: return WHITE;
        }
    }

    public static float getRed(int color) { return ((color >> 16) & 0xFF) / 255.0f; }
    public static float getGreen(int color) { return ((color >> 8) & 0xFF) / 255.0f; }
    public static float getBlue(int color) { return (color & 0xFF) / 255.0f; }
    public static float getAlpha(int color) { return ((color >> 24) & 0xFF) / 255.0f; }
}