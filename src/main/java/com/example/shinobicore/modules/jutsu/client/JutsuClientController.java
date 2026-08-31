package com.example.shinobicore.modules.jutsu.client;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.network.JutsuPackets;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;

public final class JutsuClientController {
    private static boolean castKeyHeld = false;

    public static void init() {
        ShinobiLogger.module("jutsu", "JutsuClientController initialized.");
    }

    public static void tick() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null || client.world == null) return;

        handleSlotSelection();
        handleCastInput(client);
    }

    private static void handleSlotSelection() {
        if (JutsuKeyBindings.SLOT_A.wasPressed()) selectAndSend(0);
        else if (JutsuKeyBindings.SLOT_B.wasPressed()) selectAndSend(1);
        else if (JutsuKeyBindings.SLOT_C.wasPressed()) selectAndSend(2);
        else if (JutsuKeyBindings.CYCLE_SLOT.wasPressed()) {
            int next = (JutsuClientState.getSelectedSlot() + 1) % 3;
            selectAndSend(next);
        }
    }

    private static void selectAndSend(int slot) {
        JutsuClientState.setSelectedSlot(slot);
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(0); // Action: select
        buf.writeInt(slot);
        buf.writeString(""); // Dummy for assign
        ClientPlayNetworking.send(JutsuPackets.SLOT_CHANGE, buf);
    }

    private static void handleCastInput(MinecraftClient client) {
        boolean isPressed = JutsuKeyBindings.CAST_JUTSU.isPressed();
        
        if (isPressed && !castKeyHeld) {
            // Key just pressed -> Send Cast Request
            castKeyHeld = true;
            PacketByteBuf buf = PacketByteBufs.create();
            buf.writeInt(JutsuClientState.getSelectedSlot());
            buf.writeLong(System.currentTimeMillis());
            buf.writeFloat(client.player.getYaw());
            buf.writeFloat(client.player.getPitch());
            ClientPlayNetworking.send(JutsuPackets.CAST_REQUEST, buf);
        } else if (!isPressed && castKeyHeld) {
            // Key released -> Send Cancel if still in prepare/charge
            castKeyHeld = false;
            if (JutsuClientState.isCasting() && 
               (JutsuClientState.getCurrentPhase().name().equals("PREPARE") || 
                JutsuClientState.getCurrentPhase().name().equals("CHARGE"))) {
                PacketByteBuf buf = PacketByteBufs.create();
                buf.writeString("manual_release");
                ClientPlayNetworking.send(JutsuPackets.CAST_CANCEL, buf);
            }
        }

        if (JutsuKeyBindings.CANCEL_CAST.wasPressed() && JutsuClientState.isCasting()) {
            PacketByteBuf buf = PacketByteBufs.create();
            buf.writeString("manual_cancel");
            ClientPlayNetworking.send(JutsuPackets.CAST_CANCEL, buf);
        }
    }
}