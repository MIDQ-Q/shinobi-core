package com.example.shinobicore.stat.component.impl;

import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.StatType;
import com.example.shinobicore.util.ShinobiConstants;
import net.minecraft.nbt.NbtCompound;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class StatsComponentImpl implements IStatsComponent {
    private final Map<StatType, Integer> statLevels = new EnumMap<>(StatType.class);
    private final Map<StatType, Integer> statXp = new EnumMap<>(StatType.class);
    private int skillPoints = 0;
    private int bodyHP = 0, bodySpeed = 0, bodyJump = 0;
    private int bodyVitality = 0, bodyReserve = 0, bodyEndurance = 0;
    private final Set<String> unlockedPassives = new HashSet<>();

    public StatsComponentImpl() {
        // SPRINT A: Starting level is 1 (not 0)
        for (StatType t : StatType.values()) { statLevels.put(t, 1); statXp.put(t, 0); }
    }

    @Override public int getStatLevel(StatType type) { return statLevels.getOrDefault(type, 0); }
    @Override public void setStatLevel(StatType type, int level) { statLevels.put(type, Math.max(0, Math.min(ShinobiConstants.MAX_STAT_LEVEL, level))); }
    @Override public int addStatLevel(StatType type, int amount) { int l = getStatLevel(type) + amount; setStatLevel(type, l); return l; }
    @Override public int getStatXp(StatType type) { return statXp.getOrDefault(type, 0); }
    @Override public boolean addXp(StatType type, int amount) { if (amount <= 0) return false; int xp = getStatXp(type) + amount; int req = getXpForNextLevel(type); boolean lvlUp = false; while (xp >= req && getStatLevel(type) < ShinobiConstants.MAX_STAT_LEVEL) { xp -= req; addStatLevel(type, 1); skillPoints++; lvlUp = true; req = getXpForNextLevel(type); } statXp.put(type, xp); return lvlUp; }
    @Override public void setStatXp(StatType type, int xp) { statXp.put(type, Math.max(0, xp)); }
    @Override public int getSkillPoints() { return skillPoints; }
    @Override public int getSp() { return skillPoints; }
    @Override public void addSp(int amount) { skillPoints = Math.max(0, skillPoints + amount); }
    @Override public void setSkillPoints(int points) { skillPoints = Math.max(0, points); }
    @Override public void addSkillPoints(int amount) { skillPoints = Math.max(0, skillPoints + amount); }
    @Override public boolean spendSkillPoints(int amount) { if (amount <= 0) return true; if (skillPoints < amount) return false; skillPoints -= amount; return true; }
    @Override public int getBodyLevelHP() { return bodyHP; }
    @Override public void setBodyLevelHP(int level) { bodyHP = Math.max(0, Math.min(10, level)); }
    @Override public int getBodyLevelSpeed() { return bodySpeed; }
    @Override public void setBodyLevelSpeed(int level) { bodySpeed = Math.max(0, Math.min(10, level)); }
    @Override public int getBodyLevelJump() { return bodyJump; }
    @Override public void setBodyLevelJump(int level) { bodyJump = Math.max(0, Math.min(10, level)); }
    @Override public int getBodyLevelVitality() { return bodyVitality; }
    @Override public void setBodyLevelVitality(int level) { bodyVitality = Math.max(0, Math.min(100, level)); }
    @Override public int getBodyLevelReserve() { return bodyReserve; }
    @Override public void setBodyLevelReserve(int level) { bodyReserve = Math.max(0, Math.min(100, level)); }
    @Override public int getBodyLevelEndurance() { return bodyEndurance; }
    @Override public void setBodyLevelEndurance(int level) { bodyEndurance = Math.max(0, Math.min(100, level)); }
    @Override public Set<String> getUnlockedPassives() { return new HashSet<>(unlockedPassives); }
    @Override public boolean unlockPassive(String passiveId) { return unlockedPassives.add(passiveId); }
    @Override public boolean hasPassive(String passiveId) { return unlockedPassives.contains(passiveId); }
    @Override public void removePassive(String passiveId) { unlockedPassives.remove(passiveId); }
    @Override public int getXpForNextLevel(StatType type) { int level = getStatLevel(type); return (int)(ShinobiConstants.XP_BASE * (1.0f + level * ShinobiConstants.XP_FACTOR + level * level * ShinobiConstants.XP_SQUARED_FACTOR)); }
    @Override public float getProgressToNextLevel(StatType type) { int req = getXpForNextLevel(type); if (req <= 0) return 1.0f; return (float) getStatXp(type) / (float) req; }
    // SHINOBICORE:SPRINT_A:BEGIN - New stat methods
    @Override
    public boolean tryLevelUp(StatType type) {
        int currentLevel = statLevels.getOrDefault(type, 0);
        int currentXp = statXp.getOrDefault(type, 0);
        int requiredXp = getXpForNextLevel(type);
        
        if (currentXp >= requiredXp && currentLevel < ShinobiConstants.MAX_STAT_LEVEL) {
            currentXp -= requiredXp;
            currentLevel++;
            statLevels.put(type, currentLevel);
            statXp.put(type, currentXp);
            
            // Award SP
            int spGain = ShinobiConstants.SP_PER_LEVEL_UP;
            addSkillPoints(spGain);
            
            // TODO: Send level up event to client
            return true;
        }
        return false;
    }
    // SHINOBICORE:SPRINT_A:END
    
    @Override public void resetToDefaults() { for (StatType t : StatType.values()) { statLevels.put(t, 0); statXp.put(t, 0); } skillPoints = 0; bodyHP = 0; bodySpeed = 0; bodyJump = 0; bodyVitality = 0; bodyReserve = 0; bodyEndurance = 0; unlockedPassives.clear(); }

    @Override
    public boolean trySetStatLevel(StatType type, int newLevel) {
        int currentLevel = getStatLevel(type);
        // Anti-cheat validation: suspicious level jump
        if (newLevel > currentLevel + 1 && newLevel > 1) {
            return false; 
        }
        setStatLevel(type, newLevel);
        return true;
    }
    @Override public void readFromNbt(NbtCompound nbt) {
        if (nbt.contains("StatLevels")) { NbtCompound levels = nbt.getCompound("StatLevels"); for (String key : levels.getKeys()) { StatType t = StatType.fromId(key); if (t != null) statLevels.put(t, levels.getInt(key)); } }
        if (nbt.contains("StatXP")) { NbtCompound xpNbt = nbt.getCompound("StatXP"); for (String key : xpNbt.getKeys()) { StatType t = StatType.fromId(key); if (t != null) statXp.put(t, xpNbt.getInt(key)); } }
        if (nbt.contains("SkillPoints")) skillPoints = nbt.getInt("SkillPoints");
        if (nbt.contains("BodyHP")) bodyHP = nbt.getInt("BodyHP");
        if (nbt.contains("BodySpeed")) bodySpeed = nbt.getInt("BodySpeed");
        if (nbt.contains("BodyJump")) bodyJump = nbt.getInt("BodyJump");
        if (nbt.contains("BodyVitality")) bodyVitality = nbt.getInt("BodyVitality");
        if (nbt.contains("BodyReserve")) bodyReserve = nbt.getInt("BodyReserve");
        if (nbt.contains("BodyEndurance")) bodyEndurance = nbt.getInt("BodyEndurance");
        if (nbt.contains("Passives")) { unlockedPassives.clear(); net.minecraft.nbt.NbtList list = nbt.getList("Passives", net.minecraft.nbt.NbtElement.STRING_TYPE); for (int i = 0; i < list.size(); i++) unlockedPassives.add(list.getString(i)); }
        for (StatType t : StatType.values()) { statLevels.putIfAbsent(t, 0); statXp.putIfAbsent(t, 0); }
    }

    @Override public void writeToNbt(NbtCompound nbt) {
        NbtCompound levels = new NbtCompound(); for (Map.Entry<StatType, Integer> e : statLevels.entrySet()) levels.putInt(e.getKey().getId(), e.getValue()); nbt.put("StatLevels", levels);
        NbtCompound xpNbt = new NbtCompound(); for (Map.Entry<StatType, Integer> e : statXp.entrySet()) xpNbt.putInt(e.getKey().getId(), e.getValue()); nbt.put("StatXP", xpNbt);
        nbt.putInt("SkillPoints", skillPoints);
        nbt.putInt("BodyHP", bodyHP); nbt.putInt("BodySpeed", bodySpeed); nbt.putInt("BodyJump", bodyJump);
        nbt.putInt("BodyVitality", bodyVitality); nbt.putInt("BodyReserve", bodyReserve); nbt.putInt("BodyEndurance", bodyEndurance);
        net.minecraft.nbt.NbtList passives = new net.minecraft.nbt.NbtList(); for (String p : unlockedPassives) passives.add(net.minecraft.nbt.NbtString.of(p)); nbt.put("Passives", passives);
    }

    @Override
    public float getPhysicalDamageBonus() {
        int level = statLevels.getOrDefault(StatType.PHYSICAL, 0);
        return level * 0.02f;
    }

    @Override
    public float getSpiritualChakraBonus() {
        int level = statLevels.getOrDefault(StatType.SPIRITUAL, 0);
        return level * 0.015f;
    }

    @Override
    public float getFocusCostReduction() {
        int level = statLevels.getOrDefault(StatType.FOCUS, 0);
        return Math.min(0.5f, level * 0.01f);
    }

    @Override
    public float getWillpowerFatigueReduction() {
        int level = statLevels.getOrDefault(StatType.WILLPOWER, 0);
        return Math.min(0.5f, level * 0.01f);
    }

    @Override
    public float getInsightXpMultiplier() {
        int level = statLevels.getOrDefault(StatType.INSIGHT, 0);
        return 1.0f + (level * 0.02f);
    }}