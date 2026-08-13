$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# === 1. Create GenjutsuBehavior.java ===
$gbPath = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\GenjutsuBehavior.java"
if (Test-Path $gbPath) {
    Write-Host "[SKIP] GenjutsuBehavior.java already exists"
} else {
    $gbCode = @'
package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvent;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.List;

/**
 * Genjutsu behavior: applies debuff combos to a single target.
 * The target gets purple aura particles (GenjutsuAuraEffect detects these combos).
 *
 * Types:
 * - fear:      SLOWNESS III + NAUSEA + MINING_FATIGUE II
 * - blindness: BLINDNESS + WEAKNESS II + SLOWNESS II
 * - nightmare: BLINDNESS + NAUSEA + SLOWNESS III + WEAKNESS II (strongest)
 * - paralysis: SLOWNESS 255 + MINING_FATIGUE 255 (complete freeze)
 *
 * Resist chance based on target's genjutsu stat vs caster's genjutsu stat.
 */
public class GenjutsuBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        String genType = params.has("genjutsuType") ? params.get("genjutsuType").getAsString() : "fear";
        float range = params.has("range") ? params.get("range").getAsFloat() : 8.0f;
        int baseDuration = params.has("duration") ? params.get("duration").getAsInt() : 100;
        
        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;
        
        // Find target: closest living entity in line of sight within range
        LivingEntity target = findTarget(serverWorld, player, range);
        if (target == null) {
            player.sendMessage(Text.literal("\u00a7cNo target in range!"), false);
            return;
        }
        
        String targetName = target.getName().getString();
        
        // Resist check: compare genjutsu stats
        int casterGen = data.getStatLevel(StatType.GENJUTSU);
        int casterPerception = data.getStatLevel(StatType.PERCEPTION);
        int casterScore = casterGen * 2 + casterPerception;
        
        // Target resist: if target is a player, check their genjutsu stat
        int targetScore = 0;
        if (target instanceof ServerPlayerEntity targetPlayer) {
            NinjaPlayerData targetData = ((com.example.shinobicore.stat.NinjaDataHolder) targetPlayer).shinobicore_getData();
            int targetGen = targetData.getStatLevel(StatType.GENJUTSU);
            int targetPerception = targetData.getStatLevel(StatType.PERCEPTION);
            targetScore = targetGen * 2 + targetPerception;
        } else {
            // Mobs have fixed resist based on difficulty
            targetScore = 20; // base mob resist
        }
        
        // Resist chance: if targetScore > casterScore, chance to resist
        float resistChance = Math.max(0, (targetScore - casterScore) / 100.0f);
        
        // Cast sound
        SoundEvent genCastSound = SoundEvent.of(new Identifier("shinobicore", "genjutsu_cast"));
        serverWorld.playSound(null, player.getBlockPos(), genCastSound, SoundCategory.PLAYERS, 1.0f, 0.7f);
        
        // Visual: purple particles around target
        spawnGenjutsuCastEffect(serverWorld, target);
        
        if (serverWorld.getRandom().nextFloat() < resistChance) {
            // Target resisted
            SoundEvent resistSound = SoundEvent.of(new Identifier("shinobicore", "genjutsu_resist"));
            serverWorld.playSound(null, target.getBlockPos(), resistSound, SoundCategory.HOSTILE, 0.8f, 1.5f);
            player.sendMessage(Text.literal("\u00a7e" + targetName + " resisted the genjutsu!"), false);
            JutsuLogger.logBehavior("genjutsu", String.format(
                    "RESIST: player=%s, target=%s, type=%s, resistChance=%.0f%%",
                    player.getName().getString(), targetName, genType, resistChance * 100));
            return;
        }
        
        // Apply genjutsu effects based on type
        int duration = (int)(baseDuration * (1.0f + casterGen * 0.01f)); // +1% per genjutsu level
        
        switch (genType) {
            case "fear" -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, duration, 2, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.NAUSEA, duration, 0, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, duration, 1, false, false));
            }
            case "blindness" -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, duration, 0, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, duration, 1, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, duration, 1, false, false));
            }
            case "nightmare" -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, duration, 0, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.NAUSEA, duration, 0, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, duration, 2, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, duration, 1, false, false));
            }
            case "paralysis" -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, duration, 255, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, duration, 255, false, false));
            }
        }
        
        player.sendMessage(Text.literal("\u00a7aGenjutsu applied to " + targetName + "!"), false);
        JutsuLogger.logBehavior("genjutsu", String.format(
                "APPLIED: player=%s, target=%s, type=%s, duration=%d ticks, casterGen=%d",
                player.getName().getString(), targetName, genType, duration, casterGen));
    }
    
    private LivingEntity findTarget(ServerWorld world, ServerPlayerEntity caster, float range) {
        Vec3d eye = caster.getEyePos();
        Vec3d look = caster.getRotationVector().normalize();
        
        Box searchBox = caster.getBoundingBox().expand(range);
        List<LivingEntity> entities = world.getEntitiesByClass(LivingEntity.class, searchBox,
                e -> e != caster && e.isAlive());
        
        LivingEntity best = null;
        double bestDist = Double.MAX_VALUE;
        
        for (LivingEntity e : entities) {
            Vec3d toEntity = e.getPos().add(0, e.getHeight() * 0.5, 0).subtract(eye);
            double dist = toEntity.length();
            if (dist > range) continue;
            
            // Check if roughly in line of sight (within 30 degree cone)
            double dot = look.dotProduct(toEntity.normalize());
            if (dot < 0.85) continue; // ~30 degree cone
            
            if (dist < bestDist) {
                bestDist = dist;
                best = e;
            }
        }
        return best;
    }
    
    private void spawnGenjutsuCastEffect(ServerWorld world, LivingEntity target) {
        Vec3d pos = target.getPos().add(0, target.getHeight() * 0.5, 0);
        for (int i = 0; i < 20; i++) {
            double angle = (i / 20.0) * Math.PI * 2;
            double r = 0.8;
            world.spawnParticles(ParticleTypes.PORTAL,
                    pos.x + Math.cos(angle) * r,
                    pos.y + Math.random() * target.getHeight(),
                    pos.z + Math.sin(angle) * r,
                    1, 0, 0.05, 0, 0.03);
        }
        world.spawnParticles(ParticleTypes.WITCH,
                pos.x, pos.y + target.getHeight() * 0.8, pos.z,
                10, 0.4, 0.3, 0.4, 0.02);
    }
}
'@
    [System.IO.File]::WriteAllText($gbPath, $gbCode, $utf8)
    Write-Host "[FIX] Created GenjutsuBehavior.java"
}

