package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.enums.ElementType;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Vec3d;

public class Fx {

    public static void elementBurst(ServerWorld world, Vec3d pos, ElementType el, int count) {
        if (el == null) el = ElementType.NONE;
        switch (el) {
            case FIRE -> world.spawnParticles(ParticleTypes.FLAME, pos.x, pos.y, pos.z, count, 0.3, 0.3, 0.3, 0.02);
            case WATER -> world.spawnParticles(ParticleTypes.SPLASH, pos.x, pos.y, pos.z, count, 0.3, 0.3, 0.3, 0.02);
            case WIND -> world.spawnParticles(ParticleTypes.CLOUD, pos.x, pos.y, pos.z, count, 0.3, 0.3, 0.3, 0.02);
            case EARTH -> world.spawnParticles(ParticleTypes.SMOKE, pos.x, pos.y, pos.z, count, 0.3, 0.3, 0.3, 0.01);
            case LIGHTNING -> world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, pos.x, pos.y, pos.z, count, 0.4, 0.4, 0.4, 0.05);
            case YIN -> world.spawnParticles(ParticleTypes.REVERSE_PORTAL, pos.x, pos.y, pos.z, count, 0.3, 0.3, 0.3, 0.02);
            case YANG -> world.spawnParticles(ParticleTypes.HAPPY_VILLAGER, pos.x, pos.y, pos.z, count, 0.3, 0.3, 0.3, 0.02);
            default -> world.spawnParticles(ParticleTypes.ENCHANT, pos.x, pos.y, pos.z, count, 0.3, 0.3, 0.3, 0.02);
        }
    }

    public static void trail(ServerWorld world, Vec3d pos, ElementType el) {
        elementBurst(world, pos, el, 2);
    }

    public static void castSound(net.minecraft.server.network.ServerPlayerEntity player, com.example.shinobicore.jutsu.core.JutsuDefinition jutsu) {
        ElementType el = jutsu.getElement();
        ServerWorld world = player.getServerWorld();
        Vec3d pos = player.getPos();
        switch (el) {
            case FIRE -> world.playSound(null, pos.x, pos.y, pos.z, SoundEvents.ENTITY_BLAZE_SHOOT, SoundCategory.PLAYERS, 1.0f, 1.0f);
            case LIGHTNING -> world.playSound(null, pos.x, pos.y, pos.z, SoundEvents.ENTITY_CREEPER_PRIMED, SoundCategory.PLAYERS, 0.8f, 1.4f);
            case WATER -> world.playSound(null, pos.x, pos.y, pos.z, SoundEvents.ENTITY_GENERIC_SPLASH, SoundCategory.PLAYERS, 1.0f, 1.0f);
            default -> world.playSound(null, pos.x, pos.y, pos.z, SoundEvents.ENTITY_PLAYER_ATTACK_STRONG, SoundCategory.PLAYERS, 0.7f, 1.2f);
        }
    }
}