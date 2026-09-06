# ============================================================
# SHINOBICORE SPRINT 7: Advanced AI Core (Utility AI + 4 Tiers)
# ============================================================
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $fullPath = Join-Path $root $Path
    $dir = Split-Path $fullPath -Parent
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
    Write-Host "[OK] $Path" -ForegroundColor Green
}

function Patch-File {
    param([string]$Path, [string]$Old, [string]$New, [string]$Desc)
    $fullPath = Join-Path $root $Path
    if (!(Test-Path $fullPath)) { Write-Host "[FAIL] File not found: $Path" -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($fullPath, $utf8NoBom)
    if ($c.Contains($New)) { Write-Host "[SKIP] Already applied: $Desc" -ForegroundColor Yellow; return $true }
    if (!$c.Contains($Old)) { Write-Host "[FAIL] Pattern not found for: $Desc" -ForegroundColor Red; return $false }
    $c = $c.Replace($Old, $New)
    [System.IO.File]::WriteAllText($fullPath, $c, $utf8NoBom)
    Write-Host "[PATCHED] $Desc" -ForegroundColor Green
    return $true
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 7: Advanced AI Core (Utility AI + 4 Tiers)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# ============================================================
# 1. AI TIER DEFINITIONS (JSON)
# ============================================================
Write-Host "`n[1/8] Creating AI Tier JSON configs..." -ForegroundColor Yellow
$tierDir = "src\main\resources\data\shinobicore\ai_tiers"

Write-Utf8NoBom "$tierDir\genin.json" @'
{
  "id": "genin",
  "displayName": "Genin",
  "healthMultiplier": 1.0,
  "speedMultiplier": 1.0,
  "damageMultiplier": 1.0,
  "thresholds": { "retreatHealthPercent": 0.1, "coverHealthPercent": 0.0 },
  "canUseEnvironment": false,
  "canInterruptCasts": false
}
'@

Write-Utf8NoBom "$tierDir\chunin.json" @'
{
  "id": "chunin",
  "displayName": "Chunin",
  "healthMultiplier": 1.5,
  "speedMultiplier": 1.1,
  "damageMultiplier": 1.3,
  "thresholds": { "retreatHealthPercent": 0.15, "coverHealthPercent": 0.0 },
  "canUseEnvironment": false,
  "canInterruptCasts": false
}
'@

Write-Utf8NoBom "$tierDir\jonin.json" @'
{
  "id": "jonin",
  "displayName": "Jonin",
  "healthMultiplier": 2.0,
  "speedMultiplier": 1.2,
  "damageMultiplier": 1.6,
  "thresholds": { "retreatHealthPercent": 0.2, "coverHealthPercent": 0.4 },
  "canUseEnvironment": true,
  "canInterruptCasts": true
}
'@

Write-Utf8NoBom "$tierDir\anbu.json" @'
{
  "id": "anbu",
  "displayName": "ANBU",
  "healthMultiplier": 2.5,
  "speedMultiplier": 1.3,
  "damageMultiplier": 2.0,
  "thresholds": { "retreatHealthPercent": 0.25, "coverHealthPercent": 0.5 },
  "canUseEnvironment": true,
  "canInterruptCasts": true
}
'@

# ============================================================
# 2. AI TIER REGISTRY & DEFINITION
# ============================================================
Write-Host "`n[2/8] Creating AiTierRegistry and AiTierDefinition..." -ForegroundColor Yellow
$aiV2Dir = "src\main\java\com\example\shinobicore\ai\v2"

Write-Utf8NoBom "$aiV2Dir\AiTierDefinition.java" @'
package com.example.shinobicore.ai.v2;

import java.util.Map;

public class AiTierDefinition {
    public String id;
    public String displayName;
    public float healthMultiplier;
    public float speedMultiplier;
    public float damageMultiplier;
    public Map<String, Float> thresholds;
    public boolean canUseEnvironment;
    public boolean canInterruptCasts;
}
'@

Write-Utf8NoBom "$aiV2Dir\AiTierRegistry.java" @'
package com.example.shinobicore.ai.v2;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class AiTierRegistry {
    private static final Map<String, AiTierDefinition> TIERS = new HashMap<>();

    public static void reload(ResourceManager manager) {
        TIERS.clear();
        Map<Identifier, List<Resource>> resources = manager.findAllResources("ai_tiers", 
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json"));
        
        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            try (InputStream stream = entry.getValue().get(0).getInputStream()) {
                JsonObject json = JsonParser.parseReader(new InputStreamReader(stream)).getAsJsonObject();
                AiTierDefinition def = new AiTierDefinition();
                def.id = json.get("id").getAsString();
                def.displayName = json.get("displayName").getAsString();
                def.healthMultiplier = json.get("healthMultiplier").getAsFloat();
                def.speedMultiplier = json.get("speedMultiplier").getAsFloat();
                def.damageMultiplier = json.get("damageMultiplier").getAsFloat();
                def.canUseEnvironment = json.get("canUseEnvironment").getAsBoolean();
                def.canInterruptCasts = json.get("canInterruptCasts").getAsBoolean();
                
                Map<String, Float> thresholds = new HashMap<>();
                JsonObject thJson = json.getAsJsonObject("thresholds");
                for (String key : thJson.keySet()) {
                    thresholds.put(key, thJson.get(key).getAsFloat());
                }
                def.thresholds = thresholds;
                
                TIERS.put(def.id, def);
                ShinobiCore.LOGGER.info("Loaded AI tier: {}", def.id);
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("Failed to load AI tier", e);
            }
        }
    }

    public static AiTierDefinition get(String id) { return TIERS.get(id); }
}
'@

# ============================================================
# 3. ENVIRONMENT SCANNER & REACTION SYSTEM
# ============================================================
Write-Host "`n[3/8] Creating AiEnvironmentScanner and AiReactionSystem..." -ForegroundColor Yellow

Write-Utf8NoBom "$aiV2Dir\AiEnvironmentScanner.java" @'
package com.example.shinobicore.ai.v2;

import net.minecraft.entity.mob.MobEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;

public class AiEnvironmentScanner {
    
    public static Vec3d findCover(ServerWorld world, MobEntity entity, ServerPlayerEntity target) {
        Vec3d entityPos = entity.getPos();
        Vec3d targetPos = target.getPos();
        
        for (int i = 0; i < 8; i++) {
            double angle = i * Math.PI / 4;
            double dist = 5.0;
            Vec3d checkPos = entityPos.add(Math.cos(angle) * dist, 0, Math.sin(angle) * dist);
            
            if (hasLineOfSight(world, entity, checkPos.add(0, 1, 0), targetPos.add(0, 1, 0))) {
                continue; 
            }
            
            BlockPos blockPos = BlockPos.ofFloored(checkPos);
            if (world.getBlockState(blockPos).isSolidBlock(world, blockPos) || 
                world.getBlockState(blockPos.up()).isSolidBlock(world, blockPos.up())) {
                return checkPos;
            }
        }
        return null;
    }

    public static boolean hasLineOfSight(ServerWorld world, MobEntity entity, Vec3d from, Vec3d to) {
        RaycastContext context = new RaycastContext(from, to, 
            RaycastContext.ShapeType.COLLIDER, RaycastContext.FluidHandling.NONE, entity);
        return world.raycast(context).getType() == net.minecraft.util.hit.HitResult.Type.MISS;
    }
}
'@

Write-Utf8NoBom "$aiV2Dir\AiReactionSystem.java" @'
package com.example.shinobicore.ai.v2;

import net.minecraft.server.network.ServerPlayerEntity;

public class AiReactionSystem {
    public static boolean isPlayerCasting(ServerPlayerEntity player) {
        return com.example.shinobicore.combat.CastingServerState.isCasting(player);
    }
    
    public static boolean isPlayerBlocking(ServerPlayerEntity player) {
        // Placeholder for block detection
        return false; 
    }
}
'@

# ============================================================
# 4. AI BRAIN V2 (UTILITY AI CORE)
# ============================================================
Write-Host "`n[4/8] Creating AiBrainV2 (Utility AI Core)..." -ForegroundColor Yellow

Write-Utf8NoBom "$aiV2Dir\AiBrainV2.java" @'
package com.example.shinobicore.ai.v2;

import com.example.shinobicore.jutsu.executor.Fx;
import com.example.shinobicore.jutsu.enums.ElementType;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class AiBrainV2 {
    public final MobEntity entity;
    public ServerPlayerEntity target;
    public final AiTierDefinition tier;
    
    public enum State { IDLE, APPROACH, ENGAGE_MELEE, ENGAGE_RANGED, RETREAT, SEEK_COVER }
    public State currentState = State.IDLE;
    
    public int stateTicks = 0;
    public int actionCooldown = 0;
    
    public AiBrainV2(MobEntity entity, AiTierDefinition tier) {
        this.entity = entity;
        this.tier = tier;
    }
    
    public void tick(ServerWorld world) {
        if (entity.isDead() || !entity.isAlive()) return;
        
        stateTicks++;
        if (actionCooldown > 0) actionCooldown--;
        
        if (target == null || !target.isAlive() || target.isDead()) {
            target = findTarget(world);
            if (target == null) { currentState = State.IDLE; return; }
        }
        
        double dist = entity.getPos().distanceTo(target.getPos());
        evaluateAndAct(world, dist);
    }
    
    private ServerPlayerEntity findTarget(ServerWorld world) {
        ServerPlayerEntity best = null;
        double bd = 24.0;
        for (ServerPlayerEntity p : world.getPlayers()) {
            if (p.isAlive() && !p.isSpectator()) {
                double d = p.getPos().distanceTo(entity.getPos());
                if (d < bd) { bd = d; best = p; }
            }
        }
        return best;
    }
    
    private void evaluateAndAct(ServerWorld world, double dist) {
        float hpPercent = entity.getHealth() / entity.getMaxHealth();
        
        if (hpPercent < tier.thresholds.getOrDefault("retreatHealthPercent", 0.1f)) {
            currentState = State.RETREAT;
        } else if (tier.canUseEnvironment && hpPercent < tier.thresholds.getOrDefault("coverHealthPercent", 0.4f)) {
            currentState = State.SEEK_COVER;
        }
        
        switch (currentState) {
            case IDLE:
            case APPROACH:
                if (dist > 2.5) {
                    moveTowards(target.getPos(), 1.0);
                    currentState = State.APPROACH;
                } else {
                    currentState = State.ENGAGE_MELEE;
                }
                break;
                
            case ENGAGE_MELEE:
                if (dist > 3.5) { currentState = State.APPROACH; } 
                else if (actionCooldown <= 0) {
                    performMeleeAttack();
                    actionCooldown = 20;
                }
                break;
                
            case ENGAGE_RANGED:
                if (dist < 4.0 || dist > 16.0) { currentState = State.APPROACH; } 
                else if (actionCooldown <= 0) {
                    performRangedAttack(world);
                    actionCooldown = 40;
                }
                break;
                
            case RETREAT:
                Vec3d away = entity.getPos().subtract(target.getPos()).normalize().multiply(5);
                moveTowards(entity.getPos().add(away), 1.2);
                if (hpPercent > tier.thresholds.getOrDefault("retreatHealthPercent", 0.1f) + 0.2f) {
                    currentState = State.APPROACH;
                }
                break;
                
            case SEEK_COVER:
                Vec3d coverPos = AiEnvironmentScanner.findCover(world, entity, target);
                if (coverPos != null) {
                    moveTowards(coverPos, 1.1);
                    if (entity.getPos().distanceTo(coverPos) < 2.0) { currentState = State.ENGAGE_RANGED; }
                } else { currentState = State.RETREAT; }
                break;
        }
        
        if (tier.canInterruptCasts && AiReactionSystem.isPlayerCasting(target)) {
            if (dist < 10.0 && actionCooldown <= 0) {
                performInterrupt(world);
                actionCooldown = 60;
            }
        }
    }
    
    private void moveTowards(Vec3d pos, double speed) {
        entity.getNavigation().startMovingTo(pos.x, pos.y, pos.z, speed * tier.speedMultiplier);
    }
    
    private void performMeleeAttack() {
        if (target != null && entity.getPos().distanceTo(target.getPos()) < 3.0) {
            target.damage(entity.getDamageSources().mobAttack(entity), 5.0f * tier.damageMultiplier);
        }
    }
    
    private void performRangedAttack(ServerWorld world) {
        if (target != null) {
            target.damage(entity.getDamageSources().magic(), 3.0f * tier.damageMultiplier);
            Fx.elementBurst(world, target.getPos(), ElementType.NONE, 5);
        }
    }
    
    private void performInterrupt(ServerWorld world) {
        if (target != null) {
            Vec3d dir = target.getPos().subtract(entity.getPos()).normalize();
            entity.addVelocity(dir.x * 0.8, 0.2, dir.z * 0.8);
            entity.velocityModified = true;
            Fx.elementBurst(world, entity.getPos(), ElementType.WIND, 10);
        }
    }
}
'@

# ============================================================
# 5. INTEGRATION: Patch AiSystem, EnemySystem, ShinobiCore
# ============================================================
Write-Host "`n[5/8] Integrating V2 AI into existing systems..." -ForegroundColor Yellow

$aiSystemPath = "src\main\java\com\example\shinobicore\ai\AiSystem.java"
Patch-File $aiSystemPath `
    'private static final Map<UUID, AiBrain> BRAINS = new HashMap<>();' `
    'private static final Map<UUID, AiBrain> BRAINS = new HashMap<>();
    private static final Map<UUID, com.example.shinobicore.ai.v2.AiBrainV2> BRAINS_V2 = new HashMap<>();
    public static void addV2(com.example.shinobicore.ai.v2.AiBrainV2 b) { BRAINS_V2.put(b.entity.getUuid(), b); }' `
    "Add V2 Brain map to AiSystem"

Patch-File $aiSystemPath `
    'b.lastX = b.entity.getX();
            b.lastZ = b.entity.getZ();
        }
    }
}' `
    'b.lastX = b.entity.getX();
            b.lastZ = b.entity.getZ();
        }
        
        // V2 AI Tick
        java.util.Iterator<com.example.shinobicore.ai.v2.AiBrainV2> it2 = BRAINS_V2.values().iterator();
        while (it2.hasNext()) {
            com.example.shinobicore.ai.v2.AiBrainV2 b2 = it2.next();
            if (!b2.entity.isAlive()) { it2.remove(); continue; }
            b2.tick((net.minecraft.server.world.ServerWorld) b2.entity.getWorld());
        }
    }
}' `
    "Add V2 Tick loop to AiSystem"

