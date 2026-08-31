package com.example.shinobicore.modules.combat.common;

public enum WeaponClass {
    KATANA, KUNAI, SHURIKEN, UNARMED, UNKNOWN;

    public static WeaponClass fromString(String name) {
        for (WeaponClass wc : values()) {
            if (wc.name().equalsIgnoreCase(name)) return wc;
        }
        return UNKNOWN;
    }
}