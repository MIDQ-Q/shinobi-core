package com.example.shinobicore.client;

/** Client-side selected slot per loadout (HUD highlight). */
public final class LoadoutHudState {
    public static int selA = 0;
    public static int selB = 0;

    public static void cycleA() { selA = (selA + 1) % 5; }
    public static void cycleB() { selB = (selB + 1) % 5; }

    private LoadoutHudState() {}
}