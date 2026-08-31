package com.example.shinobicore.client.parkour.actions;

import java.util.HashMap;
import java.util.Map;

public class ParkourContext {
    private final Map<String, Integer> cooldowns = new HashMap<>();
    private final Map<String, Integer> activeTicks = new HashMap<>();
    
    public boolean isOnCooldown(String actionId) {
        Integer cd = cooldowns.get(actionId);
        return cd != null && cd > 0;
    }
    
    public void setCooldown(String actionId, int ticks) {
        cooldowns.put(actionId, ticks);
    }
    
    public void tickCooldowns() {
        cooldowns.replaceAll((k, v) -> Math.max(0, v - 1));
        activeTicks.replaceAll((k, v) -> v + 1);
    }
    
    public int getActiveTicks(String actionId) {
        return activeTicks.getOrDefault(actionId, 0);
    }
    
    public void resetActive(String actionId) {
        activeTicks.put(actionId, 0);
    }
    
    public void clearActive(String actionId) {
        activeTicks.remove(actionId);
    }
}