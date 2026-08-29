package com.example.shinobicore.stat.component.impl;

import com.example.shinobicore.stat.component.IParkourComponent;
import com.example.shinobicore.stat.component.NinjaPose;
import net.minecraft.nbt.NbtCompound;

public class ParkourComponentImpl implements IParkourComponent {
    private int jumpsLeft = 3;
    private int dodgeCooldown = 0;
    private int iframeTicks = 0;
    private NinjaPose currentPose = NinjaPose.NORMAL;

    @Override public int getJumpsLeft() { return jumpsLeft; }
    @Override public void setJumpsLeft(int j) { this.jumpsLeft = Math.max(0, j); }
    @Override public void resetJumps() { this.jumpsLeft = 3; }

    @Override public int getDodgeCooldown() { return dodgeCooldown; }
    @Override public void setDodgeCooldown(int t) { this.dodgeCooldown = Math.max(0, t); }

    @Override public int getIframeTicks() { return iframeTicks; }
    @Override public void setIframeTicks(int t) { this.iframeTicks = Math.max(0, t); }
    @Override public boolean hasIframes() { return iframeTicks > 0; }

    @Override public NinjaPose getCurrentPose() { return currentPose; }
    @Override public void setCurrentPose(NinjaPose pose) { this.currentPose = pose != null ? pose : NinjaPose.NORMAL; }

    @Override
    public void readFromNbt(NbtCompound nbt) {
        this.jumpsLeft = nbt.getInt("JumpsLeft");
        this.dodgeCooldown = nbt.getInt("DodgeCD");
        this.iframeTicks = nbt.getInt("Iframes");
        String poseName = nbt.getString("Pose");
        try {
            this.currentPose = NinjaPose.valueOf(poseName);
        } catch (IllegalArgumentException e) {
            this.currentPose = NinjaPose.NORMAL;
        }
    }

    @Override
    public void writeToNbt(NbtCompound nbt) {
        nbt.putInt("JumpsLeft", this.jumpsLeft);
        nbt.putInt("DodgeCD", this.dodgeCooldown);
        nbt.putInt("Iframes", this.iframeTicks);
        nbt.putString("Pose", this.currentPose.name());
    }
}