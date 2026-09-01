package com.example.shinobicore.network.handlers;

import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;

public final class SensoryPacketHandlers {
    private SensoryPacketHandlers() {}

    public static void register() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.SENSORY_TOGGLE_ID, (server, player, handler, buf, responseSender) -> {
            final boolean enabled = buf.readBoolean();
            server.execute(() -> {
                var data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setSensoryEnabled(enabled);
                ShinobiCore.sendStatsSync(player);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(ModPackets.RASENGAN_STRIKE_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> ShinobiCore.handleRasenganStrike(player));
        });
    }
}