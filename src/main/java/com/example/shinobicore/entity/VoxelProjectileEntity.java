package com.example.shinobicore.entity;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.EntityHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.UUID;

/**
 * S4-04/S4-05: Unified voxel projectile entity.
 * Server handles physics/collision. Client renders via VoxelMeshCache.
 */
public class VoxelProjectileEntity extends Entity {
    private static final TrackedData<String> MODEL_ID = DataTracker.registerData(VoxelProjectileEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<Integer> COLOR = DataTracker.registerData(VoxelProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Float> SCALE = DataTracker.registerData(VoxelProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Boolean> HAS_GRAVITY = DataTracker.registerData(VoxelProjectileEntity.class, TrackedDataHandlerRegistry.BOOLEAN);
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(VoxelProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Boolean> EXPLODES_ON_HIT = DataTracker.registerData(VoxelProjectileEntity.class, TrackedDataHandlerRegistry.BOOLEAN);
    private static final TrackedData<Float> EXPLOSION_RADIUS = DataTracker.registerData(VoxelProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<String> SPECIAL_EFFECT = DataTracker.registerData(VoxelProjectileEntity.class, TrackedDataHandlerRegistry.STRING);

    private UUID ownerId;
    private int lifetime = 100;
    
    // FIX: Made public so renderer can access it for rotation/animation
    public int age = 0;

    public VoxelProjectileEntity(EntityType<?> type, World world) { 
        super(type, world); 
    }

    public VoxelProjectileEntity(World world, LivingEntity owner, Vec3d velocity, 
                                 String modelId, int color, float scale, float damage, boolean gravity) {
        super(ModEntities.VOXEL_PROJECTILE, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
        
        this.dataTracker.set(MODEL_ID, modelId);
        this.dataTracker.set(COLOR, color);
        this.dataTracker.set(SCALE, scale);
        this.dataTracker.set(HAS_GRAVITY, gravity);
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(EXPLODES_ON_HIT, false);
        this.dataTracker.set(EXPLOSION_RADIUS, 0f);
    }
    
    public VoxelProjectileEntity(World world, LivingEntity owner, Vec3d velocity, 
                                 String modelId, int color, float scale, float damage, boolean gravity,
                                 boolean explodes, float explosionRadius) {
        super(ModEntities.VOXEL_PROJECTILE, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
        
        this.dataTracker.set(MODEL_ID, modelId);
        this.dataTracker.set(COLOR, color);
        this.dataTracker.set(SCALE, scale);
        this.dataTracker.set(HAS_GRAVITY, gravity);
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(EXPLODES_ON_HIT, explodes);
        this.dataTracker.set(EXPLOSION_RADIUS, explosionRadius);
        this.dataTracker.set(SPECIAL_EFFECT, "");
    }
    
    public VoxelProjectileEntity(World world, LivingEntity owner, Vec3d velocity, 
                                 String modelId, int color, float scale, float damage, boolean gravity,
                                 boolean explodes, float explosionRadius, String specialEffect) {
        super(ModEntities.VOXEL_PROJECTILE, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
        
        this.dataTracker.set(MODEL_ID, modelId);
        this.dataTracker.set(COLOR, color);
        this.dataTracker.set(SCALE, scale);
        this.dataTracker.set(HAS_GRAVITY, gravity);
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(EXPLODES_ON_HIT, explodes);
        this.dataTracker.set(EXPLOSION_RADIUS, explosionRadius);
        this.dataTracker.set(SPECIAL_EFFECT, specialEffect);
    }

    @Override 
    protected void initDataTracker() {
        this.dataTracker.startTracking(MODEL_ID, "sphere");
        this.dataTracker.startTracking(COLOR, 0xFFFFFFFF);
        this.dataTracker.startTracking(SCALE, 1.0f);
        this.dataTracker.startTracking(HAS_GRAVITY, false);
        this.dataTracker.startTracking(DAMAGE, 5.0f);
        this.dataTracker.startTracking(EXPLODES_ON_HIT, false);
        this.dataTracker.startTracking(EXPLOSION_RADIUS, 0f);
        this.dataTracker.startTracking(SPECIAL_EFFECT, "");
    }

    public String getModelId() { return this.dataTracker.get(MODEL_ID); }
    public int getColor() { return this.dataTracker.get(COLOR); }
    public float getScale() { return this.dataTracker.get(SCALE); }
    public float getDamage() { return this.dataTracker.get(DAMAGE); }
    public boolean explodesOnHit() { return this.dataTracker.get(EXPLODES_ON_HIT); }
    public float getExplosionRadius() { return this.dataTracker.get(EXPLOSION_RADIUS); }
    public String getSpecialEffect() { return this.dataTracker.get(SPECIAL_EFFECT); }
    
    public Entity getOwner() { 
        return ownerId == null ? null : getWorld().getPlayerByUuid(ownerId); 
    }

    @Override 
    public void tick() {
        super.tick();
        age++;
        
        if (age > lifetime) { 
            discard(); 
            return; 
        }

        Vec3d vel = getVelocity();
        if (this.dataTracker.get(HAS_GRAVITY)) {
            vel = vel.add(0, -0.04, 0);
        }

        Vec3d start = getPos();
        Vec3d end = start.add(vel);
        
        // Block collision
        HitResult blockHit = getWorld().raycast(new RaycastContext(
            start, end, RaycastContext.ShapeType.COLLIDER, 
            RaycastContext.FluidHandling.NONE, this));
            
        // Entity collision
        LivingEntity hitEntity = null;
        Box searchBox = getBoundingBox().stretch(vel).expand(0.15);
        for (Entity e : getWorld().getOtherEntities(this, searchBox)) {
            if (e instanceof LivingEntity living && !living.getUuid().equals(ownerId)) {
                var opt = living.getBoundingBox().expand(0.3).raycast(start, end);
                if (opt.isPresent()) {
                    hitEntity = living;
                    break;
                }
            }
        }

        boolean hit = false;
        if (hitEntity != null) {
            float dmg = getDamage();
            hitEntity.damage(getDamageSources().magic(), dmg);
            hit = true;
            
            // Apply special effects on hit
            String effect = getSpecialEffect();
            if ("amaterasu".equals(effect) && hitEntity instanceof LivingEntity living) {
                applyAmaterasuBurn(living, 1200); // 60 seconds
            }
            
            // Handle explosion on hit
            if (explodesOnHit() && getWorld() instanceof ServerWorld serverWorld) {
                createExplosion(serverWorld, getPos(), getExplosionRadius());
                
                // Apply Amaterasu burn in explosion radius
                if ("amaterasu".equals(effect)) {
                    Box explosionBox = new Box(getPos(), getPos()).expand(getExplosionRadius());
                    for (Entity e : serverWorld.getOtherEntities(this, explosionBox)) {
                        if (e instanceof LivingEntity living && !living.getUuid().equals(ownerId)) {
                            applyAmaterasuBurn(living, 1200);
                        }
                    }
                }
            }
        } else if (blockHit.getType() == HitResult.Type.BLOCK) {
            hit = true;
            
            // Handle explosion on block hit
            if (explodesOnHit() && getWorld() instanceof ServerWorld serverWorld) {
                Vec3d hitPos = blockHit.getPos();
                createExplosion(serverWorld, hitPos, getExplosionRadius());
                
                // Apply Amaterasu burn in explosion radius
                String effect = getSpecialEffect();
                if ("amaterasu".equals(effect)) {
                    Box explosionBox = new Box(hitPos, hitPos).expand(getExplosionRadius());
                    for (Entity e : serverWorld.getOtherEntities(this, explosionBox)) {
                        if (e instanceof LivingEntity living && !living.getUuid().equals(ownerId)) {
                            applyAmaterasuBurn(living, 1200);
                        }
                    }
                }
            }
        }

        if (hit) {
            discard();
            return;
        }

        setPosition(end);
        setVelocity(vel);
    }
    
    /**
     * Applies Amaterasu burning effect - black flames for 60 seconds
     */
    private void applyAmaterasuBurn(LivingEntity target, int durationTicks) {
        // Set on fire for visual effect (60 seconds = 1200 ticks / 20 = 60 seconds)
        target.setOnFireFor(durationTicks / 20);
        
        // Add weakness to simulate the debilitating effect of Amaterasu
        target.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
            net.minecraft.entity.effect.StatusEffects.WEAKNESS, durationTicks, 1, false, false));
    }
    
    /**
     * Creates an explosion effect at the given position.
     */
    private void createExplosion(ServerWorld world, Vec3d pos, float radius) {
        if (radius <= 0) return;
        
        // Damage entities in radius
        Box explosionBox = new Box(pos, pos).expand(radius);
        for (Entity e : world.getOtherEntities(this, explosionBox)) {
            if (e instanceof LivingEntity living && !living.getUuid().equals(ownerId)) {
                double dist = e.getPos().distanceTo(pos);
                float damage = getDamage() * (1.0f - (float)(dist / radius));
                if (damage > 0) {
                    living.damage(getDamageSources().explosion(getOwner() instanceof LivingEntity le ? le : null), damage);
                }
            }
        }
        
        // Spawn explosion particles
        int particleCount = (int)(radius * 10);
        for (int i = 0; i < particleCount; i++) {
            double angle = (i / (float)particleCount) * Math.PI * 2;
            double px = pos.x + Math.cos(angle) * radius * 0.5;
            double py = pos.y + world.random.nextDouble() * radius;
            double pz = pos.z + Math.sin(angle) * radius * 0.5;
            world.spawnParticles(net.minecraft.particle.ParticleTypes.EXPLOSION, px, py, pz, 1, 0, 0, 0, 0.1);
        }
        
        // Play explosion sound
        world.playSound(null, pos.getBlockPos(), net.minecraft.sound.SoundEvents.ENTITY_GENERIC_EXPLODE, 
                       net.minecraft.sound.SoundCategory.PLAYERS, 1.0f, 1.0f);
    }

    @Override 
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(MODEL_ID, nbt.getString("Model"));
        this.dataTracker.set(COLOR, nbt.getInt("Color"));
        this.dataTracker.set(SCALE, nbt.getFloat("Scale"));
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        this.dataTracker.set(HAS_GRAVITY, nbt.getBoolean("HasGravity"));
        if (nbt.containsUuid("Owner")) ownerId = nbt.getUuid("Owner");
        if (nbt.contains("ExplodesOnHit")) this.dataTracker.set(EXPLODES_ON_HIT, nbt.getBoolean("ExplodesOnHit"));
        if (nbt.contains("ExplosionRadius")) this.dataTracker.set(EXPLOSION_RADIUS, nbt.getFloat("ExplosionRadius"));
    }

    @Override 
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putString("Model", getModelId());
        nbt.putInt("Color", getColor());
        nbt.putFloat("Scale", getScale());
        nbt.putFloat("Damage", getDamage());
        nbt.putBoolean("HasGravity", this.dataTracker.get(HAS_GRAVITY));
        nbt.putBoolean("ExplodesOnHit", this.dataTracker.get(EXPLODES_ON_HIT));
        nbt.putFloat("ExplosionRadius", this.dataTracker.get(EXPLOSION_RADIUS));
        if (ownerId != null) nbt.putUuid("Owner", ownerId);
    }
}