package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

/**
 * S0-06: Network layer - new packets for future systems.
 * Kawarimi (S2-04), clones (S10), VFX, dojutsu state, hit results.
 *
 * Design rules:
 * - Server sends only needed data (no full NBT).
 * - Use compact IDs for visuals.
 * - Frequent updates use delta-sync.
 * - READ ALL DATA BEFORE server.execute() / client.execute()!
 */
public class S06NetworkLayer {

    // === S2C: Server -> Client ===
    public static final Identifier CAST_COMPLETE_ID =
            new Identifier("shinobicore", "cast_complete");
    public static final Identifier VFX_SPAWN_ID =
            new Identifier("shinobicore", "vfx_spawn");
    public static final Identifier HIT_RESULT_ID =
            new Identifier("shinobicore", "hit_result");
    public static final Identifier DOJUTSU_STATE_ID =
            new Identifier("shinobicore", "dojutsu_state");
    public static final Identifier KAWARIMI_FX_ID =
            new Identifier("shinobicore", "kawarimi_fx");
    public static final Identifier CLONE_SPAWN_ID =
            new Identifier("shinobicore", "clone_spawn");
    public static final Identifier CLONE_DESPAWN_ID =
            new Identifier("shinobicore", "clone_despawn");
    public static final Identifier SENSORY_STATE_ID =
            new Identifier("shinobicore", "sensory_state");

    // === C2S: Client -> Server ===
    public static final Identifier KAWARIMI_ID =
            new Identifier("shinobicore", "kawarimi");

    // === VFX Type IDs (compact byte, max 255) ===
    public static final int VFX_SMOKE = 0;
    public static final int VFX_FIRE_BURST = 1;
    public static final int VFX_WATER_SPLASH = 2;
    public static final int VFX_LIGHTNING_SPARK = 3;
    public static final int VFX_WIND_GUST = 4;
    public static final int VFX_EARTH_CRACK = 5;
    public static final int VFX_KAWARIMI_POOF = 6;
    public static final int VFX_CLONE_POOF = 7;
    public static final int VFX_DOJUTSU_ACTIVATE = 8;
    public static final int VFX_HIT_IMPACT = 9;

    /**
     * Register server-side receivers (C2S packets).
     * Called from ModPackets.register().
     */
    public static void register() {
        // Kawarimi request (C2S) - actual logic in S2-04
        ServerPlayNetworking.registerGlobalReceiver(KAWARIMI_ID,
                (server, player, handler, buf, responseSender) -> {
            // RULE: Read ALL data BEFORE server.execute()!
            // No extra data for now, just the request itself.
            server.execute(() -> {
                NetworkDebugLogger.logPacket("kawarimi", "C2S",
                        player.getName().getString());
                // TODO S2-04: Implement kawarimi window logic
                // 1. Check cooldown
                // 2. Open 3-second window
                // 3. If damage received during window -> substitute
            });
        });

        ShinobiCore.LOGGER.info("[S0-06] Network layer registered (server)");
    }

    // === Server-side broadcast helpers ===

    /** Broadcast VFX spawn to nearby players. Compact: type + position. */
    public static void broadcastVfx(ServerPlayerEntity source, int vfxType,
                                     double x, double y, double z, float scale) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeVfxType(buf, vfxType);
        buf.writeDouble(x);
        buf.writeDouble(y);
        buf.writeDouble(z);
        buf.writeFloat(scale);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(source)) {
            ServerPlayNetworking.send(p, VFX_SPAWN_ID, buf);
        }
        ServerPlayNetworking.send(source, VFX_SPAWN_ID, buf);
        NetworkDebugLogger.logPacket("vfx_spawn", "S2C",
                source.getName().getString(), "type=" + vfxType);
    }

    /** Broadcast hit result to nearby players. */
    public static void broadcastHitResult(ServerPlayerEntity attacker,
                                           int targetEntityId, float damage, boolean crit) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeEntityId(buf, attacker.getId());
        PacketHelper.writeEntityId(buf, targetEntityId);
        buf.writeFloat(damage);
        buf.writeBoolean(crit);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(attacker)) {
            ServerPlayNetworking.send(p, HIT_RESULT_ID, buf);
        }
        ServerPlayNetworking.send(attacker, HIT_RESULT_ID, buf);
        NetworkDebugLogger.logPacket("hit_result", "S2C",
                attacker.getName().getString(),
                "target=" + targetEntityId + " dmg=" + damage);
    }

    /** Send dojutsu state to player. */
    public static void sendDojutsuState(ServerPlayerEntity player,
                                         String dojutsuId, int stage, boolean active) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeOptionalString(buf, dojutsuId);
        buf.writeByte(stage);
        buf.writeBoolean(active);
        ServerPlayNetworking.send(player, DOJUTSU_STATE_ID, buf);
        NetworkDebugLogger.logPacket("dojutsu_state", "S2C",
                player.getName().getString(),
                "id=" + dojutsuId + " stage=" + stage);
    }

    /** Broadcast kawarimi FX (log + smoke at position). */
    public static void broadcastKawarimiFx(ServerPlayerEntity player,
                                            double x, double y, double z) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeDouble(x);
        buf.writeDouble(y);
        buf.writeDouble(z);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(player)) {
            ServerPlayNetworking.send(p, KAWARIMI_FX_ID, buf);
        }
        ServerPlayNetworking.send(player, KAWARIMI_FX_ID, buf);
        NetworkDebugLogger.logPacket("kawarimi_fx", "S2C",
                player.getName().getString());
    }

    /** Broadcast clone spawn. */
    public static void broadcastCloneSpawn(ServerPlayerEntity owner,
                                            int cloneEntityId, double x, double y, double z) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeEntityId(buf, owner.getId());
        PacketHelper.writeEntityId(buf, cloneEntityId);
        buf.writeDouble(x);
        buf.writeDouble(y);
        buf.writeDouble(z);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(owner)) {
            ServerPlayNetworking.send(p, CLONE_SPAWN_ID, buf);
        }
        ServerPlayNetworking.send(owner, CLONE_SPAWN_ID, buf);
        NetworkDebugLogger.logPacket("clone_spawn", "S2C",
                owner.getName().getString(), "clone=" + cloneEntityId);
    }

    /** Broadcast clone despawn (dispersion). */
    public static void broadcastCloneDespawn(ServerPlayerEntity owner,
                                              int cloneEntityId) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeEntityId(buf, cloneEntityId);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(owner)) {
            ServerPlayNetworking.send(p, CLONE_DESPAWN_ID, buf);
        }
        ServerPlayNetworking.send(owner, CLONE_DESPAWN_ID, buf);
        NetworkDebugLogger.logPacket("clone_despawn", "S2C",
                owner.getName().getString(), "clone=" + cloneEntityId);
    }

    /** Send cast complete to player. */
    public static void sendCastComplete(ServerPlayerEntity player, String jutsuId) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeOptionalString(buf, jutsuId);
        ServerPlayNetworking.send(player, CAST_COMPLETE_ID, buf);
        NetworkDebugLogger.logPacket("cast_complete", "S2C",
                player.getName().getString(), "jutsu=" + jutsuId);
    }

    /** Send sensory state to player. */
    public static void sendSensoryState(ServerPlayerEntity player,
                                         int tier, int radius, boolean active) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeByte(tier);
        buf.writeVarInt(radius);
        buf.writeBoolean(active);
        ServerPlayNetworking.send(player, SENSORY_STATE_ID, buf);
        NetworkDebugLogger.logPacket("sensory_state", "S2C",
                player.getName().getString(),
                "tier=" + tier + " radius=" + radius);
    }
}