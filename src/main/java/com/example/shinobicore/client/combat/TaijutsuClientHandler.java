package com.example.shinobicore.client.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.combat.TaijutsuCombo;
import com.example.shinobicore.combat.TaijutsuFormulas;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Hand;
import com.example.shinobicore.ShinobiCore;

public class TaijutsuClientHandler {
    private static int comboStep = 0;
    private static long lastAttackTime = 0;
    private static long cooldownEndTime = 0;
    private static TaijutsuStyle currentStyle = TaijutsuStyle.STANDARD;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(TaijutsuClientHandler::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        if (client.player == null) return;
        long now = System.currentTimeMillis();
        if (comboStep > 0 && now - lastAttackTime > TaijutsuCombo.COMBO_TIMEOUT_MS) {
            comboStep = 0;
        }
    }

    public static boolean tryAttack(ClientPlayerEntity player) {
        ShinobiCore.LOGGER.info("[ATTACK] tryAttack called");
        
        if (!player.getMainHandStack().isEmpty()) {
            ShinobiCore.LOGGER.info("[ATTACK] Hand not empty, returning false");
            return false;
        }

        long now = System.currentTimeMillis();
        if (now < cooldownEndTime) {
            ShinobiCore.LOGGER.info("[ATTACK] On cooldown, returning false");
            return false;
        }

        if (now - lastAttackTime > TaijutsuCombo.COMBO_TIMEOUT_MS) {
            ShinobiCore.LOGGER.info("[ATTACK] Combo timeout, resetting to 0");
            comboStep = 0;
        }

        boolean chakraMode = ClientNinjaState.chakraMode;
        int taijutsuLevel = ClientNinjaState.statLevels.getOrDefault("taijutsu", 0);
        int cooldown = TaijutsuFormulas.attackCooldownTicks(currentStyle, chakraMode);

        ShinobiCore.LOGGER.info("[ATTACK] Sending packet: step={}, style={}", comboStep, currentStyle.getId());
        sendAttackPacket(comboStep, currentStyle);

        ShinobiCore.LOGGER.info("[ATTACK] Playing animation and particles");
        TaijutsuAnimations.playAttackAnimation(player, comboStep, currentStyle);
        TaijutsuParticleEffects.playAttackParticles(player, comboStep, currentStyle);

        player.swingHand(Hand.MAIN_HAND);

        lastAttackTime = now;
        cooldownEndTime = now + (cooldown * 50L);

        int oldStep = comboStep;
        comboStep = (comboStep + 1) % TaijutsuCombo.MAX_STEPS;
        ShinobiCore.LOGGER.info("[ATTACK] Combo step updated: {} -> {}", oldStep, comboStep);
        
        return true;
    }

    private static void sendAttackPacket(int step, TaijutsuStyle style) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(step);
        buf.writeString(style.getId());
        ClientPlayNetworking.send(ModPackets.TAIJUTSU_ATTACK_ID, buf);
    }

    public static int getComboStep() { return comboStep; }
    public static TaijutsuStyle getCurrentStyle() { return currentStyle; }
    public static void setStyle(TaijutsuStyle style) { currentStyle = style; }
}