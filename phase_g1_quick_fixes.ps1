$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ 1. Fireball Barrage: wider spread ============
Write-File "$base\resources\data\shinobicore\jutsu\fire_barrage.json" @'
{"id":"shinobicore:fire_barrage","name":"Fire Release: Fireball Barrage","category":"elemental_ninjutsu","nature":"fire","type":"projectile","params":{"speed":1.8,"radius":0.8,"particle":"flame","lifetime":60,"count":8,"spread":0.6},"baseCost":30,"baseDamage":6,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":20,"nature_fire":25,"ninjutsu":18}}
'@

# ============ 2. Running Fire: leaves fire blocks ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\RunningFireBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

public class RunningFireBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float distance = params.has("distance") ? params.get("distance").getAsFloat() : 8f;
        Vec3d start = player.getPos();
        Vec3d dir = player.getRotationVector().multiply(0.5);
        List<BlockPos> fireBlocks = new ArrayList<>();
        int steps = (int)(distance / 0.5);
        for (int i = 0; i < steps; i++) {
            TickScheduler.schedule(world, i * 2, 2, 1, w -> {
                Vec3d pos = start.add(dir.multiply(i));
                BlockPos bp = BlockPos.ofFloored(pos);
                if (w.getBlockState(bp).isAir()) {
                    w.setBlockState(bp, Blocks.FIRE.getDefaultState(), 3);
                    fireBlocks.add(bp);
                }
                for (LivingEntity e : w.getEntitiesByClass(LivingEntity.class, new Box(bp, bp).expand(1), t -> t != player && t.isAlive())) {
                    e.setOnFireFor(3);
                    e.damage(player.getDamageSources().inFire(), damage * 0.3f);
                }
            });
        }
        TickScheduler.schedule(world, steps * 2 + 200, 200, 1, w -> {
            for (BlockPos bp : fireBlocks) {
                if (w.getBlockState(bp).isOf(Blocks.FIRE)) w.removeBlock(bp, false);
            }
        });
        JutsuLogger.logBehavior("running_fire", "distance=" + distance);
    }
}
'@

# ============ 3. Phoenix Sage: homing AI ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\HomingProjectileBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.projectile.FireballEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class HomingProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        int count = params.has("count") ? params.get("count").getAsInt() : 12;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        for (int i = 0; i < count; i++) {
            final int idx = i;
            TickScheduler.schedule(world, i * 3, 3, 1, w -> {
                FireballEntity fb = new FireballEntity(w, player, look.x, look.y, look.z, 0);
                fb.setPosition(eye.x, eye.y, eye.z);
                fb.setVelocity(look.x * speed, look.y * speed, look.z * speed, 0.1f, 0.1f);
                w.spawnEntity(fb);
                TickScheduler.schedule(w, 1, 2, 30, world2 -> {
                    if (fb.isRemoved()) return;
                    LivingEntity target = findClosest(world2, fb.getPos(), 16, player);
                    if (target != null) {
                        Vec3d to = target.getPos().add(0, target.getHeight() / 2, 0).subtract(fb.getPos()).normalize();
                        Vec3d vel = fb.getVelocity();
                        Vec3d newVel = vel.multiply(0.9).add(to.multiply(0.3));
                        fb.setVelocity(newVel.x, newVel.y, newVel.z, 0.1f, 0.1f);
                    }
                });
            });
        }
        JutsuLogger.logBehavior("homing_projectile", "count=" + count);
    }
    private LivingEntity findClosest(ServerWorld world, Vec3d from, float range, ServerPlayerEntity caster) {
        LivingEntity best = null;
        double bestDist = Double.MAX_VALUE;
        for (Entity e : world.getOtherEntities(caster, new net.minecraft.util.math.Box(from, from).expand(range))) {
            if (e instanceof LivingEntity liv && !liv.equals(caster)) {
                double d = liv.getPos().distanceTo(from);
                if (d < bestDist) { bestDist = d; best = liv; }
            }
        }
        return best;
    }
}
'@

