package com.example.shinobicore.client.combat;

import com.example.shinobicore.client.CinematicCamera;
import com.example.shinobicore.config.ModConfig;
import net.minecraft.client.MinecraftClient;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * Combat Pack v1 (1.1.4): клиентский «сок» попадания.
 * Вызывается из приёмника HIT_STOP: раз сервер сказал «заморозить кадр»,
 * значит удар долетел — добавляем тряску камеры и искры в точке контакта.
 */
public final class CombatFeelClient {

    private CombatFeelClient() {}

    public static void onHitStop(MinecraftClient client, int entityId, int durationMs) {
        if (client.world == null || client.player == null) return;

        // 1) тряска камеры пропорциональна силе стоп-кадра (финишер трясёт сильнее)
        float shakeScale = ModConfig.instance.cameraFx.shakeScale;
        if (shakeScale > 0.001f) {
            float shake = Math.min(0.30f, 0.04f + durationMs / 1000f * 0.16f) * shakeScale;
            CinematicCamera.addShake(shake);
        }

        // 2) искры и капли в точке контакта (только для близкой цели — экономим частицы)
        Entity e = client.world.getEntityById(entityId);
        if (!(e instanceof LivingEntity target)) return;
        if (target.distanceTo(client.player) > 24f) return;
        Vec3d c = target.getPos().add(0, target.getHeight() * 0.6, 0);

        for (int i = 0; i < 8; i++) {
            client.world.addParticle(ParticleTypes.CRIT,
                    c.x + (Math.random() - 0.5) * 0.4,
                    c.y + (Math.random() - 0.5) * 0.4,
                    c.z + (Math.random() - 0.5) * 0.4,
                    (Math.random() - 0.5) * 0.12, Math.random() * 0.08, (Math.random() - 0.5) * 0.12);
        }
        Vector3f red = new Vector3f(0.75f, 0.08f, 0.08f);
        for (int i = 0; i < 4; i++) {
            client.world.addParticle(new DustParticleEffect(red, 0.7f),
                    c.x + (Math.random() - 0.5) * 0.3,
                    c.y + (Math.random() - 0.5) * 0.3,
                    c.z + (Math.random() - 0.5) * 0.3,
                    (Math.random() - 0.5) * 0.05, -0.03, (Math.random() - 0.5) * 0.05);
        }
        // 3) тяжёлые удары (финишер/добивание) — белая вспышка
        if (durationMs >= 200) {
            client.world.addParticle(ParticleTypes.END_ROD, c.x, c.y, c.z, 0.15, 0.15, 0.15);
            client.world.addParticle(ParticleTypes.END_ROD, c.x, c.y, c.z, 0.15, 0.15, 0.15);
        }
    }
}