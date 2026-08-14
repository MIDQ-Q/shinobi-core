$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$jutsuDir = "$base\resources\data\shinobicore\jutsu"
$behDir = "$base\java\com\example\shinobicore\jutsu\custom"
$treeFile = "$base\resources\data\shinobicore\skill_tree\tree.json"
$taichiPath = "$base\java\com\example\shinobicore\client\combat\TaichiComboVariants.java"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============================================================
# TAIJUTSU: procedural animations system (client-side mixin)
# ============================================================
if (Test-Path $taichiPath) { Write-Host "[SKIP] TaichiComboVariants exists" } else {
Write-File $taichiPath @'
package com.example.shinobicore.client.combat;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.util.math.MathHelper;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

/**
 * Procedural taijutsu combo variants.
 * Each LMB attack picks a random style from 4 variants:
 *   0: Leaf Hurricane (360 spin + kick up)
 *   1: Leaf Rising Wind (shoryuken uppercut)
 *   2: Dynamic Action (3-fast-punches + kick)
 *   3: Front Lotus (air combo starter)
 */
public class TaichiComboVariants {
    private static final Map<UUID, Integer> VARIANTS = new HashMap<>();
    private static final Map<UUID, Long> LAST_ATTACK = new HashMap<>();
    private static final Random RNG = new Random();

    public static int rollVariant(AbstractClientPlayerEntity p) {
        long now = System.currentTimeMillis();
        long last = LAST_ATTACK.getOrDefault(p.getUuid(), 0L);
        if (now - last < 3000) {
            return VARIANTS.getOrDefault(p.getUuid(), 0);
        }
        int v = RNG.nextInt(4);
        VARIANTS.put(p.getUuid(), v);
        LAST_ATTACK.put(p.getUuid(), now);
        return v;
    }

    public static void apply(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm,
                             ModelPart rLeg, ModelPart lLeg, ModelPart body, ModelPart head) {
        Integer v = VARIANTS.get(p.getUuid());
        if (v == null) return;
        Long last = LAST_ATTACK.get(p.getUuid());
        if (last == null) return;
        long elapsed = System.currentTimeMillis() - last;
        if (elapsed > 450) return;
        float pr = elapsed / 450f;
        float c = (float) Math.sin(pr * Math.PI);
        switch (v) {
            case 0 -> applyHurricane(rArm, lArm, rLeg, lLeg, body, head, c);
            case 1 -> applyRisingWind(rArm, lArm, rLeg, body, c);
            case 2 -> applyDynamicAction(rArm, lArm, rLeg, body, head, pr);
            case 3 -> applyFrontLotus(rArm, lArm, rLeg, lLeg, body, c);
        }
    }

    private static void applyHurricane(ModelPart rArm, ModelPart lArm, ModelPart rLeg, ModelPart lLeg,
                                        ModelPart body, ModelPart head, float c) {
        body.yaw += c * 6.28f;
        rLeg.pitch = -1.2f * c;
        rLeg.yaw = 0.6f * c;
        lLeg.pitch = 0.3f * c;
        rArm.pitch = 0.8f * c;
        lArm.pitch = 0.8f * c;
        rArm.yaw = -1.2f * c;
        lArm.yaw = 1.2f * c;
    }

    private static void applyRisingWind(ModelPart rArm, ModelPart lArm, ModelPart rLeg,
                                         ModelPart body, float c) {
        rArm.pitch = -2.8f * c;
        rArm.yaw = -0.3f * c;
        lArm.pitch = 0.5f * c;
        rLeg.pitch = -0.3f * c;
        body.pitch = -0.4f * c;
    }

    private static void applyDynamicAction(ModelPart rArm, ModelPart lArm, ModelPart rLeg,
                                            ModelPart body, ModelPart head, float pr) {
        if (pr < 0.7f) {
            float punch = MathHelper.sin(pr * 18f);
            rArm.pitch = -1.5f + punch * 0.3f;
            lArm.pitch = -1.5f - punch * 0.3f;
            rArm.yaw = -0.2f;
            lArm.yaw = 0.2f;
        } else {
            float kick = MathHelper.sin((pr - 0.7f) / 0.3f * (float) Math.PI);
            rLeg.pitch = -1.8f * kick;
            rLeg.yaw = -0.2f * kick;
            body.pitch = 0.3f * kick;
        }
    }

    private static void applyFrontLotus(ModelPart rArm, ModelPart lArm, ModelPart rLeg, ModelPart lLeg,
                                         ModelPart body, float c) {
        rArm.pitch = -1.4f * c;
        lArm.pitch = -1.4f * c;
        rArm.yaw = -0.5f * c;
        lArm.yaw = 0.5f * c;
        rLeg.pitch = 0.6f * c;
        lLeg.pitch = 0.6f * c;
        body.pitch = -0.2f * c;
        body.yaw += c * 1.5f;
    }

    public static boolean isActive(AbstractClientPlayerEntity p) {
        Long last = LAST_ATTACK.get(p.getUuid());
        if (last == null) return false;
        return System.currentTimeMillis() - last < 450;
    }
}
'@
}

