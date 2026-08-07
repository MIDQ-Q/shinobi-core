package com.example.shinobicore.entity;

import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.entity.projectile.ProjectileEntity;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.EntityHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

import java.util.UUID;

public class NinjaProjectileEntity extends ProjectileEntity {

    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<String> PARTICLE_TYPE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<Integer> LIFETIME = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);

    private UUID ownerId;
    private int age = 0;

    public NinjaProjectileEntity(EntityType<? extends ProjectileEntity> type, World world) {
        super(type, world);
    }

    public NinjaProjectileEntity(World world, LivingEntity owner, Vec3d velocity, float damage, float radius, String particle, int lifetime) {
        super(ModEntities.NINJA_PROJECTILE, world);
        this.setOwner(owner);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(RADIUS, radius);
        this.dataTracker.set(PARTICLE_TYPE, particle);
        this.dataTracker.set(LIFETIME, lifetime);
    }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 5f);
        this.dataTracker.startTracking(RADIUS, 1f);
        this.dataTracker.startTracking(PARTICLE_TYPE, "flame");
        this.dataTracker.startTracking(LIFETIME, 100);
    }

    @Override
    public void tick() {
        super.tick();
        
        age++;
        if (age > this.dataTracker.get(LIFETIME)) {
            this.discard();
            return;
        }

        if (this.getWorld() instanceof ServerWorld serverWorld) {
            String particle = this.dataTracker.get(PARTICLE_TYPE);
            var particleType = ParticleTypes.FLAME;
            if (particle.equals("water")) particleType = ParticleTypes.FALLING_WATER;
            else if (particle.equals("smoke")) particleType = ParticleTypes.SMOKE;
            else if (particle.equals("lightning")) particleType = ParticleTypes.ELECTRIC_SPARK;
            else if (particle.equals("wind")) particleType = ParticleTypes.CLOUD;
            
            serverWorld.spawnParticles(particleType,
                this.getX(), this.getY(), this.getZ(),
                3, 0.1, 0.1, 0.1, 0.02);
        }
    }

    @Override
    protected void onCollision(HitResult hitResult) {
        super.onCollision(hitResult);
        
        if (this.getWorld().isClient) return;
        
        float damage = this.dataTracker.get(DAMAGE);
        float radius = this.dataTracker.get(RADIUS);
        
        if (radius > 0.5f) {
            for (Entity entity : this.getWorld().getOtherEntities(this, this.getBoundingBox().expand(radius))) {
                if (entity instanceof LivingEntity living && !living.equals(this.getOwner())) {
                    living.damage(this.getDamageSources().magic(), damage);
                }
            }
        }
        
        this.discard();
    }

    @Override
    protected void onEntityHit(EntityHitResult entityHitResult) {
        super.onEntityHit(entityHitResult);
        
        Entity target = entityHitResult.getEntity();
        if (target instanceof LivingEntity living && !living.equals(this.getOwner())) {
            float damage = this.dataTracker.get(DAMAGE);
            living.damage(this.getDamageSources().magic(), damage);
        }
        
        this.discard();
    }

    @Override
    protected void onBlockHit(BlockHitResult blockHitResult) {
        super.onBlockHit(blockHitResult);
        this.discard();
    }

    @Override
    public void writeCustomDataToNbt(NbtCompound nbt) {
        super.writeCustomDataToNbt(nbt);
        nbt.putFloat("Damage", this.dataTracker.get(DAMAGE));
        nbt.putFloat("Radius", this.dataTracker.get(RADIUS));
        nbt.putString("Particle", this.dataTracker.get(PARTICLE_TYPE));
        nbt.putInt("Lifetime", this.dataTracker.get(LIFETIME));
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }

    @Override
    public void readCustomDataFromNbt(NbtCompound nbt) {
        super.readCustomDataFromNbt(nbt);
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        this.dataTracker.set(RADIUS, nbt.getFloat("Radius"));
        this.dataTracker.set(PARTICLE_TYPE, nbt.getString("Particle"));
        this.dataTracker.set(LIFETIME, nbt.getInt("Lifetime"));
        if (nbt.containsUuid("OwnerUUID")) {
            ownerId = nbt.getUuid("OwnerUUID");
        }
    }
}