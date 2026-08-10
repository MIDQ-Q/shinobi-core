package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.combat.TaijutsuKickHandler;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;

public class ClientInputHandler {
    
    private static boolean prevMeditatePressed = false;
    
    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ClientInputHandler::onClientTick);
    }
    
    private static void onClientTick(MinecraftClient client) {
        if (client.player == null) return;
        
        // === ЧАКРА-МОД (L) ===
        if (KeyBindings.CHAKRA_MODE.wasPressed()) {
            ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
            ShinobiCore.LOGGER.info("[CHAKRA] Mode toggled: {}", ClientNinjaState.chakraMode);
            
            if (client.getNetworkHandler() != null) {
                PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                buf.writeBoolean(ClientNinjaState.chakraMode);
                ClientPlayNetworking.send(ModPackets.CHAKRA_MODE_ID, buf);
                ShinobiCore.LOGGER.info("[CHAKRA] Packet sent to server: chakraMode={}", ClientNinjaState.chakraMode);
            }
        }
        
        // === МЕДИТАЦИЯ (M — при зажиме восстанавливает чакру) ===
        boolean meditatePressed = KeyBindings.MEDITATE.isPressed();
        
        if (meditatePressed && !prevMeditatePressed) {
            ShinobiCore.LOGGER.info("[MEDITATION] M pressed — start meditating");
            sendMeditatePacket(client, true);
        } else if (!meditatePressed && prevMeditatePressed) {
            ShinobiCore.LOGGER.info("[MEDITATION] M released — stop meditating");
            sendMeditatePacket(client, false);
        }
        prevMeditatePressed = meditatePressed;
        
        // === УДАР НОГОЙ (V) ===
        if (KeyBindings.KICK.wasPressed()) {
            boolean handEmpty = client.player.getMainHandStack().isEmpty();
            ShinobiCore.LOGGER.info("[INPUT] KICK (V) pressed, handEmpty={}", handEmpty);
            
            if (handEmpty) {
                TaijutsuKickHandler.tryKick(client.player);
            }
        }
        
        // === КАСТ ТЕХНИК (R) ===
        if (KeyBindings.CAST_A.wasPressed()) {
            ShinobiCore.LOGGER.info("[INPUT] CAST_A (R) pressed");
            ClientNinjaState.castActiveJutsu(0);
        }
        
        // === КАСТ ТЕХНИК B (T) ===
        if (KeyBindings.CAST_B.wasPressed()) {
            ShinobiCore.LOGGER.info("[INPUT] CAST_B (T) pressed");
            ClientNinjaState.castActiveJutsu(1);
        }
        
        // === ПЕРЕКЛЮЧЕНИЕ СЛОТА A (G) ===
        if (KeyBindings.CYCLE_A.wasPressed()) {
            ShinobiCore.LOGGER.info("[INPUT] CYCLE_A (G) pressed");
            ClientNinjaState.cycleLoadout(0);
        }
        
        // === ПЕРЕКЛЮЧЕНИЕ СЛОТА B (H) ===
        if (KeyBindings.CYCLE_B.wasPressed()) {
            ShinobiCore.LOGGER.info("[INPUT] CYCLE_B (H) pressed");
            ClientNinjaState.cycleLoadout(1);
        }
        
        // === МЕНЮ ПРОКАЧКИ (K) ===
        if (KeyBindings.PROGRESSION.wasPressed()) {
            ShinobiCore.LOGGER.info("[INPUT] PROGRESSION (K) pressed");
            client.setScreen(new ProgressionScreen());
        }
        
        // === ПОЛЗАНИЕ (N) ===
        if (KeyBindings.CRAWL.wasPressed()) {
            ShinobiCore.LOGGER.info("[INPUT] CRAWL (N) pressed");
        }
        
        // ❌ DODGE_LEFT и DODGE_RIGHT НЕ ТРОГАЕМ!
        // DodgeAction сам вызывает wasPressed() в canActivate()
    }
    
    private static void sendMeditatePacket(MinecraftClient client, boolean start) {
        if (client.getNetworkHandler() != null) {
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(start);
            ClientPlayNetworking.send(ModPackets.MEDITATE_ID, buf);
            ShinobiCore.LOGGER.info("[MEDITATION] Packet sent: meditating={}", start);
        }
    }
}