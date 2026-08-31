package com.example.shinobicore.modules.jutsu.data;

public enum JutsuElement {
    FIRE, WATER, WIND, LIGHTNING, EARTH, NONE;

    public static JutsuElement fromString(String s) {
        if (s == null || s.isEmpty()) return NONE;
        try {
            return valueOf(s.toUpperCase());
        } catch (Exception e) {
            return NONE;
        }
    }
}