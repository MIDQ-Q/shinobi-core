package com.example.shinobicore.event.tick;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.ShinobiCore;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public final class ChakraModeDrainService {
    private ChakraModeDrainService() {}

    public static void tick(MinecraftServer server, ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (!data.isChakraMode()) return;
        float drain = NinjaFormula.chakraModeDrainPerSecond(data);
        if (data.getCurrentChakra() >= drain) {
            data.setCurrentChakra(data.getCurrentChakra() - drain);
        } else {
            data.setChakraMode(false);
            ShinobiCore.sendBodySync(player);
            player.sendMessage(Text.literal("\u00a7cChakra depleted!"), false);
        }
    }
}