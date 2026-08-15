package com.example.shinobicore.entity;

import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;
import java.util.UUID;

public class RasenganHandEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(RasenganHandEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private UUID ownerId;
    public int age = 0;
    private static final int MAX_LIFETIME = 600;

    public RasenganHandEntity(EntityType<?> type, World world) {
        super(type, world);
    }

    public RasenganHandEntity(World world, LivingEntity owner, float damage) {
        super(ModEntities.RASENGAN_HAND, world);
        this.ownerId = owner.getUuid();
        this.dataTracker.set(DAMAGE, damage);
        updatePosition(owner);
    }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 32f);
    }

    public float getDamage() { return this.dataTracker.get(DAMAGE); }

    public Entity getOwner() {
        if (ownerId == null) return null;
        return this.getWorld().getPlayerByUuid(ownerId);
    }

    private void updatePosition(LivingEntity owner) {
        Vec3d look = owner.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        Vec3d handPos = owner.getEyePos()
                .add(look.multiply(0.6))
                .add(right.multiply(0.35))
                .add(0, -0.25, 0);
        this.setPosition(handPos.x, handPos.y, handPos.z);
    }

    @Override
    public void tick() {
        super.tick();
        age++;
        if (age > MAX_LIFETIME) {
            if (this.getWorld() instanceof ServerWorld sw) {
                sw.spawnParticles(ParticleTypes.CLOUD,
                        this.getX(), this.getY(), this.getZ(),
                        15, 0.3, 0.3, 0.3, 0.05);
            }
            this.discard();
            return;
        }
        Entity owner = getOwner();
        if (owner instanceof LivingEntity liv) {
            updatePosition(liv);
        } else {
            if (!this.getWorld().isClient) this.discard();
            return;
        }
        // Частицы
        if (this.getWorld() instanceof ServerWorld sw && age % 2 == 0) {
            float rot = age * 0.2f;
            float radius = 0.2f + (float) Math.sin(age * 0.1) * 0.05f;
            for (int i = 0; i < 6; i++) {
                double a = rot + (i / 6.0) * Math.PI * 2;
                sw.spawnParticles(ParticleTypes.SOUL_FIRE_FLAME,
                        this.getX() + Math.cos(a) * radius,
                        this.getY() + Math.sin(a * 2) * radius * 0.5,
                        this.getZ() + Math.sin(a) * radius,
                        1, 0.01, 0.01, 0.01, 0.005);
            }
            if (age % 4 == 0) {
                sw.spawnParticles(ParticleTypes.END_ROD,
                        this.getX(), this.getY(), this.getZ(),
                        1, 0.01, 0.01, 0.01, 0);
            }
        }
        this.setVelocity(0, 0, 0);
    }

    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }

    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", this.dataTracker.get(DAMAGE));
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}