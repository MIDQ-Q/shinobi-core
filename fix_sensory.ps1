$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\event\NinjaTickHandler.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)

if ($c.Contains("tickCounter % 5 == 0) sensoryTick")) {
    Write-Host "[SKIP] Sensory already tuned"
} else {
    # Add sensory tick every 5 ticks (4x faster than 20)
    $c = $c.Replace(
        "TreePassives.Bonuses b2 = TreePassives.collectServer(data);",
        "// === FAST SENSORY TICK (every 5 ticks) ===`n        int tickCounter = ((com.example.shinobicore.stat.NinjaDataHolder) player).shinobicore_getData().hashCode() & 0xFFFF;`n        tickCounter = (int)(player.getWorld().getTime() % 5);`n        if (tickCounter == 0) { // sensoryTick`n            TreePassives.Bonuses b2 = TreePassives.collectServer(data);"
    )
    # Close the if block at the end of sensory block
    $c = $c.Replace(
        "    }`n        } else if (data.getRasenganReadyTicks() != 0) {",
        "    }`n        }`n        } else if (data.getRasenganReadyTicks() != 0) {"
    )
    [System.IO.File]::WriteAllText($f, $c, $utf8)
    Write-Host "[OK] NinjaTickHandler: sensory tick every 5 ticks"
}

Write-Host "=== SENSORY FIX DONE ==="