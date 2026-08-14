$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ 1. RasenshurikenBehavior (3s charge + massive AOE) ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\RasenshurikenBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class RasenshurikenBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 8f;
        int chargeTicks = params.has("chargeTicks") ? params.get("chargeTicks").getAsInt() : 60;
        int aoeTicks = params.has("aoeTicks") ? params.get("aoeTicks").getAsInt() : 60;

        player.sendMessage(Text.literal("\u00a7bRasenshuriken charging..."), true);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_AMBIENT, SoundCategory.PLAYERS, 2.0f, 1.5f);

        // Phase 1: Charging (60 ticks = 3s)
        TickScheduler.schedule(world, 1, 2, chargeTicks / 2, w -> {
            Vec3d hand = player.getEyePos().add(player.getRotationVector().multiply(0.8)).add(0, -0.3, 0);
            float scale = 0.5f + 1.5f * ((float) (chargeTicks / 2 - 1) / (chargeTicks / 2));
            for (int i = 0; i < 20; i++) {
                double a = (i / 20.0) * Math.PI * 2 + world.getTime() * 0.3;
                w.spawnParticles(ParticleTypes.CLOUD,
                    hand.x + Math.cos(a) * scale, hand.y + Math.sin(a * 2) * 0.3, hand.z + Math.sin(a) * scale,
                    2, 0.05, 0.05, 0.05, 0.02);
                w.spawnParticles(ParticleTypes.END_ROD,
                    hand.x + Math.cos(a + 0.5) * scale * 0.7, hand.y + Math.sin(a * 3) * 0.2, hand.z + Math.sin(a + 0.5) * scale * 0.7,
                    1, 0.02, 0.02, 0.02, 0.01);
            }
            if (w.getTime() % 20 == 0) {
                world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_POWER_SELECT, SoundCategory.PLAYERS, 1.0f, 0.8f + 0.2f * ((float) (chargeTicks / 2 - 1) / (chargeTicks / 2)));
            }
        });

        // Phase 2: Throw (after charge)
        TickScheduler.schedule(world, chargeTicks + 1, chargeTicks + 1, 1, w -> {
            player.sendMessage(Text.literal("\u00a7aRASENSHURIKEN!"), true);
            world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 2.0f, 1.2f);
            Vec3d hand = player.getEyePos().add(player.getRotationVector().multiply(0.8));
            Vec3d vel = player.getRotationVector().multiply(2.5);
            Vec3d currentPos = hand;

            // Travel: 40 ticks (2 seconds)
            TickScheduler.schedule(w, 1, 1, 40, w2 -> {
                currentPos = currentPos.add(vel);
                // Massive particles while traveling
                for (int i = 0; i < 30; i++) {
                    double a = (i / 30.0) * Math.PI * 2 + w2.getTime() * 0.5;
                    double r = 1.5;
                    w2.spawnParticles(ParticleTypes.CLOUD,
                        currentPos.x + Math.cos(a) * r, currentPos.y + Math.sin(a * 3) * 0.5, currentPos.z + Math.sin(a) * r,
                        3, 0.1, 0.1, 0.1, 0.05);
                }
                // Damage anything close while traveling
                Box travelBox = new Box(currentPos, currentPos).expand(2.5);
                for (Entity e : w2.getOtherEntities(player, travelBox)) {
                    if (e instanceof LivingEntity liv && !liv.equals(player)) {
                        liv.damage(player.getDamageSources().magic(), damage * 0.3f);
                        Vec3d kb = liv.getPos().subtract(currentPos).normalize().multiply(0.3);
                        liv.addVelocity(kb.x, 0.1, kb.z);
                        liv.velocityModified = true;
                    }
                }
            });

            // Phase 3: Expand + AOE (after travel)
            TickScheduler.schedule(w, 42, 2, aoeTicks / 2, w3 -> {
                Vec3d center = currentPos;
                for (int i = 0; i < 40; i++) {
                    double a = (i / 40.0) * Math.PI * 2 + w3.getTime() * 0.2;
                    double r = radius * ((float) (i % 10) / 10.0);
                    w3.spawnParticles(ParticleTypes.CLOUD,
                        center.x + Math.cos(a) * r, center.y + Math.random() * 2, center.z + Math.sin(a) * r,
                        2, 0.05, 0.1, 0.05, 0.03);
                }
                Box aoeBox = new Box(center, center).expand(radius);
                for (Entity e : w3.getOtherEntities(player, aoeBox)) {
                    if (e instanceof LivingEntity liv && !liv.equals(player)) {
                        liv.damage(player.getDamageSources().magic(), damage * 0.15f);
                        liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, 2, false, false));
                        liv.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, 40, 1, false, false));
                    }
                }
            });
        });
        JutsuLogger.logBehavior("rasenshuriken", "charge=" + chargeTicks + " aoe=" + aoeTicks);
    }
}
'@

