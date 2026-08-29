package com.example.shinobicore.util;

import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;

/**
 * Maps JSON particle names to vanilla ParticleTypes.
 * HLD: Section 2.4
 * RULES: Some particles are forbidden, POOF is the safe fallback.
 */
public final class ParticleHelper {

    private ParticleHelper() {}

    public static ParticleEffect get(String name) {
        if (name == null) {
            return ParticleTypes.POOF;
        }
        if (name.equals("flame")) return ParticleTypes.FLAME;
        if (name.equals("smoke")) return ParticleTypes.SMOKE;
        if (name.equals("large_smoke")) return ParticleTypes.LARGE_SMOKE;
        if (name.equals("spark")) return ParticleTypes.ELECTRIC_SPARK;
        if (name.equals("splash")) return ParticleTypes.SPLASH;
        if (name.equals("bubble")) return ParticleTypes.BUBBLE;
        if (name.equals("crit")) return ParticleTypes.CRIT;
        if (name.equals("enchant")) return ParticleTypes.ENCHANT;
        if (name.equals("cloud")) return ParticleTypes.CLOUD;
        if (name.equals("ash")) return ParticleTypes.WHITE_ASH;
        if (name.equals("drip")) return ParticleTypes.DRIPPING_WATER;
        return ParticleTypes.POOF;
    }
}