package com.example.shinobicore.event.tick;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

public final class FatigueDecayService {
    private FatigueDecayService() {}

    public static void tick(MinecraftServer server, ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (data.getFatigue() > 0) {
            float decay = NinjaFormula.fatigueDecayPerSecond(data);
            if (data.isMeditating()) decay *= NinjaFormula.meditationFatigueDecayMultiplier();
            data.setFatigue(Math.max(0, data.getFatigue() - decay));
        }
    }
}