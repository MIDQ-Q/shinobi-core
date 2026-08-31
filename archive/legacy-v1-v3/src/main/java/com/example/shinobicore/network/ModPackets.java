// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.network;

import com.example.shinobicore.chakra.server.ServerChakraMirror;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.util.ShinobiConstants;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

/**
 * Central packet registry for ShinobiCore.
 * All packet IDs defined here. Registration called from entrypoints.
 */
public final class ModPackets {

    private ModPackets() {}

    // === PACKET IDs ===
    public static final Identifier CHAKRA_CLIENT_STATE =
        new Identifier(ShinobiConstants.MOD_ID, "chakra_client_state");

    public static final Identifier CHAKRA_INITIAL_STATE =
        new Identifier(ShinobiConstants.MOD_ID, "chakra_initial_state");

    public static final Identifier CHAKRA_ADMIN_SET =
        new Identifier(ShinobiConstants.MOD_ID, "chakra_admin_set");

    // Movement packets
    public static final Identifier MOVEMENT_ACTION =
        new Identifier(ShinobiConstants.MOD_ID, "movement_action");

    public static final Identifier MOVEMENT_HEARTBEAT =
        new Identifier(ShinobiConstants.MOD_ID, "movement_heartbeat");

    public static final Identifier MOVEMENT_ADMIN_RESET =
        new Identifier(ShinobiConstants.MOD_ID, "movement_admin_reset");

    // Sprint A: Level Up Event (Server -> Client)
    public static final Identifier LEVEL_UP_EVENT =
        new Identifier(ShinobiConstants.MOD_ID, "level_up_event");

    // === REGISTRATION ===

    private static boolean serverRegistered = false;
    private static boolean clientRegistered = false;

