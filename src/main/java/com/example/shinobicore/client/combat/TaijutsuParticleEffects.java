package com.example.shinobicore.client.combat;

import com.example.shinobicore.combat.TaijutsuStyle;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

import java.util.Random;

public class TaijutsuParticleEffects {
    
    private static final Random random = new Random();
      public static void playKickParticles(AbstractClientPlayerEntity player, TaijutsuStyle style) {
        MinecraftClient client = MinecraftClient.getInstance();
        Vec3d pos = player.getPos().add(0, 0.5, 0); // ноги
        Vec3d look = player.getRotationVector();
        Vec3d particlePos = pos.add(look.multiply(1.0));

        int count = 15;
        for (int i = 0; i < count; i++) {
            double offsetX = (random.nextDouble() - 0.5) * 0.6;
            double offsetY = random.nextDouble() * 0.3;
            double offsetZ = (random.nextDouble() - 0.5) * 0.6;

            if (style == TaijutsuStyle.STRONG_FIST) {
                client.world.addParticle(ParticleTypes.CLOUD,
                    particlePos.x + offsetX, particlePos.y + offsetY, particlePos.z + offsetZ,
                    0, 0.05, 0);
            } else {
                client.world.addParticle(ParticleTypes.POOF,
                    particlePos.x + offsetX, particlePos.y + offsetY, particlePos.z + offsetZ,
                    0, 0.08, 0);
            }
        }

        // Ударная волна
        for (int i = 0; i < 10; i++) {
            double angle = (i / 10.0) * Math.PI * 2;
            double r = 0.5;
            client.world.addParticle(ParticleTypes.CRIT,
                particlePos.x + Math.cos(angle) * r,
                particlePos.y + 0.2,
                particlePos.z + Math.sin(angle) * r,
                0, 0.1, 0);
        }
    }  
    public static void playAttackParticles(AbstractClientPlayerEntity player, int comboStep, TaijutsuStyle style) {
        MinecraftClient client = MinecraftClient.getInstance();
        Vec3d pos = player.getPos().add(0, player.getHeight() * 0.7, 0);
        Vec3d look = player.getRotationVector();
        Vec3d particlePos = pos.add(look.multiply(1.2));
        
        int count = 3 + comboStep * 2;
        
        for (int i = 0; i < count; i++) {
            double offsetX = (random.nextDouble() - 0.5) * 0.5;
            double offsetY = (random.nextDouble() - 0.5) * 0.5;
            double offsetZ = (random.nextDouble() - 0.5) * 0.5;
            
            if (style == TaijutsuStyle.STRONG_FIST) {
                // Зелёные частицы для Strong Fist
                client.world.addParticle(
                    ParticleTypes.HAPPY_VILLAGER,
                    particlePos.x + offsetX,
                    particlePos.y + offsetY,
                    particlePos.z + offsetZ,
                    0, 0.1, 0
                );
            } else {
                // Обычные критические искры
                client.world.addParticle(
                    ParticleTypes.CRIT,
                    particlePos.x + offsetX,
                    particlePos.y + offsetY,
                    particlePos.z + offsetZ,
                    0, 0.1, 0
                );
            }
        }
        
        // Дополнительные частицы для финишера
        if (comboStep == 3) {
            for (int i = 0; i < 15; i++) {
                client.world.addParticle(
                    ParticleTypes.ENCHANT,
                    particlePos.x + (random.nextDouble() - 0.5) * 1.0,
                    particlePos.y + (random.nextDouble() - 0.5) * 1.0,
                    particlePos.z + (random.nextDouble() - 0.5) * 1.0,
                    0, 0.1, 0
                );
            }
        }
    }
}