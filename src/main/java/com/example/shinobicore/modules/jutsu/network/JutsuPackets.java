package com.example.shinobicore.modules.jutsu.network;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.executor.JutsuCaster;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import com.example.shinobicore.modules.jutsu.client.JutsuClientState;
import com.example.shinobicore.modules.jutsu.requirement.JutsuRequirementService;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;
import io.netty.buffer.Unpooled;

/**
 * Clean packet layer for jutsu module.
 * Delegates to existing JutsuCaster for actual casting logic.
 */
public final class JutsuPackets {
    public static final Identifier CAST_REQUEST = new Identifier("shinobicore", "jutsu_cast_v2");
    public static final Identifier CAST_STATE_SYNC = new Identifier("shinobicore", "jutsu_state_sync");
    public static final Identifier CAST_FAIL = new Identifier("shinobicore", "jutsu_cast_fail");

    private JutsuPackets() {}

    public static void registerServer() {
        // CAST_REQUEST is already registered by JutsuCastBridge.
        // We register a fail-feedback sender only.
        ShinobiCore.LOGGER.info("[JutsuPackets] Server side ready.");
    }

    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(CAST_STATE_SYNC,
            (client, handler, buf, sender) -> {
                final boolean isCasting = buf.readBoolean();
                final float progress = buf.readFloat();
                final String phase = buf.readString(32);
                final String jutsuId = buf.readString(128);
                client.execute(() ->
                    JutsuClientState.update(isCasting, progress, phase, jutsuId));
            });

        ClientPlayNetworking.registerGlobalReceiver(CAST_FAIL,
            (client, handler, buf, sender) -> {
                final String reason = buf.readString(256);
                client.execute(() -> {
                    if (client.player != null) {
                        client.player.sendMessage(
                            net.minecraft.text.Text.literal("\u00a7c" + reason), true);
                    }
                });
            });

        ShinobiCore.LOGGER.info("[JutsuPackets] Client side ready.");
    }

    /** Send cast failure feedback to client. */
    public static void sendCastFail(ServerPlayerEntity player, String reason) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(reason);
        ServerPlayNetworking.send(player, CAST_FAIL, buf);
    }

    /** Send cast state sync to client. */
    public static void sendCastState(ServerPlayerEntity player,
            boolean casting, float progress, String phase, String jutsuId) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(casting);
        buf.writeFloat(progress);
        buf.writeString(phase);
        buf.writeString(jutsuId);
        ServerPlayNetworking.send(player, CAST_STATE_SYNC, buf);
    }
}