package com.example.shinobicore.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.MarkTracker;
import net.minecraft.block.Blocks;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public class NinjaProjectileEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<String> PARTICLE_TYPE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<String> MODEL_TYPE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<Integer> LIFETIME = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Boolean> HAS_GRAVITY = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.BOOLEAN);
    private static final TrackedData<Integer> PIERCE_COUNT = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Integer> BOUNCE_COUNT = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);

    public float getRadius() { return this.dataTracker.get(RADIUS); }
    public String getParticleType() { return this.dataTracker.get(PARTICLE_TYPE); }
    public String getModelType() { return this.dataTracker.get(MODEL_TYPE); }
    
    public int age = 0;
    private UUID ownerId;
    private int pierceRemaining = 0;
    private int bounceRemaining = 0;

    public NinjaProjectileEntity(EntityType<?> type, World world) { super(type, world); }

    public NinjaProjectileEntity(World world, LivingEntity owner, Vec3d velocity, float damage, float radius, String particle, String model, int lifetime) {
        super(ModEntities.NINJA_PROJECTILE, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
        this.noClip = false;
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(RADIUS, radius);
        this.dataTracker.set(PARTICLE_TYPE, particle);
        this.dataTracker.set(MODEL_TYPE, model != null ? model : "sphere");
        this.dataTracker.set(LIFETIME, lifetime);
    }

    public void setHasGravity(boolean gravity) { this.dataTracker.set(HAS_GRAVITY, gravity); }
    public void setPierceCount(int count) { this.dataTracker.set(PIERCE_COUNT, count); this.pierceRemaining = count; }
    public void setBounceCount(int count) { this.dataTracker.set(BOUNCE_COUNT, count); this.bounceRemaining = count; }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 5f);
        this.dataTracker.startTracking(RADIUS, 1f);
        this.dataTracker.startTracking(PARTICLE_TYPE, "flame");
        this.dataTracker.startTracking(MODEL_TYPE, "sphere");
        this.dataTracker.startTracking(LIFETIME, 100);
        this.dataTracker.startTracking(HAS_GRAVITY, false);
        this.dataTracker.startTracking(PIERCE_COUNT, 0);
        this.dataTracker.startTracking(BOUNCE_COUNT, 0);
    }

    public Entity getOwner() {
        if (ownerId == null) return null;
        return this.getWorld().getPlayerByUuid(ownerId);
    }

    @Override
    public void tick() {
        super.tick();
        age++;
        if (age > this.dataTracker.get(LIFETIME)) { this.discard(); return; }

        Vec3d vel = this.getVelocity();
        if (this.dataTracker.get(HAS_GRAVITY)) {
            vel = new Vec3d(vel.x, vel.y - 0.04, vel.z);
            this.setVelocity(vel);
        }

        Vec3d startPos = this.getPos();
        Vec3d endPos = startPos.add(vel);
        HitResult blockHit = this.getWorld().raycast(new RaycastContext(startPos, endPos, RaycastContext.ShapeType.COLLIDER, RaycastContext.FluidHandling.NONE, this));
        
        LivingEntity hitEntity = null;
        double closestDist = Double.MAX_VALUE;
        Box searchBox = this.getBoundingBox().stretch(vel).expand(0.15);
        List<Entity> entities = this.getWorld().getOtherEntities(this, searchBox);

        for (Entity entity : entities) {
            if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                Box entityBox = entity.getBoundingBox().expand(0.3);
                var optionalHit = entityBox.raycast(startPos, endPos);
                if (optionalHit.isPresent()) {
                    double dist = startPos.squaredDistanceTo(optionalHit.get());
                    if (dist < closestDist) { closestDist = dist; hitEntity = living; }
                }
            }
        }

        boolean hit = false;
        if (hitEntity != null) {
            float damage = this.dataTracker.get(DAMAGE);
            hitEntity.damage(this.getDamageSources().magic(), MarkTracker.boost(hitEntity, damage));
            if (pierceRemaining > 0) { pierceRemaining--; } else { hit = true; }
        }

        if (blockHit.getType() == HitResult.Type.BLOCK && !hit) {
            BlockHitResult bhr = (BlockHitResult) blockHit;
            if (bounceRemaining > 0) {
                bounceRemaining--;
                Vec3d normal = Vec3d.of(bhr.getSide().getVector());
                double dot = vel.dotProduct(normal);
                Vec3d reflected = vel.subtract(normal.multiply(2 * dot)).multiply(0.7);
                this.setVelocity(reflected);
                this.setPosition(bhr.getPos().add(normal.multiply(0.01)));
                return;
            } else { hit = true; }
        }

        if (hit) {
            float radius = this.dataTracker.get(RADIUS);
            float damage = this.dataTracker.get(DAMAGE);
            String model = this.dataTracker.get(MODEL_TYPE);

            // === ELEMENTAL INTERACTIONS ===
            if (this.getWorld() instanceof ServerWorld sw) {
                String particle = this.dataTracker.get(PARTICLE_TYPE);
                Vec3d impactPos = this.getPos();
                ServerPlayerEntity ownerPlayer = null;
                if (this.getOwner() instanceof ServerPlayerEntity sp) {
                    ownerPlayer = sp;
                }
                com.example.shinobicore.jutsu.ElementInteractionManager
                    .onElementalImpact(sw, particle, impactPos, radius, ownerPlayer);
            }

            if (radius > 0.5f) {
                for (Entity entity : this.getWorld().getOtherEntities(this, this.getBoundingBox().expand(radius))) {
                    if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                        living.damage(this.getDamageSources().magic(), damage * 0.5f);
                    }
                }
            }

            // === UNIQUE IMPACT MECHANICS ===
            if (this.getWorld() instanceof ServerWorld sw) {
                if ("water_dragon".equals(model)) {
                    // Water Puddle
                    BlockPos impactPos = this.getBlockPos();
                    List<net.minecraft.util.math.BlockPos> placed = new ArrayList<>();
                    for (int dx = -2; dx <= 2; dx++) {
                        for (int dz = -2; dz <= 2; dz++) {
                            if (dx*dx + dz*dz <= 5) {
                                BlockPos p = impactPos.add(dx, 0, dz);
                                if (sw.getBlockState(p).isAir()) {
                                    sw.setBlockState(p, Blocks.WATER.getDefaultState(), 3);
                                    placed.add(p);
                                }
                            }
                        }
                    }
                    if (!placed.isEmpty()) com.example.shinobicore.jutsu.WallRemovalTask.schedule(sw, placed, 200);
                } else if ("earth_dragon".equals(model)) {
                    // Mud Pit (Slowness + Fatigue)
                    BlockPos impactPos = this.getBlockPos();
                    Box aoe = new Box(impactPos, impactPos).expand(3.0);
                    for (Entity e : sw.getOtherEntities(this, aoe)) {
                        if (e instanceof LivingEntity liv && !liv.getUuid().equals(this.ownerId)) {
                            liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 100, 2, false, false));
                            liv.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, 100, 1, false, false));
                        }
                    }
                } else if ("blade".equals(model)) {
                    // Bleed (Wither)
                    if (hitEntity != null) {
                        hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.WITHER, 60, 1, false, false));
                    }
                } else if ("hound".equals(model)) {
                    // Paralysis
                    if (hitEntity != null) {
                        hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 80, 4, false, false));
                        hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, 80, 4, false, false));
                        hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, 80, 2, false, false));
                    }
                }
            }
            this.discard();
            return;
        }

        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);
        
        if (this.getWorld() instanceof ServerWorld serverWorld && age % 2 == 0) {
            String particle = this.dataTracker.get(PARTICLE_TYPE);
            net.minecraft.particle.ParticleEffect particleType = switch (particle) {
                case "water" -> net.minecraft.particle.ParticleTypes.FALLING_WATER;
                case "smoke" -> net.minecraft.particle.ParticleTypes.SMOKE;
                case "lightning" -> net.minecraft.particle.ParticleTypes.ELECTRIC_SPARK;
                case "wind" -> net.minecraft.particle.ParticleTypes.CLOUD;
                case "earth" -> net.minecraft.particle.ParticleTypes.POOF;
                default -> net.minecraft.particle.ParticleTypes.FLAME;
            };
            serverWorld.spawnParticles(particleType, this.getX(), this.getY(), this.getZ(), 1, 0.01, 0.01, 0.01, 0.01);
        }
    }

    @Override protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        this.dataTracker.set(RADIUS, nbt.getFloat("Radius"));
        this.dataTracker.set(PARTICLE_TYPE, nbt.getString("Particle"));
        this.dataTracker.set(MODEL_TYPE, nbt.getString("Model"));
        this.dataTracker.set(LIFETIME, nbt.getInt("Lifetime"));
        this.dataTracker.set(HAS_GRAVITY, nbt.getBoolean("HasGravity"));
        this.dataTracker.set(PIERCE_COUNT, nbt.getInt("PierceCount"));
        this.dataTracker.set(BOUNCE_COUNT, nbt.getInt("BounceCount"));
        this.pierceRemaining = this.dataTracker.get(PIERCE_COUNT);
        this.bounceRemaining = this.dataTracker.get(BOUNCE_COUNT);
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }

    @Override protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", this.dataTracker.get(DAMAGE));
        nbt.putFloat("Radius", this.dataTracker.get(RADIUS));
        nbt.putString("Particle", this.dataTracker.get(PARTICLE_TYPE));
        nbt.putString("Model", this.dataTracker.get(MODEL_TYPE));
        nbt.putInt("Lifetime", this.dataTracker.get(LIFETIME));
        nbt.putBoolean("HasGravity", this.dataTracker.get(HAS_GRAVITY));
        nbt.putInt("PierceCount", this.dataTracker.get(PIERCE_COUNT));
        nbt.putInt("BounceCount", this.dataTracker.get(BOUNCE_COUNT));
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }

    /**
     * S13-01: Returns correct particle type based on jutsu nature.
     */
    private net.minecraft.particle.ParticleEffect getParticleForNature() {
        String pType = this.dataTracker.get(PARTICLE_TYPE);
        if (pType == null || pType.isEmpty()) return net.minecraft.particle.ParticleTypes.POOF;
        switch (pType) {
            case "fire": return net.minecraft.particle.ParticleTypes.FLAME;
            case "water": return net.minecraft.particle.ParticleTypes.SPLASH;
            case "wind": return net.minecraft.particle.ParticleTypes.CLOUD;
            case "lightning": return net.minecraft.particle.ParticleTypes.ELECTRIC_SPARK;
            case "earth": return net.minecraft.particle.ParticleTypes.CRIT;
            default: return net.minecraft.particle.ParticleTypes.POOF;
        }
    }
}