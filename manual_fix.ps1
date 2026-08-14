$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\event\NinjaTickHandler.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)

# Find the broken section and remove the extra if block
$c = $c.Replace(
    "        // === FAST SENSORY TICK (every 5 ticks) ===`n        int tickCounter = ((com.example.shinobicore.stat.NinjaDataHolder) player).shinobicore_getData().hashCode() & 0xFFFF;`n        tickCounter = (int)(player.getWorld().getTime() % 5);`n        if (tickCounter == 0) { // sensoryTick`n            TreePassives.Bonuses b2 = TreePassives.collectServer(data);",
    "TreePassives.Bonuses b2 = TreePassives.collectServer(data);"
)

$c = $c.Replace(
    "    }`n        }`n        } else if (data.getRasenganReadyTicks() != 0) {",
    "    }`n        } else if (data.getRasenganReadyTicks() != 0) {"
)

# Now add the proper sensory tick speedup
$c = $c.Replace(
    "if (b2.sensory && data.isSensoryEnabled()) {",
    "int sensoryTick = (int)(player.getWorld().getTime() % 5);`n        if (b2.sensory && data.isSensoryEnabled() && sensoryTick == 0) {"
)

[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] NinjaTickHandler fixed manually"