package com.example.shinobicore.event.tick;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

public final class ChakraRegenService {
    private ChakraRegenService() {}

    public static void tick(MinecraftServer server, ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        float maxChakra = NinjaFormula.maxChakra(data);
        if (data.getCurrentChakra() < maxChakra) {
            float regen = NinjaFormula.regenPerSecond(data);
            if (data.isMeditating()) regen *= NinjaFormula.meditationRegenMultiplier();
            if (data.isChakraMode()) regen *= NinjaFormula.chakraModeRegenMultiplier();
            data.setCurrentChakra(Math.min(data.getCurrentChakra() + regen, maxChakra));
        }
    }
}