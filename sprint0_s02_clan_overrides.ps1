# ============================================================
#  SPRINT 0 / S0-02: CLAN OVERRIDES
#  Server-side clan chakra caps and stat recalculation
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint0_s02_clan_overrides.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$res = "$root\src\main\resources\data\shinobicore\clans"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace($root, ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $cNorm.Contains($oldNorm)) { Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 0 / S0-02: CLAN OVERRIDES & CHAKRA CAPS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. ModConfig.java - Base chakra without clan = 2000
# ================================================================
Write-Host "[1/7] ModConfig.java (baseChakra = 2000)..." -ForegroundColor White
Patch-File "$java\config\ModConfig.java" `
'public float baseChakra = 100f;' `
'public float baseChakra = 2000f;'

# ================================================================
# 2. ClanDefinition.java - Add chakraCap field
# ================================================================
Write-Host "[2/7] ClanDefinition.java..." -ForegroundColor White
Patch-File "$java\clan\ClanDefinition.java" `
'float reserveBonus,
    String dojutsuHook' `
'float reserveBonus,
    float chakraCap,
    String dojutsuHook'

# ================================================================
# 3. ClanRegistry.java - Parse chakra_cap from JSON
# ================================================================
Write-Host "[3/7] ClanRegistry.java..." -ForegroundColor White
Patch-File "$java\clan\ClanRegistry.java" `
'float reserveBonus = json.has("reserveBonus") ? json.get("reserveBonus").getAsFloat() : 0f;
        String dojutsuHook = json.has("dojutsuHook") && !json.get("dojutsuHook").isJsonNull()' `
'float reserveBonus = json.has("reserveBonus") ? json.get("reserveBonus").getAsFloat() : 0f;
        float chakraCap = json.has("chakra_cap") ? json.get("chakra_cap").getAsFloat() : 0f;
        String dojutsuHook = json.has("dojutsuHook") && !json.get("dojutsuHook").isJsonNull()'

Patch-File "$java\clan\ClanRegistry.java" `
'return new ClanDefinition(id, name, affinity, extraAffinityCount,
                statBonuses, natureBonuses, costMultiplier, fatigueMultiplier, reserveBonus, dojutsuHook);' `
'return new ClanDefinition(id, name, affinity, extraAffinityCount,
                statBonuses, natureBonuses, costMultiplier, fatigueMultiplier, reserveBonus, chakraCap, dojutsuHook);'

# ================================================================
# 4. NinjaFormula.java - Use chakraCap if > 0
# ================================================================
Write-Host "[4/7] NinjaFormula.java..." -ForegroundColor White
Patch-File "$java\stat\NinjaFormula.java" `
'public static float maxChakra(NinjaPlayerData data) {
        return cfg().chakra.baseChakra
            + (data.getReserveLevel() - 1) * cfg().chakra.chakraPerReserveLevel
            + getClanReserveBonus(data.getClanId());
    }' `
'public static float maxChakra(NinjaPlayerData data) {
        float base = cfg().chakra.baseChakra;
        ClanDefinition clan = ClanRegistry.get(data.getClanId());
        if (clan != null && clan.chakraCap() > 0) {
            base = clan.chakraCap();
        }
        return base
            + (data.getReserveLevel() - 1) * cfg().chakra.chakraPerReserveLevel
            + getClanReserveBonus(data.getClanId());
    }'

# ================================================================
# 5. NinjaCommand.java - Sync chakra on clan change
# ================================================================
Write-Host "[5/7] NinjaCommand.java..." -ForegroundColor White
Patch-File "$java\command\NinjaCommand.java" `
'data(p).setClanId(id);
                ShinobiCore.sendBodySync(p);
                return feedback(ctx.getSource(), "Clan set to " + id);' `
'data(p).setClanId(id);
                ShinobiCore.sendBodySync(p);
                ShinobiCore.sendChakraSync(p);
                return feedback(ctx.getSource(), "Clan set to " + id);'

Patch-File "$java\command\NinjaCommand.java" `
'data(p).setClanId(id);
            data(p).setClanChosen(true);
            ShinobiCore.sendBodySync(p);
            return feedback(ctx.getSource(), "Clan chosen: " + id);' `
'data(p).setClanId(id);
            data(p).setClanChosen(true);
            ShinobiCore.sendBodySync(p);
            ShinobiCore.sendChakraSync(p);
            return feedback(ctx.getSource(), "Clan chosen: " + id);'

