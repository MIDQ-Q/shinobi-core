package com.example.shinobicore.modules.combat.component;

import com.example.shinobicore.modules.combat.common.Stance;
import net.minecraft.nbt.NbtCompound;

public class CombatComponentImpl implements CombatComponent {
    private Stance currentStance = Stance.NONE;
    private boolean blocking = false;
    private boolean parrying = false;
    private int comboStep = 0;
    private boolean sheathed = false;
    private long parryFailRecoveryUntil = 0;
    private long comboExpireAtMs = 0;

    @Override public Stance getStance() { return currentStance; }
    @Override public void setStance(Stance stance) { this.currentStance = stance; }
    @Override public boolean isBlocking() { return blocking; }
    @Override public void setBlocking(boolean blocking) { this.blocking = blocking; }
    @Override public boolean isParrying() { return parrying; }
    @Override public void setParrying(boolean parrying) { this.parrying = parrying; }
    @Override public int getComboStep() { return comboStep; }
    @Override public void setComboStep(int step) { this.comboStep = step; }
    @Override public void resetCombo() { this.comboStep = 0; this.comboExpireAtMs = 0; }
    @Override public boolean isSheathed() { return sheathed; }
    @Override public void setSheathed(boolean sheathed) { this.sheathed = sheathed; }
    @Override public long getParryFailRecoveryUntil() { return parryFailRecoveryUntil; }
    @Override public void setParryFailRecoveryUntil(long timestampMs) { this.parryFailRecoveryUntil = timestampMs; }
    @Override public long getComboExpireAtMs() { return comboExpireAtMs; }
    @Override public void setComboExpireAtMs(long timestampMs) { this.comboExpireAtMs = timestampMs; }

    @Override
    public void readFromNbt(NbtCompound tag) {
        String stanceName = tag.getString("stance");
        try {
            this.currentStance = Stance.valueOf(stanceName.toUpperCase());
        } catch (Exception e) {
            this.currentStance = Stance.NONE;
        }
        this.blocking = tag.getBoolean("blocking");
        this.comboStep = tag.getInt("comboStep");
        this.sheathed = tag.getBoolean("sheathed");
        this.parryFailRecoveryUntil = tag.getLong("parryFailRecoveryUntil");
        this.comboExpireAtMs = tag.getLong("comboExpireAtMs");
    }

    @Override
    public void writeToNbt(NbtCompound tag) {
        tag.putString("stance", this.currentStance.name());
        tag.putBoolean("blocking", this.blocking);
        tag.putInt("comboStep", this.comboStep);
        tag.putBoolean("sheathed", this.sheathed);
        tag.putLong("parryFailRecoveryUntil", this.parryFailRecoveryUntil);
        tag.putLong("comboExpireAtMs", this.comboExpireAtMs);
    }
}