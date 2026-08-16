$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    
    if ($cNorm.Contains($newNorm)) {
        Write-Host "[SKIP] already patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow
        return $true
    }
    if (-not $cNorm.Contains($oldNorm)) {
        Write-Host "[FAIL] pattern not found in $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red
        return $false
    }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    return $true
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIXING S0-02 REMAINING ERRORS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 0. Safety check: Ensure ClanDefinition has chakraCap
$clanDefFile = "$java\clan\ClanDefinition.java"
$cDef = [System.IO.File]::ReadAllText($clanDefFile, $utf8)
if ($cDef -notmatch "chakraCap") {
    Write-Host "[WARN] ClanDefinition.java is missing chakraCap! Attempting to fix..." -ForegroundColor Yellow
    $cDef = $cDef.Replace("String dojutsuHook`r`n)", "String dojutsuHook,`r`n    float chakraCap`r`n)")
    $cDef = $cDef.Replace("String dojutsuHook`n)", "String dojutsuHook,`n    float chakraCap`n)")
    [System.IO.File]::WriteAllText($clanDefFile, $cDef, $utf8)
}

# 1. ClanRegistry.java (Robust string replacement to avoid pattern errors)
$regFile = "$java\clan\ClanRegistry.java"
$c = [System.IO.File]::ReadAllText($regFile, $utf8)
if (-not $c.Contains("chakraCap);")) {
    $c = $c.Replace("dojutsuHook);", "dojutsuHook, chakraCap);")
    if (-not $c.Contains("float chakraCap =")) {
        $c = $c.Replace("String dojutsuHook =", "float chakraCap = json.has(""chakra_cap"") ? json.get(""chakra_cap"").getAsFloat() : 0f;`n        String dojutsuHook =")
    }
    [System.IO.File]::WriteAllText($regFile, $c, $utf8)
    Write-Host "[OK] patched: ClanRegistry.java" -ForegroundColor Green
} else {
    Write-Host "[SKIP] ClanRegistry.java already has chakraCap" -ForegroundColor Yellow
}

# 2. NinjaFormula.java (Override baseChakra with clan.chakraCap if > 0)
$formulaOld = @"
    public static float maxChakra(NinjaPlayerData data) {
        return cfg().chakra.baseChakra
                + (data.getReserveLevel() - 1) * cfg().chakra.chakraPerReserveLevel
                + getClanReserveBonus(data.getClanId());
    }
"@
$formulaNew = @"
    public static float maxChakra(NinjaPlayerData data) {
        float base = cfg().chakra.baseChakra;
        com.example.shinobicore.clan.ClanDefinition clan = com.example.shinobicore.clan.ClanRegistry.get(data.getClanId());
        if (clan != null && clan.chakraCap() > 0) {
            base = clan.chakraCap();
        }
        return base
                + (data.getReserveLevel() - 1) * cfg().chakra.chakraPerReserveLevel
                + getClanReserveBonus(data.getClanId());
    }
"@
Patch-File "$java\stat\NinjaFormula.java" $formulaOld $formulaNew

# 3. NinjaCommand.java (Sync chakra when clan is changed via command)
$cmdOld1 = @"
                    data(p).setClanId(id);
                    ShinobiCore.sendBodySync(p);
                    return feedback(ctx.getSource(), "Clan set to " + id);
"@
$cmdNew1 = @"
                    data(p).setClanId(id);
                    ShinobiCore.sendBodySync(p);
                    ShinobiCore.sendChakraSync(p);
                    return feedback(ctx.getSource(), "Clan set to " + id);
"@
Patch-File "$java\command\NinjaCommand.java" $cmdOld1 $cmdNew1

$cmdOld2 = @"
                    data(p).setClanId(id);
                    data(p).setClanChosen(true);
                    ShinobiCore.sendBodySync(p);
                    return feedback(ctx.getSource(), "Clan chosen: " + id);
"@
$cmdNew2 = @"
                    data(p).setClanId(id);
                    data(p).setClanChosen(true);
                    ShinobiCore.sendBodySync(p);
                    ShinobiCore.sendChakraSync(p);
                    return feedback(ctx.getSource(), "Clan chosen: " + id);
"@
Patch-File "$java\command\NinjaCommand.java" $cmdOld2 $cmdNew2

# 4. NinjaTickHandler.java (Cap current chakra if max chakra drops)
$tickOld = @"
            float maxChakra = NinjaFormula.maxChakra(data);
            if (data.getCurrentChakra() < maxChakra) {
"@
$tickNew = @"
            float maxChakra = NinjaFormula.maxChakra(data);
            if (data.getCurrentChakra() > maxChakra) {
                data.setCurrentChakra(maxChakra);
            }
            if (data.getCurrentChakra() < maxChakra) {
"@
Patch-File "$java\event\NinjaTickHandler.java" $tickOld $tickNew

Write-Host "================================================================" -ForegroundColor Green
Write-Host "  FIX COMPLETE. Run: .\gradlew.bat build" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green