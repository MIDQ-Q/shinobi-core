$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\custom\CounterStanceBehavior.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
$c = $c.Replace(
    "player.playSound(SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, 0.8f, 1.2f, SoundCategory.PLAYERS);",
    "world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 0.8f, 1.2f);"
)
[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] Fixed playSound signature"