# ============================================================
# BEHAVIOR 1: CounterStanceBehavior
# ============================================================
Write-File "$behDir\CounterStanceBehavior.java" @'
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
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Vec3d;

public class CounterStanceBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float window = params.has("window") ? params.get("window").getAsFloat() : 1.5f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 3.5f;
        float multiplier = params.has("multiplier") ? params.get("multiplier").getAsFloat() : 2.5f;
        int ticks = (int)(window * 20);
        player.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
            net.minecraft.entity.effect.StatusEffects.RESISTANCE, ticks, 2, false, false));
        player.playSound(SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, 0.8f, 1.2f, SoundCategory.PLAYERS);
        Vec3d c = player.getPos().add(0, 1, 0);
        for (int i = 0; i < 25; i++) {
            double a = (i / 25.0) * Math.PI * 2;
            world.spawnParticles(ParticleTypes.CRIT,
                c.x + Math.cos(a) * 0.8, c.y, c.z + Math.sin(a) * 0.8,
                1, 0, 0.05, 0, 0.02);
        }
        int counterHits = 0;
        for (int t = 0; t < ticks; t += 2) {
            final int tt = t;
            world.getServer().execute(() -> {
                for (Entity e : world.getOtherEntities(player,
                        new net.minecraft.util.math.Box(c, c).expand(radius))) {
                    if (e instanceof LivingEntity liv && !liv.equals(player)) {
                        if (liv.hurtTime > 0 && tt % 4 == 0) {
                            liv.damage(player.getDamageSources().magic(), damage * multiplier);
                            Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(1.2);
                            liv.addVelocity(kb.x, 0.4, kb.z);
                            liv.velocityModified = true;
                            world.spawnParticles(ParticleTypes.ENCHANT,
                                liv.getX(), liv.getY() + 1, liv.getZ(),
                                10, 0.3, 0.3, 0.3, 0.05);
                        }
                    }
                }
            });
            try { Thread.sleep(100); } catch (Exception ignored) {}
        }
        JutsuLogger.logBehavior("counter_stance", "window=" + window + " mult=" + multiplier);
    }
}
'@

# ============================================================
# BEHAVIOR 2: HeavenlyStrikeBehavior (jump + downward AOE)
# ============================================================
Write-File "$behDir\HeavenlyStrikeBehavior.java" @'
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

public class HeavenlyStrikeBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float jumpHeight = params.has("jumpHeight") ? params.get("jumpHeight").getAsFloat() : 1.8f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
        float knockdown = params.has("knockdown") ? params.get("knockdown").getAsFloat() : 0.6f;
        Vec3d jumpVec = new Vec3d(0, jumpHeight, 0).add(player.getRotationVector().multiply(0.3));
        player.addVelocity(jumpVec.x, jumpVec.y, jumpVec.z);
        player.velocityModified = true;
        world.getServer().execute(() -> {
            try { Thread.sleep(600); } catch (Exception ignored) {}
            world.getServer().execute(() -> {
                Vec3d center = player.getPos();
                for (Entity e : world.getOtherEntities(player,
                        new net.minecraft.util.math.Box(center, center).expand(radius))) {
                    if (e instanceof LivingEntity liv && !liv.equals(player)) {
                        liv.damage(player.getDamageSources().magic(), damage);
                        Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(knockdown);
                        liv.addVelocity(kb.x, -0.3, kb.z);
                        liv.velocityModified = true;
                    }
                }
                for (int i = 0; i < 40; i++) {
                    double a = (i / 40.0) * Math.PI * 2;
                    world.spawnParticles(ParticleTypes.CRIT,
                        center.x + Math.cos(a) * radius, center.y, center.z + Math.sin(a) * radius,
                        2, 0, 0.15, 0, 0.05);
                }
            });
        });
        JutsuLogger.logBehavior("heavenly_strike", "jump=" + jumpHeight + " radius=" + radius);
    }
}
'@

# ============================================================
# BEHAVIOR 3: SubstitutionBehavior (on-hit teleport)
# ============================================================
Write-File "$behDir\SubstitutionBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

