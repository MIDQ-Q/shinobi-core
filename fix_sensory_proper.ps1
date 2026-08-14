$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\event\NinjaTickHandler.java"

# Restore from git
& git -C "E:\Games\mod" checkout HEAD -- "src\main\java\com\example\shinobicore\event\NinjaTickHandler.java" 2>$null

$c = [System.IO.File]::ReadAllText($f, $utf8)

# Just speed up sensory tick from 20 to 5
$c = $c.Replace(
    "if (b2.sensory && data.isSensoryEnabled()) {",
    "int sensoryTick = (int)(player.getWorld().getTime() % 5);`n        if (b2.sensory && data.isSensoryEnabled() && sensoryTick == 0) {"
)

[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] NinjaTickHandler: sensory tick every 5 ticks (proper)"