# ================================================================
# 6. NinjaTickHandler.java - Sync chakra when stats are dirty
# ================================================================
Write-Host "[6/7] NinjaTickHandler.java..." -ForegroundColor White
Patch-File "$java\event\NinjaTickHandler.java" `
'if (data.consumeStatsDirty()) {
                    ShinobiCore.sendStatsSync(player);
                }' `
'if (data.consumeStatsDirty()) {
                    ShinobiCore.sendStatsSync(player);
                    ShinobiCore.sendChakraSync(player);
                }'

# ================================================================
# 7. Update Clan JSONs with chakra_cap
# ================================================================
Write-Host "[7/7] Updating Clan JSONs..." -ForegroundColor White

$uzumaki = @'
{
  "id": "uzumaki",
  "name": "Uzumaki Clan",
  "affinity": "water",
  "extraAffinityCount": 0,
  "statBonuses": { "control": 5, "ninjutsu": 5 },
  "natureBonuses": { "water": 10 },
  "costMultiplier": {},
  "fatigueMultiplier": 0.85,
  "reserveBonus": 150,
  "chakra_cap": 6000,
  "dojutsuHook": null
}
'@
Write-File "$res\uzumaki.json" $uzumaki

$uchiha = @'
{
  "id": "uchiha",
  "name": "Uchiha Clan",
  "affinity": "fire",
  "extraAffinityCount": 0,
  "statBonuses": { "genjutsu": 5, "perception": 5 },
  "natureBonuses": { "fire": 10 },
  "costMultiplier": { "fire": 0.90 },
  "fatigueMultiplier": 1.0,
  "reserveBonus": 0,
  "chakra_cap": 2500,
  "dojutsuHook": "sharingan"
}
'@
Write-File "$res\uchiha.json" $uchiha

$hyuga = @'
{
  "id": "hyuga",
  "name": "Hyuga Clan",
  "affinity": "earth",
  "extraAffinityCount": 0,
  "statBonuses": { "taijutsu": 5, "perception": 5 },
  "natureBonuses": { "earth": 5 },
  "costMultiplier": {},
  "fatigueMultiplier": 0.95,
  "reserveBonus": 50,
  "chakra_cap": 2500,
  "dojutsuHook": "byakugan"
}
'@
Write-File "$res\hyuga.json" $hyuga

$sarutobi = @'
{
  "id": "sarutobi",
  "name": "Sarutobi Clan",
  "affinity": "fire",
  "extraAffinityCount": 1,
  "statBonuses": { "ninjutsu": 5, "control": 3, "perception": 3 },
  "natureBonuses": { "fire": 8, "wind": 5 },
  "costMultiplier": { "fire": 0.95 },
  "fatigueMultiplier": 1.0,
  "reserveBonus": 50,
  "chakra_cap": 2500,
  "dojutsuHook": null
}
'@
Write-File "$res\sarutobi.json" $sarutobi

$hatake = @'
{
  "id": "hatake",
  "name": "Hatake Clan",
  "affinity": "lightning",
  "extraAffinityCount": 1,
  "statBonuses": { "ninjutsu": 5, "taijutsu": 3, "control": 3 },
  "natureBonuses": { "lightning": 8 },
  "costMultiplier": { "lightning": 0.92 },
  "fatigueMultiplier": 1.0,
  "reserveBonus": 30,
  "chakra_cap": 2500,
  "dojutsuHook": null
}
'@
Write-File "$res\hatake.json" $hatake

$nara = @'
{
  "id": "nara",
  "name": "Nara Clan",
  "affinity": "earth",
  "extraAffinityCount": 0,
  "statBonuses": { "control": 8, "perception": 5 },
  "natureBonuses": { "earth": 5 },
  "costMultiplier": {},
  "fatigueMultiplier": 1.1,
  "reserveBonus": 0,
  "chakra_cap": 2000,
  "dojutsuHook": null
}
'@
Write-File "$res\nara.json" $nara

# ================================================================
# SUMMARY & EXIT CODE
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S0-02 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Logic implemented:" -ForegroundColor White
Write-Host "    - Base chakra without clan is now 2000" -ForegroundColor White
Write-Host "    - Clans can override base chakra via 'chakra_cap'" -ForegroundColor White
Write-Host "    - Uzumaki sets base chakra to 6000" -ForegroundColor White
Write-Host "    - Chakra correctly recalculates and syncs on clan change" -ForegroundColor White
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected - stopping sprint chain!" -ForegroundColor Red
    Write-Host "  Fix errors before running sprint0_s03_json_loaders.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  Then: sprint0_s03_json_loaders.ps1" -ForegroundColor Yellow
exit 0