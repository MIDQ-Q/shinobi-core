package com.example.shinobicore.combat;

import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Kenjutsu stances (HLD 4.2).
 * AGGRESSIVE: balanced plus damage.
 * IAI: high damage, high risk, speed boost.
 * SEIGAN: defensive 360 guard, chakra regen.
 */
public enum Stance {

    AGGRESSIVE("aggressive", 1.15f),
    IAI("iai", 1.30f),
    SEIGAN("seigan", 0.80f);

    private final String id;
    private final float damageMult;

    Stance(String id, float damageMult) {
        this.id = id;
        this.damageMult = damageMult;
    }

    public String getId() { return id; }
    public float getDamageMult() { return damageMult; }

    public static Stance fromId(String id) {
        if (id == null) return AGGRESSIVE;
        for (Stance s : values()) {
            if (s.id.equals(id)) return s;
        }
        return AGGRESSIVE;
    }

    public static Stance next(Stance current) {
        Stance[] all = values();
        int idx = current.ordinal() + 1;
        if (idx >= all.length) {
            idx = 0;
        }
        return all[idx];
    }

    /**
     * Re-applied every second by StanceManager (hidden effects).
     */
    public void applyPassives(ServerPlayerEntity player) {
        if (this == IAI) {
            player.addStatusEffect(new StatusEffectInstance(
                StatusEffects.SPEED, 40, 0, true, false, false));
        }
        if (this == SEIGAN) {
            player.addStatusEffect(new StatusEffectInstance(
                StatusEffects.RESISTANCE, 40, 0, true, false, false));
        }
        if (this == AGGRESSIVE) {
            player.addStatusEffect(new StatusEffectInstance(
                StatusEffects.HASTE, 40, 0, true, false, false));
        }
    }
}