# ============================================================
#  SPRINT 1 / S1-01 & S1-02: CHAKRA LIMIT & STAMINA POOL
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint1_s01_s02_chakra_stamina.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$res = "$root\src\main\resources\data\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] Created: $($p.Replace($root, ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) {
        Write-Host "[MISS] $p" -ForegroundColor Red
        $script:err++
        return
    }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) {
        Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow
        $script:skip++
        return
    }
    if (-not $cNorm.Contains($oldNorm)) {
        Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red
        $script:err++
        return
    }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 1 / S1-01 & S1-02: CHAKRA LIMIT & STAMINA POOL" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. ModConfig.java
Write-Host "[1/9] ModConfig.java..." -ForegroundColor White
Patch-File "$java\config\ModConfig.java" `
"public Hud hud = new Hud();" `
"public Hud hud = new Hud();`n    public Stamina stamina = new Stamina();`n`n    public static class Stamina {`n        public float baseStamina = 100f;`n        public float baseRegen = 5.0f;`n        public float sprintCostPerSecond = 2.0f;`n    }"

Patch-File "$java\config\ModConfig.java" `
"public float baseChakra = 100f;" `
"public float baseChakra = 2000f;"

# 2. ClanDefinition.java
Write-Host "[2/9] ClanDefinition.java..." -ForegroundColor White
Patch-File "$java\clan\ClanDefinition.java" `
"float reserveBonus,`n    String dojutsuHook`n)" `
"float reserveBonus,`n    String dojutsuHook,`n    int chakraCap`n)"

