package com.example.shinobicore.modules.chakra.component;

import com.example.shinobicore.api.chakra.IChakraComponent;
import dev.onyxstudios.cca.api.v3.component.ComponentV3;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;
import net.minecraft.nbt.NbtCompound;

public final class ChakraComponentImpl implements IChakraComponent, ComponentV3, AutoSyncedComponent {
    private double current = 0.0;
    private double max = 100.0;
    private boolean chakraModeActive = false;
    private boolean exhausted = false;

    @Override public double getCurrent() { return current; }
    @Override public double getMax() { return max; }
    @Override public boolean isChakraModeActive() { return chakraModeActive; }
    @Override public boolean isExhausted() { return exhausted; }

    @Override public void setCurrent(double value) { 
        this.current = Math.max(0, Math.min(value, max)); 
    }
    @Override public void setMax(double value) { 
        this.max = Math.max(1, value); 
        if (current > max) current = max;
    }
    @Override public void setChakraModeActive(boolean active) { this.chakraModeActive = active; }
    @Override public void setExhausted(boolean exhausted) { this.exhausted = exhausted; }

    @Override
    public boolean trySpend(double amount) {
        if (amount <= 0) return true;
        if (exhausted) return false;
        if (current < amount) return false;
        current -= amount;
        if (current <= 0) {
            current = 0;
            exhausted = true;
            chakraModeActive = false;
        }
        return true;
    }

    @Override
    public void regenerate(double amount) {
        if (amount <= 0) return;
        current = Math.min(max, current + amount);
        if (current > max * 0.2 && exhausted) {
            exhausted = false;
        }
    }

    @Override
    public void readFromNbt(NbtCompound tag) {
        current = tag.getDouble("current");
        max = tag.getDouble("max");
        chakraModeActive = tag.getBoolean("mode");
        exhausted = tag.getBoolean("exhausted");
    }

    @Override
    public void writeToNbt(NbtCompound tag) {
        tag.putDouble("current", current);
        tag.putDouble("max", max);
        tag.putBoolean("mode", chakraModeActive);
        tag.putBoolean("exhausted", exhausted);
    }
}