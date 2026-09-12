package com.example.shinobicore.network.handlers;

import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.pose.LowPoseTracker;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;

public final class MovementPacketHandlers {
    private MovementPacketHandlers() {}

    public static void register() {
        registerDodge();
        registerPoseSync();
        registerParkourAction();
    }

    private static void registerDodge() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.DODGE_ID, (server, player, handler, buf, responseSender) -> {
            final int direction = buf.readInt();
            // E2: защита от флуда (все байты прочитаны выше)
            if (!com.example.shinobicore.network.PacketRateLimiter.allow(
                    player.getUuid(), "DODGE", 400)) return;
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.getCurrentChakra() <= 0 || data.isExhausted()) return;
                // E3: direction пока не влияет на стоимость, но валидируем и логируем —
                // поле понадобится для античита стороны рывка в Спринте 22.
                if (direction != -1 && direction != 1 && direction != 0) {
                    com.example.shinobicore.network.PacketValidator.logRejection(
                        player, "DODGE", "invalid direction " + direction);
                    return;
                }
                data.setFatigue(data.getFatigue() + ModConfig.instance.parkour.dodgeFatigue);
            });
        });
    }

    private static void registerPoseSync() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.POSE_SYNC_ID, (server, player, handler, buf, responseSender) -> {
            final boolean low = buf.readBoolean();
            // E2: пакет шлётся только по фронту изменения, чаще 10/с быть не должно
            if (!com.example.shinobicore.network.PacketRateLimiter.allow(
                    player.getUuid(), "POSE_SYNC", 100)) return;
            server.execute(() -> LowPoseTracker.set(player.getUuid(), low));
        });

        ServerPlayConnectionEvents.DISCONNECT.register((handler, server) ->
            LowPoseTracker.set(handler.player.getUuid(), false));
    }

    private static void registerParkourAction() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.PARKOUR_ACTION_ID, (server, player, handler, buf, responseSender) -> {
            final String actionId = buf.readString();
            float fatigueValue = 0;
            if (actionId.equals("charged_jump")) {
                fatigueValue = buf.readFloat();
            }
            final float finalFatigue = fatigueValue;
            final String finalActionId = actionId;
            // E2: защита от флуда. Все байты уже прочитаны — возвращаться безопасно.
            if (!com.example.shinobicore.network.PacketRateLimiter.allow(
                    player.getUuid(), "PARKOUR_ACTION", 100)) return;
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.getCurrentChakra() <= 0 || data.isExhausted()) return;
                float f = 0;
                if (finalActionId.equals("charged_jump")) {
                    // ADR-004 (P1-4): клиент прислал ДОЛЮ ЗАРЯДА, не стоимость.
                    // Валидируем вход и считаем цену сами — из конфига.
                    float safeRatio = finalFatigue;
                    if (Float.isNaN(safeRatio)) safeRatio = 0.0f;
                    safeRatio = Math.min(1.0f, Math.max(0.0f, safeRatio));
                    f = ModConfig.instance.parkour.chargedJumpFatiguePerCharge * safeRatio;
                } else {
                    switch (finalActionId) {
                        case "slide": f = ModConfig.instance.parkour.slideFatigue; break;
                        case "double_jump": f = ModConfig.instance.parkour.doubleJumpFatigue; break;
                        case "wall_jump": f = ModConfig.instance.parkour.wallJumpFatigue; break;
                        case "vault": f = ModConfig.instance.parkour.vaultFatigue; break;
                        case "wall_run": f = ModConfig.instance.parkour.wallRunFatiguePerTick; break;
                        case "edge_grab": f = ModConfig.instance.parkour.edgeGrabFatigue; break;
                        case "roll": f = ModConfig.instance.parkour.rollFatigue; break;
                        default:
                            com.example.shinobicore.network.PacketValidator.logRejection(
                                player, "PARKOUR_ACTION", "unknown actionId: " + finalActionId);
                            return;
                    }
                }
                if (f > 0) data.setFatigue(data.getFatigue() + f);
            });
        });
    }
}