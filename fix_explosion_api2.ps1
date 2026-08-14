$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\custom"

# ============ 1. Boomerang: используем CLOUD ============
$f = "$base\BoomerangBehavior.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
$c = $c.Replace("ParticleTypes.SMALL_GUST", "ParticleTypes.CLOUD")
[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] Boomerang: SMALL_GUST -> CLOUD"

# ============ 2. Exploding: используем простую сигнатуру ============
$f = "$base\ExplodingProjectileBehavior.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
$c = $c.Replace(
    "w.createExplosion(fb, pos.x, pos.y, pos.z, radius, false, net.minecraft.world.explosion.Explosion.DestructionType.DESTROY);",
    "w.createExplosion(fb, pos.x, pos.y, pos.z, radius, true);"
)
[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] Exploding: simplified to createExplosion(entity, x, y, z, power, causeFire)"