# ============================================================
#  SPRINT 1 / S1-09 & S1-10: BALANCE EARLY/LATE TECHNIQUES & TESTS
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint1_s09_s10_balance.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$jutsuDir = "$root\src\main\resources\data\shinobicore\jutsu"
$javaDir = "$root\src\main\java\com\example\shinobicore"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 1 / S1-09 & S1-10: BALANCE & TESTS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# S1-09: Balance early and late techniques (Assign Tiers & Cast Times)
# ================================================================
Write-Host "[1/2] S1-09: Assigning Tiers and Cast Times to Jutsu..." -ForegroundColor White
$files = Get-ChildItem -Path $jutsuDir -Filter "*.json" -ErrorAction SilentlyContinue
$updated = 0
$skipped = 0

if ($files) {
    foreach ($f in $files) {
        if ($f.Name -like "_template*") { continue }
        $content = [System.IO.File]::ReadAllText($f.FullName, $utf8)
        
        # Idempotency check
        if ($content -match '"tier"\s*:') { 
            $skipped++
            continue 
        }
        
        # Extract baseCost or chakra_cost
        $cost = 0
        if ($content -match '"baseCost"\s*:\s*([0-9\.]+)') {
            $cost = [float]$Matches[1]
        } elseif ($content -match '"chakra_cost"\s*:\s*([0-9\.]+)') {
            $cost = [float]$Matches[1]
        }
        
        # Determine Tier (T1-T5) based on cost brackets
        $tier = 1
        if ($cost -gt 80) { $tier = 5 }
        elseif ($cost -gt 50) { $tier = 4 }
        elseif ($cost -gt 35) { $tier = 3 }
        elseif ($cost -gt 20) { $tier = 2 }
        
        # Determine Cast Time based on Tier (S1-03 logic)
        $castTime = switch ($tier) {
            1 { 0.5 }
            2 { 1.0 }
            3 { 1.5 }
            4 { 2.5 }
            5 { 4.0 }
        }
        
        # Inject tier and cast_time after "id": "..."
        $pattern = '("id"\s*:\s*"[^"]+"\s*,)'
        $replacement = "`$1`n  `"tier`": $tier,`n  `"cast_time`": $castTime,"
        
        $newContent = [regex]::Replace($content, $pattern, $replacement, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        if ($newContent -ne $content) {
            [System.IO.File]::WriteAllText($f.FullName, $newContent, $utf8)
            $updated++
        }
    }
    Write-Host "  [OK] Updated $updated jutsu files. Skipped $skipped (already have tier)." -ForegroundColor Green
} else {
    Write-Host "  [WARN] No jutsu JSON files found in $jutsuDir" -ForegroundColor Yellow
}

# ================================================================
# S1-10: Balance Core Tests
# ================================================================
Write-Host "[2/2] S1-10: Adding Balance Core Tests to TestAllCommand.java..." -ForegroundColor White
$testFile = "$javaDir\command\TestAllCommand.java"

if (-not (Test-Path $testFile)) {
    Write-Host "  [FAIL] TestAllCommand.java not found!" -ForegroundColor Red
    exit 1
}

$testContent = [System.IO.File]::ReadAllText($testFile, $utf8)

# 1. Add runBalanceTests(source); to runAllTests
if (-not $testContent.Contains("runBalanceTests(source);")) {
    $testContent = $testContent.Replace("runCombatTests(source);", "runCombatTests(source);`n        runBalanceTests(source);")
}

# 2. Add the runBalanceTests method
$balanceTestMethod = @"

    // ==================== BALANCE TESTS (S1-10) ====================
    private static int runBalanceTests(ServerCommandSource source) {
        source.sendFeedback(() -> Text.literal("§6--- Balance Core Tests (S1-10) ---"), false);
        
        Collection<JutsuDefinition> allJutsu = JutsuRegistry.getAll();
        int tierCostOk = 0, tierCostFail = 0;
        int castTimeOk = 0, castTimeFail = 0;
        java.util.List<String> tierMismatches = new java.util.ArrayList<>();
        
        for (JutsuDefinition def : allJutsu) {
            // 1. Tier vs Cost bracket check
            float cost = def.baseCost();
            int tier = def.tier();
            boolean costMatch = false;
            
            // Brackets: T1 <= 25, T2 <= 40, T3 <= 60, T4 <= 90, T5 > 70
            if (tier == 1 && cost <= 25) costMatch = true;
            if (tier == 2 && cost <= 40) costMatch = true;
            if (tier == 3 && cost <= 60) costMatch = true;
            if (tier == 4 && cost <= 90) costMatch = true;
            if (tier == 5 && cost > 70) costMatch = true;
            
            if (costMatch) { tierCostOk++; } 
            else { 
                tierCostFail++; 
                tierMismatches.add(def.id() + " (T" + tier + " cost=" + cost + ")");
            }
            
            // 2. Cast time > 0
            if (def.castTime() > 0) castTimeOk++; else castTimeFail++;
        }
        
        check("T1-T5 Cost brackets match tiers", tierCostFail == 0, 
            tierCostOk + " ok, " + tierCostFail + " mismatched" + 
            (tierCostFail > 0 ? ": " + String.join(", ", tierMismatches.subList(0, Math.min(5, tierMismatches.size()))) : ""));
            
        check("All jutsu have cast_time > 0", castTimeFail == 0, 
            castTimeOk + " ok, " + castTimeFail + " missing/zero");
            
        // 3. Stamina factor affects regen
        NinjaPlayerData testData = new NinjaPlayerData();
        testData.setCurrentStamina(0f); // Zero stamina
        float regenZeroStam = NinjaFormula.regenPerSecond(testData);
        testData.setCurrentStamina(100f); // Full stamina
        float regenFullStam = NinjaFormula.regenPerSecond(testData);
        
        check("Stamina factor affects regen (0 vs 100)", regenZeroStam < regenFullStam, 
            "zero=" + String.format("%.2f", regenZeroStam) + " full=" + String.format("%.2f", regenFullStam));
            
        // 4. calculateCost() > 0 for all jutsu
        boolean castFormulaOk = true;
        try {
            for (JutsuDefinition def : allJutsu) {
                float cost = NinjaFormula.calculateCost(def, testData);
                if (cost <= 0) castFormulaOk = false;
            }
        } catch (Exception e) {
            castFormulaOk = false;
        }
        check("calculateCost() > 0 for all jutsu", castFormulaOk, "No crashes, all positive");
        
        source.sendFeedback(() -> Text.literal("§7Balance tests done."), false);
        return 1;
    }
"@

if (-not $testContent.Contains("runBalanceTests(ServerCommandSource source)")) {
    # Insert before the last closing brace of the class
    $lastBrace = $testContent.LastIndexOf("}")
    if ($lastBrace -gt 0) {
        $testContent = $testContent.Substring(0, $lastBrace) + $balanceTestMethod + "`n" + $testContent.Substring($lastBrace)
    }
}

[System.IO.File]::WriteAllText($testFile, $testContent, $utf8)
Write-Host "  [OK] Added S1-10 Balance Tests to TestAllCommand.java" -ForegroundColor Green

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S1-09 & S1-10 COMPLETE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Changes:" -ForegroundColor White
Write-Host "    - S1-09: Assigned T1-T5 tiers and cast_time to all jutsu JSONs" -ForegroundColor White
Write-Host "    - S1-10: Added balance autotests to /testall command" -ForegroundColor White
Write-Host ""
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  Then: .\gradlew.bat runClient -> type /testall in game" -ForegroundColor Yellow
exit 0