package com.example.shinobicore.entity;
import com.example.shinobicore.combat.MarkTracker;
import com.example.shinobicore.combat.ThrowingHelper;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.UUID;
public class ShurikenEntity extends Entity {
    private UUID ownerId;
    private float damage = 3f;
    private boolean stuck = false;
    private int age = 0;
    public ShurikenEntity(EntityType<?> type, World world) { super(type, world); }
    public ShurikenEntity(World world, LivingEntity owner, Vec3d velocity, float damage) {
        super(ModEntities.SHURIKEN, world);
        this.ownerId = owner.getUuid();
        this.damage = damage;
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
    }
    @Override protected void initDataTracker() {}
    @Override public void tick() {
        super.tick();
        age++;
        if (stuck) { if (age > 400) discard(); return; }
        if (age > 160) { discard(); return; }
        Vec3d vel = this.getVelocity();
        vel = new Vec3d(vel.x, vel.y - 0.035, vel.z);
        this.setVelocity(vel);
        Vec3d start = this.getPos();
        Vec3d end = start.add(vel);
        HitResult blockHit = this.getWorld().raycast(new RaycastContext(start, end,
                RaycastContext.ShapeType.COLLIDER, RaycastContext.FluidHandling.NONE, this));
        LivingEntity hitEntity = null;
        double closest = Double.MAX_VALUE;
        Box searchBox = this.getBoundingBox().stretch(vel).expand(0.15);
        for (Entity entity : this.getWorld().getOtherEntities(this, searchBox)) {
            if (entity instanceof LivingEntity living
                    && (ownerId == null || !living.getUuid().equals(ownerId))) {
                var opt = living.getBoundingBox().expand(0.3).raycast(start, end);
                if (opt.isPresent()) {
                    double d = start.squaredDistanceTo(opt.get());
                    if (d < closest) { closest = d; hitEntity = living; }
                }
            }
        }
        if (hitEntity != null) {
            hitEntity.damage(this.getDamageSources().magic(), MarkTracker.boost(hitEntity, damage));
            Entity owner = getOwner();
            if (owner instanceof ServerPlayerEntity sp) {
                MarkTracker.mark(hitEntity, ThrowingHelper.markDurationMs(sp));
            } else {
                MarkTracker.mark(hitEntity, 10000);
            }
            hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.GLOWING, 100, 0, false, false));
            if (this.getWorld() instanceof ServerWorld sw) {
                sw.spawnParticles(ParticleTypes.CRIT, hitEntity.getX(), hitEntity.getY() + 1,
                        hitEntity.getZ(), 8, 0.3, 0.3, 0.3, 0.05);
            }
            this.playSound(SoundEvents.ENTITY_ARROW_HIT, 0.8f, 1.2f);
            this.discard();
            return;
        }
        if (blockHit.getType() == HitResult.Type.BLOCK) {
            if (this.getWorld() instanceof ServerWorld swHit) {
                swHit.spawnParticles(ParticleTypes.POOF, this.getX(), this.getY(), this.getZ(), 4, 0.1, 0.1, 0.1, 0.02);
            }
            this.playSound(SoundEvents.BLOCK_WOOD_HIT, 0.5f, 1.4f);
            this.discard();
            return;
        }
        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);
    }
    public void reflect(ServerPlayerEntity newOwner) {
        this.ownerId = newOwner.getUuid();
        Vec3d v = this.getVelocity();
        this.setVelocity(v.multiply(-1.3));
        this.velocityDirty = true;
    }

    public Entity getOwner() {
        if (ownerId == null) return null;
        if (this.getWorld() instanceof ServerWorld sw) return sw.getPlayerByUuid(ownerId);
        return null;
    }
    public int getAge() { return age; }
    public boolean isStuck() { return stuck; }
    @Override protected void readCustomDataFromNbt(NbtCompound nbt) {
        damage = nbt.getFloat("Damage");
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }
    @Override protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", damage);
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}