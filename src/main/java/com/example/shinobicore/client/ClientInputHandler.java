package com.example.shinobicore.client;

import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.math.Vec3d;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class ClientInputHandler {
    private static boolean wasMeditating = false;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ClientInputHandler::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        if (client.player == null) return;

        boolean isMeditating = KeyBindings.MEDITATE.isPressed();
        if (isMeditating != wasMeditating) {
            wasMeditating = isMeditating;
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(isMeditating);
            ClientPlayNetworking.send(ModPackets.MEDITATE_ID, buf);
        }

        if (KeyBindings.PROGRESSION.wasPressed()) {
            client.setScreen(new ProgressionScreen());
        }

        if (KeyBindings.CHAKRA_MODE.wasPressed()) {
            ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(ClientNinjaState.chakraMode);
            ClientPlayNetworking.send(ModPackets.CHAKRA_MODE_ID, buf);
        }
        // Dodge влево (Z)
        if (KeyBindings.DODGE_LEFT.wasPressed()) {
            performDodge(-1);
        }
        
        // Dodge вправо (C)
        if (KeyBindings.DODGE_RIGHT.wasPressed()) {
            performDodge(1);
        }

        if (KeyBindings.CAST_A.wasPressed()) cast(client, 0);
        if (KeyBindings.CAST_B.wasPressed()) cast(client, 1);

        if (KeyBindings.CYCLE_A.wasPressed()) selectSlot(0, (ClientNinjaState.activeA + 1) % 5);
        if (KeyBindings.CYCLE_B.wasPressed()) selectSlot(1, (ClientNinjaState.activeB + 1) % 5);
    }

    private static void cast(MinecraftClient client, int set) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(set);
        buf.writeInt(ClientNinjaState.active(set));
        ClientPlayNetworking.send(ModPackets.CAST_SLOT_ID, buf);
    }

    private static void selectSlot(int set, int i) {
        if (set == 0) ClientNinjaState.activeA = i; else ClientNinjaState.activeB = i;
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(set);
        buf.writeInt(i);
        ClientPlayNetworking.send(ModPackets.SELECT_SLOT_ID, buf);
    }
    private static void performDodge(int direction) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        
        ClientPlayerEntity player = client.player;
        
        // Проверки
        if (!ClientNinjaState.chakraMode) return;
        if (ChakraHudRenderer.currentChakra <= 0) return;
        if (ChakraHudRenderer.exhausted) return;
        
        // Вычисляем направление (перпендикулярно взгляду)
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        Vec3d dodgeDir = right.multiply(direction);
        
        // Импульс вбок
        player.addVelocity(dodgeDir.x * 1.2, 0.2, dodgeDir.z * 1.2);
        player.velocityModified = true;
        
        // Неуязвимость (i-frames)
        player.timeUntilRegen = 6;
        
        // Звук
        com.example.shinobicore.client.parkour.util.ParkourSounds.playRoll();
        
        // Отправляем пакет для усталости
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(direction);
        ClientPlayNetworking.send(ModPackets.DODGE_ID, buf);
    }
    private static void sendDodgePacket(int direction) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString("dodge");
        buf.writeInt(direction);
        ClientPlayNetworking.send(ModPackets.DODGE_ID, buf);
    }
}