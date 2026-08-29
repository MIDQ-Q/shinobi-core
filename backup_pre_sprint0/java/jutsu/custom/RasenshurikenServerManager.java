package com.example.shinobicore.jutsu.custom;

import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.Identifier;

import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public class RasenshurikenServerManager {
    // Хранит текущие тики зарядки и максимальные тики [current, max]
    private static final Map<UUID, int[]> CHARGING = new ConcurrentHashMap<>();
    // Игроки, которые зарядили и держат его в руке
    private static final Set<UUID> READY = ConcurrentHashMap.newKeySet();
    
    public static final Identifier SYNC_ID = new Identifier("shinobicore", "rs_sync");

    static {
        // Тикаем каждый серверный тик для всех игроков
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
                tickPlayer(player);
            }
        });
    }

    public static void startCharge(ServerPlayerEntity player, int maxTicks) {
        CHARGING.put(player.getUuid(), new int[]{maxTicks, maxTicks});
        sendSync(player, true, 0f, false);
    }

    public static boolean isCharging(ServerPlayerEntity player) {
        return CHARGING.containsKey(player.getUuid());
    }

    public static boolean isReady(ServerPlayerEntity player) {
        return READY.contains(player.getUuid());
    }

    public static void clearReady(ServerPlayerEntity player) {
        READY.remove(player.getUuid());
        sendSync(player, false, 0f, false);
    }

    private static void tickPlayer(ServerPlayerEntity player) {
        UUID id = player.getUuid();
        if (CHARGING.containsKey(id)) {
            int[] data = CHARGING.get(id);
            if (data == null) return;
            data[0]--;
            if (data[0] <= 0) {
                CHARGING.remove(id);
                READY.add(id);
                sendSync(player, false, 1f, true);
                player.getWorld().playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_POWER_SELECT, SoundCategory.PLAYERS, 1.5f, 1.2f);
            } else {
                float progress = 1f - ((float) data[0] / (float) data[1]);
                sendSync(player, true, progress, false);
            }
        }
    }

    public static void sendSync(ServerPlayerEntity player, boolean charging, float progress, boolean ready) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(charging);
        buf.writeFloat(progress);
        buf.writeBoolean(ready);
        ServerPlayNetworking.send(player, SYNC_ID, buf);
    }
}