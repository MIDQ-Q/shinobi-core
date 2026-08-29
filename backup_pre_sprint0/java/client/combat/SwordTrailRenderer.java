package com.example.shinobicore.client.combat;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

/**
 * Sword Trail: arc of particles following katana slashes.
 * Each combo step has a different trail pattern:
 * - Step 0: horizontal left-to-right arc
 * - Step 1: horizontal right-to-left arc
 * - Step 2: vertical top-to-bottom arc
 * - Step 3 (finisher): full 360 ring + orange flash
 */
public class SwordTrailRenderer {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(SwordTrailRenderer::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null) return;
        tickCounter++;
    }

    /**
     * Called from KenjutsuClientHandler.tryAttack() after each slash.
     * Spawns trail particles in an arc pattern.
     */
    public static void playSlashTrail(AbstractClientPlayerEntity player, int comboStep) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.world == null) return;

        Vec3d pos = player.getPos().add(0, 1.2, 0);
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        Vec3d up = new Vec3d(0, 1, 0);

        switch (comboStep) {
            case 0 -> spawnHorizontalArc(client, pos, right, up, true);   // left to right
            case 1 -> spawnHorizontalArc(client, pos, right, up, false);  // right to left
            case 2 -> spawnVerticalArc(client, pos, look, right);         // top to bottom
            case 3 -> spawnFinisherRing(client, pos);                     // 360 ring
        case 4 -> spawnHorizontalArc(client, pos, right, up, true);   // step 4
        case 5 -> spawnFinisherRing(client, pos);                     // step 5 finisher
        }
    }

    private static void spawnHorizontalArc(MinecraftClient client, Vec3d center,
                                            Vec3d right, Vec3d up, boolean leftToRight) {
        int count = 14;
        for (int i = 0; i < count; i++) {
            float t = (float) i / count;
            float angle = leftToRight ? (t * 1.8f - 0.9f) : (0.9f - t * 1.8f);
            Vec3d offset = right.multiply(Math.cos(angle) * 1.6)
                    .add(up.multiply(Math.sin(angle) * 0.6 + 0.2));
            Vec3d p = center.add(offset);

            // White sweep particles (main trail)
            client.world.addParticle(ParticleTypes.SWEEP_ATTACK,
                    p.x, p.y, p.z,
                    offset.x * 0.05, offset.y * 0.05, offset.z * 0.05);

            // Small white sparkle at trail edge
            if (i % 3 == 0) {
                client.world.addParticle(ParticleTypes.CRIT,
                        p.x, p.y, p.z, 0, 0.02, 0);
            }
        }
    }

    private static void spawnVerticalArc(MinecraftClient client, Vec3d center,
                                          Vec3d look, Vec3d right) {
        int count = 14;
        for (int i = 0; i < count; i++) {
            float t = (float) i / count;
            float angle = t * 1.6f - 0.8f; // -0.8 to +0.8 radians
            Vec3d offset = look.multiply(0.8)
                    .add(new Vec3d(0, 1, 0).multiply(Math.cos(angle) * 1.2))
                    .add(right.multiply(Math.sin(angle) * 0.4));
            Vec3d p = center.add(offset);

            client.world.addParticle(ParticleTypes.SWEEP_ATTACK,
                    p.x, p.y, p.z,
                    0, -0.06, 0);

            if (i % 4 == 0) {
                client.world.addParticle(ParticleTypes.CRIT,
                        p.x, p.y, p.z, 0, -0.03, 0);
            }
        }
    }

    private static void spawnFinisherRing(MinecraftClient client, Vec3d center) {
        // 360 degree ring of particles
        int count = 28;
        for (int i = 0; i < count; i++) {
            float angle = (float) (i / (double) count) * (float)(Math.PI * 2);
            double r = 1.8;
            double x = center.x + Math.cos(angle) * r;
            double z = center.z + Math.sin(angle) * r;
            double y = center.y + Math.sin(angle * 2) * 0.3;

            // Orange enchant particles for finisher
            client.world.addParticle(ParticleTypes.ENCHANT,
                    x, y, z,
                    Math.cos(angle) * 0.1, 0.05, Math.sin(angle) * 0.1);

            // White crit sparks
            if (i % 3 == 0) {
                client.world.addParticle(ParticleTypes.CRIT,
                        x, y, z, 0, 0.08, 0);
            }
        }

        // Central flash (small explosion particle)
        client.world.addParticle(ParticleTypes.EXPLOSION,
                center.x, center.y, center.z, 0, 0, 0);

        // Rising sparks
        for (int i = 0; i < 8; i++) {
            client.world.addParticle(ParticleTypes.END_ROD,
                    center.x + (Math.random() - 0.5) * 1.5,
                    center.y + Math.random() * 0.5,
                    center.z + (Math.random() - 0.5) * 1.5,
                    0, 0.12, 0);
        }
    }

    /**
     * Jump attack trail: downward arc.
     */
    public static void playJumpTrail(AbstractClientPlayerEntity player) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.world == null) return;
        Vec3d pos = player.getPos().add(0, 1.5, 0);
        Vec3d look = player.getRotationVector();
        for (int i = 0; i < 18; i++) {
            float t = (float) i / 18;
            Vec3d offset = look.multiply(0.5 + t * 1.5)
                    .add(new Vec3d(0, -t * 2.0, 0));
            Vec3d p = pos.add(offset);
            client.world.addParticle(ParticleTypes.SWEEP_ATTACK, p.x, p.y, p.z, 0, -0.1, 0);
            if (i % 3 == 0) client.world.addParticle(ParticleTypes.CRIT, p.x, p.y, p.z, 0, -0.05, 0);
        }
        client.world.addParticle(ParticleTypes.EXPLOSION, pos.x + look.x * 1.5, pos.y - 1.5, pos.z + look.z * 1.5, 0, 0, 0);
    }

    /**
     * Sprint attack trail: forward thrust.
     */
    public static void playSprintTrail(AbstractClientPlayerEntity player) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.world == null) return;
        Vec3d pos = player.getPos().add(0, 1.2, 0);
        Vec3d look = player.getRotationVector();
        for (int i = 0; i < 12; i++) {
            float t = (float) i / 12;
            Vec3d p = pos.add(look.multiply(t * 3.0))
                    .add(new Vec3d((Math.random()-0.5)*0.3, (Math.random()-0.5)*0.3, (Math.random()-0.5)*0.3));
            client.world.addParticle(ParticleTypes.SWEEP_ATTACK, p.x, p.y, p.z, look.x * 0.1, 0, look.z * 0.1);
        }
        for (int i = 0; i < 6; i++) {
            client.world.addParticle(ParticleTypes.CLOUD,
                    pos.x + look.x * 2.5 + (Math.random()-0.5)*0.5,
                    pos.y + (Math.random()-0.5)*0.5,
                    pos.z + look.z * 2.5 + (Math.random()-0.5)*0.5, 0, 0.02, 0);
        }
    }

    /**
     * Called when a projectile is deflected.
     * Spawns bright sparks at the deflection point.
     */
    public static void playDeflectSparks(AbstractClientPlayerEntity player) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.world == null) return;

        Vec3d pos = player.getPos().add(0, 1.3, 0);
        Vec3d look = player.getRotationVector();
        Vec3d sparkPos = pos.add(look.multiply(0.8));

        // Bright white sparks burst
        for (int i = 0; i < 16; i++) {
            double angle = Math.random() * Math.PI * 2;
            double speed = 0.1 + Math.random() * 0.15;
            client.world.addParticle(ParticleTypes.CRIT,
                    sparkPos.x, sparkPos.y, sparkPos.z,
                    Math.cos(angle) * speed,
                    Math.random() * 0.15,
                    Math.sin(angle) * speed);
        }

        // Electric spark for metallic feel
        for (int i = 0; i < 6; i++) {
            client.world.addParticle(ParticleTypes.ELECTRIC_SPARK,
                    sparkPos.x + (Math.random() - 0.5) * 0.4,
                    sparkPos.y + (Math.random() - 0.5) * 0.4,
                    sparkPos.z + (Math.random() - 0.5) * 0.4,
                    0, 0.05, 0);
        }

        // Small flash
        client.world.addParticle(ParticleTypes.FLASH,
                sparkPos.x, sparkPos.y, sparkPos.z, 0, 0, 0);
    }
}