package com.example.shinobicore.jutsu.effects;

import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * S13-02: Clan-specific particle and effect helpers.
 * Each clan has unique visual identity.
 */
public class ClanParticleEffects {

    // === UCHIHA: red fire ===
    public static void fireBurst(ServerWorld w, Vec3d pos, int count) {
        w.spawnParticles(ParticleTypes.FLAME, pos.x, pos.y + 1, pos.z, count, 0.6, 0.6, 0.6, 0.05);
        w.spawnParticles(ParticleTypes.LAVA, pos.x, pos.y + 1, pos.z, count/3, 0.4, 0.4, 0.4, 0.02);
    }
    public static void susanooAura(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.SOUL_FIRE_FLAME, pos.x, pos.y + 1, pos.z, 15, 0.5, 1.0, 0.5, 0.02);
        w.spawnParticles(dustColor(0.9f, 0.2f, 0.1f), pos.x, pos.y + 1.2, pos.z, 8, 0.3, 0.3, 0.3, 0.01);
    }

    // === HYUGA: white/blue chakra ===
    public static void byakuganPulse(ServerWorld w, Vec3d pos) {
        w.spawnParticles(dustColor(0.8f, 0.9f, 1.0f), pos.x, pos.y + 1, pos.z, 20, 0.8, 0.8, 0.8, 0.01);
        w.spawnParticles(ParticleTypes.ENCHANT, pos.x, pos.y + 1, pos.z, 10, 0.5, 0.5, 0.5, 0.1);
    }

    // === UZUMAKI: red/orange chains ===
    public static void chakraChain(ServerWorld w, Vec3d from, Vec3d to) {
        Vec3d dir = to.subtract(from).normalize();
        for (int i = 0; i < 10; i++) {
            Vec3d p = from.add(dir.multiply(i * 0.3));
            w.spawnParticles(dustColor(1.0f, 0.4f, 0.1f), p.x, p.y, p.z, 2, 0.05, 0.05, 0.05, 0.0);
        }
    }
    public static void barrierSeal(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.ENCHANT, pos.x, pos.y + 1, pos.z, 25, 0.8, 0.8, 0.8, 0.1);
        w.spawnParticles(dustColor(1.0f, 0.5f, 0.1f), pos.x, pos.y + 1, pos.z, 10, 0.5, 0.5, 0.5, 0.02);
    }

    // === SENJU: green wood ===
    public static void woodGrowth(ServerWorld w, Vec3d pos, float radius) {
        w.spawnParticles(ParticleTypes.HAPPY_VILLAGER, pos.x, pos.y + 1, pos.z, 20, radius, 0.5, radius, 0.05);
        w.spawnParticles(ParticleTypes.SPORE_BLOSSOM_AIR, pos.x, pos.y + 1, pos.z, 15, radius, 1.0, radius, 0.02);
    }
    public static void regeneration(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.HEART, pos.x, pos.y + 1.5, pos.z, 6, 0.3, 0.3, 0.3, 0.02);
        w.spawnParticles(ParticleTypes.HAPPY_VILLAGER, pos.x, pos.y + 1, pos.z, 10, 0.4, 0.4, 0.4, 0.02);
    }

    // === NARA: dark shadows ===
    public static void shadowGrab(ServerWorld w, Vec3d from, Vec3d to) {
        Vec3d dir = to.subtract(from).normalize();
        for (int i = 0; i < 12; i++) {
            Vec3d p = from.add(dir.multiply(i * 0.25));
            w.spawnParticles(ParticleTypes.LARGE_SMOKE, p.x, p.y + 0.1, p.z, 2, 0.05, 0.02, 0.05, 0.0);
        }
    }
    public static void shadowTrap(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.SMOKE, pos.x, pos.y + 0.1, pos.z, 15, 0.6, 0.1, 0.6, 0.02);
        w.spawnParticles(ParticleTypes.LARGE_SMOKE, pos.x, pos.y + 0.2, pos.z, 8, 0.4, 0.1, 0.4, 0.01);
    }

    // === ABURAME: insects/dark ===
    public static void insectSwarm(ServerWorld w, Vec3d pos, float radius) {
        w.spawnParticles(ParticleTypes.ITEM_SLIME, pos.x, pos.y + 1, pos.z, 25, radius, 0.6, radius, 0.08);
        w.spawnParticles(dustColor(0.2f, 0.15f, 0.1f), pos.x, pos.y + 1, pos.z, 12, radius * 0.7, 0.5, radius * 0.7, 0.01);
    }
    public static void bugShield(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.ITEM_SLIME, pos.x, pos.y + 1, pos.z, 15, 0.5, 0.8, 0.5, 0.05);
        w.spawnParticles(ParticleTypes.CLOUD, pos.x, pos.y + 1, pos.z, 8, 0.3, 0.3, 0.3, 0.02);
    }

    // === INUZUKA: dust/impact ===
    public static void fangStrike(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.CRIT, pos.x, pos.y + 1, pos.z, 12, 0.4, 0.4, 0.4, 0.15);
        w.spawnParticles(ParticleTypes.POOF, pos.x, pos.y + 0.5, pos.z, 8, 0.3, 0.2, 0.3, 0.03);
    }
    public static void spinAttack(ServerWorld w, Vec3d pos, float radius) {
        w.spawnParticles(ParticleTypes.CRIT, pos.x, pos.y + 0.8, pos.z, 20, radius, 0.4, radius, 0.2);
        w.spawnParticles(ParticleTypes.CLOUD, pos.x, pos.y + 0.5, pos.z, 12, radius, 0.3, radius, 0.05);
    }

    // === AKIMICHI: expansion/dust ===
    public static void expansion(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.POOF, pos.x, pos.y + 1, pos.z, 20, 0.8, 0.8, 0.8, 0.08);
        w.spawnParticles(ParticleTypes.CLOUD, pos.x, pos.y + 1, pos.z, 10, 0.6, 0.6, 0.6, 0.03);
    }
    public static void stoneFist(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.CRIT, pos.x, pos.y + 1, pos.z, 15, 0.5, 0.5, 0.5, 0.2);
        w.spawnParticles(ParticleTypes.LAVA, pos.x, pos.y + 1, pos.z, 10, 0.4, 0.4, 0.4, 0.1);  // S13-02: replaced BLOCK (requires BlockState)
    }

    // === HATAKE: lightning ===
    public static void lightningBlade(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.ELECTRIC_SPARK, pos.x, pos.y + 1, pos.z, 25, 0.5, 0.5, 0.5, 0.15);
        w.spawnParticles(ParticleTypes.FLASH, pos.x, pos.y + 1.2, pos.z, 1, 0, 0, 0, 0);
    }
    public static void raikiri(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.ELECTRIC_SPARK, pos.x, pos.y + 1, pos.z, 40, 0.7, 0.7, 0.7, 0.2);
        w.spawnParticles(ParticleTypes.FLASH, pos.x, pos.y + 1.2, pos.z, 2, 0, 0, 0, 0);
        w.spawnParticles(dustColor(0.6f, 0.8f, 1.0f), pos.x, pos.y + 1, pos.z, 15, 0.5, 0.5, 0.5, 0.02);
    }

    // === COMMON ===
    public static void applySlowness(LivingEntity e, int ticks, int amp) {
        e.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, ticks, amp, false, true));
    }
    public static void applyResistance(LivingEntity e, int ticks, int amp) {
        e.addStatusEffect(new StatusEffectInstance(StatusEffects.RESISTANCE, ticks, amp, false, true));
    }
    public static void applyStrength(LivingEntity e, int ticks, int amp) {
        e.addStatusEffect(new StatusEffectInstance(StatusEffects.STRENGTH, ticks, amp, false, true));
    }
    public static void applyPoison(LivingEntity e, int ticks, int amp) {
        e.addStatusEffect(new StatusEffectInstance(StatusEffects.POISON, ticks, amp, false, true));
    }

    public static void meleeDamage(ServerWorld w, LivingEntity attacker, Vec3d pos, float radius, float damage) {
        Box aoe = new Box(pos.subtract(radius, radius, radius), pos.add(radius, radius, radius));
        for (var e : w.getOtherEntities(attacker, aoe)) {
            if (e instanceof LivingEntity liv) {
                liv.damage(attacker.getDamageSources().playerAttack((net.minecraft.server.network.ServerPlayerEntity) attacker), damage);
            }
        }
    }

    public static void aoeDamage(ServerWorld w, LivingEntity attacker, Vec3d pos, float radius, float damage) {
        Box aoe = new Box(pos.subtract(radius, radius, radius), pos.add(radius, radius, radius));
        for (var e : w.getOtherEntities(attacker, aoe)) {
            if (e instanceof LivingEntity liv) {
                liv.damage(attacker.getDamageSources().playerAttack((net.minecraft.server.network.ServerPlayerEntity) attacker), damage);
            }
        }
    }

    private static DustParticleEffect dustColor(float r, float g, float b) {
        return new DustParticleEffect(new Vector3f(r, g, b), 1.0f);
    }
}