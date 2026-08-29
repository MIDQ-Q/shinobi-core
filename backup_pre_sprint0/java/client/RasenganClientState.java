package com.example.shinobicore.client;

public class RasenganClientState {
    public static boolean charging = false;
    public static float chargeProgress = 0f;
    public static boolean ready = false;

    public static void reset() {
        charging = false;
        chargeProgress = 0f;
        ready = false;
    }
}