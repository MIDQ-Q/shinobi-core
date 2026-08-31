package com.example.shinobicore.modules.combat.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.service.*;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public final class CombatPackets {
    private static final Identifier STANCE_CHANGE = new Identifier("shinobicore", "combat_stance_change");
    private static final Identifier BLOCK_START = new Identifier("shinobicore", "combat_block_start");
    private static final Identifier PARRY_ATTEMPT = new Identifier("shinobicore", "combat_parry_attempt");
    private static final Identifier THROW = new Identifier("shinobicore", "combat_throw");
    private static final Identifier SHEATH_TOGGLE = new Identifier("shinobicore", "combat_sheath_toggle");
    private static final Identifier KICK = new Identifier("shinobicore", "combat_kick");
    private static final Identifier QUICK_SLOT = new Identifier("shinobicore", "combat_quick_slot");
    private static final Identifier STATE_SYNC = new Identifier("shinobicore", "combat_state_sync");

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(STANCE_CHANGE, (server, player, handler, buf, sender) -> {
            final int stanceOrdinal = buf.readInt();
            server.execute(() -> ShinobiLogger.module("combat", "Server received stance change: " + stanceOrdinal));
        });
        
        ServerPlayNetworking.registerGlobalReceiver(BLOCK_START, (server, player, handler, buf, sender) -> {
            server.execute(() -> BlockService.startBlock(player));
        });

        ServerPlayNetworking.registerGlobalReceiver(PARRY_ATTEMPT, (server, player, handler, buf, sender) -> {
            final long pressTimeMs = buf.readLong();
            server.execute(() -> ParryService.attemptParry(player, pressTimeMs));
        });

        ServerPlayNetworking.registerGlobalReceiver(THROW, (server, player, handler, buf, sender) -> {
            final float yaw = buf.readFloat();
            final float pitch = buf.readFloat();
            server.execute(() -> ThrowableService.throwWeapon(player, yaw, pitch));
        });

        ServerPlayNetworking.registerGlobalReceiver(SHEATH_TOGGLE, (server, player, handler, buf, sender) -> {
            server.execute(() -> SheathService.toggleSheath(player));
        });

        ServerPlayNetworking.registerGlobalReceiver(KICK, (server, player, handler, buf, sender) -> {
            server.execute(() -> KickService.performKick(player));
        });

        ServerPlayNetworking.registerGlobalReceiver(QUICK_SLOT, (server, player, handler, buf, sender) -> {
            server.execute(() -> QuickWeaponSlotService.cycleWeapon(player));
        });

        ShinobiLogger.module("combat", "Server combat packets registered");
    }

    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(STATE_SYNC, (client, handler, buf, sender) -> {
            final int stanceOrdinal = buf.readInt();
            final boolean isSheathed = buf.readBoolean();
            client.execute(() -> {
                com.example.shinobicore.modules.combat.client.CombatClientState.setCurrentStance(Stance.fromOrdinal(stanceOrdinal));
                com.example.shinobicore.modules.combat.client.CombatClientState.setSheathed(isSheathed);
            });
        });
        ShinobiLogger.module("combat", "Client combat packets registered");
    }

    public static void sendStanceChange(int stanceOrdinal) {
        PacketByteBuf buf = PacketByteBufs.create(); buf.writeInt(stanceOrdinal);
        ClientPlayNetworking.send(STANCE_CHANGE, buf);
    }
    public static void sendParryAttempt(long pressTimeMs) {
        PacketByteBuf buf = PacketByteBufs.create(); buf.writeLong(pressTimeMs);
        ClientPlayNetworking.send(PARRY_ATTEMPT, buf);
    }
    public static void sendBlockStart() { ClientPlayNetworking.send(BLOCK_START, PacketByteBufs.create()); }
    public static void sendThrow(float yaw, float pitch) {
        PacketByteBuf buf = PacketByteBufs.create(); buf.writeFloat(yaw); buf.writeFloat(pitch);
        ClientPlayNetworking.send(THROW, buf);
    }
    public static void sendSheathToggle() { ClientPlayNetworking.send(SHEATH_TOGGLE, PacketByteBufs.create()); }
    public static void sendKick() { ClientPlayNetworking.send(KICK, PacketByteBufs.create()); }
    public static void sendQuickSlotCycle() { ClientPlayNetworking.send(QUICK_SLOT, PacketByteBufs.create()); }
}