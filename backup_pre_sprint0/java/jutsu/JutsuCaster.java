package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.behavior.BehaviorRegistry;
import com.example.shinobicore.jutsu.behavior.JutsuBehavior;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.jutsu.data.JutsuRegistry;
import com.example.shinobicore.network.packet.VfxSpawnPacket;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.IDojutsuComponent;
import com.example.shinobicore.stat.component.IJutsuComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
import java.util.Map;

/**
 * Central casting pipeline: validate -> deduct chakra -> execute behavior.
 * Formulas:
 *   Cost: baseCost * (1 - control*0.004 - endurance*0.009 - passive)
 *   Damage: baseDamage * (1 + stat*0.02 + passive)
 */
public final class JutsuCaster {

    private JutsuCaster() {}

    public static boolean cast(ServerPlayerEntity player, String jutsuId) {
        IJutsuComponent jutsuComp = NinjaComponents.getJutsu(player);
        IChakraComponent chakraComp = NinjaComponents.getChakra(player);
        IStatsComponent statsComp = NinjaComponents.getStats(player);
        if (jutsuComp == null || chakraComp == null || statsComp == null) {
            player.sendMessage(Text.literal("Components not available"), false);
            return false;
        }
        if (chakraComp.isExhausted()) {
            player.sendMessage(Text.literal("You are exhausted!"), false);
            return false;
        }
        if (!jutsuComp.hasLearned(jutsuId)) {
            player.sendMessage(Text.literal("You haven't learned this jutsu!"), false);
            return false;
        }
        JutsuDefinition def = JutsuRegistry.get(jutsuId);
        if (def == null) {
            player.sendMessage(Text.literal("Jutsu not found!"), false);
            return false;
        }
        if (!checkRequirements(def, statsComp)) {
            player.sendMessage(Text.literal("Your stats are too low!"), false);
            return false;
        }
        if (def.requiresDojutsu() != null) {
            IDojutsuComponent dojutsuComp = NinjaComponents.getDojutsu(player);
            if (dojutsuComp == null || !def.requiresDojutsu().equals(dojutsuComp.getActiveDojutsu())) {
                player.sendMessage(Text.literal("Requires active dojutsu: " + def.requiresDojutsu()), false);
                return false;
            }
        }

        float cost = calculateCost(def, statsComp);
        if (!chakraComp.spendChakra(cost)) {
            player.sendMessage(Text.literal("Not enough chakra!"), false);
            return false;
        }

        // Fatigue with endurance reduction (0.9% per level)
        int endurance = statsComp.getBodyLevelEndurance();
        float fatigueReduction = Math.min(0.9f, endurance * 0.009f);
        float fatigue = def.strain() * (1.0f - fatigueReduction);
        chakraComp.addFatigue(fatigue);

        float damage = calculateDamage(def, statsComp);
        JutsuBehavior behavior = BehaviorRegistry.getFor(def);
        try {
            behavior.cast(player, def, def.params(), damage);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Cast failed for jutsu {}", jutsuId, e);
            player.sendMessage(Text.literal("Cast error: " + e.toString()), false);
            return false;
        }
        jutsuComp.addMasteryUse(jutsuId);
        try {
            Vec3d pos = player.getEyePos();
            VfxSpawnPacket.send(player, 0, pos.x, pos.y, pos.z);
        } catch (Exception e) {
            ShinobiCore.LOGGER.warn("VFX packet failed for {}: {}", jutsuId, e.toString());
        }
        return true;
    }

    private static boolean checkRequirements(JutsuDefinition def, IStatsComponent stats) {
        for (Map.Entry<String, Integer> req : def.requirements().entrySet()) {
            StatType type = StatType.fromString(req.getKey());
            if (type == null) continue;
            if (stats.getStatLevel(type) < req.getValue()) return false;
        }
        return true;
    }

    private static StatType statForCategory(String category) {
        if (category == null) return StatType.NINJUTSU;
        switch (category) {
            case "taijutsu": return StatType.TAIJUTSU;
            case "genjutsu": return StatType.GENJUTSU;
            case "kenjutsu": return StatType.KENJUTSU;
            case "shuriken": return StatType.SHURIKEN;
            default: return StatType.NINJUTSU;
        }
    }

    /**
     * Cost = baseCost * (1 - control*0.004 - passive_reduction)
     * Control reduces up to 40% at lvl 100, cost_reduction passive = extra -5%
     */
    private static float calculateCost(JutsuDefinition def, IStatsComponent stats) {
        float control = stats.getStatLevel(StatType.CONTROL);
        float reduction = Math.min(0.4f, control * 0.004f);
        if (stats.hasPassive("cost_reduction")) {
            reduction += 0.05f;
        }
        return def.baseCost() * (1.0f - reduction);
    }

    /**
     * Damage = baseDamage * (1 + stat*0.02 + passives)
     * Genjutsu: +2% damage AND duration (duration handled in behavior)
     * Fire mastery: +10% fire damage
     */
    private static float calculateDamage(JutsuDefinition def, IStatsComponent stats) {
        StatType type = statForCategory(def.category());
        float level = stats.getStatLevel(type);
        float damage = def.baseDamage() * (1.0f + level * 0.02f);
        if (stats.hasPassive("fire_mastery") && "fire".equals(def.element())) {
            damage *= 1.10f;
        }
        return damage;
    }
}