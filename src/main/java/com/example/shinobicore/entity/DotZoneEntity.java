package com.example.shinobicore.entity;

import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.world.World;
import java.util.UUID;

/**
 * S5-03: Server-side DoT zone entity.
 * Created by Rasenshuriken impact and other area effects.
 * Deals periodic damage to enemies within radius.
 */
public class DotZoneEntity extends Entity {
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(DotZoneEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Float> DAMAGE_PER_TICK = DataTracker.registerData(DotZoneEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Integer> DURATION_TICKS = DataTracker.registerData(DotZoneEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<String> ELEMENT = DataTracker.registerData(DotZoneEntity.class, TrackedDataHandlerRegistry.STRING);
    
    private UUID ownerId;
    private int ticksActive = 0;
    private int tickInterval = 10; // Damage every 10 ticks (0.5s)
    
    public DotZoneEntity(EntityType<?> type, World world) { super(type, world); }
    
    public DotZoneEntity(World world, LivingEntity owner, double x, double y, double z,
                         float radius, float damagePerTick, int durationTicks, String element) {
        super(ModEntities.DOT_ZONE, world);
        this.ownerId = owner.getUuid();
        this.setPosition(x, y, z);
        this.dataTracker.set(RADIUS, radius);
        this.dataTracker.set(DAMAGE_PER_TICK, damagePerTick);
        this.dataTracker.set(DURATION_TICKS, durationTicks);
        this.dataTracker.set(ELEMENT, element != null ? element : "wind");
    }
    
    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(RADIUS, 5.0f);
        this.dataTracker.startTracking(DAMAGE_PER_TICK, 2.0f);
        this.dataTracker.startTracking(DURATION_TICKS, 100);
        this.dataTracker.startTracking(ELEMENT, "wind");
    }
    
    public float getRadius() { return this.dataTracker.get(RADIUS); }
    public float getDamagePerTick() { return this.dataTracker.get(DAMAGE_PER_TICK); }
    public int getDurationTicks() { return this.dataTracker.get(DURATION_TICKS); }
    public String getElement() { return this.dataTracker.get(ELEMENT); }
    public float getProgress() { return Math.min(1f, (float)ticksActive / getDurationTicks()); }
    public Entity getOwner() {
        return ownerId == null ? null : getWorld().getPlayerByUuid(ownerId);
    }
    
    @Override
    public void tick() {
        super.tick();
        ticksActive++;
        
        if (ticksActive >= getDurationTicks()) {
            discard();
            return;
        }
        
        // Server-side damage logic
        if (!getWorld().isClient && ticksActive % tickInterval == 0) {
            float radius = getRadius();
            float damage = getDamagePerTick();
            Box aoe = new Box(getPos(), getPos()).expand(radius);
            
            for (Entity e : getWorld().getOtherEntities(this, aoe)) {
                if (e instanceof LivingEntity liv) {
                    // Don't damage owner or allies
                    if (ownerId != null && liv.getUuid().equals(ownerId)) continue;
                    
                    liv.damage(getDamageSources().magic(), damage);
                    // Apply element-specific effects
                    String elem = getElement();
                    if ("wind".equals(elem)) {
                        // Wind shreds: slowness + weakness
                        liv.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
                            net.minecraft.entity.effect.StatusEffects.SLOWNESS, 30, 1, false, false));
                    } else if ("fire".equals(elem)) {
                        liv.setOnFireFor(2);
                    }
                }
            }
        }
        
        // Zero velocity - zone stays in place
        setVelocity(0, 0, 0);
    }
    
    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(RADIUS, nbt.getFloat("Radius"));
        this.dataTracker.set(DAMAGE_PER_TICK, nbt.getFloat("Damage"));
        this.dataTracker.set(DURATION_TICKS, nbt.getInt("Duration"));
        this.dataTracker.set(ELEMENT, nbt.getString("Element"));
        ticksActive = nbt.getInt("TicksActive");
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }
    
    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Radius", getRadius());
        nbt.putFloat("Damage", getDamagePerTick());
        nbt.putInt("Duration", getDurationTicks());
        nbt.putString("Element", getElement());
        nbt.putInt("TicksActive", ticksActive);
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}