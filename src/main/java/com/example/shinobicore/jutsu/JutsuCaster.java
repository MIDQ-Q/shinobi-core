package com.example.shinobicore.jutsu;

import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
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
            JutsuLogger.logBehavior("caster",
                    String.format("REJECTED requirements: player=%s, jutsu=%s",
                            player.getName().getString(), jutsuId));
            return false;
        }
        float cost = NinjaFormula.calculateCost(def, data);
        if (data.getCurrentChakra() < cost) {
            player.sendMessage(Text.literal("§cNot enough chakra!"), false);
            JutsuLogger.logBehavior("caster",
                    String.format("REJECTED chakra: player=%s, need=%.1f, have=%.1f",
                            player.getName().getString(), cost, data.getCurrentChakra()));
            return false;
        }

        // Списываем чакру
        data.setCurrentChakra(data.getCurrentChakra() - cost);

        // Усталость с учётом клана
        float strain = def.strain();
        ClanDefinition clan = ClanRegistry.get(data.getClanId());
        if (clan != null) {
            strain *= clan.fatigueMultiplier();
        }
        data.setFatigue(data.getFatigue() + strain);

        // Опыт
        NinjaFormula.grantUsage(data, jutsuId, 1);
        if (def.hasNature() && data.isNatureUnlocked(def.nature())) {
            float xpMult = (data.getAffinity() == def.nature())
                    ? ModConfig.instance.combat.affinityXpMultiplier
                    : 1f;
            int natureXp = Math.max(1, Math.round(cost * 0.2f * xpMult));
            NinjaFormula.grantNatureXp(data, def.nature(), natureXp);
        }
        int ninjutsuXp = Math.max(1, Math.round(cost * 0.1f));
        NinjaFormula.grantStatXp(data, StatType.NINJUTSU, ninjutsuXp);

        // Урон
        float damage = def.baseDamage() * NinjaFormula.damageMultiplier(data, def);

        // === ЛОГИРОВАНИЕ ===
        JutsuLogger.logCast(player, def, data, damage, cost);

        // Вызываем behavior
        JutsuBehavior behavior = BehaviorRegistry.getFor(def);
        behavior.cast(player, def, data, def.params(), damage);

        return true;
    }
}