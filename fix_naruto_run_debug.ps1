$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\mixin\PlayerRenderAnimationMixin.java"

$c = [System.IO.File]::ReadAllText($f, $utf8)

# Добавляем отладочный вывод чтобы понять почему наруто-ран не работает
$debug = @"
        // === НАРУТО-РАН DEBUG ===
        boolean narutoRunCondition = chakraMode && sprinting && !sliding && !rolling;
        boolean standingOnWater = com.example.shinobicore.client.ChakraPhysicsClient.standingOnWater;
        boolean wallRunning = com.example.shinobicore.client.parkour.ParkourManager.isWallRunning();
        
        if (player.isSprinting() && chakraMode) {
            com.example.shinobicore.ShinobiCore.LOGGER.info("[NARUTO-RUN DEBUG] chakraMode={}, sprinting={}, sliding={}, rolling={}, standingOnWater={}, wallRunning={}", 
                chakraMode, sprinting, sliding, rolling, standingOnWater, wallRunning);
            com.example.shinobicore.ShinobiCore.LOGGER.info("[NARUTO-RUN DEBUG] narutoRunCondition={}, currentChakra={}", 
                narutoRunCondition, ChakraHudRenderer.currentChakra);
        }
        
        // === WATER RUNNING === // BATCH3_WATER
"@

$c = $c.Replace(
    "        // === WATER RUNNING === // BATCH3_WATER",
    $debug
)

[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] Added debug logging to PlayerRenderAnimationMixin"