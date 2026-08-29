package com.example.shinobicore.entity;

import com.example.shinobicore.util.ParticleHelper;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import net.minecraft.util.hit.HitResult;

import java.util.List;
import java.util.UUID;

/**
 * Generic jutsu projectile driven by JSON params.
 * HLD: Section 2.3 (vanilla Entity = correct physics, raycasts)
 * Yarn 1.20.1: initDataTracker uses startTracking() to CREATE entries,
 * set() is only used AFTER entries exist.
 */
public class NinjaProjectileEntity extends Entity {

    private static final TrackedData<Float> DAMAGE =
        DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Float> RADIUS =
        DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<String> PARTICLE =
        DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<Integer> COLOR =
        DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Boolean> HAS_GRAVITY =
        DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.BOOLEAN);
    private static final TrackedData<Integer> BURN_SECONDS =
        DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);

    private UUID ownerId;
    private int age = 0;
    private int lifetime = 100;

    public NinjaProjectileEntity(EntityType<?> type, World world) {
        super(type, world);
    }

    public NinjaProjectileEntity(World world, LivingEntity owner, float damage, float radius,
                                 String particle, int color, boolean gravity, int burnSeconds, int lifetime) {
        this(ModEntities.NINJA_PROJECTILE, world);
        this.ownerId = owner.getUuid();
        this.lifetime = lifetime;
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(RADIUS, radius);
        this.dataTracker.set(PARTICLE, particle);
        this.dataTracker.set(COLOR, color);
        this.dataTracker.set(HAS_GRAVITY, gravity);
        this.dataTracker.set(BURN_SECONDS, burnSeconds);
    }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 10.0f);
        this.dataTracker.startTracking(RADIUS, 1.0f);
        this.dataTracker.startTracking(PARTICLE, "flame");
        this.dataTracker.startTracking(COLOR, 0xFFFFFF);
        this.dataTracker.startTracking(HAS_GRAVITY, false);
        this.dataTracker.startTracking(BURN_SECONDS, 0);
    }

    public int getColor() {
        return this.dataTracker.get(COLOR);
    }

    public String getParticleName() {
        return this.dataTracker.get(PARTICLE);
    }

    public float getDamage() {
        return this.dataTracker.get(DAMAGE);
    }

    public float getRadius() {
        return this.dataTracker.get(RADIUS);
    }

    @Override
    public void tick() {
        super.tick();
        this.age++;

        if (this.age > this.lifetime) {
            this.discard();
            return;
        }

        Vec3d vel = this.getVelocity();
        if (this.dataTracker.get(HAS_GRAVITY)) {
            vel = vel.add(0.0, -0.05, 0.0);
        }

        Vec3d start = this.getPos();
        Vec3d end = start.add(vel);

        HitResult hit = this.getWorld().raycast(new RaycastContext(
            start, end,
            RaycastContext.ShapeType.COLLIDER,
            RaycastContext.FluidHandling.NONE,
            this
        ));

        if (hit.getType() != HitResult.Type.MISS) {
            this.onImpact(hit.getPos());
            this.discard();
            return;
        }

        Box box = this.getBoundingBox().stretch(vel).expand(1.0);
        List<Entity> entities = this.getWorld().getOtherEntities(this, box);
        for (Entity e : entities) {
            if (!(e instanceof LivingEntity)) {
                continue;
            }
            if (this.ownerId != null && e.getUuid().equals(this.ownerId)) {
                continue;
            }
            this.onImpact(e.getPos());
            this.discard();
            return;
        }

        this.setVelocity(vel);
        this.setPosition(end.x, end.y, end.z);

        if (this.age % 2 == 0) {
            this.getWorld().addParticle(
                ParticleHelper.get(this.dataTracker.get(PARTICLE)),
                this.getX(), this.getY(), this.getZ(),
                0.0, 0.0, 0.0
            );
        }
    }

    private void onImpact(Vec3d pos) {
        float radius = this.dataTracker.get(RADIUS);
        float damage = this.dataTracker.get(DAMAGE);
        int burn = this.dataTracker.get(BURN_SECONDS);

        Box aoe = new Box(pos, pos).expand(radius);
        List<Entity> targets = this.getWorld().getOtherEntities(this, aoe);
        for (Entity e : targets) {
            if (!(e instanceof LivingEntity le)) {
                continue;
            }
            if (this.ownerId != null && e.getUuid().equals(this.ownerId)) {
                continue;
            }
            le.damage(this.getDamageSources().magic(), damage);
            if (burn > 0) {
                le.setOnFireFor(burn);
            }
            le.addVelocity(0.0, 0.2, 0.0);
            le.velocityModified = true;
        }

        for (int i = 0; i < 12; i++) {
            this.getWorld().addParticle(
                ParticleHelper.get(this.dataTracker.get(PARTICLE)),
                pos.x, pos.y, pos.z,
                (this.random.nextFloat() - 0.5f) * 0.4,
                (this.random.nextFloat() - 0.5f) * 0.4,
                (this.random.nextFloat() - 0.5f) * 0.4
            );
        }
    }

    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        if (nbt.contains("OwnerId")) {
            this.ownerId = nbt.getUuid("OwnerId");
        }
        this.age = nbt.getInt("Age");
        this.lifetime = nbt.getInt("Lifetime");
    }

    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        if (this.ownerId != null) {
            nbt.putUuid("OwnerId", this.ownerId);
        }
        nbt.putInt("Age", this.age);
        nbt.putInt("Lifetime", this.lifetime);
    }
}