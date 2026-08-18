package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.JutsuProjectileEntity;
import com.example.shinobicore.particle.ParticleTypes;
import com.example.shinobicore.sound.SoundEvents;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

/**
 * Поведение для Bakuton - серия из 4 взрывов с интервалом 1 секунду
 */
public class BakutonBehavior implements JutsuProjectileBehavior {
    
    private static final int EXPLOSION_COUNT = 4;
    private static final int EXPLOSION_INTERVAL_TICKS = 20; // 1 секунда
    private static final float EXPLOSION_RADIUS = 3.0f;
    private static final float EXPLOSION_DAMAGE = 8.0f;
    
    private int explosionIndex = 0;
    private int ticksUntilNextExplosion = 0;
    private boolean hasStarted = false;
    
    @Override
    public void onSpawn(JutsuProjectileEntity projectile, LivingEntity shooter) {
        this.hasStarted = false;
        this.explosionIndex = 0;
        this.ticksUntilNextExplosion = 5; // Небольшая задержка перед первым взрывом
    }
    
    @Override
    public void tick(JutsuProjectileEntity projectile, LivingEntity shooter) {
        if (!hasStarted) {
            hasStarted = true;
            return;
        }
        
        if (projectile.getWorld().isClient()) {
            return;
        }
        
        ticksUntilNextExplosion--;
        
        if (ticksUntilNextExplosion <= 0 && explosionIndex < EXPLOSION_COUNT) {
            createExplosion(projectile, shooter);
            explosionIndex++;
            
            if (explosionIndex < EXPLOSION_COUNT) {
                ticksUntilNextExplosion = EXPLOSION_INTERVAL_TICKS;
                
                // Перемещаем снаряд к следующей точке взрыва
                Vec3d direction = projectile.getVelocity().normalize();
                double moveDistance = 8.0; // Расстояние между взрывами
                projectile.setPosition(
                    projectile.getX() + direction.x * moveDistance,
                    projectile.getY() + direction.y * moveDistance,
                    projectile.getZ() + direction.z * moveDistance
                );
            } else {
                // Все взрывы завершены - удаляем снаряд
                projectile.discard();
            }
        }
        
        // Частицы между взрывами
        if (projectile.getWorld().isClient() && explosionIndex < EXPLOSION_COUNT) {
            spawnParticles(projectile);
        }
    }
    
    private void createExplosion(JutsuProjectileEntity projectile, LivingEntity shooter) {
        ServerWorld world = (ServerWorld) projectile.getWorld();
        double x = projectile.getX();
        double y = projectile.getY();
        double z = projectile.getZ();
        
        // Звук взрыва
        world.playSound(null, x, y, z, SoundEvents.EXPLODE, SoundCategory.PLAYERS, 1.5f, 0.8f + world.random.nextFloat() * 0.4f);
        
        // Урон по области
        List<Entity> affectedEntities = new ArrayList<>();
        world.getOtherEntities(projectile, projectile.getBoundingBox().expand(EXPLOSION_RADIUS), entity -> 
            entity != shooter && entity.isLiving()
        ).forEach(affectedEntities::add);
        
        for (Entity entity : affectedEntities) {
            LivingEntity living = (LivingEntity) entity;
            double distance = living.squaredDistanceTo(x, y, z);
            double damageMultiplier = 1.0 - (distance / (EXPLOSION_RADIUS * EXPLOSION_RADIUS));
            
            if (damageMultiplier > 0) {
                float damage = EXPLOSION_DAMAGE * (float) damageMultiplier;
                living.damage(world.getDamageSources().explosion(shooter), damage);
                
                // Отбрасывание
                Vec3d explosionVec = new Vec3d(x, y, z).subtract(living.getPos()).normalize().multiply(1.5);
                living.addVelocity(explosionVec.x, Math.max(explosionVec.y, 0.3), explosionVec.z);
                
                // Поджигание
                living.setOnFireFor(5);
            }
        }
        
        // Частицы взрыва
        if (world.isClient()) {
            for (int i = 0; i < 50; i++) {
                double angle = world.random.nextDouble() * Math.PI * 2;
                double speed = world.random.nextDouble() * 0.5;
                world.addParticle(
                    ParticleTypes.FIRE,
                    x + Math.cos(angle) * speed * 3,
                    y + world.random.nextDouble() * 2,
                    z + Math.sin(angle) * speed * 3,
                    (Math.cos(angle) * speed) * 0.5,
                    world.random.nextDouble() * 0.5,
                    (Math.sin(angle) * speed) * 0.5
                );
            }
        }
    }
    
    private void spawnParticles(JutsuProjectileEntity projectile) {
        if (projectile.getWorld().isClient()) {
            for (int i = 0; i < 3; i++) {
                double offsetX = (projectile.getWorld().random.nextDouble() - 0.5) * 0.5;
                double offsetY = (projectile.getWorld().random.nextDouble() - 0.5) * 0.5;
                double offsetZ = (projectile.getWorld().random.nextDouble() - 0.5) * 0.5;
                
                projectile.getWorld().addParticle(
                    ParticleTypes.FLAME,
                    projectile.getX() + offsetX,
                    projectile.getY() + offsetY,
                    projectile.getZ() + offsetZ,
                    0, 0.1, 0
                );
            }
        }
    }
    
    @Override
    public void onHit(JutsuProjectileEntity projectile, Entity target, LivingEntity shooter) {
        // Взрывы обрабатываются в tick(), не при попадании
    }
    
    @Override
    public void onBlockHit(JutsuProjectileEntity projectile, LivingEntity shooter) {
        // Взрывы обрабатываются в tick(), не при попадании в блок
    }
}
