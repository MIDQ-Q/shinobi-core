package com.example.shinobicore.stat.component.impl;

import com.example.shinobicore.stat.component.IJutsuComponent;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.nbt.NbtElement;
import net.minecraft.nbt.NbtList;
import net.minecraft.nbt.NbtString;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class JutsuComponentImpl implements IJutsuComponent {
    private static final int LOADOUT_SIZE = 5;
    private final Set<String> learned = new HashSet<>();
    private final String[] loadoutA = new String[LOADOUT_SIZE];
    private final String[] loadoutB = new String[LOADOUT_SIZE];
    private final Map<String, Integer> masteryUses = new HashMap<>();
    private int activeLoadout = 0;

    @Override public Set<String> getLearnedJutsus() { return new HashSet<>(learned); }
    @Override public boolean hasLearned(String jutsuId) { return jutsuId != null && learned.contains(jutsuId); }
    @Override public boolean learnJutsu(String jutsuId) { if (jutsuId == null || jutsuId.isEmpty()) return false; return learned.add(jutsuId); }
    @Override public void forgetJutsu(String jutsuId) { if (jutsuId == null) return; learned.remove(jutsuId); masteryUses.remove(jutsuId); for (int i = 0; i < LOADOUT_SIZE; i++) { if (jutsuId.equals(loadoutA[i])) loadoutA[i] = null; if (jutsuId.equals(loadoutB[i])) loadoutB[i] = null; } }
    @Override public String getLoadoutSlot(int loadoutIndex, int slotIndex) { if (slotIndex < 0 || slotIndex >= LOADOUT_SIZE) return null; return (loadoutIndex == 0 ? loadoutA : loadoutB)[slotIndex]; }
    @Override public boolean setLoadoutSlot(int loadoutIndex, int slotIndex, String jutsuId) { if (slotIndex < 0 || slotIndex >= LOADOUT_SIZE) return false; if (jutsuId != null && !learned.contains(jutsuId)) return false; (loadoutIndex == 0 ? loadoutA : loadoutB)[slotIndex] = jutsuId; return true; }
    @Override public String[] getLoadout(int loadoutIndex) { return (loadoutIndex == 0 ? loadoutA : loadoutB).clone(); }
    @Override public int getMasteryUses(String jutsuId) { if (jutsuId == null) return 0; return masteryUses.getOrDefault(jutsuId, 0); }
    @Override public boolean addMasteryUse(String jutsuId) { if (jutsuId == null || !learned.contains(jutsuId)) return false; masteryUses.put(jutsuId, masteryUses.getOrDefault(jutsuId, 0) + 1); return false; }
    @Override public void setMasteryUses(String jutsuId, int uses) { if (jutsuId == null) return; masteryUses.put(jutsuId, Math.max(0, uses)); }
    @Override public Map<String, Integer> getAllMasteryUses() { return new HashMap<>(masteryUses); }
    @Override public int getActiveLoadout() { return activeLoadout; }
    @Override public void setActiveLoadout(int loadoutIndex) { activeLoadout = (loadoutIndex == 0) ? 0 : 1; }
    @Override public void toggleLoadout() { activeLoadout = (activeLoadout == 0) ? 1 : 0; }
    @Override public void resetAll() { learned.clear(); masteryUses.clear(); for (int i = 0; i < LOADOUT_SIZE; i++) { loadoutA[i] = null; loadoutB[i] = null; } activeLoadout = 0; }

    @Override public void readFromNbt(NbtCompound nbt) {
        if (nbt.contains("Learned")) { learned.clear(); NbtList list = nbt.getList("Learned", NbtElement.STRING_TYPE); for (int i = 0; i < list.size(); i++) learned.add(list.getString(i)); }
        if (nbt.contains("LoadoutA")) { NbtList list = nbt.getList("LoadoutA", NbtElement.STRING_TYPE); for (int i = 0; i < LOADOUT_SIZE && i < list.size(); i++) { String v = list.getString(i); loadoutA[i] = v.isEmpty() ? null : v; } }
        if (nbt.contains("LoadoutB")) { NbtList list = nbt.getList("LoadoutB", NbtElement.STRING_TYPE); for (int i = 0; i < LOADOUT_SIZE && i < list.size(); i++) { String v = list.getString(i); loadoutB[i] = v.isEmpty() ? null : v; } }
        if (nbt.contains("Mastery")) { masteryUses.clear(); NbtCompound mNbt = nbt.getCompound("Mastery"); for (String key : mNbt.getKeys()) masteryUses.put(key, mNbt.getInt(key)); }
        if (nbt.contains("ActiveLoadout")) activeLoadout = nbt.getInt("ActiveLoadout");
    }

    @Override public void writeToNbt(NbtCompound nbt) {
        NbtList learnedList = new NbtList(); for (String id : learned) learnedList.add(NbtString.of(id)); nbt.put("Learned", learnedList);
        NbtList listA = new NbtList(); for (int i = 0; i < LOADOUT_SIZE; i++) { String v = loadoutA[i]; listA.add(NbtString.of(v != null ? v : "")); } nbt.put("LoadoutA", listA);
        NbtList listB = new NbtList(); for (int i = 0; i < LOADOUT_SIZE; i++) { String v = loadoutB[i]; listB.add(NbtString.of(v != null ? v : "")); } nbt.put("LoadoutB", listB);
        NbtCompound mNbt = new NbtCompound(); for (Map.Entry<String, Integer> e : masteryUses.entrySet()) mNbt.putInt(e.getKey(), e.getValue()); nbt.put("Mastery", mNbt);
        nbt.putInt("ActiveLoadout", activeLoadout);
    }
}