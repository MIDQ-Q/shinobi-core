package com.example.shinobicore.client;

import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.network.PacketByteBuf;

public class ClientInputHandler {
    private static boolean wasMeditating = false;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ClientInputHandler::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        if (client.player == null) return;

        // Медитация (удерживать)
        boolean isMeditating = KeyBindings.MEDITATE.isPressed();
        if (isMeditating != wasMeditating) {
            wasMeditating = isMeditating;
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(isMeditating);
            ClientPlayNetworking.send(ModPackets.MEDITATE_ID, buf);
        }

        // Меню прокачки (K)
        if (KeyBindings.PROGRESSION.wasPressed()) {
            client.setScreen(new ProgressionScreen());
        }

        // Чакра-режим — toggle (нажать)
        if (KeyBindings.CHAKRA_MODE.wasPressed()) {
            ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(ClientNinjaState.chakraMode);
            ClientPlayNetworking.send(ModPackets.CHAKRA_MODE_ID, buf);
        }

        // Переключение слота (G)
        if (KeyBindings.CYCLE_SLOT.wasPressed()) {
            selectSlot((ClientNinjaState.activeSlot + 1) % 5);
        }

        // Прямой выбор слота
        KeyBinding[] slots = { KeyBindings.SLOT_1, KeyBindings.SLOT_2, KeyBindings.SLOT_3, KeyBindings.SLOT_4, KeyBindings.SLOT_5 };
        for (int i = 0; i < 5; i++) {
            if (slots[i].wasPressed()) {
                selectSlot(i);
            }
        }

        // Каст (R)
        if (KeyBindings.CAST.wasPressed()) {
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeInt(ClientNinjaState.activeSlot);
            ClientPlayNetworking.send(ModPackets.CAST_SLOT_ID, buf);
        }
    }

    private static void selectSlot(int i) {
        ClientNinjaState.activeSlot = i;
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(i);
        ClientPlayNetworking.send(ModPackets.SELECT_SLOT_ID, buf);
    }
}