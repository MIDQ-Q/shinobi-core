package com.example.shinobicore.entity;

import com.example.shinobicore.util.TickScheduler;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.List;
import java.util.UUID;

public class RasenshurikenEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(RasenshurikenEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Boolean> LAUNCHED = DataTracker.registerData(RasenshurikenEntity.class, TrackedDataHandlerRegistry.BOOLEAN);
    private UUID ownerId;
    public int age = 0;

    public RasenshurikenEntity(EntityType<?> type, World world) {
        super(type, world);
    }

    public RasenshurikenEntity(World world, LivingEntity owner, float damage) {
        super(ModEntities.RASENSHURIKEN, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getY() + owner.getHeight() + 0.8, owner.getZ());
        this.setVelocity(0, 0, 0);
        this.velocityDirty = true;
        this.noClip = false;
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(LAUNCHED, false);
    }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 45f);
        this.dataTracker.startTracking(LAUNCHED, false);
    }

    public boolean isLaunched() { return this.dataTracker.get(LAUNCHED); }
    public float getDamage() { return this.dataTracker.get(DAMAGE); }

    public Entity getOwner() {
        if (ownerId == null) return null;
        return this.getWorld().getPlayerByUuid(ownerId);
    }

    public void launch(Vec3d direction) {
        this.dataTracker.set(LAUNCHED, true);
        this.setVelocity(direction.multiply(2.5));
        this.velocityDirty = true;
    }

    @Override
    public void tick() {
        super.tick();
        age++;
        if (age > 600) { this.discard(); return; }

        Entity owner = getOwner();

        if (!isLaunched()) {
            // Зависание над головой — следовать за игроком
            if (owner instanceof LivingEntity liv) {
                this.setPosition(liv.getX(), liv.getY() + liv.getHeight() + 0.8, liv.getZ());
                this.setVelocity(0, 0, 0);
                // Частицы вращения
                if (this.getWorld() instanceof ServerWorld sw && age % 2 == 0) {
                    float rot = age * 0.3f;
                    for (int i = 0; i < 8; i++) {
                        double a = rot + (i / 8.0) * Math.PI * 2;
                        double r = 0.8;
                        sw.spawnParticles(ParticleTypes.CLOUD,
                                this.getX() + Math.cos(a) * r,
                                this.getY() + Math.sin(a * 2) * 0.2,
                                this.getZ() + Math.sin(a) * r,
                                1, 0.02, 0.02, 0.02, 0.01);
                    }
                }
            } else {
                if (!this.getWorld().isClient) this.discard();
            }
            return;
        }

        // === Летящий снаряд ===
        Vec3d vel = this.getVelocity();
        Vec3d startPos = this.getPos();
        Vec3d endPos = startPos.add(vel);

        HitResult blockHit = this.getWorld().raycast(new RaycastContext(
                startPos, endPos,
                RaycastContext.ShapeType.COLLIDER,
                RaycastContext.FluidHandling.NONE, this));

        LivingEntity hitEntity = null;
        double closestDist = Double.MAX_VALUE;
        Box searchBox = this.getBoundingBox().stretch(vel).expand(0.5);
        List<Entity> entities = this.getWorld().getOtherEntities(this, searchBox);
        for (Entity entity : entities) {
            if (entity instanceof LivingEntity living
                    && (ownerId == null || !living.getUuid().equals(ownerId))) {
                Box entityBox = entity.getBoundingBox().expand(0.3);
                var optionalHit = entityBox.raycast(startPos, endPos);
                if (optionalHit.isPresent()) {
                    double dist = startPos.squaredDistanceTo(optionalHit.get());
                    if (dist < closestDist) { closestDist = dist; hitEntity = living; }
                }
            }
        }

        if (hitEntity != null || (blockHit.getType() == HitResult.Type.BLOCK)) {
            createExpandingSphere();
            this.discard();
            return;
        }

        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);

        // Частицы полёта
        if (this.getWorld() instanceof ServerWorld sw) {
            float rot = age * 0.5f;
            for (int i = 0; i < 12; i++) {
                double a = rot + (i / 12.0) * Math.PI * 2;
                double r = 1.2;
                sw.spawnParticles(ParticleTypes.CLOUD,
                        this.getX() + Math.cos(a) * r,
                        this.getY() + Math.sin(a * 3) * 0.3,
                        this.getZ() + Math.sin(a) * r,
                        2, 0.08, 0.08, 0.08, 0.04);
            }
            sw.spawnParticles(ParticleTypes.END_ROD,
                    this.getX(), this.getY(), this.getZ(),
                    1, 0.02, 0.02, 0.02, 0.01);
        }
    }

    private void createExpandingSphere() {
        if (!(this.getWorld() instanceof ServerWorld world)) return;
        final Vec3d center = this.getPos();
        final float damage = this.dataTracker.get(DAMAGE);
        final float maxRadius = 10f;
        final int duration = 60;

        world.playSound(null, this.getBlockPos(),
                net.minecraft.sound.SoundEvents.ENTITY_GENERIC_EXPLODE,
                net.minecraft.sound.SoundCategory.PLAYERS, 3.0f, 0.8f);

        for (int t = 0; t < duration; t++) {
            final int tick = t;
            TickScheduler.schedule(world, t, 1, 1, w -> {
                float expandR = maxRadius * ((float) tick / duration);
                for (int i = 0; i < 25; i++) {
                    double theta = Math.random() * Math.PI * 2;
                    double phi = Math.acos(2 * Math.random() - 1);
                    double x = center.x + expandR * Math.sin(phi) * Math.cos(theta);
                    double y = center.y + expandR * Math.cos(phi);
                    double z = center.z + expandR * Math.sin(phi) * Math.sin(theta);
                    w.spawnParticles(ParticleTypes.CLOUD, x, y, z, 2, 0.05, 0.05, 0.05, 0.03);
                    if (tick > duration / 3) {
                        w.spawnParticles(ParticleTypes.END_ROD, x, y, z, 1, 0.02, 0.02, 0.02, 0.01);
                    }
                }
                if (tick < duration / 2) {
                    w.spawnParticles(ParticleTypes.EXPLOSION_EMITTER, center.x, center.y, center.z, 1, 0, 0, 0, 0);
                }
                if (tick % 3 == 0) {
                    Entity ownerEntity = getOwner();
                    Box aoeBox = new Box(center, center).expand(expandR);
                    for (Entity e : w.getOtherEntities(ownerEntity, aoeBox)) {
                        if (e instanceof LivingEntity liv
                                && (ownerId == null || !liv.getUuid().equals(ownerId))) {
                            float dmg = damage * 0.15f * (1f - (float) tick / duration);
                            liv.damage(w.getDamageSources().magic(), dmg);
                            Vec3d kb = liv.getPos().subtract(center).normalize().multiply(0.5);
                            liv.addVelocity(kb.x, 0.2, kb.z);
                            liv.velocityModified = true;
                            liv.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
                                    net.minecraft.entity.effect.StatusEffects.SLOWNESS, 40, 2, false, false));
                            liv.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
                                    net.minecraft.entity.effect.StatusEffects.WEAKNESS, 40, 1, false, false));
                        }
                    }
                }
            });
        }
    }

    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        this.dataTracker.set(LAUNCHED, nbt.getBoolean("Launched"));
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }

    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", this.dataTracker.get(DAMAGE));
        nbt.putBoolean("Launched", this.dataTracker.get(LAUNCHED));
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}