public class SubstitutionBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float teleportDistance = params.has("distance") ? params.get("distance").getAsFloat() : 6f;
        int invisDuration = params.has("invisDuration") ? params.get("invisDuration").getAsInt() : 40;
        Vec3d oldPos = player.getPos();
        Vec3d dir = player.getRotationVector().multiply(-1).normalize();
        Vec3d newPos = oldPos.add(dir.multiply(teleportDistance));
        for (int i = 0; i < 20; i++) {
            world.spawnParticles(ParticleTypes.SMOKE,
                oldPos.x + (Math.random() - 0.5) * 1.5,
                oldPos.y + Math.random() * 1.8,
                oldPos.z + (Math.random() - 0.5) * 1.5,
                1, 0.1, 0.1, 0.1, 0.03);
        }
        BlockPos logPos = BlockPos.ofFloored(oldPos);
        if (world.getBlockState(logPos).isAir()) {
            world.setBlockState(logPos, Blocks.OAK_LOG.getDefaultState(), 3);
            com.example.shinobicore.jutsu.WallRemovalTask.schedule(world,
                java.util.List.of(logPos), 60);
        }
        player.teleport(newPos.x, newPos.y, newPos.z);
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.INVISIBILITY, invisDuration, 0, false, false));
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.SPEED, invisDuration, 1, false, false));
        JutsuLogger.logBehavior("substitution", "dist=" + teleportDistance);
    }
}
'@

# ============================================================
# BEHAVIOR 4: PhantomFlightBehavior (summon phantom + levitate)
# ============================================================
Write-File "$behDir\PhantomFlightBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.entity.mob.PhantomEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class PhantomFlightBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 400;
        PhantomEntity phantom = EntityType.PHANTOM.create(world);
        if (phantom == null) return;
        Vec3d spawn = player.getPos().add(0, 3, 0);
        phantom.setPosition(spawn.x, spawn.y, spawn.z);
        phantom.setAiDisabled(false);
        world.spawnEntity(phantom);
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.LEVITATION, duration, 1, false, false));
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOW_FALLING, duration + 60, 0, false, false));
        JutsuLogger.logBehavior("phantom_flight", "dur=" + duration);
    }
}
'@

# ============================================================
# JSON TECHNIQUES (15)
# ============================================================
$jsons = @{}

# Kenjutsu+ (2)
$jsons["ken_counter"] = @'
{"id":"shinobicore:ken_counter","name":"Kenjutsu: Counter Stance","category":"taijutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.CounterStanceBehavior","params":{"window":1.5,"radius":3.5,"multiplier":2.5},"baseCost":32,"baseDamage":10,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"taijutsu":30,"control":22}}
'@
$jsons["ken_heavenly"] = @'
{"id":"shinobicore:ken_heavenly","name":"Kenjutsu: Heavenly Strike","category":"taijutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.HeavenlyStrikeBehavior","params":{"jumpHeight":1.8,"radius":4,"knockdown":1.2},"baseCost":35,"baseDamage":14,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"taijutsu":32,"control":24}}
'@

# Shuriken+ (4)
$jsons["shu_homing"] = @'
{"id":"shinobicore:shu_homing","name":"Shuriken: Homing Kunai","category":"shape_ninjutsu","type":"projectile","params":{"speed":1.8,"radius":1,"particle":"crit","lifetime":80,"homing":true},"baseCost":24,"baseDamage":6,"strain":6,"requiredUsesForFullProficiency":40,"requirements":{"control":22,"perception":25}}
'@
$jsons["shu_triple"] = @'
{"id":"shinobicore:shu_triple","name":"Shuriken: Triple Throw","category":"shape_ninjutsu","type":"projectile","params":{"speed":2.2,"radius":0.8,"particle":"crit","lifetime":60,"count":3},"baseCost":22,"baseDamage":4,"strain":5,"requiredUsesForFullProficiency":35,"requirements":{"control":20,"perception":18}}
'@
$jsons["shu_flash"] = @'
{"id":"shinobicore:shu_flash","name":"Tool: Flash Bomb","category":"shape_ninjutsu","type":"aoe","params":{"radius":6,"particle":"flash","particleCount":80,"statusEffect":"blindness","statusDuration":60},"baseCost":20,"baseDamage":0,"strain":5,"requiredUsesForFullProficiency":30,"requirements":{"control":18,"perception":16}}
'@
$jsons["shu_senbon"] = @'
{"id":"shinobicore:shu_senbon","name":"Tool: Poison Senbon","category":"shape_ninjutsu","type":"projectile","params":{"speed":2.8,"radius":0.5,"particle":"smoke","lifetime":50,"statusEffect":"poison","statusDuration":120},"baseCost":22,"baseDamage":3,"strain":5,"requiredUsesForFullProficiency":35,"requirements":{"control":20,"medical":15}}
'@

