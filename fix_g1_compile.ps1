$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\custom"

# ============ 1. Boomerang: WIND -> SMALL_GUST ============
$f = "$base\BoomerangBehavior.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
$c = $c.Replace("ParticleTypes.WIND", "ParticleTypes.SMALL_GUST")
if (-not $c.Contains("SMALL_GUST")) { $c = $c.Replace("ParticleTypes.WIND", "ParticleTypes.CLOUD") }
[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] Boomerang: WIND -> SMALL_GUST"

# ============ 2. Exploding: DestructionType -> ExplosionSourceType ============
$f = "$base\ExplodingProjectileBehavior.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
# Replace import and method call
$c = $c.Replace("import net.minecraft.world.explosion.Explosion;", "import net.minecraft.world.explosion.Explosion;`nimport net.minecraft.world.explosion.ExplosionSourceType;")
$c = $c.Replace(
    "w.createExplosion(fb, pos.x, pos.y, pos.z, radius, false, Explosion.DestructionType.DESTROY);",
    "w.createExplosion(fb, pos.x, pos.y, pos.z, radius, false, ExplosionSourceType.MOB);"
)
[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] Exploding: DestructionType -> ExplosionSourceType.MOB"