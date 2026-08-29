package com.example.shinobicore.network.packet;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

/**
 * Combat action packet (client -> server).
 * HLD: Section 1.2
 * CRITICAL: Read buf BEFORE server.execute()!
 */
public class CombatActionPacket {
    public static final Identifier ID = new Identifier("shinobicore", "combat_action");

    public static void send(int actionOrdinal, String targetId) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(actionOrdinal);
        buf.writeString(targetId != null ? targetId : "");
        ClientPlayNetworking.send(ID, buf);
    }

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
            final int action = buf.readInt();
            final String targetId = buf.readString();
            server.execute(() -> {
                if (action == 5) {
                    com.example.shinobicore.combat.StanceManager.cycle(player);
                } else {
                    ShinobiCore.LOGGER.debug("Combat action: " + action + " target: " + targetId);
                }
            });
        });
    }
}