# ============ 2. SubstitutionBehavior: instant + 10s cooldown ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\SubstitutionBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import java.util.List;

public class SubstitutionBehavior implements JutsuBehavior {
    private static long LAST_USE_MS = 0;
    private static final long COOLDOWN_MS = 10000;

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        long now = System.currentTimeMillis();
        long since = now - LAST_USE_MS;
        if (since < COOLDOWN_MS) {
            player.sendMessage(Text.literal("\u00a7cSubstitution on cooldown: " + ((COOLDOWN_MS - since) / 1000) + "s"), false);
            return;
        }
        LAST_USE_MS = now;

        float teleportDistance = params.has("distance") ? params.get("distance").getAsFloat() : 8f;
        int invisDuration = params.has("invisDuration") ? params.get("invisDuration").getAsInt() : 40;
        Vec3d oldPos = player.getPos();
        Vec3d dir = player.getRotationVector().multiply(-1).normalize();
        Vec3d newPos = oldPos.add(dir.multiply(teleportDistance));

        // Particles at old position
        for (int i = 0; i < 30; i++) {
            world.spawnParticles(ParticleTypes.SMOKE,
                oldPos.x + (Math.random() - 0.5) * 1.5, oldPos.y + Math.random() * 1.8, oldPos.z + (Math.random() - 0.5) * 1.5,
                1, 0.1, 0.1, 0.1, 0.05);
            world.spawnParticles(ParticleTypes.LARGE_SMOKE,
                oldPos.x + (Math.random() - 0.5) * 1.0, oldPos.y + Math.random() * 1.5, oldPos.z + (Math.random() - 0.5) * 1.0,
                1, 0.05, 0.05, 0.05, 0.02);
        }

        // Place log at old position
        BlockPos logPos = BlockPos.ofFloored(oldPos);
        if (world.getBlockState(logPos).isAir()) {
            world.setBlockState(logPos, Blocks.OAK_LOG.getDefaultState(), 3);
            WallRemovalTask.schedule(world, List.of(logPos), 60);
        }

        world.playSound(null, BlockPos.ofFloored(oldPos), SoundEvents.ENTITY_ENDERMAN_TELEPORT, SoundCategory.PLAYERS, 1.0f, 1.0f);
        player.teleport(newPos.x, newPos.y, newPos.z);
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.INVISIBILITY, invisDuration, 0, false, false));
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.SPEED, invisDuration, 2, false, false));
        player.sendMessage(Text.literal("\u00a77*Substitution!*"), true);
        JutsuLogger.logBehavior("substitution", "dist=" + teleportDistance);
    }
}
'@

# ============ 3. ImprovedWaterMirrorBehavior (real water puddle) ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\ImprovedWaterMirrorBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

public class ImprovedWaterMirrorBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 8f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 5f;
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 200;
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        BlockPos c = BlockPos.ofFloored(center);
        List<BlockPos> placed = new ArrayList<>();
        int r = (int) radius;
        for (int dx = -r; dx <= r; dx++) {
            for (int dz = -r; dz <= r; dz++) {
                if (dx * dx + dz * dz > r * r) continue;
                BlockPos p = c.add(dx, 0, dz);
                if (world.getBlockState(p).isAir()) {
                    world.setBlockState(p, Blocks.WATER.getDefaultState(), 3);
                    placed.add(p);
                }
            }
        }
        if (!placed.isEmpty()) WallRemovalTask.schedule(world, placed, lifetime);
        for (LivingEntity e : world.getOtherEntities(player, new Box(center, center).expand(radius))) {
            if (e instanceof LivingEntity living && !living.equals(player)) {
                living.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, lifetime, 2, false, false));
            }
        }
        JutsuLogger.logBehavior("improved_water_mirror", "placed=" + placed.size() + " radius=" + radius);
    }
}
'@

# ============ 4. IceMirrorBehavior (2 portals + teleport) ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\IceMirrorBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