    /**
     * Register server-side receivers. Called from ShinobiCore.onInitialize().
     */
    public static void registerServer() {
        if (serverRegistered) return;
        serverRegistered = true;

        // Player join -> send saved chakra state
        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            ServerPlayerEntity player = handler.player;
            sendInitialState(player);
        });

        // Receive chakra state from client
        ServerPlayNetworking.registerGlobalReceiver(CHAKRA_CLIENT_STATE,
            (server, player, handler, buf, responseSender) -> {
                // CRITICAL: read ALL buffer fields BEFORE server.execute()
                final int seq = buf.readVarInt();
                final float currentChakra = buf.readFloat();
                final float fatigue = buf.readFloat();
                final boolean chakraMode = buf.readBoolean();
                final boolean exhausted = buf.readBoolean();
                final boolean meditating = buf.readBoolean();

                server.execute(() -> {
                    ServerChakraMirror.updateFromClient(player,
                        currentChakra, fatigue, chakraMode, exhausted, meditating);
                });
            });

        // Movement action receiver
        ServerPlayNetworking.registerGlobalReceiver(MOVEMENT_ACTION,
            (server, player, handler, buf, responseSender) -> {
                // CRITICAL: read ALL fields BEFORE server.execute()
                final int seq = buf.readVarInt();
                final int actionId = buf.readVarInt();
                final boolean hasWallNormal = buf.readBoolean();
                final double wx = hasWallNormal ? buf.readDouble() : 0;
                final double wy = hasWallNormal ? buf.readDouble() : 0;
                final double wz = hasWallNormal ? buf.readDouble() : 0;

                server.execute(() -> {
                    com.example.shinobicore.movement.common.MovementActionType action =
                        com.example.shinobicore.movement.common.MovementActionType.fromId(actionId);
                    net.minecraft.util.math.Vec3d wallNormal = hasWallNormal
                        ? new net.minecraft.util.math.Vec3d(wx, wy, wz) : null;

                    // Server-side validation for wall actions (only logs)
                    if (action == com.example.shinobicore.movement.common.MovementActionType.WALL_START) {
                        com.example.shinobicore.movement.server.ServerWallValidator.validateWallStart(player, wallNormal);
                    } else if (action == com.example.shinobicore.movement.common.MovementActionType.WALL_JUMP) {
                        com.example.shinobicore.movement.server.ServerWallValidator.validateWallJump(player);
                    }

                    com.example.shinobicore.movement.server.ServerMovementMirror.onAction(
                        player, action, wallNormal);
                });
            });

        // Movement heartbeat receiver
        ServerPlayNetworking.registerGlobalReceiver(MOVEMENT_HEARTBEAT,
            (server, player, handler, buf, responseSender) -> {
                final int seq = buf.readVarInt();
                final int phaseOrdinal = buf.readVarInt();
                final boolean onWater = buf.readBoolean();
                final boolean crawling = buf.readBoolean();
                final boolean sliding = buf.readBoolean();
                final boolean meditating = buf.readBoolean();

                server.execute(() -> {
                    com.example.shinobicore.movement.common.MovementPhase phase =
                        com.example.shinobicore.movement.common.MovementPhase.values()[
                            Math.min(phaseOrdinal, com.example.shinobicore.movement.common.MovementPhase.values().length - 1)];
                    com.example.shinobicore.movement.server.ServerMovementMirror.onHeartbeat(
                        player, phase, onWater, crawling, sliding, meditating);
                });
            });

        ShinobiLogger.info("[PACKETS] Server receivers registered");
    }

    /**
     * Register client-side receivers. Called from ShinobiCoreClient.onInitializeClient().
     */
    public static void registerClient() {
        if (clientRegistered) return;
        clientRegistered = true;

        net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking.registerGlobalReceiver(
            CHAKRA_INITIAL_STATE,
            (client, handler, buf, responseSender) -> {
                // CRITICAL: read ALL fields BEFORE client.execute()
                final float currentChakra = buf.readFloat();
                final float maxChakra = buf.readFloat();
                final float fatigue = buf.readFloat();
                final boolean chakraMode = buf.readBoolean();
                final boolean exhausted = buf.readBoolean();
                final boolean meditating = buf.readBoolean();

                client.execute(() -> {
                    com.example.shinobicore.chakra.client.ClientChakraController
                        .onInitialServerSync(currentChakra, maxChakra, fatigue,
                            chakraMode, exhausted, meditating);
                });
            });

        net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking.registerGlobalReceiver(
            CHAKRA_ADMIN_SET,
            (client, handler, buf, responseSender) -> {
                // CRITICAL: read ALL fields BEFORE client.execute()
                final float newCurrent = buf.readFloat();
                final float newMax = buf.readFloat();
                final float newFatigue = buf.readFloat();
                final boolean newMode = buf.readBoolean();
                final boolean newExhausted = buf.readBoolean();

                client.execute(() -> {
                    com.example.shinobicore.chakra.client.ClientChakraController
                        .applyAdminSet(newCurrent, newMax, newFatigue, newMode, newExhausted);
                });
            });

        // Sprint A: Level Up Event Receiver
        net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking.registerGlobalReceiver(
            LEVEL_UP_EVENT,
            (client, handler, buf, responseSender) -> {
                final String statId = buf.readString();
                final int newLevel = buf.readVarInt();
                client.execute(() -> {
                    if (client.player != null) {
                        net.minecraft.text.Text msg = net.minecraft.text.Text.literal(
                            "в¬† " + statId.toUpperCase() + " Level " + newLevel + "!"
                        ).formatted(net.minecraft.util.Formatting.GOLD);
                        client.player.sendMessage(msg, true); // Action bar
                        client.player.playSound(net.minecraft.sound.SoundEvents.ENTITY_PLAYER_LEVELUP, 1.0f, 1.0f);
                    }
                });
            });

        ShinobiLogger.info("[PACKETS] Client receivers registered");
    }

    // === SEND HELPERS ===

    /**
     * Send initial saved state to client on join.
     */
    public static void sendInitialState(ServerPlayerEntity player) {
        if (player == null) return;
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (chakra == null) return;

        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeFloat(chakra.getCurrentChakra());
        buf.writeFloat(chakra.getMaxChakra());
        buf.writeFloat(chakra.getFatigue());
        buf.writeBoolean(chakra.isChakraMode());
        buf.writeBoolean(chakra.isExhausted());
        buf.writeBoolean(chakra.isMeditating());

        ServerPlayNetworking.send(player, CHAKRA_INITIAL_STATE, buf);
    }

    /**
     * Send admin set command to client.
     */
    public static void sendAdminSet(ServerPlayerEntity player,
            float current, float max, float fatigue, boolean mode, boolean exhausted) {
        if (player == null) return;

        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeFloat(current);
        buf.writeFloat(max);
        buf.writeFloat(fatigue);
        buf.writeBoolean(mode);
        buf.writeBoolean(exhausted);

        ServerPlayNetworking.send(player, CHAKRA_ADMIN_SET, buf);
    }
    public static void sendChakraUpdate(float current, float max, float fatigue, boolean mode, boolean exhausted) {
        // SPRINT 2 no-op stub for client sync.
    }
}