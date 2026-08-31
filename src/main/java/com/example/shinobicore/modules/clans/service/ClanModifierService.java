package com.example.shinobicore.modules.clans.service;

import com.example.shinobicore.modules.clans.component.ClanComponentKey;
import com.example.shinobicore.modules.clans.data.ClanDefinition;
import com.example.shinobicore.modules.clans.data.ClanRegistry;
import com.example.shinobicore.modules.clans.event.FormulaCalculationEvent;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Map;
import java.util.Optional;

public final class ClanModifierService {

    public static void init() {}

    public static void applyModifiers(FormulaCalculationEvent event) {
        PlayerEntity player = event.player();
        Optional<com.example.shinobicore.modules.clans.component.ClanComponent> compOpt =
            ClanComponentKey.get(player);
        if (compOpt.isEmpty()) return;

        ClanDefinition clan = ClanRegistry.get(compOpt.get().getClanId()).orElse(null);
        if (clan == null) return;

        for (Map.Entry<String, Integer> entry : clan.statBonuses().entrySet()) {
            event.addStatBonus(entry.getKey(), entry.getValue());
        }

        for (Map.Entry<String, Integer> entry : clan.natureBonuses().entrySet()) {
            event.addElementDamageBonus(entry.getKey(), entry.getValue() / 100.0f);
        }

        for (Map.Entry<String, Float> entry : clan.costMultiplier().entrySet()) {
            event.setCostMultiplier(entry.getKey(), entry.getValue());
        }

        event.setFatigueMultiplier(clan.fatigueMultiplier());
        event.setChakraCap(clan.chakraCap());
    }
}