# ============ 4. Exploding Flame: creates explosion ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\ExplodingProjectileBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.projectile.FireballEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.explosion.Explosion;

public class ExplodingProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.8f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        FireballEntity fb = new FireballEntity(world, player, look.x, look.y, look.z, 0);
        fb.setPosition(eye.x, eye.y, eye.z);
        fb.setVelocity(look.x * speed, look.y * speed, look.z * speed, 0.1f, 0.1f);
        world.spawnEntity(fb);
        TickScheduler.schedule(world, 1, 2, 40, w -> {
            if (fb.isRemoved() || fb.horizontalCollision || fb.verticalCollision) {
                Vec3d pos = fb.getPos();
                w.createExplosion(fb, pos.x, pos.y, pos.z, radius, false, Explosion.DestructionType.DESTROY);
                fb.discard();
            }
        });
        JutsuLogger.logBehavior("exploding_projectile", "radius=" + radius);
    }
}
'@

# ============ 5. Formation Wall: creates water wall ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\WallCreationBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

public class WallCreationBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 6f;
        int width = params.has("width") ? params.get("width").getAsInt() : 5;
        int height = params.has("height") ? params.get("height").getAsInt() : 3;
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;
        String blockType = params.has("blockType") ? params.get("blockType").getAsString() : "water";
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        BlockPos c = BlockPos.ofFloored(center);
        List<BlockPos> placed = new ArrayList<>();
        float yaw = player.getYaw() * ((float)Math.PI / 180f);
        float rightX = (float)Math.cos(yaw + Math.PI/2);
        float rightZ = (float)Math.sin(yaw + Math.PI/2);
        for (int dx = -width/2; dx <= width/2; dx++) {
            for (int dy = 0; dy < height; dy++) {
                BlockPos p = c.add((int)(rightX * dx), dy, (int)(rightZ * dx));
                if (world.getBlockState(p).isAir()) {
                    if (blockType.equals("water")) world.setBlockState(p, Blocks.WATER.getDefaultState(), 3);
                    else if (blockType.equals("ice")) world.setBlockState(p, Blocks.ICE.getDefaultState(), 3);
                    else if (blockType.equals("dirt")) world.setBlockState(p, Blocks.DIRT.getDefaultState(), 3);
                    else if (blockType.equals("iron")) world.setBlockState(p, Blocks.IRON_BLOCK.getDefaultState(), 3);
                    else if (blockType.equals("stone")) world.setBlockState(p, Blocks.STONE.getDefaultState(), 3);
                    placed.add(p);
                }
            }
        }
        if (!placed.isEmpty()) WallRemovalTask.schedule(world, placed, lifetime);
        JutsuLogger.logBehavior("wall_creation", "placed=" + placed.size());
    }
}
'@

# ============ 6. Update JSONs to use new behaviors ============
Write-File "$base\resources\data\shinobicore\jutsu\fire_phoenix_sage_f.json" @'
{"id":"shinobicore:fire_phoenix_sage_f","name":"Fire Release: Phoenix Sage Flower","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.HomingProjectileBehavior","params":{"count":12,"speed":2.0},"baseCost":32,"baseDamage":4,"strain":8,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_fire":28,"ninjutsu":18,"perception":15}}
'@

Write-File "$base\resources\data\shinobicore\jutsu\fire_exploding.json" @'
{"id":"shinobicore:fire_exploding","name":"Fire Release: Exploding Flame","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ExplodingProjectileBehavior","params":{"speed":1.8,"radius":4},"baseCost":32,"baseDamage":10,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_fire":28,"ninjutsu":20}}
'@

Write-File "$base\resources\data\shinobicore\jutsu\fire_running.json" @'
{"id":"shinobicore:fire_running","name":"Fire Release: Running Fire","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.RunningFireBehavior","params":{"distance":8},"baseCost":28,"baseDamage":5,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"control":18,"nature_fire":22,"ninjutsu":15}}
'@

Write-File "$base\resources\data\shinobicore\jutsu\water_formation.json" @'
{"id":"shinobicore:water_formation","name":"Water Release: Water Formation Wall","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.WallCreationBehavior","params":{"range":6,"width":5,"height":3,"lifetime":100,"blockType":"water"},"baseCost":32,"baseDamage":0,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_water":28,"ninjutsu":18}}
'@

Write-File "$base\resources\data\shinobicore\jutsu\earth_iron_wall.json" @'
{"id":"shinobicore:earth_iron_wall","name":"Earth Release: Iron Wall","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.WallCreationBehavior","params":{"range":4,"width":3,"height":3,"lifetime":600,"blockType":"iron"},"baseCost":44,"baseDamage":0,"strain":11,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"nature_earth":34,"ninjutsu":24}}
'@

Write-File "$base\resources\data\shinobicore\jutsu\earth_shore.json" @'
{"id":"shinobicore:earth_shore","name":"Earth Release: Earth Shore","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.WallCreationBehavior","params":{"range":4,"width":4,"height":2,"lifetime":600,"blockType":"dirt"},"baseCost":28,"baseDamage":0,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"control":20,"nature_earth":26,"ninjutsu":16}}
'@