# Summoning Contracts (4)
$jsons["sum_wolf_contract"] = @'
{"id":"shinobicore:sum_wolf_contract","name":"Contract: Wolf Pack","category":"shape_ninjutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.SummonBehavior","params":{"entity":"minecraft:wolf","count":3},"baseCost":45,"baseDamage":0,"strain":11,"requiredUsesForFullProficiency":50,"requirements":{"control":25,"ninjutsu":25,"perception":20}}
'@
$jsons["sum_golem_contract"] = @'
{"id":"shinobicore:sum_golem_contract","name":"Contract: Iron Fortress","category":"shape_ninjutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"resistance","amplifier":2,"duration":400},"baseCost":55,"baseDamage":0,"strain":14,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"ninjutsu":30}}
'@
$jsons["sum_phantom_contract"] = @'
{"id":"shinobicore:sum_phantom_contract","name":"Contract: Phantom Flight","category":"shape_ninjutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.PhantomFlightBehavior","params":{"duration":400},"baseCost":60,"baseDamage":0,"strain":15,"requiredUsesForFullProficiency":65,"requirements":{"control":30,"ninjutsu":32}}
'@
$jsons["sum_skeleton_contract"] = @'
{"id":"shinobicore:sum_skeleton_contract","name":"Contract: Arrow Barrage","category":"shape_ninjutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ArrowRainBehavior","params":{"count":24,"area":8,"arrowDamage":5},"baseCost":55,"baseDamage":0,"strain":13,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"perception":25}}
'@