# 3. ClanRegistry.java
Write-Host "[3/9] ClanRegistry.java..." -ForegroundColor White
Patch-File "$java\clan\ClanRegistry.java" `
"String dojutsuHook = json.has(""dojutsuHook"") && !json.get(""dojutsuHook"").isJsonNull()`n            ? json.get(""dojutsuHook"").getAsString() : null;`n`n        return new ClanDefinition(id, name, affinity, extraAffinityCount,`n                statBonuses, natureBonuses, costMultiplier, fatigueMultiplier, reserveBonus, dojutsuHook);" `
"String dojutsuHook = json.has(""dojutsuHook"") && !json.get(""dojutsuHook"").isJsonNull()`n            ? json.get(""dojutsuHook"").getAsString() : null;`n        int chakraCap = json.has(""chakraCap"") ? json.get(""chakraCap"").getAsInt() : 2000;`n`n        return new ClanDefinition(id, name, affinity, extraAffinityCount,`n                statBonuses, natureBonuses, costMultiplier, fatigueMultiplier, reserveBonus, dojutsuHook, chakraCap);"

# 4. uzumaki.json
Write-Host "[4/9] uzumaki.json..." -ForegroundColor White
Patch-File "$res\clans\uzumaki.json" `
"\"reserveBonus\": 150," `
"\"reserveBonus\": 150,`n  \"chakraCap\": 6000,"

# 5. NinjaPlayerData.java
Write-Host "[5/9] NinjaPlayerData.java..." -ForegroundColor White
Patch-File "$java\stat\NinjaPlayerData.java" `
"private float currentChakra = 100f;" `
"private float currentChakra = 2000f;`n    private float currentStamina = 100f;`n    private float maxStamina = 100f;`n    private float modeBuffer = 0f;"

Patch-File "$java\stat\NinjaPlayerData.java" `
"public float getCurrentChakra() { return currentChakra; }" `
"public float getCurrentChakra() { return currentChakra; }`n    public float getCurrentStamina() { return currentStamina; }`n    public void setCurrentStamina(float v) { this.currentStamina = Math.max(0, Math.min(v, maxStamina)); }`n    public float getMaxStamina() { return maxStamina; }`n    public void setMaxStamina(float v) { this.maxStamina = Math.max(1, v); }`n    public float getModeBuffer() { return modeBuffer; }`n    public void setModeBuffer(float v) { this.modeBuffer = Math.max(0, v); }"

Patch-File "$java\stat\NinjaPlayerData.java" `
"nbt.putFloat(\"Chakra\", currentChakra);" `
"nbt.putFloat(\"Chakra\", currentChakra);`n        nbt.putFloat(\"Stamina\", currentStamina);`n        nbt.putFloat(\"MaxStamina\", maxStamina);`n        nbt.putFloat(\"ModeBuffer\", modeBuffer);"

Patch-File "$java\stat\NinjaPlayerData.java" `
"currentChakra = nbt.getFloat(\"Chakra\");" `
"currentChakra = nbt.getFloat(\"Chakra\");`n        currentStamina = nbt.contains(\"Stamina\") ? nbt.getFloat(\"Stamina\") : 100f;`n        maxStamina = nbt.contains(\"MaxStamina\") ? nbt.getFloat(\"MaxStamina\") : 100f;`n        modeBuffer = nbt.getFloat(\"ModeBuffer\");"

# 6. NinjaFormula.java
Write-Host "[6/9] NinjaFormula.java..." -ForegroundColor White
Patch-File "$java\stat\NinjaFormula.java" `
"public static float maxChakra(NinjaPlayerData data) {`n        return cfg().chakra.baseChakra`n            + (data.getReserveLevel() - 1) * cfg().chakra.chakraPerReserveLevel`n            + getClanReserveBonus(data.getClanId());`n    }" `
"public static float maxChakra(NinjaPlayerData data) {`n        float cap = cfg().chakra.baseChakra;`n        com.example.shinobicore.clan.ClanDefinition clan = com.example.shinobicore.clan.ClanRegistry.get(data.getClanId());`n        if (clan != null && clan.chakraCap() > 0) {`n            cap = clan.chakraCap();`n        }`n        cap += (data.getReserveLevel() - 1) * cfg().chakra.chakraPerReserveLevel;`n        cap += data.getModeBuffer();`n        return cap;`n    }"

Patch-File "$java\stat\NinjaFormula.java" `
"public static float regenPerSecond(NinjaPlayerData data) {`n        float regen = cfg().chakra.baseRegen`n            + data.getReserveLevel() * cfg().chakra.regenPerReserveLevel`n            + data.getStatLevel(StatType.CONTROL) * cfg().chakra.regenPerControlLevel;`n        if (data.getFatigue() > cfg().fatigue.hardThreshold)`n            regen *= cfg().chakra.regenHardFatigueMultiplier;`n        if (data.isExhausted())`n            regen *= cfg().chakra.regenExhaustedMultiplier;`n        return regen;`n    }" `
"public static float regenPerSecond(NinjaPlayerData data) {`n        float regen = cfg().chakra.baseRegen`n            + data.getReserveLevel() * cfg().chakra.regenPerReserveLevel`n            + data.getStatLevel(StatType.CONTROL) * cfg().chakra.regenPerControlLevel;`n        if (data.getFatigue() > cfg().fatigue.hardThreshold)`n            regen *= cfg().chakra.regenHardFatigueMultiplier;`n        if (data.isExhausted())`n            regen *= cfg().chakra.regenExhaustedMultiplier;`n        `n        // S1-02: Stamina factor`n        float staminaFactor = 0.3f + 0.7f * (data.getCurrentStamina() / Math.max(1f, data.getMaxStamina()));`n        regen *= staminaFactor;`n        `n        return regen;`n    }"

# 7. ChakraSyncPacket.java
Write-Host "[7/9] ChakraSyncPacket.java..." -ForegroundColor White
Patch-File "$java\network\ChakraSyncPacket.java" `
"public record ChakraSyncPacket(`n        float currentChakra,`n        float maxChakra,`n        float fatigue,`n        boolean exhausted,`n        boolean meditating,`n        int reserveLevel,`n        String clanId,`n        String affinityId`n    )" `
"public record ChakraSyncPacket(`n        float currentChakra,`n        float maxChakra,`n        float currentStamina,`n        float maxStamina,`n        float fatigue,`n        boolean exhausted,`n        boolean meditating,`n        int reserveLevel,`n        String clanId,`n        String affinityId`n    )"

Patch-File "$java\network\ChakraSyncPacket.java" `
"buf.writeFloat(currentChakra);`n        buf.writeFloat(maxChakra);`n        buf.writeFloat(fatigue);" `
"buf.writeFloat(currentChakra);`n        buf.writeFloat(maxChakra);`n        buf.writeFloat(currentStamina);`n        buf.writeFloat(maxStamina);`n        buf.writeFloat(fatigue);"

