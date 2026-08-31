package com.example.shinobicore.modules.combat.common;

public enum Stance {
    AGGRESSIVE,
    DEFENSIVE,
    NONE;

    public static Stance fromOrdinal(int ordinal) {
        if (ordinal < 0 || ordinal >= values().length) return NONE;
        return values()[ordinal];
    }
}