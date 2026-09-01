package com.example.shinobicore.network.handlers;

import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public final class ChakraPacketHandlers {
    private ChakraPacketHandlers() {}

    public static void register() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.MEDITATE_ID, (server, player, handler, buf, responseSender) -> {
            boolean start = buf.readBoolean();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setMeditating(start));
        });

        ServerPlayNetworking.registerGlobalReceiver(ModPackets.CHAKRA_MODE_ID, (server, player, handler, buf, responseSender) -> {
            boolean enable = buf.readBoolean();
            ShinobiCore.LOGGER.info("[CHAKRA-SERVER] Packet received: player={}, enable={}",
                player.getName().getString(), enable);
            server.execute(() -> {
                var data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setChakraMode(enable);
                ShinobiCore.LOGGER.info("[CHAKRA-SERVER] Server chakraMode set to: {}", enable);
                ShinobiCore.sendBodySync(player);
            });
        });
    }
}