# General Ninjutsu (5)
$jsons["gen_shunshin_plus"] = @'
{"id":"shinobicore:gen_shunshin_plus","name":"Body Flicker (Improved)","category":"shape_ninjutsu","type":"dash","params":{"distance":20,"knockback":0.5,"hitRadius":1,"particle":"smoke","particleCount":30},"baseCost":28,"baseDamage":4,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"control":22,"ninjutsu":20}}
'@
$jsons["gen_substitution"] = @'
{"id":"shinobicore:gen_substitution","name":"Substitution Jutsu","category":"shape_ninjutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.SubstitutionBehavior","params":{"distance":6,"invisDuration":40},"baseCost":30,"baseDamage":0,"strain":8,"requiredUsesForFullProficiency":40,"requirements":{"control":22,"ninjutsu":22}}
'@
$jsons["gen_paper_trap"] = @'
{"id":"shinobicore:gen_paper_trap","name":"Tool: Paper Bomb Trap","category":"shape_ninjutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ZoneBehavior","params":{"range":6,"radius":3,"duration":100,"tickDamage":6,"tickInterval":40,"burn":true},"baseCost":28,"baseDamage":0,"strain":7,"requiredUsesForFullProficiency":35,"requirements":{"control":20,"ninjutsu":18}}
'@
$jsons["gen_chakra_blade"] = @'
{"id":"shinobicore:gen_chakra_blade","name":"Chakra Blade","category":"taijutsu","type":"melee","params":{"range":4,"coneAngle":100,"knockback":0.8,"particle":"enchant"},"baseCost":22,"baseDamage":10,"strain":6,"requiredUsesForFullProficiency":35,"requirements":{"taijutsu":25,"control":18}}
'@
$jsons["gen_heal_plus"] = @'
{"id":"shinobicore:gen_heal_plus","name":"Medical: Greater Healing","category":"medical","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"regeneration","amplifier":3,"duration":300},"baseCost":45,"baseDamage":0,"strain":11,"requiredUsesForFullProficiency":50,"requirements":{"control":26,"medical":32}}
'@

foreach ($k in $jsons.Keys) {
    Write-File "$jutsuDir\$k.json" $jsons[$k]
}

# ============================================================
# PATCH: tree.json (15 new nodes)
# ============================================================
$tree = [System.IO.File]::ReadAllText($treeFile, $utf8)
if (-not $tree.Contains('"ken_counter"')) {
    $newNodes = @'
,
{"id":"ken_counter_n","branch":"kenjutsu","distance":3,"type":"jutsu","jutsuId":"shinobicore:ken_counter","spCost":8,"requires":["ken_wind"],"icon":"/","name":"Counter Stance","description":"Parry and counter"},
{"id":"ken_heavenly_n","branch":"kenjutsu","distance":3,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:ken_heavenly","spCost":9,"requires":["ken_wind"],"icon":"/","name":"Heavenly Strike","description":"Jump + AOE slam"},
{"id":"shu_homing_n","branch":"shuriken","distance":5,"type":"jutsu","jutsuId":"shinobicore:shu_homing","spCost":6,"requires":["shu_boom"],"icon":"x","name":"Homing Kunai","description":"Auto-targets enemies"},
{"id":"shu_triple_n","branch":"shuriken","distance":5,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:shu_triple","spCost":5,"requires":["shu_boom"],"icon":"x","name":"Triple Throw","description":"3 kunai spread"},
{"id":"shu_flash_n","branch":"shuriken","distance":5,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:shu_flash","spCost":5,"requires":["shu_tag"],"icon":"x","name":"Flash Bomb","description":"AOE blindness"},
{"id":"shu_senbon_n","branch":"shuriken","distance":5,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:shu_senbon","spCost":5,"requires":["shu_tag"],"icon":"x","name":"Poison Senbon","description":"Poison needle"},
{"id":"sum_wolf_c","branch":"summon","distance":3,"type":"jutsu","jutsuId":"shinobicore:sum_wolf_contract","spCost":10,"requires":["sum_golem"],"icon":"P","name":"Wolf Pack Contract","description":"3 wolves"},
{"id":"sum_golem_c","branch":"summon","distance":3,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:sum_golem_contract","spCost":11,"requires":["sum_golem"],"icon":"P","name":"Iron Fortress","description":"Resistance III"},
{"id":"sum_phantom_c","branch":"summon","distance":3,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:sum_phantom_contract","spCost":13,"requires":["sum_arrow"],"icon":"P","name":"Phantom Flight","description":"Levitate + slow fall"},
{"id":"sum_skeleton_c","branch":"summon","distance":3,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:sum_skeleton_contract","spCost":11,"requires":["sum_arrow"],"icon":"P","name":"Arrow Barrage","description":"24 arrows from sky"},
{"id":"gen_shunshin_p","branch":"general","distance":4,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:gen_shunshin_plus","spCost":6,"requires":["tool_hide"],"icon":"o","name":"Body Flicker+","description":"20-block dash"},
{"id":"gen_sub_n","branch":"general","distance":4,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:gen_substitution","spCost":6,"requires":["tool_hide"],"icon":"o","name":"Substitution","description":"Teleport + invis"},
{"id":"gen_paper_n","branch":"general","distance":4,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:gen_paper_trap","spCost":6,"requires":["tool_smoke"],"icon":"o","name":"Paper Bomb Trap","description":"DOT explosive zone"},
{"id":"gen_blade_n","branch":"taijutsu","distance":3,"type":"jutsu","jutsuId":"shinobicore:gen_chakra_blade","spCost":5,"requires":["tai_swallow"],"icon":"T","name":"Chakra Blade","description":"Sharp melee wave"},
{"id":"gen_heal_p","branch":"medical","distance":4,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:gen_heal_plus","spCost":10,"requires":["med_resus"],"icon":"+","name":"Greater Healing","description":"Regen III 15s"}
'@
    $tree = $tree.Replace('"description":"Open the Gates"}', '"description":"Open the Gates"}' + $newNodes)
    [System.IO.File]::WriteAllText($treeFile, $tree, $utf8)
    Write-Host "[OK] tree.json patched with 15 new nodes"
}

# ============================================================
# PATCH: PlayerRenderAnimationMixin (hook taichi variants)
# ============================================================
$mx = "$root\mixin\PlayerRenderAnimationMixin.java"
$mx = "E:\Games\mod\src\main\java\com\example\shinobicore\mixin\PlayerRenderAnimationMixin.java"
$mxC = [System.IO.File]::ReadAllText($mx, $utf8)
if (-not $mxC.Contains("TaichiComboVariants.isActive")) {
    $hook = "        // === PHASE E: TAIJUTSU VARIANTS ===`n" +
            "        if (com.example.shinobicore.client.combat.TaichiComboVariants.isActive(player)) {`n" +
            "            com.example.shinobicore.client.combat.TaichiComboVariants.apply(player, rightArm, leftArm, rightLeg, leftLeg, body, head);`n" +
            "            return;`n" +
            "        }`n" +
            "        if (TaijutsuAnimations.isKicking(player)) {"
    $mxC = $mxC.Replace("        if (TaijutsuAnimations.isKicking(player)) {", $hook)
    [System.IO.File]::WriteAllText($mx, $mxC, $utf8)
    Write-Host "[OK] PlayerRenderAnimationMixin: taichi variants hooked"
}

Write-Host "=== PHASE E DONE ==="
Write-Host "Created: 1 client taichi system + 4 behaviors + 15 JSONs + 15 tree nodes"