$enemySystemPath = "src\main\java\com\example\shinobicore\ai\EnemySystem.java"
Patch-File $enemySystemPath `
    'public static void register(MobEntity mob, int level) {' `
    'public static void registerV2(MobEntity mob, String tierId) {
        com.example.shinobicore.ai.v2.AiTierDefinition tier = com.example.shinobicore.ai.v2.AiTierRegistry.get(tierId);
        if (tier == null) tier = com.example.shinobicore.ai.v2.AiTierRegistry.get("genin");
        
        com.example.shinobicore.ai.v2.AiBrainV2 brain = new com.example.shinobicore.ai.v2.AiBrainV2(mob, tier);
        AiSystem.addV2(brain);
        
        var hpAttr = mob.getAttributeInstance(net.minecraft.entity.attribute.EntityAttributes.GENERIC_MAX_HEALTH);
        if (hpAttr != null) {
            hpAttr.setBaseValue(AiEntities.BASE_HP * tier.healthMultiplier);
            mob.setHealth(mob.getMaxHealth());
        }
        var spAttr = mob.getAttributeInstance(net.minecraft.entity.attribute.EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (spAttr != null) {
            spAttr.setBaseValue(AiEntities.BASE_SPEED * tier.speedMultiplier);
        }
    }

    public static void register(MobEntity mob, int level) {' `
    "Add registerV2 method to EnemySystem"

$corePath = "src\main\java\com\example\shinobicore\ShinobiCore.java"
Patch-File $corePath `
    'ClanRegistry.reload(server.getResourceManager());' `
    'ClanRegistry.reload(server.getResourceManager());
            com.example.shinobicore.ai.v2.AiTierRegistry.reload(server.getResourceManager());' `
    "Register AiTierRegistry reload in ShinobiCore"

# ============================================================
# 6. TEST COMMAND: Spawn ANBU
# ============================================================
Write-Host "`n[6/8] Adding test command to spawn V2 AI..." -ForegroundColor Yellow
$testCmdPath = "src\main\java\com\example\shinobicore\command\JutsuTestCommand.java"
Patch-File $testCmdPath `
    'dispatcher.register(literal("shinobicore").then(jutsu).then(aiBranch()));' `
    'dispatcher.register(literal("shinobicore").then(jutsu).then(aiBranch()).then(aiV2Branch()));' `
    "Add aiV2Branch to command"

Patch-File $testCmdPath `
    'private static LiteralArgumentBuilder<ServerCommandSource> aiBranch() {' `
    'private static LiteralArgumentBuilder<ServerCommandSource> aiV2Branch() {
        return literal("ai_v2").then(literal("spawn")
            .then(argument("tier", StringArgumentType.word())
                .suggests((ctx, b) -> {
                    b.suggest("genin"); b.suggest("chunin"); b.suggest("jonin"); b.suggest("anbu");
                    return b.buildFuture();
                })
                .executes(ctx -> {
                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                    String tier = StringArgumentType.getString(ctx, "tier");
                    net.minecraft.entity.mob.MobEntity mob = com.example.shinobicore.ai.AiEntities.ROGUE_NINJA.create(p.getServerWorld());
                    if (mob != null) {
                        net.minecraft.util.math.Vec3d pos = p.getPos().add(p.getRotationVector().multiply(4));
                        mob.setPosition(pos.x, pos.y, pos.z);
                        p.getServerWorld().spawnEntity(mob);
                        com.example.shinobicore.ai.EnemySystem.registerV2(mob, tier);
                        ctx.getSource().sendFeedback(() -> net.minecraft.text.Text.literal("§aSpawned V2 AI: " + tier), false);
                    }
                    return 1;
                })));
    }

    private static LiteralArgumentBuilder<ServerCommandSource> aiBranch() {' `
    "Implement aiV2Branch logic"

# ============================================================
# 7. BUILD
# ============================================================
Write-Host "`n[7/8] Building project..." -ForegroundColor Yellow
Push-Location $root
try {
    $buildOut = & cmd /c "gradlew.bat build 2>&1" | Out-String
    if ($buildOut -match "BUILD SUCCESSFUL") {
        Write-Host "[PASS] BUILD SUCCESSFUL!" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Build errors:" -ForegroundColor Red
        ($buildOut -split "`n") | Where-Object { $_ -match "error:" } | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 7 COMPLETE!" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Test in game with: /shinobicore ai_v2 spawn anbu" -ForegroundColor Yellow