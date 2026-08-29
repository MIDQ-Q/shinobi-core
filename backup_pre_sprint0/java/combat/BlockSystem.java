package com.example.shinobicore.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.packet.BlockPacket;
import net.fabricmc.fabric.api.entity.event.v1.ServerLivingEntityEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Hold-RMB block: 60% damage reduction while blocking.
 * Self-contained (static map), no component edits.
 */
public final class BlockSystem {
    private static final Map<UUID, Boolean> BLOCKING = new ConcurrentHashMap<>();
    private static final Map<UUID, Boolean> REENTRANT = new ConcurrentHashMap<>();

    private BlockSystem() {}

    public static void init() {
        ServerPlayNetworking.registerGlobalReceiver(BlockPacket.ID,
            (server, player, handler, buf, sender) -> {
                final boolean b = buf.readBoolean();
                server.execute(() -> BLOCKING.put(player.getUuid(), b));
            });

        ServerPlayConnectionEvents.DISCONNECT.register((handler, server) -> {
            BLOCKING.remove(handler.getPlayer().getUuid());
            REENTRANT.remove(handler.getPlayer().getUuid());
        });

        ServerLivingEntityEvents.ALLOW_DAMAGE.register((entity, source, amount) -> {
            if (!(entity instanceof ServerPlayerEntity p)) return true;
            if (!BLOCKING.getOrDefault(p.getUuid(), false)) return true;
            if (amount <= 0) return true;
            if (source.isSourceCreativePlayer()) return true;
            if (REENTRANT.getOrDefault(p.getUuid(), false)) return true;

            REENTRANT.put(p.getUuid(), true);
            final float reduced = amount * 0.4f;
            p.getServer().execute(() -> {
                try {
                    p.damage(source, reduced);
                } finally {
                    REENTRANT.put(p.getUuid(), false);
                }
            });
            return false;
        });
        ShinobiCore.LOGGER.info("BlockSystem initialized (RMB block, 60% reduction)");
    }

    public static boolean isBlocking(UUID id) {
        return BLOCKING.getOrDefault(id, false);
    }
}