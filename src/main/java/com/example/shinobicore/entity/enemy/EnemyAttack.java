package com.example.shinobicore.entity.enemy;

import net.minecraft.sound.SoundEvent;

/**
 * S9-02: Definition of an enemy attack.
 * Simplified attacks (not full jutsu cast).
 */
public class EnemyAttack {
    public enum AttackType { MELEE, RANGED, AOE, DASH_ATTACK }

    private final String name;
    private final AttackType type;
    private final float damage;
    private final float range;
    private final int telegraphTicks;
    private final int cooldownTicks;
    private final SoundEvent telegraphSound;

    public EnemyAttack(String name, AttackType type, float damage, float range,
                       int telegraphTicks, int cooldownTicks, SoundEvent telegraphSound) {
        this.name = name;
        this.type = type;
        this.damage = damage;
        this.range = range;
        this.telegraphTicks = telegraphTicks;
        this.cooldownTicks = cooldownTicks;
        this.telegraphSound = telegraphSound;
    }

    public String getName() { return name; }
    public AttackType getType() { return type; }
    public float getDamage() { return damage; }
    public float getRange() { return range; }
    public int getTelegraphTicks() { return telegraphTicks; }
    public int getCooldownTicks() { return cooldownTicks; }
    public SoundEvent getTelegraphSound() { return telegraphSound; }

    /** Create default melee attack. */
    public static EnemyAttack melee(float damage, int telegraph, int cooldown) {
        return new EnemyAttack("melee_strike", AttackType.MELEE, damage, 2.5f,
            telegraph, cooldown, net.minecraft.sound.SoundEvents.ENTITY_ZOMBIE_ATTACK_WOODEN_DOOR);
    }

    /** Create default ranged attack. */
    public static EnemyAttack ranged(float damage, float range, int telegraph, int cooldown) {
        return new EnemyAttack("ranged_shot", AttackType.RANGED, damage, range,
            telegraph, cooldown, net.minecraft.sound.SoundEvents.ENTITY_SKELETON_SHOOT);
    }

    /** Create default AOE attack. */
    public static EnemyAttack aoe(float damage, float range, int telegraph, int cooldown) {
        return new EnemyAttack("aoe_burst", AttackType.AOE, damage, range,
            telegraph, cooldown, net.minecraft.sound.SoundEvents.ENTITY_CREEPER_PRIMED);
    }

    /** Create default dash attack. */
    public static EnemyAttack dashAttack(float damage, int telegraph, int cooldown) {
        return new EnemyAttack("dash_strike", AttackType.DASH_ATTACK, damage, 4.0f,
            telegraph, cooldown, net.minecraft.sound.SoundEvents.ENTITY_ENDERMAN_TELEPORT);
    }
}