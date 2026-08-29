package com.example.shinobicore.client;

public class RasenshurikenClientState {
    public static boolean charging = false;
    public static float progress = 0f;
    public static boolean ready = false;

    public static void reset() {
        charging = false;
        progress = 0f;
        ready = false;
    }
}