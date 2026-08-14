$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$jutsuDir = "$base\resources\data\shinobicore\jutsu"
$behDir = "$base\java\com\example\shinobicore\jutsu\custom"
$treeFile = "$base\resources\data\shinobicore\skill_tree\tree.json"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============================================================
# BEHAVIOR 1: ZoneBehavior (DOT area damage)
# ============================================================
Write-File "$behDir\ZoneBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class ZoneBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 10f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 5f;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 200;
        float tickDamage = params.has("tickDamage") ? params.get("tickDamage").getAsFloat() : 2f;
        int tickInterval = params.has("tickInterval") ? params.get("tickInterval").getAsInt() : 20;
        boolean burn = params.has("burn") && params.get("burn").getAsBoolean();
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        int ticks = duration / tickInterval;
        for (int t = 0; t < ticks; t++) {
            final int tt = t;
            world.getServer().execute(() -> {
                for (Entity e : world.getOtherEntities(player,
                        new net.minecraft.util.math.Box(center, center).expand(radius))) {
                    if (e instanceof LivingEntity liv && !liv.equals(player)) {
                        liv.damage(player.getDamageSources().magic(), tickDamage);
                        if (burn) liv.setOnFireFor(2);
                    }
                }
                for (int i = 0; i < 20; i++) {
                    double a = Math.random() * Math.PI * 2;
                    double r = Math.random() * radius;
                    world.spawnParticles(ParticleTypes.FLAME,
                            center.x + Math.cos(a) * r, center.y + 0.1, center.z + Math.sin(a) * r,
                            1, 0, 0.05, 0, 0.02);
                }
            });
            try { Thread.sleep(tickInterval * 50); } catch (Exception ignored) {}
        }
        JutsuLogger.logBehavior("zone", "center=" + center + " ticks=" + ticks);
    }
}
'@

# ============================================================
# BEHAVIOR 2: PullBehavior (pulls enemies to center)
# ============================================================
Write-File "$behDir\PullBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class PullBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 12f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 6f;
        float pullStrength = params.has("pullStrength") ? params.get("pullStrength").getAsFloat() : 0.4f;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 60;
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        for (int t = 0; t < duration; t += 5) {
            final int tt = t;
            world.getServer().execute(() -> {
                for (Entity e : world.getOtherEntities(player,
                        new net.minecraft.util.math.Box(center, center).expand(radius))) {
                    if (e instanceof LivingEntity liv && !liv.equals(player)) {
                        Vec3d pull = center.subtract(liv.getPos()).normalize().multiply(pullStrength);
                        liv.addVelocity(pull.x, 0.1, pull.z);
                        liv.velocityModified = true;
                        if (damage > 0 && tt % 20 == 0) {
                            liv.damage(player.getDamageSources().magic(), damage);
                        }
                    }
                }
                for (int i = 0; i < 15; i++) {
                    double a = (i / 15.0) * Math.PI * 2;
                    world.spawnParticles(ParticleTypes.PORTAL,
                            center.x + Math.cos(a) * radius, center.y + 0.5, center.z + Math.sin(a) * radius,
                            1, -Math.cos(a) * 0.1, 0.05, -Math.sin(a) * 0.1, 0.03);
                }
            });
            try { Thread.sleep(250); } catch (Exception ignored) {}
        }
        JutsuLogger.logBehavior("pull", "duration=" + duration + " strength=" + pullStrength);
    }
}
'@

