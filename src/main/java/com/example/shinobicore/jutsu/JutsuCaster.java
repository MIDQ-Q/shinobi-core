package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public class JutsuCaster {
    
    public static boolean cast(ServerPlayerEntity player, String jutsuId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        
        if (!data.getLearnedJutsus().contains(jutsuId)) {
            player.sendMessage(Text.literal("§cYou haven't learned this jutsu!"), false);
            return false;
        }

        JutsuDefinition def = JutsuRegistry.get(jutsuId);
        if (def == null) {
            player.sendMessage(Text.literal("§cJutsu not found!"), false);
            return false;
        }

        if (!NinjaFormula.checkRequirements(def, data)) {
            player.sendMessage(Text.literal("§cYour stats are too low for this jutsu!"), false);
            return false;
        }

        float cost = NinjaFormula.calculateCost(def, data);
        if (data.getCurrentChakra() < cost) {
            player.sendMessage(Text.literal("§cNot enough chakra!"), false);
            return false;
        }

        data.setCurrentChakra(data.getCurrentChakra() - cost);
        data.setFatigue(data.getFatigue() + def.strain());

        NinjaFormula.grantUsage(data, jutsuId, 1);

        if (def.hasNature() && data.isNatureUnlocked(def.nature())) {
            float xpMult = (data.getAffinity() == def.nature())
                ? com.example.shinobicore.config.ModConfig.instance.combat.affinityXpMultiplier
                : 1f;
            int natureXp = Math.max(1, Math.round(cost * 0.2f * xpMult));
            NinjaFormula.grantNatureXp(data, def.nature(), natureXp);
        }

        int ninjutsuXp = Math.max(1, Math.round(cost * 0.1f));
        NinjaFormula.grantStatXp(data, com.example.shinobicore.stat.StatType.NINJUTSU, ninjutsuXp);

        // Вычисляем урон с учётом mastery
        float damage = def.baseDamage() * NinjaFormula.damageMultiplier(data, def);

        // Вызываем behavior
        JutsuBehavior behavior = BehaviorRegistry.getFor(def);
        behavior.cast(player, def, data, def.params(), damage);

        return true;
    }
}