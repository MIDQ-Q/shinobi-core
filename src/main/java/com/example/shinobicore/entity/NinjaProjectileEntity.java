package com.example.shinobicore.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.MarkTracker;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.List;
import java.util.UUID;

public class NinjaProjectileEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<String> PARTICLE_TYPE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<String> MODEL_TYPE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING); // РќРћР’РћР•
    private static final TrackedData<Integer> LIFETIME = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Boolean> HAS_GRAVITY = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.BOOLEAN);
    private static final TrackedData<Integer> PIERCE_COUNT = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Integer> BOUNCE_COUNT = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);

    public float getRadius() { return this.dataTracker.get(RADIUS); }
    public String getParticleType() { return this.dataTracker.get(PARTICLE_TYPE); }
    public String getModelType() { return this.dataTracker.get(MODEL_TYPE); } // РќРћР’РћР•

    private UUID ownerId;
    public Entity getOwner() {
        if (ownerId == null) return null;
        if (this.getWorld() instanceof ServerWorld sw) return sw.getPlayerByUuid(ownerId);
        return null;
    }

    // РР·РјРµРЅРµРЅРѕ РЅР° public, С‡С‚РѕР±С‹ СЂРµРЅРґРµСЂРµСЂ РјРѕРі С‡РёС‚Р°С‚СЊ age РґР»СЏ Р°РЅРёРјР°С†РёРё РІСЂР°С‰РµРЅРёСЏ
    public int age = 0; 
    private int pierceRemaining = 0;
    private int bounceRemaining = 0;

    public NinjaProjectileEntity(EntityType<?> type, World world) {
        super(type, world);
    }

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
            if (radius > 0.5f) {
                for (Entity entity : this.getWorld().getOtherEntities(this, this.getBoundingBox().expand(radius))) {
                    if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                        living.damage(this.getDamageSources().magic(), damage * 0.5f);
                    }
                }
            }
            this.discard();
            return;
        }

        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);

        if (this.getWorld() instanceof ServerWorld serverWorld) {
            String particle = this.dataTracker.get(PARTICLE_TYPE);
            float radius = this.dataTracker.get(RADIUS);
            net.minecraft.particle.ParticleEffect particleType = switch (particle) {
                case "water" -> net.minecraft.particle.ParticleTypes.FALLING_WATER;
                case "smoke" -> net.minecraft.particle.ParticleTypes.SMOKE;
                case "lightning" -> net.minecraft.particle.ParticleTypes.ELECTRIC_SPARK;
                case "wind" -> net.minecraft.particle.ParticleTypes.CLOUD;
                case "earth" -> net.minecraft.particle.ParticleTypes.POOF;
                default -> net.minecraft.particle.ParticleTypes.FLAME;
            };
            int count = Math.max(3, (int)(radius * 1.5));
            float spread = radius * 0.2f;
            for (int i = 0; i < count; i++) {
                if (age % 2 == 0) serverWorld.spawnParticles(particleType,
                    this.getX() + (Math.random() - 0.5) * spread, 
                    this.getY() + (Math.random() - 0.5) * spread, 
                    this.getZ() + (Math.random() - 0.5) * spread,
                    1, 0.01, 0.01, 0.01, 0.01);
            }
        }
    }

    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
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

    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
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
}