# ============ 7. Vacuum Bullet: invisible ============
Write-File "$base\resources\data\shinobicore\jutsu\wind_vacuum_bullet.json" @'
{"id":"shinobicore:wind_vacuum_bullet","name":"Wind Release: Vacuum Bullet","category":"elemental_ninjutsu","nature":"wind","type":"projectile","params":{"speed":3.2,"radius":1,"particle":"none","lifetime":60},"baseCost":26,"baseDamage":8,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"control":20,"nature_wind":25,"ninjutsu":18}}
'@

Write-File "$base\resources\data\shinobicore\jutsu\wind_air_bullet.json" @'
{"id":"shinobicore:wind_air_bullet","name":"Wind Release: Air Bullet","category":"elemental_ninjutsu","nature":"wind","type":"projectile","params":{"speed":4.0,"radius":0.8,"particle":"none","lifetime":50},"baseCost":24,"baseDamage":6,"strain":6,"requiredUsesForFullProficiency":40,"requirements":{"control":18,"nature_wind":24,"ninjutsu":16}}
'@

# ============ 8. Shuriken Boomerang: return to player ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\BoomerangBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.projectile.thrown.SnowballEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class BoomerangBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        SnowballEntity sb = new SnowballEntity(world, player);
        sb.setPosition(eye.x, eye.y, eye.z);
        sb.setVelocity(look.x * speed, look.y * speed, look.z * speed, 0.1f, 0.1f);
        world.spawnEntity(sb);
        TickScheduler.schedule(world, 30, 2, 30, w -> {
            if (sb.isRemoved()) return;
            Vec3d to = player.getPos().add(0, 1, 0).subtract(sb.getPos()).normalize();
            Vec3d vel = sb.getVelocity();
            Vec3d newVel = vel.multiply(0.85).add(to.multiply(0.35));
            sb.setVelocity(newVel.x, newVel.y, newVel.z, 0.1f, 0.1f);
            w.spawnParticles(ParticleTypes.WIND, sb.getX(), sb.getY(), sb.getZ(), 2, 0.1, 0.1, 0.1, 0.02);
            if (sb.distanceTo(player) < 1.5) sb.discard();
        });
        JutsuLogger.logBehavior("boomerang", "speed=" + speed);
    }
}
'@

Write-File "$base\resources\data\shinobicore\jutsu\shuriken_boomerang.json" @'
{"id":"shinobicore:shuriken_boomerang","name":"Shuriken: Boomerang","category":"shape_ninjutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BoomerangBehavior","params":{"speed":2.0},"baseCost":20,"baseDamage":5,"strain":5,"requiredUsesForFullProficiency":35,"requirements":{"control":18,"perception":15}}
'@

Write-Host "=== PHASE G1 QUICK FIXES DONE ==="
Write-Host "Created 4 new behaviors + updated 10 JSONs"