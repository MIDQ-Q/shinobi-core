package com.example.shinobicore.modules.jutsu.cooldown;

public record CooldownEntry(String jutsuId, int remainingTicks, int maxTicks) {
    public boolean isFinished() {
        return remainingTicks <= 0;
    }
    
    public float getProgress() {
        if (maxTicks <= 0) return 1.0f;
        return 1.0f - ((float) remainingTicks / maxTicks);
    }
}