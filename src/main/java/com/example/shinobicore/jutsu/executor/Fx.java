package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.enums.ElementType;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

public class Fx {

    /** Element-typed burst */
    public static void elementBurst(ServerWorld world, Vec3d pos, ElementType el, int count) {
        if (el == null) el = ElementType.NONE;
        switch (el) {
            case FIRE -> {
                world.spawnParticles(ParticleTypes.FLAME, pos.x, pos.y, pos.z, count, 0.4, 0.4, 0.4, 0.03);
                world.spawnParticles(ParticleTypes.SMOKE, pos.x, pos.y, pos.z, count / 3, 0.3, 0.3, 0.3, 0.02);
            }
            case WATER -> world.spawnParticles(ParticleTypes.SPLASH, pos.x, pos.y, pos.z, count, 0.4, 0.4, 0.4, 0.03);
            case WIND -> {
                world.spawnParticles(ParticleTypes.CLOUD, pos.x, pos.y, pos.z, count, 0.4, 0.4, 0.4, 0.03);
                world.spawnParticles(ParticleTypes.CRIT, pos.x, pos.y, pos.z, count / 2, 0.3, 0.3, 0.3, 0.05);
            }
            case EARTH -> world.spawnParticles(ParticleTypes.SMOKE, pos.x, pos.y, pos.z, count, 0.4, 0.4, 0.4, 0.03);
            case LIGHTNING -> {
                world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, pos.x, pos.y, pos.z, count * 2, 0.4, 0.4, 0.4, 0.05);
                world.spawnParticles(ParticleTypes.ENCHANT, pos.x, pos.y, pos.z, count / 3, 0.3, 0.3, 0.3, 0.02);
            }
            case YIN -> world.spawnParticles(ParticleTypes.REVERSE_PORTAL, pos.x, pos.y, pos.z, count, 0.4, 0.4, 0.4, 0.03);
            case YANG -> world.spawnParticles(ParticleTypes.HAPPY_VILLAGER, pos.x, pos.y, pos.z, count, 0.4, 0.4, 0.4, 0.03);
            default -> world.spawnParticles(ParticleTypes.ENCHANT, pos.x, pos.y, pos.z, count, 0.4, 0.4, 0.4, 0.03);
        }
    }

    /** Trail along a moving position (projectiles, dashes) */
    public static void trail(ServerWorld world, Vec3d pos, ElementType el) {
        if (el == null) el = ElementType.NONE;
        switch (el) {
            case FIRE -> {
                world.spawnParticles(ParticleTypes.FLAME, pos.x, pos.y, pos.z, 2, 0.1, 0.1, 0.1, 0.01);
                world.spawnParticles(ParticleTypes.SMOKE, pos.x, pos.y, pos.z, 1, 0.1, 0.1, 0.1, 0.0);
            }
            case WATER -> world.spawnParticles(ParticleTypes.SPLASH, pos.x, pos.y, pos.z, 2, 0.1, 0.1, 0.1, 0.01);
            case WIND -> world.spawnParticles(ParticleTypes.CLOUD, pos.x, pos.y, pos.z, 2, 0.1, 0.1, 0.1, 0.01);
            case EARTH -> world.spawnParticles(ParticleTypes.SMOKE, pos.x, pos.y, pos.z, 2, 0.1, 0.1, 0.1, 0.01);
            case LIGHTNING -> world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, pos.x, pos.y, pos.z, 3, 0.1, 0.1, 0.1, 0.03);
            case YIN -> world.spawnParticles(ParticleTypes.REVERSE_PORTAL, pos.x, pos.y, pos.z, 2, 0.1, 0.1, 0.1, 0.01);
            case YANG -> world.spawnParticles(ParticleTypes.HAPPY_VILLAGER, pos.x, pos.y, pos.z, 2, 0.1, 0.1, 0.1, 0.01);
            default -> world.spawnParticles(ParticleTypes.ENCHANT, pos.x, pos.y, pos.z, 2, 0.1, 0.1, 0.1, 0.01);
        }
    }

    /**
     * Spinning sphere effect - used by Rasengan / Rasenshuriken held in hand.
     * Multiple rings of particles rotating at different speeds.
     */
    public static void spinningSphere(ServerWorld world, Vec3d center, ElementType el, double radius, int tick) {
        if (el == null) el = ElementType.NONE;
        double baseAngle = tick * 0.4;
        ParticleEffect particle = getElementParticle(el);

        // Three rotating rings on perpendicular axes
        for (int ring = 0; ring < 3; ring++) {
            double phi = ring * Math.PI / 3.0; // 60° apart
            for (int i = 0; i < 8; i++) {
                double angle = baseAngle + (i / 8.0) * Math.PI * 2.0;
                double x = center.x + radius * Math.cos(angle) * Math.cos(phi);
                double y = center.y + radius * Math.sin(angle);
                double z = center.z + radius * Math.cos(angle) * Math.sin(phi);
                world.spawnParticles(particle, x, y, z, 1, 0, 0, 0, 0);
            }
        }

        // Core glow
        world.spawnParticles(ParticleTypes.END_ROD, center.x, center.y, center.z, 2, 0.1, 0.1, 0.1, 0.0);
    }

    /** Expanding impact ring - explosion / burst effect */
    public static void impactRing(ServerWorld world, Vec3d center, ElementType el, double maxRadius, int tick, int duration) {
        double progress = (double) tick / duration;
        double radius = maxRadius * progress;
        int count = (int) (20 + progress * 20);
        ParticleEffect particle = getElementParticle(el);
        for (int i = 0; i < count; i++) {
            double angle = (i / (double) count) * Math.PI * 2.0;
            double x = center.x + radius * Math.cos(angle);
            double y = center.y + 0.5 + (1.0 - progress) * 1.5;
            double z = center.z + radius * Math.sin(angle);
            world.spawnParticles(particle, x, y, z, 1, 0, 0.05, 0, 0.01);
        }
    }

    private static ParticleEffect getElementParticle(ElementType el) {
        return switch (el) {
            case FIRE -> ParticleTypes.FLAME;
            case WATER -> ParticleTypes.SPLASH;
            case WIND -> ParticleTypes.CLOUD;
            case EARTH -> new DustParticleEffect(new Vector3f(0.6f, 0.4f, 0.2f), 1.0f);
            case LIGHTNING -> ParticleTypes.ELECTRIC_SPARK;
            case YIN -> ParticleTypes.REVERSE_PORTAL;
            case YANG -> ParticleTypes.HAPPY_VILLAGER;
            default -> ParticleTypes.ENCHANT;
        };
    }
}