# === 2. Register genjutsu behavior in ShinobiCore.java ===
$scPath = "E:\Games\mod\src\main\java\com\example\shinobicore\ShinobiCore.java"
$scContent = [System.IO.File]::ReadAllText($scPath, $utf8)
$sentinel2 = "PHASE_E_GENJUTSU_BEHAVIOR_REGISTERED"

if ($scContent.Contains($sentinel2)) {
    Write-Host "[SKIP] GenjutsuBehavior already registered"
} else {
    # Add import
    $importAnchor = "import com.example.shinobicore.jutsu.WallBehavior;"
    if ($scContent.Contains($importAnchor)) {
        $scContent = $scContent.Replace($importAnchor, $importAnchor + "`nimport com.example.shinobicore.jutsu.GenjutsuBehavior; // PHASE_E_GENJUTSU_BEHAVIOR_REGISTERED")
        Write-Host "[FIX] Added GenjutsuBehavior import"
    }
    
    # Add registration
    $regAnchor = 'BehaviorRegistry.register("utility", new UtilityBehavior());'
    if ($scContent.Contains($regAnchor)) {
        $scContent = $scContent.Replace($regAnchor, $regAnchor + "`n        BehaviorRegistry.register(`"genjutsu`", new GenjutsuBehavior());")
        Write-Host "[FIX] Registered genjutsu behavior"
    }
    
    [System.IO.File]::WriteAllText($scPath, $scContent, $utf8)
    Write-Host "[OK] ShinobiCore.java updated"
}

# === 3. Create genjutsu JSON files ===
$jutsuDir = "E:\Games\mod\src\main\resources\data\shinobicore\jutsu"

$jsonFiles = @{
    "genjutsu_fear.json" = @'
{
    "id": "shinobicore:genjutsu_fear",
    "name": "Genjutsu: Fear",
    "category": "genjutsu",
    "type": "genjutsu",
    "params": {
        "genjutsuType": "fear",
        "range": 8.0,
        "duration": 100
    },
    "baseCost": 20,
    "baseDamage": 0,
    "strain": 5,
    "requiredUsesForFullProficiency": 30,
    "requirements": {
        "control": 15,
        "genjutsu": 10
    }
}
'@
    "genjutsu_blindness.json" = @'
{
    "id": "shinobicore:genjutsu_blindness",
    "name": "Genjutsu: Darkness",
    "category": "genjutsu",
    "type": "genjutsu",
    "params": {
        "genjutsuType": "blindness",
        "range": 8.0,
        "duration": 100
    },
    "baseCost": 22,
    "baseDamage": 0,
    "strain": 6,
    "requiredUsesForFullProficiency": 35,
    "requirements": {
        "control": 18,
        "genjutsu": 15
    }
}
'@
    "genjutsu_nightmare.json" = @'
{
    "id": "shinobicore:genjutsu_nightmare",
    "name": "Genjutsu: Nightmare",
    "category": "genjutsu",
    "type": "genjutsu",
    "params": {
        "genjutsuType": "nightmare",
        "range": 6.0,
        "duration": 120
    },
    "baseCost": 35,
    "baseDamage": 0,
    "strain": 10,
    "requiredUsesForFullProficiency": 50,
    "requirements": {
        "control": 30,
        "genjutsu": 25
    }
}
'@
    "genjutsu_paralysis.json" = @'
{
    "id": "shinobicore:genjutsu_paralysis",
    "name": "Genjutsu: Paralysis",
    "category": "genjutsu",
    "type": "genjutsu",
    "params": {
        "genjutsuType": "paralysis",
        "range": 5.0,
        "duration": 60
    },
    "baseCost": 40,
    "baseDamage": 0,
    "strain": 12,
    "requiredUsesForFullProficiency": 60,
    "requirements": {
        "control": 35,
        "genjutsu": 30
    }
}
'@
}

foreach ($entry in $jsonFiles.GetEnumerator()) {
    $filePath = Join-Path $jutsuDir $entry.Key
    if (Test-Path $filePath) {
        Write-Host "[SKIP] $($entry.Key) already exists"
    } else {
        [System.IO.File]::WriteAllText($filePath, $entry.Value, $utf8)
        Write-Host "[FIX] Created $($entry.Key)"
    }
}

# === 4. Add genjutsu nodes to skill tree ===
$treePath = "E:\Games\mod\src\main\resources\data\shinobicore\skill_tree\tree.json"
$treeContent = [System.IO.File]::ReadAllText($treePath, $utf8)
$sentinel4 = "PHASE_E_GENJUTSU_NODES"

if ($treeContent.Contains($sentinel4)) {
    Write-Host "[SKIP] Genjutsu nodes already in tree"
} else {
    # Add genjutsu branch if not exists
    if (-not $treeContent.Contains('"genjutsu"')) {
        $branchInsert = '"sensory":   {"angle": 0,   "color": "#66DDFF", "label": "Sensory"},'
        $branchNew = $branchInsert + "`n`"genjutsu`":  {`"angle`": 0,   `"color`": `"#AA44FF`", `"label`": `"Genjutsu`"},"
        $treeContent = $treeContent.Replace($branchInsert, $branchNew)
        Write-Host "[FIX] Added genjutsu branch to tree"
    }
    
    # Add nodes before the closing ]
    $genNodes = @'
,
{"id":"gen_fear","branch":"genjutsu","distance":1,"type":"jutsu","jutsuId":"shinobicore:genjutsu_fear","spCost":3,"requires":[],"icon":"?","name":"Genjutsu: Fear","description":"Slowness + Nausea + Mining Fatigue"},
{"id":"gen_blind","branch":"genjutsu","distance":2,"type":"jutsu","jutsuId":"shinobicore:genjutsu_blindness","spCost":4,"requires":["gen_fear"],"icon":"?","name":"Genjutsu: Darkness","description":"Blindness + Weakness + Slowness"},
{"id":"gen_nightmare","branch":"genjutsu","distance":3,"type":"jutsu","jutsuId":"shinobicore:genjutsu_nightmare","spCost":6,"requires":["gen_blind"],"icon":"?","name":"Genjutsu: Nightmare","description":"All debuffs combined"},
{"id":"gen_paralysis","branch":"genjutsu","distance":3,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:genjutsu_paralysis","spCost":7,"requires":["gen_blind"],"icon":"?","name":"Genjutsu: Paralysis","description":"Complete freeze","visibilityCondition":{"type":"stat_level","key":"genjutsu","value":25}}
'@
    
    # Insert before the last ]
    $lastBracket = $treeContent.LastIndexOf(']')
    if ($lastBracket -ge 0) {
        $treeContent = $treeContent.Substring(0, $lastBracket) + $genNodes + "`n]`n// " + $sentinel4
        [System.IO.File]::WriteAllText($treePath, $treeContent, $utf8)
        Write-Host "[FIX] Added genjutsu nodes to skill tree"
    }
}

Write-Host ""
Write-Host "=== PHASE E STEP 4 (GENJUTSU FULL) APPLIED ==="
Write-Host "Run: .\gradlew.bat build"