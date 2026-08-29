package com.example.shinobicore.dojutsu;

import com.example.shinobicore.stat.component.IDojutsuComponent;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

/**
 * Sharingan logic: evolution by usage, blindness on stress overflow,
 * Mangekyo Chronosphere (Slowness/Weakness 255 target, Resistance 255 self).
 * HLD: Section 7.1
 */
public final class SharinganManager {

    public static final String ID = "sharingan";
    private static final int CHRONOSPHERE_TICKS = 600; // 30 seconds

    private SharinganManager() {}

    /**
     * Server tick while sharingan active: accumulate stress, check blindness.
     */
    public static void tick(ServerPlayerEntity player, IDojutsuComponent comp, DojutsuDefinition def) {
        if (player.age % 20 != 0) return;

        comp.addStress(ID, 1.0f);
        float stress = comp.getStress(ID);

        if (def != null && stress >= def.maxStress()) {
            // Overload: force blindness and deactivate
            player.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, 200, 0));
            comp.deactivateDojutsu();
            comp.removeStress(ID, stress);
            player.sendMessage(Text.literal("Your eyes overload! Blindness applied."), false);
        }
    }

    /**
     * Grant usage (called on successful copy / combat action) and evolve stage.
     */
    public static void addUsageAndEvolve(ServerPlayerEntity player, IDojutsuComponent comp, DojutsuDefinition def) {
        comp.addUsage(ID, 1);
        if (def == null) return;
        int usage = comp.getUsage(ID);
        int stage = comp.getActiveStage();
        int needed = def.usagePerStage() * (stage + 1);
        if (usage >= needed && stage < 3) {
            comp.setActiveStage(stage + 1);
            player.sendMessage(Text.literal("Sharingan evolved to stage " + (stage + 1) + "!"), false);
        }
    }

    /**
     * Mangekyo Chronosphere: lock target, protect self for 30s.
     */
    public static void chronosphere(ServerPlayerEntity player, net.minecraft.entity.LivingEntity target) {
        target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, CHRONOSPHERE_TICKS, 254));
        target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, CHRONOSPHERE_TICKS, 254));
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.RESISTANCE, CHRONOSPHERE_TICKS, 254));
        player.sendMessage(Text.literal("Chronosphere activated (30s)!"), false);
    }
}