# ============================================================
# BEHAVIOR 3: ChainLightningBehavior
# ============================================================
Write-File "$behDir\ChainLightningBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class ChainLightningBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        int maxTargets = params.has("maxTargets") ? params.get("maxTargets").getAsInt() : 5;
        float chainRange = params.has("chainRange") ? params.get("chainRange").getAsFloat() : 8f;
        float damageFalloff = params.has("damageFalloff") ? params.get("damageFalloff").getAsFloat() : 0.85f;
        Vec3d start = player.getEyePos().add(player.getRotationVector().multiply(2));
        LivingEntity first = findClosest(world, start, chainRange, player, null);
        if (first == null) return;
        Set<LivingEntity> hit = new HashSet<>();
        LivingEntity current = first;
        float currentDamage = damage;
        for (int i = 0; i < maxTargets && current != null; i++) {
            hit.add(current);
            current.damage(player.getDamageSources().magic(), currentDamage);
            spawnBolt(world, start, current.getPos().add(0, current.getHeight() / 2, 0));
            current.setOnFireFor(1);
            currentDamage *= damageFalloff;
            start = current.getPos().add(0, current.getHeight() / 2, 0);
            current = findClosest(world, start, chainRange, player, hit);
        }
        JutsuLogger.logBehavior("chain_lightning", "targets=" + hit.size() + " damage=" + damage);
    }
    private LivingEntity findClosest(ServerWorld world, Vec3d from, float range,
                                      ServerPlayerEntity caster, Set<LivingEntity> exclude) {
        LivingEntity best = null;
        double bestDist = Double.MAX_VALUE;
        for (Entity e : world.getOtherEntities(caster,
                new net.minecraft.util.math.Box(from, from).expand(range))) {
            if (e instanceof LivingEntity liv && !liv.equals(caster)) {
                if (exclude != null && exclude.contains(liv)) continue;
                double d = liv.getPos().distanceTo(from);
                if (d < bestDist) { bestDist = d; best = liv; }
            }
        }
        return best;
    }
    private void spawnBolt(ServerWorld world, Vec3d from, Vec3d to) {
        Vec3d dir = to.subtract(from).normalize();
        double dist = from.distanceTo(to);
        for (double d = 0; d < dist; d += 0.3) {
            Vec3d p = from.add(dir.multiply(d));
            world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, p.x, p.y, p.z, 1, 0, 0, 0, 0);
        }
    }
}
'@

# ============================================================
# BEHAVIOR 4: KnockdownBehavior (AOE knockdown)
# ============================================================
Write-File "$behDir\KnockdownBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class KnockdownBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 8f;
        int stunDuration = params.has("stunDuration") ? params.get("stunDuration").getAsInt() : 40;
        float knockback = params.has("knockback") ? params.get("knockback").getAsFloat() : 1.5f;
        Vec3d center = player.getPos();
        int count = 0;
        for (Entity e : world.getOtherEntities(player,
                new net.minecraft.util.math.Box(center, center).expand(radius))) {
            if (e instanceof LivingEntity liv && !liv.equals(player)) {
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, stunDuration, 255, false, false));
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, stunDuration, 255, false, false));
                Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(knockback);
                liv.addVelocity(kb.x, 0.3, kb.z);
                liv.velocityModified = true;
                if (damage > 0) liv.damage(player.getDamageSources().magic(), damage);
                count++;
            }
        }
        for (int i = 0; i < 50; i++) {
            double a = (i / 50.0) * Math.PI * 2;
            double r = radius * (i % 3 == 0 ? 1.0 : 0.7);
            world.spawnParticles(ParticleTypes.EXPLOSION,
                    center.x + Math.cos(a) * r, center.y, center.z + Math.sin(a) * r,
                    1, 0, 0.1, 0, 0.05);
        }
        JutsuLogger.logBehavior("knockdown", "radius=" + radius + " targets=" + count);
    }
}
'@

# ============================================================
# JSON TECHNIQUES (19)
# ============================================================
$jsons = @{}

