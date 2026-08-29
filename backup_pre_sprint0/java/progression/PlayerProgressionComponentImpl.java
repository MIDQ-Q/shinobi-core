package com.example.shinobicore.progression;

import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.nbt.NbtCompound;

import java.util.HashMap;
import java.util.Map;

/**
 * Implementation of PlayerProgressionComponent.
 * Stores level, XP, SP and stats, persists to NBT via CCA.
 * HLD Section 10 (Progression System).
 */
public class PlayerProgressionComponentImpl implements PlayerProgressionComponent {

    private final PlayerEntity player;

    private int level = 1;
    private int xp = 0;
    private int sp = 0;
    private final Map<String, Integer> stats = new HashMap<>();

    public PlayerProgressionComponentImpl(PlayerEntity player) {
        this.player = player;
    }

    // ---- Level & XP ----

    @Override
    public int getLevel() { return level; }

    @Override
    public void setLevel(int level) { this.level = Math.max(1, level); }

    @Override
    public int getXp() { return xp; }

    @Override
    public void addXP(int amount) {
        this.xp += Math.max(0, amount);
    }

    // ---- Skill Points ----

    @Override
    public int getSP() { return sp; }

    @Override
    public void addSP(int amount) {
        this.sp += Math.max(0, amount);
    }

    @Override
    public boolean spendSP(int amount) {
        if (amount <= 0) return false;
        if (this.sp < amount) return false;
        this.sp -= amount;
        return true;
    }

    // ---- Stats ----

    @Override
    public int getStat(String name) {
        return stats.getOrDefault(name, 0);
    }

    @Override
    public void setStat(String name, int value) {
        stats.put(name, Math.max(0, value));
    }

    @Override
    public void addStat(String name, int amount) {
        stats.put(name, stats.getOrDefault(name, 0) + amount);
    }

    // ---- NBT Persistence ----

    @Override
    public void readFromNbt(NbtCompound tag) {
        this.level = tag.getInt("Level");
        this.xp = tag.getInt("XP");
        this.sp = tag.getInt("SP");

        this.stats.clear();
        NbtCompound statsTag = tag.getCompound("Stats");
        for (String key : statsTag.getKeys()) {
            this.stats.put(key, statsTag.getInt(key));
        }
    }

    @Override
    public void writeToNbt(NbtCompound tag) {
        tag.putInt("Level", this.level);
        tag.putInt("XP", this.xp);
        tag.putInt("SP", this.sp);

        NbtCompound statsTag = new NbtCompound();
        for (Map.Entry<String, Integer> e : stats.entrySet()) {
            statsTag.putInt(e.getKey(), e.getValue());
        }
        tag.put("Stats", statsTag);
    }
}