package com.example.shinobicore.stat.component.impl;

import com.example.shinobicore.stat.component.IDojutsuComponent;
import net.minecraft.nbt.NbtCompound;
import java.util.HashMap;
import java.util.Map;

public class DojutsuComponentImpl implements IDojutsuComponent {
    private static final float BLINDNESS_THRESHOLD = 100.0f;
    private String activeDojutsu = null;
    private int activeStage = 0;
    private final Map<String, Integer> usageMap = new HashMap<>();
    private final Map<String, Float> stressMap = new HashMap<>();
    private final Map<String, Integer> stageMap = new HashMap<>();

    @Override public String getActiveDojutsu() { return activeDojutsu; }
    @Override public boolean activateDojutsu(String dojutsuId) { if (dojutsuId == null || dojutsuId.isEmpty()) return deactivateDojutsu(); this.activeDojutsu = dojutsuId; this.activeStage = stageMap.getOrDefault(dojutsuId, 0); usageMap.putIfAbsent(dojutsuId, 0); stressMap.putIfAbsent(dojutsuId, 0.0f); stageMap.putIfAbsent(dojutsuId, 0); return true; }
    @Override public boolean deactivateDojutsu() { if (activeDojutsu == null) return false; activeDojutsu = null; activeStage = 0; return true; }
    @Override public int getActiveStage() { return activeStage; }
    @Override public void setActiveStage(int stage) { this.activeStage = Math.max(0, stage); if (activeDojutsu != null) stageMap.put(activeDojutsu, activeStage); }
    @Override public int getUsage(String dojutsuId) { if (dojutsuId == null) return 0; return usageMap.getOrDefault(dojutsuId, 0); }
    @Override public void addUsage(String dojutsuId, int amount) { if (dojutsuId == null || amount <= 0) return; usageMap.put(dojutsuId, usageMap.getOrDefault(dojutsuId, 0) + amount); }
    @Override public float getStress(String dojutsuId) { if (dojutsuId == null) return 0.0f; return stressMap.getOrDefault(dojutsuId, 0.0f); }
    @Override public void addStress(String dojutsuId, float amount) { if (dojutsuId == null || amount <= 0) return; stressMap.put(dojutsuId, stressMap.getOrDefault(dojutsuId, 0.0f) + amount); }
    @Override public void removeStress(String dojutsuId, float amount) { if (dojutsuId == null || amount <= 0) return; float current = stressMap.getOrDefault(dojutsuId, 0.0f); stressMap.put(dojutsuId, Math.max(0.0f, current - amount)); }
    @Override public boolean isBlinded() { if (activeDojutsu == null) return false; return stressMap.getOrDefault(activeDojutsu, 0.0f) >= BLINDNESS_THRESHOLD; }
    @Override public void resetAll() { activeDojutsu = null; activeStage = 0; usageMap.clear(); stressMap.clear(); stageMap.clear(); }

    @Override public void readFromNbt(NbtCompound nbt) {
        if (nbt.contains("Active")) { String stored = nbt.getString("Active"); activeDojutsu = stored.isEmpty() ? null : stored; }
        if (nbt.contains("ActiveStage")) activeStage = nbt.getInt("ActiveStage");
        if (nbt.contains("Data")) { usageMap.clear(); stressMap.clear(); stageMap.clear(); NbtCompound data = nbt.getCompound("Data"); for (String key : data.getKeys()) { NbtCompound d = data.getCompound(key); usageMap.put(key, d.getInt("Usage")); stressMap.put(key, d.getFloat("Stress")); stageMap.put(key, d.getInt("Stage")); } }
    }

    @Override public void writeToNbt(NbtCompound nbt) {
        nbt.putString("Active", activeDojutsu != null ? activeDojutsu : "");
        nbt.putInt("ActiveStage", activeStage);
        NbtCompound data = new NbtCompound(); for (Map.Entry<String, Integer> e : usageMap.entrySet()) { NbtCompound d = new NbtCompound(); d.putInt("Usage", e.getValue()); d.putFloat("Stress", stressMap.getOrDefault(e.getKey(), 0.0f)); d.putInt("Stage", stageMap.getOrDefault(e.getKey(), 0)); data.put(e.getKey(), d); } nbt.put("Data", data);
    }
}