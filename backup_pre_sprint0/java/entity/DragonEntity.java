package com.example.shinobicore.entity;

import com.example.shinobicore.jutsu.ElementInteractionManager;
import com.example.shinobicore.jutsu.WallRemovalTask;
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
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * S5-04: Segmented dragon entity.
 * Server handles head movement + segment hitboxes.
 * Client renders voxel segments along the trail.
 */
public class DragonEntity extends Entity {
    private static final TrackedData<String> ELEMENT = DataTracker.registerData(DragonEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(DragonEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Integer> SEGMENTS = DataTracker.registerData(DragonEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(DragonEntity.class, TrackedDataHandlerRegistry.FLOAT);

    private UUID ownerId;
    public int age = 0;
    private static final int MAX_LIFETIME = 140;

    public DragonEntity(EntityType<?> type, World world) { super(type, world); }

    public DragonEntity(World world, LivingEntity owner, Vec3d velocity,
                        String element, float damage, float radius, int segments) {
        super(ModEntities.DRAGON, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
        this.dataTracker.set(ELEMENT, element);
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(SEGMENTS, Math.min(segments, 12));
        this.dataTracker.set(RADIUS, radius);
    }

    @Override protected void initDataTracker() {
        this.dataTracker.startTracking(ELEMENT, "fire");
        this.dataTracker.startTracking(DAMAGE, 10f);
        this.dataTracker.startTracking(SEGMENTS, 6);
        this.dataTracker.startTracking(RADIUS, 3f);
    }

    public String getElement() { return this.dataTracker.get(ELEMENT); }
    public float getDamage() { return this.dataTracker.get(DAMAGE); }
    public int getSegmentCount() { return this.dataTracker.get(SEGMENTS); }
    public float getRadius() { return this.dataTracker.get(RADIUS); }

    public Entity getOwner() {
        return ownerId == null ? null : getWorld().getPlayerByUuid(ownerId);
    }

    @Override
    public void tick() {
        super.tick();
        age++;
        if (age > MAX_LIFETIME) { discard(); return; }

        Vec3d vel = getVelocity();
        Vec3d startPos = getPos();
        Vec3d endPos = startPos.add(vel);

        // FIX: Explicit cast to float to avoid lossy conversion error
        float wave = (float) Math.sin(age * 0.15) * 0.3f;
        endPos = endPos.add(0, wave * 0.1, 0);

        // Block collision for head
        HitResult blockHit = getWorld().raycast(new RaycastContext(
            startPos, endPos, RaycastContext.ShapeType.COLLIDER,
            RaycastContext.FluidHandling.NONE, this));

        // Entity collision for head
        LivingEntity hitEntity = null;
        double closestDist = Double.MAX_VALUE;
        Box searchBox = getBoundingBox().stretch(vel).expand(0.3);
        for (Entity e : getWorld().getOtherEntities(this, searchBox)) {
            if (e instanceof LivingEntity liv && !liv.getUuid().equals(ownerId)) {
                var opt = liv.getBoundingBox().expand(0.4).raycast(startPos, endPos);
                if (opt.isPresent()) {
                    double d = startPos.squaredDistanceTo(opt.get());
                    if (d < closestDist) { closestDist = d; hitEntity = liv; }
                }
            }
        }

        // Segment hitbox check (simplified: expanded box around head)
        LivingEntity segHit = null;
        if (hitEntity == null) {
            float segRadius = getRadius() * 0.5f;
            Box segBox = getBoundingBox().expand(segRadius);
            for (Entity e : getWorld().getOtherEntities(this, segBox)) {
                if (e instanceof LivingEntity liv && !liv.getUuid().equals(ownerId)) {
                    if (liv.getBoundingBox().intersects(segBox)) {
                        segHit = liv;
                        break;
                    }
                }
            }
        }

        boolean hit = false;
        if (hitEntity != null) {
            hitEntity.damage(getDamageSources().magic(), getDamage());
            hit = true;
        } else if (segHit != null) {
            segHit.damage(getDamageSources().magic(), getDamage() * 0.4f);
        }

        if (blockHit.getType() == HitResult.Type.BLOCK) hit = true;

        if (hit) {
            onImpact();
            discard();
            return;
        }

        setPosition(endPos.x, endPos.y, endPos.z);
        setVelocity(vel);

        // Trail particles on server
        if (getWorld() instanceof ServerWorld sw && age % 3 == 0) {
            String elem = getElement();
            if ("fire".equals(elem)) {
                sw.spawnParticles(ParticleTypes.FLAME, getX(), getY(), getZ(), 3, 0.3, 0.3, 0.3, 0.05);
            } else if ("water".equals(elem)) {
                sw.spawnParticles(ParticleTypes.FALLING_WATER, getX(), getY(), getZ(), 3, 0.3, 0.3, 0.3, 0.05);
            } else {
                sw.spawnParticles(ParticleTypes.POOF, getX(), getY(), getZ(), 2, 0.3, 0.3, 0.3, 0.03);
            }
        }
    }

    private void onImpact() {
        if (!(getWorld() instanceof ServerWorld sw)) return;
        String elem = getElement();
        float radius = getRadius();
        Vec3d pos = getPos();
        ServerPlayerEntity owner = null;
        if (getOwner() instanceof ServerPlayerEntity sp) owner = sp;

        // Elemental interaction
        ElementInteractionManager.onElementalImpact(sw, elem.equals("fire") ? "fire" : "water", pos, radius, owner);

        // Element-specific effects
        if ("water".equals(elem)) {
            BlockPos bp = getBlockPos();
            List<BlockPos> placed = new ArrayList<>();
            for (int dx = -2; dx <= 2; dx++) {
                for (int dz = -2; dz <= 2; dz++) {
                    if (dx * dx + dz * dz <= 5) {
                        BlockPos p = bp.add(dx, 0, dz);
                        if (sw.getBlockState(p).isAir()) {
                            sw.setBlockState(p, Blocks.WATER.getDefaultState(), 3);
                            placed.add(p);
                        }
                    }
                }
            }
            if (!placed.isEmpty()) WallRemovalTask.schedule(sw, placed, 200);
        } else if ("earth".equals(elem)) {
            Box aoe = new Box(getBlockPos()).expand(3.0);
            for (Entity e : sw.getOtherEntities(this, aoe)) {
                if (e instanceof LivingEntity liv && !liv.getUuid().equals(ownerId)) {
                    liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 100, 2, false, false));
                    liv.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, 100, 1, false, false));
                }
            }
        }

        // AOE damage
        for (Entity e : getWorld().getOtherEntities(this, getBoundingBox().expand(radius))) {
            if (e instanceof LivingEntity liv && !liv.getUuid().equals(ownerId)) {
                liv.damage(getDamageSources().magic(), getDamage() * 0.5f);
            }
        }
    }

    @Override protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(ELEMENT, nbt.getString("Element"));
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        this.dataTracker.set(SEGMENTS, nbt.getInt("Segments"));
        this.dataTracker.set(RADIUS, nbt.getFloat("Radius"));
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }

    @Override protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putString("Element", getElement());
        nbt.putFloat("Damage", getDamage());
        nbt.putInt("Segments", getSegmentCount());
        nbt.putFloat("Radius", getRadius());
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}