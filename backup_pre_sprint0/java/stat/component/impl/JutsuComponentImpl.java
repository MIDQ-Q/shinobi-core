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

/**
 * Jutsu component implementation with full NBT serialization.
 * HLD: Section 1.1
 * RULES: No ternary operator.
 */
public class JutsuComponentImpl implements IJutsuComponent {
    private static final int LOADOUT_SIZE = 5;
    private final Set<String> learned = new HashSet<>();
    private final String[] loadoutA = new String[LOADOUT_SIZE];
    private final String[] loadoutB = new String[LOADOUT_SIZE];
    private final Map<String, Integer> masteryUses = new HashMap<>();
    private int activeLoadout = 0;

    private String[] getLoadoutArray(int index) {
        if (index == 0) return loadoutA;
        return loadoutB;
    }

    @Override public Set<String> getLearnedJutsus() { return new HashSet<>(learned); }
    @Override public boolean hasLearned(String id) { return id != null && learned.contains(id); }
    @Override public boolean learnJutsu(String id) {
        if (id == null || id.isEmpty()) return false;
        return learned.add(id);
    }

    @Override
    public void forgetJutsu(String id) {
        if (id == null) return;
        learned.remove(id);
        masteryUses.remove(id);
        for (int i = 0; i < LOADOUT_SIZE; i++) {
            if (id.equals(loadoutA[i])) loadoutA[i] = null;
            if (id.equals(loadoutB[i])) loadoutB[i] = null;
        }
    }

    @Override
    public String getLoadoutSlot(int loadoutIndex, int slotIndex) {
        if (slotIndex < 0 || slotIndex >= LOADOUT_SIZE) return null;
        return getLoadoutArray(loadoutIndex)[slotIndex];
    }

    @Override
    public boolean setLoadoutSlot(int loadoutIndex, int slotIndex, String jutsuId) {
        if (slotIndex < 0 || slotIndex >= LOADOUT_SIZE) return false;
        if (jutsuId != null && !learned.contains(jutsuId)) return false;
        getLoadoutArray(loadoutIndex)[slotIndex] = jutsuId;
        return true;
    }

    @Override
    public String[] getLoadout(int loadoutIndex) {
        return getLoadoutArray(loadoutIndex).clone();
    }

    @Override public int getMasteryUses(String id) {
        if (id == null) return 0;
        return masteryUses.getOrDefault(id, 0);
    }

    @Override
    public boolean addMasteryUse(String id) {
        if (id == null || !learned.contains(id)) return false;
        masteryUses.put(id, masteryUses.getOrDefault(id, 0) + 1);
        return false;
    }

    @Override public void setMasteryUses(String id, int uses) {
        if (id == null) return;
        masteryUses.put(id, Math.max(0, uses));
    }

    @Override public Map<String, Integer> getAllMasteryUses() { return new HashMap<>(masteryUses); }
    @Override public int getActiveLoadout() { return activeLoadout; }
    @Override public void setActiveLoadout(int l) { activeLoadout = (l == 0) ? 0 : 1; }
    @Override public void toggleLoadout() {
        if (activeLoadout == 0) {
            activeLoadout = 1;
        } else {
            activeLoadout = 0;
        }
    }

    @Override
    public void resetAll() {
        learned.clear();
        masteryUses.clear();
        for (int i = 0; i < LOADOUT_SIZE; i++) {
            loadoutA[i] = null;
            loadoutB[i] = null;
        }
        activeLoadout = 0;
    }

    @Override
    public void readFromNbt(NbtCompound nbt) {
        if (nbt.contains("Learned")) {
            learned.clear();
            NbtList list = nbt.getList("Learned", NbtElement.STRING_TYPE);
            for (int i = 0; i < list.size(); i++) learned.add(list.getString(i));
        }
        if (nbt.contains("LoadoutA")) {
            NbtList list = nbt.getList("LoadoutA", NbtElement.STRING_TYPE);
            for (int i = 0; i < LOADOUT_SIZE && i < list.size(); i++) {
                String v = list.getString(i);
                loadoutA[i] = v.isEmpty() ? null : v;
            }
        }
        if (nbt.contains("LoadoutB")) {
            NbtList list = nbt.getList("LoadoutB", NbtElement.STRING_TYPE);
            for (int i = 0; i < LOADOUT_SIZE && i < list.size(); i++) {
                String v = list.getString(i);
                loadoutB[i] = v.isEmpty() ? null : v;
            }
        }
        if (nbt.contains("Mastery")) {
            masteryUses.clear();
            NbtCompound mNbt = nbt.getCompound("Mastery");
            for (String key : mNbt.getKeys()) masteryUses.put(key, mNbt.getInt(key));
        }
        if (nbt.contains("ActiveLoadout")) activeLoadout = nbt.getInt("ActiveLoadout");
    }

    @Override
    public void writeToNbt(NbtCompound nbt) {
        NbtList learnedList = new NbtList();
        for (String id : learned) learnedList.add(NbtString.of(id));
        nbt.put("Learned", learnedList);

        NbtList listA = new NbtList();
        for (int i = 0; i < LOADOUT_SIZE; i++) {
            String v = loadoutA[i];
            listA.add(NbtString.of(v != null ? v : ""));
        }
        nbt.put("LoadoutA", listA);

        NbtList listB = new NbtList();
        for (int i = 0; i < LOADOUT_SIZE; i++) {
            String v = loadoutB[i];
            listB.add(NbtString.of(v != null ? v : ""));
        }
        nbt.put("LoadoutB", listB);

        NbtCompound mNbt = new NbtCompound();
        for (Map.Entry<String, Integer> e : masteryUses.entrySet()) {
            mNbt.putInt(e.getKey(), e.getValue());
        }
        nbt.put("Mastery", mNbt);
        nbt.putInt("ActiveLoadout", activeLoadout);
    }
}