# FIRE (3)
$jsons["fire_flame_prison"] = @'
{"id":"shinobicore:fire_flame_prison","name":"Fire Release: Flame Prison","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ZoneBehavior","params":{"range":10,"radius":5,"duration":160,"tickDamage":3,"tickInterval":20,"burn":true},"baseCost":38,"baseDamage":0,"strain":10,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_fire":30,"ninjutsu":20}}
'@
$jsons["fire_scorched_earth"] = @'
{"id":"shinobicore:fire_scorched_earth","name":"Fire Release: Scorched Earth","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ZoneBehavior","params":{"range":8,"radius":6,"duration":200,"tickDamage":2,"tickInterval":25,"burn":true},"baseCost":42,"baseDamage":0,"strain":11,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_fire":32,"ninjutsu":22}}
'@
$jsons["fire_ash_pile"] = @'
{"id":"shinobicore:fire_ash_pile","name":"Fire Release: Ash Pile Burn","category":"elemental_ninjutsu","nature":"fire","type":"aoe","params":{"radius":6,"particle":"smoke","particleCount":80,"statusEffect":"blindness","statusDuration":100},"baseCost":34,"baseDamage":4,"strain":9,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_fire":28,"ninjutsu":18}}
'@

# WATER (3)
$jsons["water_dragon_bullet"] = @'
{"id":"shinobicore:water_dragon_bullet","name":"Water Release: Water Dragon Bullet","category":"elemental_ninjutsu","nature":"water","type":"projectile","params":{"speed":1.4,"radius":4,"particle":"water","lifetime":100,"gravity":false},"baseCost":45,"baseDamage":14,"strain":12,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"nature_water":35,"ninjutsu":24}}
'@
$jsons["water_rain_arrows"] = @'
{"id":"shinobicore:water_rain_arrows","name":"Water Release: Rain of Arrows","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ArrowRainBehavior","params":{"count":18,"area":7,"arrowDamage":3},"baseCost":40,"baseDamage":0,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_water":30,"ninjutsu":20}}
'@
$jsons["water_maelstrom"] = @'
{"id":"shinobicore:water_maelstrom","name":"Water Release: Maelstrom Vortex","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.PullBehavior","params":{"range":10,"radius":6,"pullStrength":0.5,"duration":60},"baseCost":38,"baseDamage":3,"strain":10,"requiredUsesForFullProficiency":50,"requirements":{"control":25,"nature_water":32,"ninjutsu":20}}
'@

# WIND (3)
$jsons["wind_tornado_cage"] = @'
{"id":"shinobicore:wind_tornado_cage","name":"Wind Release: Tornado Cage","category":"elemental_ninjutsu","nature":"wind","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.RootBehavior","params":{"range":10,"radius":4,"duration":80,"fromTarget":true},"baseCost":36,"baseDamage":2,"strain":9,"requiredUsesForFullProficiency":45,"requirements":{"control":24,"nature_wind":30,"ninjutsu":18}}
'@
$jsons["wind_pressure_damage"] = @'
{"id":"shinobicore:wind_pressure_damage","name":"Wind Release: Pressure Damage","category":"elemental_ninjutsu","nature":"wind","type":"aoe","params":{"radius":5,"particle":"wind","particleCount":70,"knockback":0.5,"stun":true,"stunDuration":30},"baseCost":32,"baseDamage":4,"strain":8,"requiredUsesForFullProficiency":40,"requirements":{"control":22,"nature_wind":28,"ninjutsu":16}}
'@
$jsons["wind_divine_wind"] = @'
{"id":"shinobicore:wind_divine_wind","name":"Wind Release: Divine Wind","category":"elemental_ninjutsu","nature":"wind","type":"projectile","params":{"speed":3.0,"radius":0.8,"particle":"wind","lifetime":80,"pierce":5},"baseCost":34,"baseDamage":10,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_wind":32,"ninjutsu":20}}
'@

# LIGHTNING (3)
$jsons["lightning_thunder_cut"] = @'
{"id":"shinobicore:lightning_thunder_cut","name":"Lightning Release: Thunder Cut","category":"elemental_ninjutsu","nature":"lightning","type":"melee","params":{"range":4,"coneAngle":120,"knockback":1.0,"particle":"lightning"},"baseCost":28,"baseDamage":12,"strain":8,"requiredUsesForFullProficiency":40,"requirements":{"control":22,"nature_lightning":28,"ninjutsu":18}}
'@
$jsons["lightning_depth_charge"] = @'
{"id":"shinobicore:lightning_depth_charge","name":"Lightning Release: Depth Charge","category":"elemental_ninjutsu","nature":"lightning","type":"dash","params":{"distance":12,"knockback":2.5,"hitRadius":3,"particle":"lightning","particleCount":80,"statusEffect":"slowness","statusDuration":50},"baseCost":40,"baseDamage":14,"strain":11,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_lightning":32,"ninjutsu":22}}
'@
$jsons["lightning_chain"] = @'
{"id":"shinobicore:lightning_chain","name":"Lightning Release: Chain Lightning","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ChainLightningBehavior","params":{"maxTargets":6,"chainRange":8,"damageFalloff":0.8},"baseCost":42,"baseDamage":10,"strain":11,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_lightning":34,"ninjutsu":22}}
'@

# EARTH (3)
$jsons["earth_earthquake"] = @'
{"id":"shinobicore:earth_earthquake","name":"Earth Release: Earthquake","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.KnockdownBehavior","params":{"radius":10,"stunDuration":50,"knockback":1.8},"baseCost":45,"baseDamage":6,"strain":12,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"nature_earth":35,"ninjutsu":24}}
'@
$jsons["earth_antlion_trap"] = @'
{"id":"shinobicore:earth_antlion_trap","name":"Earth Release: Antlion Trap","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.PullBehavior","params":{"range":8,"radius":4,"pullStrength":0.6,"duration":80},"baseCost":34,"baseDamage":4,"strain":9,"requiredUsesForFullProficiency":45,"requirements":{"control":24,"nature_earth":30,"ninjutsu":18}}
'@
$jsons["earth_sandwich"] = @'
{"id":"shinobicore:earth_sandwich","name":"Earth Release: Sandwich","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.RootBehavior","params":{"range":12,"radius":3,"duration":100,"fromTarget":true},"baseCost":36,"baseDamage":8,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_earth":32,"ninjutsu":20}}
'@

# KEKKEI ACTIVE (3)
$jsons["kekkei_ice_mirror"] = @'
{"id":"shinobicore:kekkei_ice_mirror","name":"Ice Release: Ice Mirror","category":"elemental_ninjutsu","nature":"water","type":"utility","params":{"effect":"teleport","range":15},"baseCost":50,"baseDamage":0,"strain":12,"requiredUsesForFullProficiency":60,"requirements":{"control":30,"nature_water":25,"nature_wind":25,"ninjutsu":30},"visibilityCondition":{"type":"kekkei","key":"ice"}}
'@
$jsons["kekkei_lava_golem"] = @'
{"id":"shinobicore:kekkei_lava_golem","name":"Lava Release: Lava Golem","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.SummonBehavior","params":{"entity":"minecraft:magma_cube","count":1},"baseCost":60,"baseDamage":0,"strain":15,"requiredUsesForFullProficiency":70,"requirements":{"control":32,"nature_fire":25,"nature_earth":25,"ninjutsu":30},"visibilityCondition":{"type":"kekkei","key":"lava"}}
'@
$jsons["kekkei_blaze_flame"] = @'
{"id":"shinobicore:kekkei_blaze_flame","name":"Blaze Release: Black Flame","category":"elemental_ninjutsu","nature":"fire","type":"projectile","params":{"speed":1.5,"radius":2,"particle":"smoke","lifetime":100,"pierce":1},"baseCost":55,"baseDamage":10,"strain":14,"requiredUsesForFullProficiency":70,"requirements":{"control":30,"nature_fire":30,"genjutsu":20,"ninjutsu":28},"visibilityCondition":{"type":"kekkei","key":"blaze"}}
'@

# FORBIDDEN (1)
$jsons["forbidden_edo_tensei"] = @'
{"id":"shinobicore:forbidden_edo_tensei","name":"Forbidden: Edo Tensei","category":"taijutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.SummonBehavior","params":{"entity":"minecraft:zombie","count":3},"baseCost":80,"baseDamage":0,"strain":25,"requiredUsesForFullProficiency":1,"requirements":{"taijutsu":45,"control":35,"ninjutsu":35}}
'@

foreach ($k in $jsons.Keys) {
    Write-File "$jutsuDir\$k.json" $jsons[$k]
}

# ============================================================
# PATCH TREE.JSON (19 new nodes)
# ============================================================
$tree = [System.IO.File]::ReadAllText($treeFile, $utf8)
if (-not $tree.Contains('"fire_flame_prison"')) {
    $newNodes = @'
,
{"id":"fire_prison_n","branch":"fire","distance":5,"type":"jutsu","jutsuId":"shinobicore:fire_flame_prison","spCost":8,"requires":["fire_expl"],"icon":"F","name":"Flame Prison","description":"Ring of fire DOT"},
{"id":"fire_scorch_n","branch":"fire","distance":5,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:fire_scorched_earth","spCost":9,"requires":["fire_expl"],"icon":"F","name":"Scorched Earth","description":"Burning ground zone"},
{"id":"fire_ash_n","branch":"fire","distance":4,"angleOffset":15,"type":"jutsu","jutsuId":"shinobicore:fire_ash_pile","spCost":7,"requires":["fire_ash"],"icon":"F","name":"Ash Pile Burn","description":"Blinding smoke AOE"},
{"id":"water_dragon_n","branch":"water","distance":5,"type":"jutsu","jutsuId":"shinobicore:water_dragon_bullet","spCost":10,"requires":["water_shark_n"],"icon":"W","name":"Water Dragon","description":"Massive water sphere"},
{"id":"water_rain_n","branch":"water","distance":5,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:water_rain_arrows","spCost":8,"requires":["water_prison_n"],"icon":"W","name":"Rain of Arrows","description":"Sky arrows"},
{"id":"water_mael_n","branch":"water","distance":5,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:water_maelstrom","spCost":8,"requires":["water_prison_n"],"icon":"W","name":"Maelstrom","description":"Pulls enemies"},
{"id":"wind_cage_n","branch":"wind","distance":5,"type":"jutsu","jutsuId":"shinobicore:wind_tornado_cage","spCost":7,"requires":["wind_vac_n"],"icon":"~","name":"Tornado Cage","description":"Trap in tornado"},
{"id":"wind_pressure_n","branch":"wind","distance":5,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:wind_pressure_damage","spCost":6,"requires":["wind_sickle_n"],"icon":"~","name":"Pressure Damage","description":"Top-down stun"},
{"id":"wind_divine_n","branch":"wind","distance":5,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:wind_divine_wind","spCost":7,"requires":["wind_vac_n"],"icon":"~","name":"Divine Wind","description":"Piercing blade"},
{"id":"light_cut_n","branch":"lightning","distance":5,"type":"jutsu","jutsuId":"shinobicore:lightning_thunder_cut","spCost":6,"requires":["light_beast_n"],"icon":"L","name":"Thunder Cut","description":"Melee x2.5"},
{"id":"light_depth_n","branch":"lightning","distance":5,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:lightning_depth_charge","spCost":8,"requires":["light_beast_n"],"icon":"L","name":"Depth Charge","description":"Dash + AOE"},
{"id":"light_chain_n","branch":"lightning","distance":5,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:lightning_chain","spCost":9,"requires":["light_armor_n"],"icon":"L","name":"Chain Lightning","description":"Jumping bolt"},
{"id":"earth_quake_n","branch":"earth","distance":5,"type":"jutsu","jutsuId":"shinobicore:earth_earthquake","spCost":9,"requires":["earth_golem_n"],"icon":"#","name":"Earthquake","description":"AOE knockdown"},
{"id":"earth_trap_n","branch":"earth","distance":5,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:earth_antlion_trap","spCost":7,"requires":["earth_spear_n"],"icon":"#","name":"Antlion Trap","description":"Sucking pit"},
{"id":"earth_sand_n","branch":"earth","distance":5,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:earth_sandwich","spCost":7,"requires":["earth_spear_n"],"icon":"#","name":"Sandwich","description":"Crushing walls"},
{"id":"kek_ice_n","branch":"kekkei","distance":3,"type":"jutsu","jutsuId":"shinobicore:kekkei_ice_mirror","spCost":12,"requires":["kg_ice"],"icon":"K","name":"Ice Mirror","description":"Teleport","visibilityCondition":{"type":"kekkei","key":"ice"}},
{"id":"kek_lava_n","branch":"kekkei","distance":3,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:kekkei_lava_golem","spCost":13,"requires":["kg_lava"],"icon":"K","name":"Lava Golem","description":"Summon magma cube","visibilityCondition":{"type":"kekkei","key":"lava"}},
{"id":"kek_blaze_n","branch":"kekkei","distance":3,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:kekkei_blaze_flame","spCost":12,"requires":["kg_blaze"],"icon":"K","name":"Blaze Flame","description":"Black fire projectile","visibilityCondition":{"type":"kekkei","key":"blaze"}},
{"id":"forb_edo_n","branch":"forbidden","distance":3,"type":"jutsu","jutsuId":"shinobicore:forbidden_edo_tensei","spCost":20,"requires":["forb_gates_node"],"icon":"!","name":"Edo Tensei","description":"Summon zombie horde"}
'@
    $tree = $tree.Replace('"description":"Long-range thrust"}', '"description":"Long-range thrust"}' + $newNodes)
    [System.IO.File]::WriteAllText($treeFile, $tree, $utf8)
    Write-Host "[OK] tree.json patched with 19 new nodes"
}

Write-Host "=== PHASE D ELEMENTS DONE ==="
Write-Host "Created 4 behaviors + 19 JSONs + 19 tree nodes"