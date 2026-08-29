package com.example.shinobicore.stat.component.impl;

import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.component.IStatsComponent;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.nbt.NbtElement;
import net.minecraft.nbt.NbtList;
import net.minecraft.nbt.NbtString;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class StatsComponentImpl implements IStatsComponent {
    private final Map<StatType, Integer> statLevels = new HashMap<>();
    private final Map<StatType, Integer> statXp = new HashMap<>();
    private int skillPoints = 0;
    private int bodyLevelHP = 0;
    private int bodyLevelSpeed = 0;
    private int bodyLevelJump = 0;
    private int bodyLevelVitality = 0;
    private int bodyLevelReserve = 0;
    private int bodyLevelEndurance = 0;
    private final Set<String> unlockedPassives = new HashSet<>();

    public StatsComponentImpl() { resetToDefaults(); }

    @Override public int getStatLevel(StatType type) { return statLevels.getOrDefault(type, 0); }
    @Override public void setStatLevel(StatType type, int level) { statLevels.put(type, Math.max(0, level)); }
    @Override public int addStatLevel(StatType type, int amount) {
        int l = getStatLevel(type) + amount;
        setStatLevel(type, l);
        return l;
    }
    @Override public int getStatXp(StatType type) { return statXp.getOrDefault(type, 0); }
    @Override public boolean addXp(StatType type, int amount) {
        if (amount <= 0) return false;
        int xp = getStatXp(type) + amount;
        int req = getXpForNextLevel(type);
        boolean lvlUp = false;
        while (xp >= req && getStatLevel(type) < 100) {
            xp -= req;
            addStatLevel(type, 1);
            skillPoints++;
            lvlUp = true;
            req = getXpForNextLevel(type);
        }
        statXp.put(type, xp);
        return lvlUp;
    }
    @Override public void setStatXp(StatType type, int xp) { statXp.put(type, Math.max(0, xp)); }
    @Override public int getSkillPoints() { return skillPoints; }
    @Override public void setSkillPoints(int points) { skillPoints = Math.max(0, points); }
    @Override public void addSkillPoints(int amount) { skillPoints = Math.max(0, skillPoints + amount); }
    @Override public boolean spendSkillPoints(int amount) {
        if (amount <= 0) return true;
        if (skillPoints < amount) return false;
        skillPoints -= amount;
        return true;
    }
    @Override public int getBodyLevelHP() { return bodyLevelHP; }
    @Override public void setBodyLevelHP(int level) { bodyLevelHP = clamp(level, 10); }
    @Override public int getBodyLevelSpeed() { return bodyLevelSpeed; }
    @Override public void setBodyLevelSpeed(int level) { bodyLevelSpeed = clamp(level, 10); }
    @Override public int getBodyLevelJump() { return bodyLevelJump; }
    @Override public void setBodyLevelJump(int level) { bodyLevelJump = clamp(level, 10); }
    @Override public int getBodyLevelVitality() { return bodyLevelVitality; }
    @Override public void setBodyLevelVitality(int level) { bodyLevelVitality = clamp(level, 100); }
    @Override public int getBodyLevelReserve() { return bodyLevelReserve; }
    @Override public void setBodyLevelReserve(int level) { bodyLevelReserve = clamp(level, 100); }
    @Override public int getBodyLevelEndurance() { return bodyLevelEndurance; }
    @Override public void setBodyLevelEndurance(int level) { bodyLevelEndurance = clamp(level, 100); }

    private static int clamp(int v, int max) { return Math.max(0, Math.min(max, v)); }

    @Override public Set<String> getUnlockedPassives() { return new HashSet<>(unlockedPassives); }
    @Override public boolean unlockPassive(String id) { return unlockedPassives.add(id); }
    @Override public boolean hasPassive(String id) { return unlockedPassives.contains(id); }
    @Override public void removePassive(String id) { unlockedPassives.remove(id); }

    @Override public int getXpForNextLevel(StatType type) {
        return (int) Math.floor(100.0 * Math.pow(1.5, getStatLevel(type)));
    }
    @Override public float getProgressToNextLevel(StatType type) {
        int req = getXpForNextLevel(type);
        if (req <= 0) return 1.0f;
        return (float) getStatXp(type) / (float) req;
    }

    @Override public void resetToDefaults() {
        statLevels.clear(); statXp.clear(); unlockedPassives.clear();
        skillPoints = 0;
        bodyLevelHP = 0; bodyLevelSpeed = 0; bodyLevelJump = 0;
        bodyLevelVitality = 0; bodyLevelReserve = 0; bodyLevelEndurance = 0;
        for (StatType t : StatType.values()) { statLevels.put(t, 0); statXp.put(t, 0); }
    }

    @Override public void readFromNbt(NbtCompound nbt) {
        if (nbt.contains("StatLevels")) {
            NbtCompound levels = nbt.getCompound("StatLevels");
            for (String key : levels.getKeys()) {
                StatType t = StatType.fromString(key);
                if (t != null) statLevels.put(t, levels.getInt(key));
            }
        }
        if (nbt.contains("StatXP")) {
            NbtCompound xpNbt = nbt.getCompound("StatXP");
            for (String key : xpNbt.getKeys()) {
                StatType t = StatType.fromString(key);
                if (t != null) statXp.put(t, xpNbt.getInt(key));
            }
        }
        if (nbt.contains("SkillPoints")) skillPoints = nbt.getInt("SkillPoints");
        if (nbt.contains("BodyHP")) bodyLevelHP = nbt.getInt("BodyHP");
        if (nbt.contains("BodySpeed")) bodyLevelSpeed = nbt.getInt("BodySpeed");
        if (nbt.contains("BodyJump")) bodyLevelJump = nbt.getInt("BodyJump");
        if (nbt.contains("BodyVitality")) bodyLevelVitality = nbt.getInt("BodyVitality");
        if (nbt.contains("BodyReserve")) bodyLevelReserve = nbt.getInt("BodyReserve");
        if (nbt.contains("BodyEndurance")) bodyLevelEndurance = nbt.getInt("BodyEndurance");
        if (nbt.contains("Passives")) {
            unlockedPassives.clear();
            NbtList list = nbt.getList("Passives", NbtElement.STRING_TYPE);
            for (int i = 0; i < list.size(); i++) unlockedPassives.add(list.getString(i));
        }
        for (StatType t : StatType.values()) {
            statLevels.putIfAbsent(t, 0);
            statXp.putIfAbsent(t, 0);
        }
    }

    @Override public void writeToNbt(NbtCompound nbt) {
        NbtCompound levels = new NbtCompound();
        for (Map.Entry<StatType, Integer> e : statLevels.entrySet()) levels.putInt(e.getKey().getId(), e.getValue());
        nbt.put("StatLevels", levels);
        NbtCompound xpNbt = new NbtCompound();
        for (Map.Entry<StatType, Integer> e : statXp.entrySet()) xpNbt.putInt(e.getKey().getId(), e.getValue());
        nbt.put("StatXP", xpNbt);
        nbt.putInt("SkillPoints", skillPoints);
        nbt.putInt("BodyHP", bodyLevelHP);
        nbt.putInt("BodySpeed", bodyLevelSpeed);
        nbt.putInt("BodyJump", bodyLevelJump);
        nbt.putInt("BodyVitality", bodyLevelVitality);
        nbt.putInt("BodyReserve", bodyLevelReserve);
        nbt.putInt("BodyEndurance", bodyLevelEndurance);
        NbtList passives = new NbtList();
        for (String p : unlockedPassives) passives.add(NbtString.of(p));
        nbt.put("Passives", passives);
    }
}