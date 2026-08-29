package com.example.shinobicore.util;

/**
 * Parses hex color strings like #FF6600 into packed RGB int.
 * HLD: Section 2.4 (visuals)
 */
public final class ColorHelper {

    private ColorHelper() {}

    public static int parse(String hex) {
        if (hex == null || hex.length() < 7) {
            return 0xFFFFFF;
        }
        String s = hex;
        if (s.startsWith("#")) {
            s = s.substring(1);
        }
        try {
            return (int) Long.parseLong(s, 16);
        } catch (Exception e) {
            return 0xFFFFFF;
        }
    }

    public static float red(int color) {
        return ((color >> 16) & 0xFF) / 255.0f;
    }

    public static float green(int color) {
        return ((color >> 8) & 0xFF) / 255.0f;
    }

    public static float blue(int color) {
        return (color & 0xFF) / 255.0f;
    }
}