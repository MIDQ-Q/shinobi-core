package com.example.shinobicore.jutsu.core;

/**
 * Звуковое оформление техники.
 */
public class SoundDefinition {
    private final String cast;
    private final String hit;
    private final String loop;
    private final String end;

    public SoundDefinition(String cast, String hit, String loop, String end) {
        this.cast = cast;
        this.hit = hit;
        this.loop = loop;
        this.end = end;
    }

    public String getCast() { return cast; }
    public String getHit() { return hit; }
    public String getLoop() { return loop; }
    public String getEnd() { return end; }
}