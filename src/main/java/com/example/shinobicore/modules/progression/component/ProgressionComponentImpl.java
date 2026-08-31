package com.example.shinobicore.modules.progression.component;

import net.minecraft.nbt.NbtCompound;
import net.minecraft.nbt.NbtElement;
import net.minecraft.nbt.NbtList;
import net.minecraft.nbt.NbtString;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class ProgressionComponentImpl implements ProgressionComponent {
    private int playerLevel = 1;
    private int currentXp = 0;
    private int availableSp = 0;
    private final Set<String> unlockedNodes = new HashSet<>();
    private final Set<String> unlockedElements = new HashSet<>();
    private final Map<String, Integer> statLevels = new HashMap<>();
    private final Map<String, Integer> bodyStatLevels = new HashMap<>();
    private final Map<String, Float> statXpMap = new HashMap<>();
    private final Map<String, Integer> jutsuLevels = new HashMap<>();
    private final Map<String, Integer> jutsuUses = new HashMap<>();
    private final Map<String, Float> jutsuXpMap = new HashMap<>();
    private final Map<String, Float> attunementProgressMap = new HashMap<>();
    private final Map<String, Integer> reputationMap = new HashMap<>();

    @Override public int getPlayerLevel() { return playerLevel; }
    @Override public void setPlayerLevel(int level) { this.playerLevel = Math.max(1, level); }
    @Override public int getCurrentXp() { return currentXp; }
    @Override public void addXp(int amount) { this.currentXp += Math.max(0, amount); }
    @Override public void subtractXp(int amount) { this.currentXp = Math.max(0, this.currentXp - amount); }
    @Override public int getAvailableSp() { return availableSp; }
    @Override public void addSp(int amount) { this.availableSp += Math.max(0, amount); }
    @Override public void spendSp(int amount) { this.availableSp = Math.max(0, this.availableSp - amount); }

    @Override public Set<String> getUnlockedNodes() { return unlockedNodes; }
    @Override public boolean isNodeUnlocked(String nodeId) { return unlockedNodes.contains(nodeId); }
    @Override public void unlockNode(String nodeId) { unlockedNodes.add(nodeId); }

    @Override public Set<String> getUnlockedElements() { return unlockedElements; }
    @Override public boolean isElementUnlocked(String elementId) { return unlockedElements.contains(elementId); }
    @Override public void unlockElement(String elementId) { unlockedElements.add(elementId); }
    @Override public int getUnlockedElementCount() { return unlockedElements.size(); }

    @Override public int getStatLevel(String statId) { return statLevels.getOrDefault(statId, 0); }
    @Override public void setStatLevel(String statId, int level) { statLevels.put(statId, Math.max(0, level)); }
    @Override public Map<String, Integer> getAllStats() { return new HashMap<>(statLevels); }

    @Override public int getBodyStatLevel(String id) { return bodyStatLevels.getOrDefault(id, 0); }
    @Override public void setBodyStatLevel(String id, int level) { bodyStatLevels.put(id, Math.max(0, level)); }
    @Override public Map<String, Integer> getAllBodyStats() { return new HashMap<>(bodyStatLevels); }

    @Override public float getStatXp(String statId) { return statXpMap.getOrDefault(statId, 0.0f); }
    @Override public void addStatXp(String statId, float amount) {
        statXpMap.merge(statId, Math.max(0, amount), Float::sum);
    }

    @Override public int getJutsuLevel(String jutsuId) { return jutsuLevels.getOrDefault(jutsuId, 0); }
    @Override public void setJutsuLevel(String jutsuId, int level) { jutsuLevels.put(jutsuId, Math.max(0, level)); }
    @Override public int getJutsuUses(String jutsuId) { return jutsuUses.getOrDefault(jutsuId, 0); }
    @Override public void addJutsuUse(String jutsuId) { jutsuUses.merge(jutsuId, 1, Integer::sum); }
    @Override public float getJutsuXp(String jutsuId) { return jutsuXpMap.getOrDefault(jutsuId, 0.0f); }
    @Override public void addJutsuXp(String jutsuId, float amount) {
        jutsuXpMap.merge(jutsuId, Math.max(0, amount), Float::sum);
    }
    @Override public void setJutsuXp(String jutsuId, float xp) { jutsuXpMap.put(jutsuId, Math.max(0, xp)); }

    @Override public float getAttunementProgress(String elementId) {
        return attunementProgressMap.getOrDefault(elementId, 0.0f);
    }
    @Override public void setAttunementProgress(String elementId, float progress) {
        attunementProgressMap.put(elementId, Math.max(0, Math.min(1, progress)));
    }

    @Override public int getReputation(String factionId) { return reputationMap.getOrDefault(factionId, 0); }
    @Override public void setReputation(String factionId, int value) { reputationMap.put(factionId, value); }
    @Override public Map<String, Integer> getAllReputation() { return new HashMap<>(reputationMap); }

    @Override
    public void readFromNbt(NbtCompound tag) {
        playerLevel = tag.contains("Level") ? tag.getInt("Level") : 1;
        currentXp = tag.contains("Xp") ? tag.getInt("Xp") : 0;
        availableSp = tag.contains("SP") ? tag.getInt("SP") : 0;

        unlockedNodes.clear();
        if (tag.contains("Nodes", NbtElement.LIST_TYPE)) {
            NbtList list = tag.getList("Nodes", NbtElement.STRING_TYPE);
            for (int i = 0; i < list.size(); i++) unlockedNodes.add(list.getString(i));
        }

        unlockedElements.clear();
        if (tag.contains("Elements", NbtElement.LIST_TYPE)) {
            NbtList list = tag.getList("Elements", NbtElement.STRING_TYPE);
            for (int i = 0; i < list.size(); i++) unlockedElements.add(list.getString(i));
        }

        readIntMap(tag, "Stats", statLevels);
        readIntMap(tag, "BodyStats", bodyStatLevels);
        readFloatMap(tag, "StatXp", statXpMap);
        readIntMap(tag, "JutsuLevels", jutsuLevels);
        readIntMap(tag, "JutsuUses", jutsuUses);
        readFloatMap(tag, "JutsuXp", jutsuXpMap);
        readFloatMap(tag, "AttuneProg", attunementProgressMap);
        readIntMap(tag, "Reputation", reputationMap);
    }

    @Override
    public void writeToNbt(NbtCompound tag) {
        tag.putInt("Level", playerLevel);
        tag.putInt("Xp", currentXp);
        tag.putInt("SP", availableSp);

        NbtList nodeList = new NbtList();
        for (String node : unlockedNodes) nodeList.add(NbtString.of(node));
        tag.put("Nodes", nodeList);

        NbtList elemList = new NbtList();
        for (String el : unlockedElements) elemList.add(NbtString.of(el));
        tag.put("Elements", elemList);

        writeIntMap(tag, "Stats", statLevels);
        writeIntMap(tag, "BodyStats", bodyStatLevels);
        writeFloatMap(tag, "StatXp", statXpMap);
        writeIntMap(tag, "JutsuLevels", jutsuLevels);
        writeIntMap(tag, "JutsuUses", jutsuUses);
        writeFloatMap(tag, "JutsuXp", jutsuXpMap);
        writeFloatMap(tag, "AttuneProg", attunementProgressMap);
        writeIntMap(tag, "Reputation", reputationMap);
    }

    private void readIntMap(NbtCompound tag, String key, Map<String, Integer> map) {
        map.clear();
        if (tag.contains(key, NbtElement.COMPOUND_TYPE)) {
            NbtCompound sub = tag.getCompound(key);
            for (String k : sub.getKeys()) map.put(k, sub.getInt(k));
        }
    }

    private void readFloatMap(NbtCompound tag, String key, Map<String, Float> map) {
        map.clear();
        if (tag.contains(key, NbtElement.COMPOUND_TYPE)) {
            NbtCompound sub = tag.getCompound(key);
            for (String k : sub.getKeys()) map.put(k, sub.getFloat(k));
        }
    }

    private void writeIntMap(NbtCompound tag, String key, Map<String, Integer> map) {
        NbtCompound sub = new NbtCompound();
        for (Map.Entry<String, Integer> e : map.entrySet()) sub.putInt(e.getKey(), e.getValue());
        tag.put(key, sub);
    }

    private void writeFloatMap(NbtCompound tag, String key, Map<String, Float> map) {
        NbtCompound sub = new NbtCompound();
        for (Map.Entry<String, Float> e : map.entrySet()) sub.putFloat(e.getKey(), e.getValue());
        tag.put(key, sub);
    }
}