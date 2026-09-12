package com.example.shinobicore.mixin;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.CombatFeelServer;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.damage.DamageTypes;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.entity.projectile.PersistentProjectileEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.ModifyVariable;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * Катана-защита: отклонение снарядов (было) + Combat Pack v1 (1.1.4):
 *
 *   ПАРРИРОВАНИЕ — удар в пределах окна combat.parryWindowMs (400 мс) от
 *   нажатия кнопки отражения: урон полностью отменён, атакующий отброшен
 *   и замедлен, стоп-кадр, искры, «звон».
 *
 *   БЛОК — удержание отражения в DEFENSIVE-стойке: входящий ближний урон
 *   режется на combat.blockReduction (60%), каждый заблокированный удар
 *   добавляет усталость (combat.blockFatigue) — блок не вечный.
 *
 * Прежняя логика снарядов сохранена: tap-отклонение (180° фронт) и
 * hold-щит DEFENSIVE (360°).
 */
@Mixin(LivingEntity.class)
public abstract class KatanaDeflectMixin {

    @Inject(method = "damage", at = @At("HEAD"), cancellable = true)
    private void shinobicore_katanaDeflect(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (!(self instanceof ServerPlayerEntity player)) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (data == null) return;
        long now = System.currentTimeMillis();
        KenjutsuStance stance = KenjutsuStance.fromId(data.getKatanaStanceId());
        boolean tapActive = now < data.getKatanaDeflectUntil();
        boolean holdActive = data.isKatanaDeflectHeld() && stance.canDeflect();

        Entity projectile = source.getSource();
        if (projectile instanceof PersistentProjectileEntity) {
            ShinobiCore.LOGGER.debug("[DEFLECT] damage tick: stance={}, tapActive={}, holdActive={}",
                    stance.getId(), tapActive, holdActive);
        }

        if (!tapActive && !holdActive) return;

        // ================================================================
        //  БЛИЖНИЙ БОЙ: парирование (окно) — отменяем урон полностью
        // ================================================================
        if (projectile == null) {
            // Блок/парирование работают только против ближнего боя (yarn 1.20.1:
            // у DamageSource нет isExplosion()/isFire() — только isOf(DamageTypes.*))
            if (!isMelee(source)) {
                return;
            }
            Entity attackerEnt = source.getAttacker();
            if (!(attackerEnt instanceof LivingEntity attacker) || attacker == player) return;

            long pressMs = CombatFeelServer.getDeflectPressMs(player.getUuid());
            boolean inParryWindow = tapActive || (pressMs > 0 && now - pressMs <= CombatFeelServer.parryWindowMs());
            boolean feedbackReady = now - data.getLastDeflectReflectMs() >= 200;

            if (inParryWindow && feedbackReady) {
                // === PARRY ===
                data.setLastDeflectReflectMs(now);
                float kb = CombatFeelServer.parryKnockback();
                Vec3d away = attacker.getPos().subtract(player.getPos());
                if (away.lengthSquared() < 1e-6) away = player.getRotationVector().multiply(-1);
                away = away.normalize();
                attacker.addVelocity(away.x * kb, 0.35, away.z * kb);
                attacker.velocityModified = true;
                attacker.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 30, 1, false, false));

                player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.6f);
                player.playSound(SoundEvents.ENTITY_PLAYER_ATTACK_CRIT, 0.9f, 0.7f);
                if (player.getWorld() instanceof ServerWorld sw) {
                    Vec3d c = player.getPos().add(0, 1.1, 0).add(player.getRotationVector().multiply(0.6));
                    sw.spawnParticles(ParticleTypes.CRIT, c.x, c.y, c.z, 18, 0.35, 0.35, 0.35, 0.12);
                    sw.spawnParticles(ParticleTypes.END_ROD, c.x, c.y, c.z, 8, 0.2, 0.2, 0.2, 0.02);
                    Vector3f steel = new Vector3f(0.85f, 0.9f, 1.0f);
                    sw.spawnParticles(new DustParticleEffect(steel, 1.2f), c.x, c.y, c.z, 8, 0.3, 0.3, 0.3, 0.02);
                }
                ShinobiCore.broadcastHitStop(player, attacker, 140, 420);
                player.sendMessage(Text.literal("\u00a76\u00a7lPARRY!"), false);
                cir.setReturnValue(false);
                return;
            }

            // === BLOCK (hold в защитной стойке): урон режется в ModifyVariable ниже ===
            if (holdActive && stance == KenjutsuStance.DEFENSIVE) {
                if (feedbackReady) {
                    data.setLastDeflectReflectMs(now);
                    data.setFatigue(data.getFatigue() + CombatFeelServer.blockFatigue());
                    player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 0.65f, 1.0f);
                    if (player.getWorld() instanceof ServerWorld sw) {
                        Vec3d c = player.getPos().add(0, 1.0, 0).add(player.getRotationVector().multiply(0.5));
                        sw.spawnParticles(ParticleTypes.CRIT, c.x, c.y, c.z, 6, 0.25, 0.25, 0.25, 0.06);
                    }
                }
                // урон проходит, но уменьшенный — см. shinobicore_blockReduction
            }
            return;
        }

        // ================================================================
        //  СНАРЯДЫ (прежняя логика)
        // ================================================================
        if (projectile instanceof ServerPlayerEntity) return;

        // DEFENSIVE + hold = 360° щит (полностью пропускаем проверку фронта)
        boolean isGuardShield = holdActive && stance == KenjutsuStance.DEFENSIVE;
        if (!isGuardShield && now - data.getLastDeflectReflectMs() < 200) return;

        if (!isGuardShield) {
            // Только для tap-отклонения проверяем фронт 180°
            Vec3d toProj = projectile.getPos().subtract(player.getPos());
            Vec3d look = player.getRotationVector();
            Vec3d lookFlat = new Vec3d(look.x, 0, look.z);
            if (lookFlat.lengthSquared() > 0.001 && toProj.lengthSquared() > 0.001) {
                double dot = lookFlat.normalize().dotProduct(new Vec3d(toProj.x, 0, toProj.z).normalize());
                if (dot < -0.2) {
                    ShinobiCore.LOGGER.debug("[DEFLECT] rejected: projectile behind player");
                    return;
                }
            }
        }

        LivingEntity shooter = null;
        boolean reflected = false;

        if (projectile instanceof PersistentProjectileEntity proj) {
            Entity owner = proj.getOwner();
            if (owner == player) return;
            if (owner instanceof LivingEntity l) shooter = l;
            proj.setVelocity(proj.getVelocity().multiply(-1.3));
            proj.setOwner(player);
            proj.velocityDirty = true;
            reflected = true;
        }

        if (!reflected) return;

        data.setLastDeflectReflectMs(now);
        player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);
        if (player.getWorld() instanceof ServerWorld sw) {
            sw.spawnParticles(ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(), 12, 0.4, 0.4, 0.4, 0.05);
        }
        if (shooter != null) {
            shooter.damage(player.getDamageSources().playerAttack(player), 4f);
        }
        player.sendMessage(Text.literal("\u00a7eDEFLECTED!"), false);
        cir.setReturnValue(false);
    }

    /**
     * Блок в защитной стойке: входящий урон ближнего боя умножается на
     * (1 - combat.blockReduction). Работает через подмену аргумента — без
     * рекурсии damage() и без отмены события.
     */
    @ModifyVariable(method = "damage", at = @At("HEAD"), argsOnly = true)
    private float shinobicore_blockReduction(float amount, DamageSource source) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (!(self instanceof ServerPlayerEntity player)) return amount;
        if (source == null) return amount;
        if (!isMelee(source)) {
            return amount;
        }
        if (!(source.getAttacker() instanceof LivingEntity attacker) || attacker == player) return amount;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (data == null) return amount;
        KenjutsuStance stance = KenjutsuStance.fromId(data.getKatanaStanceId());
        boolean holdActive = data.isKatanaDeflectHeld() && stance == KenjutsuStance.DEFENSIVE;
        if (!holdActive) return amount;
        long pressMs = CombatFeelServer.getDeflectPressMs(player.getUuid());
        long now = System.currentTimeMillis();
        boolean inParryWindow = now < data.getKatanaDeflectUntil()
                || (pressMs > 0 && now - pressMs <= CombatFeelServer.parryWindowMs());
        if (inParryWindow) return amount;   // парирование отменяет урон целиком в HEAD-инжекторе
        float reduction = CombatFeelServer.blockReduction();
        ModConfig.Combat c = ModConfig.instance.combat;
        if (c != null && !c.blockEnabled) return amount;
        return amount * (1.0f - reduction);
    }

    /** Ближний бой: удар игрока/моба (включая неагрессивных). Всё остальное не блокируется. */
    private static boolean isMelee(DamageSource source) {
        return source.isOf(DamageTypes.PLAYER_ATTACK)
                || source.isOf(DamageTypes.MOB_ATTACK)
                || source.isOf(DamageTypes.MOB_ATTACK_NO_AGGRO);
    }
}