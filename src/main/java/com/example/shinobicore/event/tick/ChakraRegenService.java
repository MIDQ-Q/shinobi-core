package com.example.shinobicore.event.tick;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

/**
 * C2 / R-9: сервис включается в NinjaTickHandler.
 *
 * ВАЖНО: исходная версия сервиса НЕ содержала ветку расенгана, которая была
 * в инлайн-коде NinjaTickHandler. Наивное включение сервиса молча сломало бы
 * заряжание расенгана (регрессия R-9). Ветка перенесена сюда 1-в-1.
 */
public final class ChakraRegenService {

    private ChakraRegenService() {}

    public static void tick(MinecraftServer server, ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        float maxChakra = NinjaFormula.maxChakra(data);
        if (data.getCurrentChakra() >= maxChakra) return;

        float regen = NinjaFormula.regenPerSecond(data);
        if (data.isMeditating()) regen *= NinjaFormula.meditationRegenMultiplier();

        if (data.isRasenganCharging()) {
            // === ВЕТКА РАСЕНГАНА (перенесена из NinjaTickHandler) ===
            data.setRasenganChargeTicks(data.getRasenganChargeTicks() + 1);
            if (data.getRasenganChargeTicks() >= data.getRasenganChargeTarget()) {
                data.setRasenganCharging(false);
                data.setRasenganReady(true);
                player.sendMessage(Text.literal("\u00a7b\u2726 Rasengan ready! Press LMB to strike!"), false);
                ShinobiCore.sendRasenganSync(player);
            }
            if (data.getRasenganChargeTicks() % 5 == 0) {
                ShinobiCore.sendRasenganSync(player);
            }
        } else if (data.isChakraMode()) {
            regen *= NinjaFormula.chakraModeRegenMultiplier();
        }

        data.setCurrentChakra(Math.min(data.getCurrentChakra() + regen, maxChakra));
    }
}