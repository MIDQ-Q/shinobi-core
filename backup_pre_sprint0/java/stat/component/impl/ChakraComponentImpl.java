package com.example.shinobicore.stat.component.impl;

import com.example.shinobicore.stat.component.IChakraComponent;
import net.minecraft.nbt.NbtCompound;

public class ChakraComponentImpl implements IChakraComponent {
    private float currentChakra = 2000.0f;
    private float maxChakra = 2000.0f;
    private int reserveLevel = 1;
    private float fatigue = 0.0f;
    private boolean chakraMode = false;

    @Override public float getCurrentChakra() { return currentChakra; }
    @Override public float getMaxChakra() { return maxChakra; }
    @Override public int getReserveLevel() { return reserveLevel; }
    @Override public float getFatigue() { return fatigue; }

    @Override
    public void setCurrentChakra(float value) {
        this.currentChakra = Math.max(0.0f, Math.min(value, maxChakra));
    }
    @Override
    public void setMaxChakra(float value) {
        this.maxChakra = Math.max(1.0f, value);
        if (currentChakra > maxChakra) currentChakra = maxChakra;
    }
    @Override
    public void setReserveLevel(int level) { this.reserveLevel = Math.max(1, level); }

    @Override
    public void addFatigue(float amount) {
        if (amount > 0) this.fatigue = Math.min(100.0f, this.fatigue + amount);
    }
    @Override
    public void removeFatigue(float amount) {
        if (amount > 0) this.fatigue = Math.max(0.0f, this.fatigue - amount);
    }
    @Override
    public void setFatigue(float value) {
        this.fatigue = Math.max(0.0f, Math.min(100.0f, value));
    }
    @Override public boolean isExhausted() { return fatigue >= 100.0f; }

    @Override
    public float restoreChakra(float amount) {
        if (amount <= 0) return 0.0f;
        float old = currentChakra;
        currentChakra = Math.min(maxChakra, currentChakra + amount);
        return currentChakra - old;
    }
    @Override
    public boolean spendChakra(float amount) {
        if (amount <= 0) return true;
        if (currentChakra < amount) return false;
        currentChakra -= amount;
        return true;
    }
    @Override public boolean isChakraMode() { return chakraMode; }
    @Override public void setChakraMode(boolean v) { this.chakraMode = v; }

    @Override
    public void resetToDefaults() {
        currentChakra = 2000.0f;
        maxChakra = 2000.0f;
        reserveLevel = 1;
        fatigue = 0.0f;
        chakraMode = false;
    }

    @Override
    public void readFromNbt(NbtCompound nbt) {
        if (nbt.contains("CurrentChakra")) currentChakra = nbt.getFloat("CurrentChakra");
        if (nbt.contains("MaxChakra")) maxChakra = nbt.getFloat("MaxChakra");
        if (nbt.contains("ReserveLevel")) reserveLevel = nbt.getInt("ReserveLevel");
        if (nbt.contains("Fatigue")) fatigue = nbt.getFloat("Fatigue");
        if (nbt.contains("ChakraMode")) chakraMode = nbt.getBoolean("ChakraMode");
        if (maxChakra <= 0) maxChakra = 2000.0f;
        if (currentChakra > maxChakra) currentChakra = maxChakra;
    }

    @Override
    public void writeToNbt(NbtCompound nbt) {
        nbt.putFloat("CurrentChakra", currentChakra);
        nbt.putFloat("MaxChakra", maxChakra);
        nbt.putInt("ReserveLevel", reserveLevel);
        nbt.putFloat("Fatigue", fatigue);
        nbt.putBoolean("ChakraMode", chakraMode);
    }
}