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
    }

    @Override 
    protected void initDataTracker() {
        this.dataTracker.startTracking(MODEL_ID, "sphere");
        this.dataTracker.startTracking(COLOR, 0xFFFFFFFF);
        this.dataTracker.startTracking(SCALE, 1.0f);
        this.dataTracker.startTracking(HAS_GRAVITY, false);
        this.dataTracker.startTracking(DAMAGE, 5.0f);
    }

    public String getModelId() { return this.dataTracker.get(MODEL_ID); }
    public int getColor() { return this.dataTracker.get(COLOR); }
    public float getScale() { return this.dataTracker.get(SCALE); }
    public float getDamage() { return this.dataTracker.get(DAMAGE); }
    
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
        } else if (blockHit.getType() == HitResult.Type.BLOCK) {
            hit = true;
        }

        if (hit) {
            // TODO: Add impact VFX/particles here later
            discard();
            return;
        }

        setPosition(end);
        setVelocity(vel);
    }

    @Override 
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(MODEL_ID, nbt.getString("Model"));
        this.dataTracker.set(COLOR, nbt.getInt("Color"));
        this.dataTracker.set(SCALE, nbt.getFloat("Scale"));
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        this.dataTracker.set(HAS_GRAVITY, nbt.getBoolean("HasGravity"));
        if (nbt.containsUuid("Owner")) ownerId = nbt.getUuid("Owner");
    }

    @Override 
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putString("Model", getModelId());
        nbt.putInt("Color", getColor());
        nbt.putFloat("Scale", getScale());
        nbt.putFloat("Damage", getDamage());
        nbt.putBoolean("HasGravity", this.dataTracker.get(HAS_GRAVITY));
        if (ownerId != null) nbt.putUuid("Owner", ownerId);
    }
}