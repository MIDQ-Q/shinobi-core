# fix_modpackets_scope.ps1 - Move taijutsuLevel declaration to correct scope
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$mp = "$root\network\ModPackets.java"
$mpContent = [System.IO.File]::ReadAllText($mp, $utf8)

# Replace the entire TAIJUTSU_ATTACK_ID handler block with correct variable order
$oldBlock = @"
        server.execute(() -> {
            if (player.getWorld().isClient()) return;
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            if (data.isExhausted()) return;
            if (data.getCurrentChakra() <= 0) return;
            // === ВАЛИДАЦИЯ: проверяем что стиль валиден ===
            TaijutsuStyle style = TaijutsuStyle.fromId(styleId);
"@

$newBlock = @"
        server.execute(() -> {
            if (player.getWorld().isClient()) return;
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            if (data.isExhausted()) return;
            if (data.getCurrentChakra() <= 0) return;
            int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);
            // === ВАЛИДАЦИЯ: проверяем что стиль валиден ===
            TaijutsuStyle style = TaijutsuStyle.fromId(styleId);
"@

$mpContent = $mpContent.Replace($oldBlock, $newBlock)

# Now remove the duplicate declaration later in the same method
$mpContent = $mpContent.Replace(
    "            // Всё ок — применяем урон`n            int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);`n            boolean chakraMode = data.isChakraMode();",
    "            // Всё ок — применяем урон`n            boolean chakraMode = data.isChakraMode();"
)

[System.IO.File]::WriteAllText($mp, $mpContent, $utf8)
Write-Host "[FIX] ModPackets: moved taijutsuLevel to correct scope"
Write-Host "Run: .\gradlew.bat build"