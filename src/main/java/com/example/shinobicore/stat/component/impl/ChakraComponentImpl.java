package com.example.shinobicore.stat.component.impl;

import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.util.ShinobiConstants;
import net.minecraft.nbt.NbtCompound;

public class ChakraComponentImpl implements IChakraComponent {
    private float currentChakra = ShinobiConstants.BASE_MAX_CHAKRA;
    private float maxChakra = ShinobiConstants.BASE_MAX_CHAKRA;
    private float fatigue = 0.0f;
    private boolean chakraMode = false;
    private boolean exhausted = false;
    private boolean meditating = false;

    @Override public float getCurrentChakra() { return currentChakra; }
    @Override public float getMaxChakra() { return maxChakra; }
    @Override public float getFatigue() { return fatigue; }
    @Override public boolean isChakraMode() { return chakraMode; }

    @Override public void setCurrentChakra(float value) { this.currentChakra = Math.max(0, Math.min(value, maxChakra)); }
    @Override public void setMaxChakra(float value) { this.maxChakra = Math.max(1, value); if (currentChakra > maxChakra) currentChakra = maxChakra; }
    @Override public void setFatigue(float value) { this.fatigue = Math.max(0, Math.min(100, value)); }
    @Override public void setChakraMode(boolean v) { this.chakraMode = v; }
    @Override public void addFatigue(float amount) { if (amount > 0) this.fatigue = Math.min(100, this.fatigue + amount); }
    @Override public void removeFatigue(float amount) { if (amount > 0) this.fatigue = Math.max(0, this.fatigue - amount); }
    @Override public boolean isExhausted() { return fatigue >= 100.0f; }
    @Override public float restoreChakra(float amount) { if (amount <= 0) return 0; float old = currentChakra; currentChakra = Math.min(maxChakra, currentChakra + amount); return currentChakra - old; }
    @Override public boolean spendChakra(float amount) { if (amount <= 0) return true; if (currentChakra < amount) return false; currentChakra -= amount; return true; }
    @Override public void resetToDefaults() { currentChakra = ShinobiConstants.BASE_MAX_CHAKRA; maxChakra = ShinobiConstants.BASE_MAX_CHAKRA; fatigue = 0; chakraMode = false; exhausted = false; meditating = false; }

    @Override public void setExhausted(boolean v) { this.exhausted = v; }
    @Override public boolean isMeditating() { return meditating; }
    @Override public void setMeditating(boolean v) { this.meditating = v; }

    @Override public void readFromNbt(NbtCompound nbt) {
        if (nbt.contains("CurrentChakra")) currentChakra = nbt.getFloat("CurrentChakra");
        if (nbt.contains("MaxChakra")) maxChakra = nbt.getFloat("MaxChakra");
        if (nbt.contains("Fatigue")) fatigue = nbt.getFloat("Fatigue");
        if (nbt.contains("ChakraMode")) chakraMode = nbt.getBoolean("ChakraMode");
        if (nbt.contains("Exhausted")) exhausted = nbt.getBoolean("Exhausted");
        if (nbt.contains("Meditating")) meditating = nbt.getBoolean("Meditating");
        if (maxChakra <= 0) maxChakra = ShinobiConstants.BASE_MAX_CHAKRA;
        if (currentChakra > maxChakra) currentChakra = maxChakra;
    }

    @Override public void writeToNbt(NbtCompound nbt) {
        nbt.putFloat("CurrentChakra", currentChakra);
        nbt.putFloat("MaxChakra", maxChakra);
        nbt.putFloat("Fatigue", fatigue);
        nbt.putBoolean("ChakraMode", chakraMode);
        nbt.putBoolean("Exhausted", exhausted);
        nbt.putBoolean("Meditating", meditating);
    }
}