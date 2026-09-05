package com.example.shinobicore.ai;

import net.minecraft.entity.LivingEntity;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class AiBrain {
    public final LivingEntity entity;
    public final UUID owner;
    public String behavior = "fight_for_caster";
    public LivingEntity target;
    public AiState state;
    public int stateTicks;
    public int lifetime = -1;
    public int level = 1;
    public final List<String> jutsus = new ArrayList<>();
    public int jutsuIndex = 0;
    public final Map<String, Integer> cooldowns = new HashMap<>();
    public float meleeDamage = 3f;
    public float explodeDamage = 8f;
    public float explodeRadius = 3f;
    public Vec3d home;
    public int personality = 0; // 0 aggressive, 1 cautious
    public float dodgeChance = 0f;
    public float speedMult = 1f;
    public float castScale = 0.5f;
    public int navCd = 0;
    public double lastX = Double.MAX_VALUE;
    public double lastZ = Double.MAX_VALUE;
    public int stuck = 0;

    public AiBrain(LivingEntity entity, UUID owner) {
        this.entity = entity;
        this.owner = owner;
    }

    public void setState(AiState s) {
        if (state != null) state.exit(this);
        state = s;
        stateTicks = 0;
        if (s != null) s.enter(this);
    }

    public boolean cdOk(String key, int ticks) {
        if (cooldowns.getOrDefault(key, 0) > 0) return false;
        cooldowns.put(key, ticks);
        return true;
    }
}