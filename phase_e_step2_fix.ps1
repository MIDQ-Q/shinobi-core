$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# === 1. Fix NinjaTickHandler.java - line 50 ===
$nthPath = "E:\Games\mod\src\main\java\com\example\shinobicore\event\NinjaTickHandler.java"
$nthContent = [System.IO.File]::ReadAllText($nthPath, $utf8)

$badLine = "if (world instanceof ServerWorld sw) GenjutsuAuraEffect.tick(sw); // PHASE_E_GEN_AURA_REGISTERED"
$goodLine = "if (world instanceof ServerWorld) GenjutsuAuraEffect.tick((ServerWorld) world); // PHASE_E_GEN_AURA_REGISTERED"

if ($nthContent.Contains($badLine)) {
    $nthContent = $nthContent.Replace($badLine, $goodLine)
    [System.IO.File]::WriteAllText($nthPath, $nthContent, $utf8)
    Write-Host "[FIX] NinjaTickHandler: fixed instanceof pattern"
} else {
    Write-Host "[SKIP] NinjaTickHandler already fixed"
}

# === 2. Fix GenjutsuAuraEffect.java - rewrite the tick method ===
$gaePath = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\GenjutsuAuraEffect.java"
$gaeContent = [System.IO.File]::ReadAllText($gaePath, $utf8)

# Replace the broken entity iteration block
$badBlock = @"
        for (LivingEntity entity : world.iterateEntities()) {
            if (!(entity instanceof LivingEntity living)) continue;
            if (!living.isAlive()) continue;
            if (!isUnderGenjutsu(living)) continue;

            spawnGenjutsuAura(world, living);
        }
"@

$goodBlock = @"
        for (Object obj : world.iterateEntities()) {
            if (!(obj instanceof LivingEntity)) continue;
            LivingEntity living = (LivingEntity) obj;
            if (!living.isAlive()) continue;
            if (!isUnderGenjutsu(living)) continue;

            spawnGenjutsuAura(world, living);
        }
"@

if ($gaeContent.Contains("for (LivingEntity entity : world.iterateEntities())")) {
    # Also remove the useless ZOMBIE block
    $zombieBlock = @"
        for (LivingEntity entity : world.getEntitiesByType(
                net.minecraft.entity.EntityType.ZOMBIE, e -> true)) {
            // no-op, we iterate manually below for all living
        }
"@
    $gaeContent = $gaeContent.Replace($zombieBlock, "")
    $gaeContent = $gaeContent.Replace($badBlock, $goodBlock)
    [System.IO.File]::WriteAllText($gaePath, $gaeContent, $utf8)
    Write-Host "[FIX] GenjutsuAuraEffect: fixed entity iteration for Java 17"
} else {
    Write-Host "[SKIP] GenjutsuAuraEffect already fixed"
}

Write-Host ""
Write-Host "=== JAVA 17 FIX APPLIED ==="
Write-Host "Run: .\gradlew.bat build"