package com.example.shinobicore.jutsu;

import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffect;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import net.minecraft.sound.SoundEvent;
import net.minecraft.sound.SoundCategory;
import net.minecraft.util.Identifier;

/**
 * Server-side visual: purple aura around entities suffering from genjutsu.
 * Detects the unique debuff combos applied by GenjutsuBehavior and spawns
 * purple particles around the afflicted entity every 5 ticks.
 */
public class GenjutsuAuraEffect {
    private static int tickCounter = 0;

    public static void tick(ServerWorld world) {
        tickCounter++;
        if (tickCounter % 5 != 0) return;



        // Iterate all living entities in the world
        for (Object obj : world.iterateEntities()) {
            if (!(obj instanceof LivingEntity)) continue;
            LivingEntity living = (LivingEntity) obj;
            if (!living.isAlive()) continue;
            if (!isUnderGenjutsu(living)) continue;

            spawnGenjutsuAura(world, living);
        }
    }

    /**
     * Detects our unique genjutsu debuff combinations:
     * - fear:      SLOWNESS + NAUSEA (+ MINING_FATIGUE)
     * - blindness: BLINDNESS + WEAKNESS
     * - nightmare: BLINDNESS + NAUSEA + SLOWNESS + WEAKNESS
     * - paralysis: SLOWNESS(255) + MINING_FATIGUE(255)
     *
     * Core marker: SLOWNESS + NAUSEA together, OR BLINDNESS + WEAKNESS together.
     * These combos are unique to our genjutsu (vanilla doesn't apply them together).
     */
    private static boolean isUnderGenjutsu(LivingEntity entity) {
        boolean hasSlowness = entity.hasStatusEffect(StatusEffects.SLOWNESS);
        boolean hasNausea = entity.hasStatusEffect(StatusEffects.NAUSEA);
        boolean hasBlindness = entity.hasStatusEffect(StatusEffects.BLINDNESS);
        boolean hasWeakness = entity.hasStatusEffect(StatusEffects.WEAKNESS);
        boolean hasMiningFatigue = entity.hasStatusEffect(StatusEffects.MINING_FATIGUE);

        // Fear / Nightmare / Paralysis marker
        if (hasSlowness && (hasNausea || hasMiningFatigue)) return true;

        // Blindness / Nightmare marker
        if (hasBlindness && hasWeakness) return true;

        return false;
    }

    private static void spawnGenjutsuAura(ServerWorld world, LivingEntity entity) {
        Vec3d pos = entity.getPos().add(0, entity.getHeight() * 0.5, 0);
        double bodyRadius = 0.6;
        double height = entity.getHeight();

        // Swirling purple portal particles in a helix around the body
        float phase = tickCounter * 0.15f;
        for (int i = 0; i < 4; i++) {
            float angle = phase + (i / 4.0f) * (float)(Math.PI * 2);
            double y = pos.y + (height * 0.5) * ((Math.sin(phase + i) + 1.0) * 0.5);
            double x = pos.x + Math.cos(angle) * bodyRadius;
            double z = pos.z + Math.sin(angle) * bodyRadius;

            world.spawnParticles(ParticleTypes.PORTAL,
                x, y, z,
                1, 0, 0.02, 0, 0.02);
        }

        // Occasional rising soul particles
        if (tickCounter % 10 == 0) {
            world.spawnParticles(ParticleTypes.SCULK_SOUL,
                pos.x + (Math.random() - 0.5) * 0.8,
                pos.y + height * 0.3,
                pos.z + (Math.random() - 0.5) * 0.8,
                1, 0, 0.08, 0, 0.01);
        }

        // Witch particles near the head (mental effect indicator)
        if (tickCounter % 15 == 0) {
            world.spawnParticles(ParticleTypes.WITCH,
                pos.x,
                pos.y + height * 0.85,
                pos.z,
                2, 0.3, 0.2, 0.3, 0.02);
        }

        // Ambient genjutsu sound every 30 ticks (eerie whispers) // PHASE_E_GEN_AMBIENT_SOUND
        if (tickCounter % 30 == 0) {
            SoundEvent ambientSound = SoundEvent.of(new Identifier("shinobicore", "genjutsu_ambient"));
            world.playSound(null, entity.getBlockPos(), ambientSound, SoundCategory.HOSTILE, 0.3f, 0.5f);
        }
    }
}