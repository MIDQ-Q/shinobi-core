package com.example.shinobicore.stat.component.impl;

import com.example.shinobicore.stat.component.ICombatComponent;
import net.minecraft.nbt.NbtCompound;

/**
 * Combat state storage with full NBT serialization.
 * HLD: Section 1.1 (CombatComponent)
 */
public class CombatComponentImpl implements ICombatComponent {

    private int comboStep = 0;
    private long lastAttackMs = 0;
    private String stanceId = "aggressive";
    private boolean blocking = false;
    private int gateState = 0;

    @Override public int getComboStep() { return comboStep; }
    @Override public void setComboStep(int step) { this.comboStep = Math.max(0, step); }

    @Override
    public void incrementCombo() {
        if (this.comboStep >= 3) {
            this.comboStep = 0;
        } else {
            this.comboStep++;
        }
    }

    @Override public void resetCombo() { this.comboStep = 0; }
    @Override public long getLastAttackMs() { return lastAttackMs; }
    @Override public void setLastAttackMs(long time) { this.lastAttackMs = time; }
    @Override public String getStanceId() { return stanceId; }
    @Override public void setStanceId(String id) { this.stanceId = id; }
    @Override public boolean isBlocking() { return blocking; }
    @Override public void setBlocking(boolean b) { this.blocking = b; }
    @Override public int getGateState() { return gateState; }
    @Override public void setGateState(int gate) { this.gateState = Math.max(0, Math.min(8, gate)); }

    @Override
    public void readFromNbt(NbtCompound nbt) {
        if (nbt.contains("ComboStep")) comboStep = nbt.getInt("ComboStep");
        if (nbt.contains("LastAttackMs")) lastAttackMs = nbt.getLong("LastAttackMs");
        if (nbt.contains("StanceId")) stanceId = nbt.getString("StanceId");
        if (nbt.contains("Blocking")) blocking = nbt.getBoolean("Blocking");
        if (nbt.contains("GateState")) gateState = nbt.getInt("GateState");
    }

    @Override
    public void writeToNbt(NbtCompound nbt) {
        nbt.putInt("ComboStep", comboStep);
        nbt.putLong("LastAttackMs", lastAttackMs);
        nbt.putString("StanceId", stanceId);
        nbt.putBoolean("Blocking", blocking);
        nbt.putInt("GateState", gateState);
    }
}