package com.example.shinobicore.modules.clans.event;

import net.minecraft.entity.player.PlayerEntity;
import java.util.HashMap;
import java.util.Map;

public final class FormulaCalculationEvent {
    private final PlayerEntity player;
    private final Map<String, Integer> statBonuses = new HashMap<>();
    private final Map<String, Float> elementDamageBonuses = new HashMap<>();
    private final Map<String, Float> costMultipliers = new HashMap<>();
    private float fatigueMultiplier = 1.0f;
    private int chakraCap = Integer.MAX_VALUE;

    public FormulaCalculationEvent(PlayerEntity player) {
        this.player = player;
    }

    public PlayerEntity player() { return player; }

    public void addStatBonus(String statId, int bonus) {
        statBonuses.merge(statId, bonus, Integer::sum);
    }

    public int getStatBonus(String statId) {
        return statBonuses.getOrDefault(statId, 0);
    }

    public void addElementDamageBonus(String elementId, float bonus) {
        elementDamageBonuses.merge(elementId, bonus, Float::sum);
    }

    public float getElementDamageBonus(String elementId) {
        return elementDamageBonuses.getOrDefault(elementId, 0.0f);
    }

    public void setCostMultiplier(String elementId, float multiplier) {
        costMultipliers.put(elementId, multiplier);
    }

    public float getCostMultiplier(String elementId) {
        return costMultipliers.getOrDefault(elementId, 1.0f);
    }

    public void setFatigueMultiplier(float multiplier) {
        this.fatigueMultiplier = multiplier;
    }

    public float getFatigueMultiplier() { return fatigueMultiplier; }

    public void setChakraCap(int cap) {
        this.chakraCap = Math.min(this.chakraCap, cap);
    }

    public int getChakraCap() { return chakraCap; }
}