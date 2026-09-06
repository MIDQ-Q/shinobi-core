package com.example.shinobicore.stealth;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;
import net.minecraft.nbt.NbtCompound;
public class StealthComponentImpl implements StealthComponent, AutoSyncedComponent {
    private float visibility = 1.0f;
    private float noise = 0.0f;
    @Override public float getVisibility() { return visibility; }
    @Override public void setVisibility(float v) { this.visibility = v; }
    @Override public boolean isHidden() { return visibility < 0.3f && noise < 1.0f; }
    @Override public void addNoise(float amount) { this.noise = Math.min(10.0f, this.noise + amount); }
    @Override public float getNoise() { return noise; }
    @Override public void tick() { this.noise = Math.max(0, this.noise - 0.05f); }
    @Override public void readFromNbt(NbtCompound tag) { visibility = tag.getFloat("Visibility"); noise = tag.getFloat("Noise"); }
    @Override public void writeToNbt(NbtCompound tag) { tag.putFloat("Visibility", visibility); tag.putFloat("Noise", noise); }
}