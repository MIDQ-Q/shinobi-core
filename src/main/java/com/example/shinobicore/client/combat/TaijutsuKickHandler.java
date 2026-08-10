package com.example.shinobicore.client.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Hand;

public class TaijutsuKickHandler {
    private static long kickCooldownEnd = 0;
    public static final long KICK_COOLDOWN_MS = 500;

    public static boolean tryKick(ClientPlayerEntity player) {
        ShinobiCore.LOGGER.info("[KICK] tryKick called");
        
        if (!player.getMainHandStack().isEmpty()) {
            ShinobiCore.LOGGER.info("[KICK] Hand not empty, aborting");
            return false;
        }

        long now = System.currentTimeMillis();
        long remaining = kickCooldownEnd - now;
        
        if (now < kickCooldownEnd) {
            ShinobiCore.LOGGER.info("[KICK] On cooldown, {}ms remaining", remaining);
            return false;
        }

        TaijutsuStyle style = TaijutsuClientHandler.getCurrentStyle();
        boolean chakraMode = ClientNinjaState.chakraMode;
        int taijutsuLevel = ClientNinjaState.statLevels.getOrDefault("taijutsu", 0);

        ShinobiCore.LOGGER.info("[KICK] Performing kick: style={}, chakra={}, level={}",
            style.getId(), chakraMode, taijutsuLevel);

        ShinobiCore.LOGGER.info("[KICK] Sending packet to server");
        sendKickPacket(style);

        ShinobiCore.LOGGER.info("[KICK] Playing animation");
        TaijutsuAnimations.playKickAnimation(player, style);
        
        ShinobiCore.LOGGER.info("[KICK] Playing particles");
        TaijutsuParticleEffects.playKickParticles(player, style);

        ShinobiCore.LOGGER.info("[KICK] Swinging hand");
        player.swingHand(Hand.MAIN_HAND);

        kickCooldownEnd = now + KICK_COOLDOWN_MS;
        ShinobiCore.LOGGER.info("[KICK] Cooldown set until {}", kickCooldownEnd);
        ShinobiCore.LOGGER.info("[KICK] SUCCESS");
        return true;
    }

    private static void sendKickPacket(TaijutsuStyle style) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(style.getId());
        ClientPlayNetworking.send(ModPackets.TAIJUTSU_KICK_ID, buf);
    }

    public static long getCooldownRemainingMs() {
        long now = System.currentTimeMillis();
        return Math.max(0, kickCooldownEnd - now);
    }

    public static float getCooldownRatio() {
        return getCooldownRemainingMs() / (float) KICK_COOLDOWN_MS;
    }

    public static boolean isOnCooldown() {
        return System.currentTimeMillis() < kickCooldownEnd;
    }
}