Patch-File "$java\network\ChakraSyncPacket.java" `
"float chakra = buf.readFloat();`n        float max = buf.readFloat();`n        float fatigue = buf.readFloat();" `
"float chakra = buf.readFloat();`n        float max = buf.readFloat();`n        float stam = buf.readFloat();`n        float maxStam = buf.readFloat();`n        float fatigue = buf.readFloat();"

Patch-File "$java\network\ChakraSyncPacket.java" `
"return new ChakraSyncPacket(`n                chakra,`n                max,`n                fatigue," `
"return new ChakraSyncPacket(`n                chakra,`n                max,`n                stam,`n                maxStam,`n                fatigue,"

Patch-File "$java\network\ChakraSyncPacket.java" `
"return new ChakraSyncPacket(`n                data.getCurrentChakra(),`n                NinjaFormula.maxChakra(data),`n                data.getFatigue()," `
"return new ChakraSyncPacket(`n                data.getCurrentChakra(),`n                NinjaFormula.maxChakra(data),`n                data.getCurrentStamina(),`n                data.getMaxStamina(),`n                data.getFatigue(),"

# 8. ChakraHudRenderer.java & ShinobiCoreClient.java
Write-Host "[8/9] HUD & Client Sync..." -ForegroundColor White
Patch-File "$java\client\ChakraHudRenderer.java" `
"public static float currentChakra = 100f;`n    public static float maxChakra = 100f;" `
"public static float currentChakra = 2000f;`n    public static float maxChakra = 2000f;`n    public static float currentStamina = 100f;`n    public static float maxStamina = 100f;"

Patch-File "$java\client\ChakraHudRenderer.java" `
"bars.add(new BarSpec(chakraRatio, CHAKRA_LIGHT, CHAKRA_DARK, chakraRatio < 0.25f && !exhausted,`n                \"CH\", (int) currentChakra + \"/\" + (int) maxChakra));" `
"bars.add(new BarSpec(chakraRatio, CHAKRA_LIGHT, CHAKRA_DARK, chakraRatio < 0.25f && !exhausted,`n                \"CH\", (int) currentChakra + \"/\" + (int) maxChakra));`n        float stamRatio = maxStamina > 0 ? currentStamina / maxStamina : 0;`n        bars.add(new BarSpec(stamRatio, 0xFF44EE44, 0xFF22AA22, stamRatio < 0.25f,`n                \"ST\", (int) currentStamina + \"/\" + (int) maxStamina));"

Patch-File "$java\client\ShinobiCoreClient.java" `
"ChakraHudRenderer.currentChakra = packet.currentChakra();`n                ChakraHudRenderer.maxChakra = packet.maxChakra();`n                ChakraHudRenderer.fatigue = packet.fatigue();" `
"ChakraHudRenderer.currentChakra = packet.currentChakra();`n                ChakraHudRenderer.maxChakra = packet.maxChakra();`n                ChakraHudRenderer.currentStamina = packet.currentStamina();`n                ChakraHudRenderer.maxStamina = packet.maxStamina();`n                ChakraHudRenderer.fatigue = packet.fatigue();"

# 9. NinjaTickHandler.java
Write-Host "[9/9] NinjaTickHandler.java..." -ForegroundColor White
Patch-File "$java\event\NinjaTickHandler.java" `
"if (data.getFatigue() > 0) {" `
"// === S1-02: STAMINA REGEN & SPRINT COST ===`n            if (data.getCurrentStamina() < data.getMaxStamina()) {`n                float stRegen = ModConfig.instance.stamina.baseRegen;`n                data.setCurrentStamina(data.getCurrentStamina() + stRegen);`n            }`n            if (player.isSprinting() && data.getCurrentStamina() > 0) {`n                data.setCurrentStamina(data.getCurrentStamina() - ModConfig.instance.stamina.sprintCostPerSecond);`n            }`n`n            if (data.getFatigue() > 0) {"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S1-01 & S1-02 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected - stopping sprint chain!" -ForegroundColor Red
    exit 1
}
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0