public class IceMirrorBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 15f;
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 200;

        Vec3d startPos = player.getPos();
        Vec3d endPos = startPos.add(player.getRotationVector().multiply(range));

        // Build portal A (around player)
        List<BlockPos> portalA = buildMirror(world, startPos);
        // Build portal B (at target)
        List<BlockPos> portalB = buildMirror(world, endPos);

        if (portalA.isEmpty() || portalB.isEmpty()) {
            player.sendMessage(Text.literal("\u00a7cCannot create ice mirror - no space"), false);
            return;
        }

        WallRemovalTask.schedule(world, portalA, lifetime);
        WallRemovalTask.schedule(world, portalB, lifetime);

        // Sound + particles
        world.playSound(null, BlockPos.ofFloored(startPos), SoundEvents.BLOCK_GLASS_BREAK, SoundCategory.PLAYERS, 1.5f, 0.8f);
        world.playSound(null, BlockPos.ofFloored(endPos), SoundEvents.BLOCK_GLASS_BREAK, SoundCategory.PLAYERS, 1.5f, 0.8f);

        for (int i = 0; i < 40; i++) {
            double a = (i / 40.0) * Math.PI * 2;
            world.spawnParticles(ParticleTypes.END_ROD,
                startPos.x + Math.cos(a) * 1.5, startPos.y + 1 + Math.random(), startPos.z + Math.sin(a) * 1.5,
                2, 0.1, 0.2, 0.1, 0.03);
            world.spawnParticles(ParticleTypes.END_ROD,
                endPos.x + Math.cos(a) * 1.5, endPos.y + 1 + Math.random(), endPos.z + Math.sin(a) * 1.5,
                2, 0.1, 0.2, 0.1, 0.03);
        }

        // Teleport player to target portal
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOW_FALLING, 60, 0, false, false));
        player.teleport(endPos.x, endPos.y, endPos.z);
        player.sendMessage(Text.literal("\u00a7b*Ice Mirror Teleport*"), true);

        JutsuLogger.logBehavior("ice_mirror", "range=" + range);
    }

    private List<BlockPos> buildMirror(ServerWorld world, Vec3d center) {
        BlockPos c = BlockPos.ofFloored(center);
        List<BlockPos> placed = new ArrayList<>();
        // Mirror frame: 3x3 ring of ICE + PACKED_ICE center
        int[][] offsets = {
            {-1, 0, -1}, {0, 0, -1}, {1, 0, -1},
            {-1, 0, 0},              {1, 0, 0},
            {-1, 0, 1},  {0, 0, 1},  {1, 0, 1},
            {0, 1, -1}, {0, 2, -1},
            {0, 1, 1},  {0, 2, 1},
            {-1, 1, 0}, {-1, 2, 0},
            {1, 1, 0},  {1, 2, 0},
            {0, 3, 0}
        };
        for (int[] off : offsets) {
            BlockPos p = c.add(off[0], off[1], off[2]);
            if (world.getBlockState(p).isAir()) {
                world.setBlockState(p, Blocks.PACKED_ICE.getDefaultState(), 3);
                placed.add(p);
            }
        }
        return placed;
    }
}
'@

# ============ 5. Update JSONs to use new behaviors ============
Write-File "$base\resources\data\shinobicore\jutsu\rasenshuriken.json" @'
{"id":"shinobicore:rasenshuriken","name":"Wind Release: Rasenshuriken","category":"shape_ninjutsu","nature":"wind","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.RasenshurikenBehavior","params":{"radius":10,"chargeTicks":60,"aoeTicks":60},"baseCost":100,"baseDamage":45,"strain":20,"requiredUsesForFullProficiency":120,"requirements":{"control":40,"nature_wind":45,"ninjutsu":40}}
'@

Write-File "$base\resources\data\shinobicore\jutsu\gen_substitution.json" @'
{"id":"shinobicore:gen_substitution","name":"Substitution Jutsu","category":"shape_ninjutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.SubstitutionBehavior","params":{"distance":8,"invisDuration":40},"baseCost":30,"baseDamage":0,"strain":8,"requiredUsesForFullProficiency":40,"requirements":{"control":22,"ninjutsu":22}}
'@

Write-File "$base\resources\data\shinobicore\jutsu\water_release_water_mirror.json" @'
{"id":"shinobicore:water_release_water_mirror","name":"Water Release: Water Mirror","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ImprovedWaterMirrorBehavior","params":{"range":8,"radius":5,"lifetime":200},"baseCost":30,"baseDamage":0,"strain":8,"requiredUsesForFullProficiency":50,"requirements":{"control":25,"nature_water":30,"ninjutsu":20}}
'@

Write-File "$base\resources\data\shinobicore\jutsu\kekkei_ice_mirror.json" @'
{"id":"shinobicore:kekkei_ice_mirror","name":"Ice Release: Ice Mirror","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.IceMirrorBehavior","params":{"range":15,"lifetime":200},"baseCost":50,"baseDamage":0,"strain":12,"requiredUsesForFullProficiency":60,"requirements":{"control":30,"nature_water":25,"nature_wind":25,"ninjutsu":30}}
'@

Write-Host "=== PHASE G2 BATCH A DONE ==="
Write-Host "4 flagship techniques with unique mechanics"