package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public final class BehaviorContext {
    public final LivingEntity caster;
    public final String jutsuId;
    public final JutsuDefinition definition;
    public final JsonObject behaviorData;
    public final Entity target;
    public final int casterLevel;
    public final float chargeMultiplier;
    public final ServerWorld world;

    public BehaviorContext(
            LivingEntity caster,
            String jutsuId,
            JutsuDefinition definition,
            JsonObject behaviorData,
            Entity target,
            int casterLevel,
            float chargeMultiplier,
            ServerWorld world
    ) {
        this.caster = caster;
        this.jutsuId = jutsuId;
        this.definition = definition;
        this.behaviorData = behaviorData;
        this.target = target;
        this.casterLevel = casterLevel;
        this.chargeMultiplier = chargeMultiplier;
        this.world = world;
    }

    public Vec3d getCasterEyePos() {
        return caster.getEyePos();
    }
}