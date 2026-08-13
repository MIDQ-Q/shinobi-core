# fix_phase6.ps1
# Phase 6: Projectile Collision + Dodge Visual + Dash Afterimage
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-File($path, $content) {
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "[OK] $path"
}

# ============================================================
# 1. MODIFY: NinjaProjectileEntity.java - add projectile collision
# ============================================================
$npe = "$root\entity\NinjaProjectileEntity.java"
$npeContent = [System.IO.File]::ReadAllText($npe, $utf8)

$sentinel1 = "// === PHASE6_PROJECTILE_COLLISION ==="
if ($npeContent.Contains($sentinel1)) {
    Write-Host "[SKIP] Projectile collision already added"
} else {
    # Insert collision check before movement code
    $collisionCode = @"
     // === PHASE6_PROJECTILE_COLLISION ===
     // Check collision with other projectiles (different owners)
     for (Entity other : this.getWorld().getOtherEntities(this, this.getBoundingBox().expand(0.5))) {
         if (other instanceof NinjaProjectileEntity otherProj && otherProj.age > 2) {
             // Skip same-owner projectiles (multi-shot techniques)
             if (this.ownerId != null && this.ownerId.equals(otherProj.ownerId)) continue;
             // Collision! Both destroyed
             if (this.getWorld() instanceof ServerWorld sw) {
                 sw.spawnParticles(ParticleTypes.POOF,
                     this.getX(), this.getY(), this.getZ(),
                     15, 0.4, 0.4, 0.4, 0.08);
                 sw.spawnParticles(ParticleTypes.CRIT,
                     this.getX(), this.getY(), this.getZ(),
                     8, 0.2, 0.2, 0.2, 0.1);
             }
             this.discard();
             otherProj.discard();
             ShinobiCore.LOGGER.info("[PROJECTILE] Collision! Both destroyed");
             return;
         }
     }
"@
    $npeContent = $npeContent.Replace(
        "     // Перемещение`n     this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);",
        "$collisionCode`n     // Перемещение`n     this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);"
    )
    Write-File $npe $npeContent
    Write-Host "[FIX] NinjaProjectileEntity: added projectile collision"
}

# ============================================================
# 2. MODIFY: DodgeAction.java - add visual particles
# ============================================================
$da = "$root\client\parkour\actions\DodgeAction.java"
$daContent = [System.IO.File]::ReadAllText($da, $utf8)

$sentinel2 = "// === PHASE6_DODGE_VISUAL ==="
if ($daContent.Contains($sentinel2)) {
    Write-Host "[SKIP] Dodge visual already added"
} else {
    # Add import
    $daContent = $daContent.Replace(
        "import net.minecraft.util.math.Vec3d;",
        "import net.minecraft.util.math.Vec3d;`nimport net.minecraft.client.MinecraftClient;`nimport net.minecraft.particle.ParticleTypes;"
    )
    
    # Add particles in activate() after ParkourSounds.playRoll()
    $dodgeActivateParticles = @"
        // === PHASE6_DODGE_VISUAL ===
        // Spawn dodge particles (ring of clouds)
        MinecraftClient dodgeClient = MinecraftClient.getInstance();
        if (dodgeClient.world != null) {
            for (int i = 0; i < 10; i++) {
                double angle = (i / 10.0) * Math.PI * 2;
                dodgeClient.world.addParticle(ParticleTypes.CLOUD,
                    player.getX() + Math.cos(angle) * 0.4,
                    player.getY() + 0.3,
                    player.getZ() + Math.sin(angle) * 0.4,
                    Math.cos(angle) * 0.08, 0.03, Math.sin(angle) * 0.08);
            }
        }
"@
    $daContent = $daContent.Replace(
        "ctx.resetActive(ID);`n        ParkourSounds.playRoll();",
        "ctx.resetActive(ID);`n        ParkourSounds.playRoll();`n$dodgeActivateParticles"
    )
    
    # Add trail in tick() during i-frames
    $dodgeTrailParticles = @"
     // === PHASE6_DODGE_TRAIL ===
     if (dodgeTicks <= INVULNERABILITY_TICKS) {
         MinecraftClient trailClient = MinecraftClient.getInstance();
         if (trailClient.world != null && trailClient.player != null) {
             // Ghost smoke trail during i-frames
             trailClient.world.addParticle(ParticleTypes.SMOKE,
                 player.getX() + (Math.random() - 0.5) * 0.3,
                 player.getY() + 0.5 + Math.random() * 0.5,
                 player.getZ() + (Math.random() - 0.5) * 0.3,
                 0, 0.02, 0);
             // Speed lines
             if (dodgeTicks % 2 == 0) {
                 trailClient.world.addParticle(ParticleTypes.SWEEP_ATTACK,
                     player.getX(), player.getY() + 0.8, player.getZ(),
                     0, 0, 0);
             }
         }
     }
"@
    $daContent = $daContent.Replace(
        "if (dodgeTicks <= INVULNERABILITY_TICKS) {`n            player.timeUntilRegen = INVULNERABILITY_TICKS - dodgeTicks;`n        }",
        "if (dodgeTicks <= INVULNERABILITY_TICKS) {`n            player.timeUntilRegen = INVULNERABILITY_TICKS - dodgeTicks;`n        }`n$dodgeTrailParticles"
    )
    
    Write-File $da $daContent
    Write-Host "[FIX] DodgeAction: added visual particles"
}

# ============================================================
# 3. MODIFY: DashBehavior.java - add afterimage trail
# ============================================================
$db = "$root\jutsu\DashBehavior.java"
$dbContent = [System.IO.File]::ReadAllText($db, $utf8)

$sentinel3 = "// === PHASE6_DASH_AFTERIMAGE ==="
if ($dbContent.Contains($sentinel3)) {
    Write-Host "[SKIP] Dash afterimage already added"
} else {
    # Add afterimage particles after spawnDashParticles call
    $afterimageCode = @"
     // === PHASE6_DASH_AFTERIMAGE ===
     // Ghost afterimages along the dash path
     Vec3d dir2 = endPos.subtract(startPos).normalize();
     float len2 = (float) startPos.distanceTo(endPos);
     int ghostCount = (int)(len2 * 3); // 3 ghosts per block
     for (int g = 0; g < ghostCount; g++) {
         float progress = (float) g / ghostCount;
         Vec3d ghostPos = startPos.add(dir2.multiply(progress * len2));
         // Sweep attack particles as "afterimage"
         serverWorld.spawnParticles(ParticleTypes.SWEEP_ATTACK,
             ghostPos.x + (Math.random() - 0.5) * 0.4,
             ghostPos.y + 0.8 + (Math.random() - 0.5) * 0.6,
             ghostPos.z + (Math.random() - 0.5) * 0.4,
             1, 0, 0.02, 0, 0);
     }
     // Landing burst
     serverWorld.spawnParticles(ParticleTypes.CLOUD,
         endPos.x, endPos.y + 0.3, endPos.z,
         12, 0.5, 0.3, 0.5, 0.06);
"@
    $dbContent = $dbContent.Replace(
        "JutsuLogger.logBehavior(`"dash`", String.format(",
        "$afterimageCode`n     JutsuLogger.logBehavior(`"dash`", String.format("
    )
    Write-File $db $dbContent
    Write-Host "[FIX] DashBehavior: added afterimage trail"
}

Write-Host ""
Write-Host "=== PHASE 6 APPLIED ==="
Write-Host "Run: .\gradlew.bat build"