$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"

function Normalize($text) { return $text.Replace("`r`n", "`n") }

Write-Host "=== FIXING COMPILATION ERRORS ===" -ForegroundColor Cyan

# 1. Fix ChakraHudRenderer.java (Remove duplicate stamina variables)
$hudPath = "$java\client\ChakraHudRenderer.java"
if (Test-Path $hudPath) {
    Write-Host "[1/3] Fixing ChakraHudRenderer.java..." -ForegroundColor Yellow
    $lines = [System.IO.File]::ReadAllLines($hudPath, $utf8)
    $newLines = New-Object System.Collections.Generic.List[string]
    $seenStamina = $false
    $seenMaxStamina = $false
    foreach ($line in $lines) {
        if ($line -match "public static float currentStamina\s*=") {
            if ($seenStamina) { continue } else { $seenStamina = $true }
        }
        if ($line -match "public static float maxStamina\s*=") {
            if ($seenMaxStamina) { continue } else { $seenMaxStamina = $true }
        }
        $newLines.Add($line)
    }
    [System.IO.File]::WriteAllLines($hudPath, $newLines, $utf8)
    Write-Host "  [OK] Removed duplicate stamina variables." -ForegroundColor Green
}

# 2. Fix ClanDefinition.java (Add startingJutsu to record)
$clanDefPath = "$java\clan\ClanDefinition.java"
if (Test-Path $clanDefPath) {
    Write-Host "[2/3] Fixing ClanDefinition.java..." -ForegroundColor Yellow
    $c = Normalize([System.IO.File]::ReadAllText($clanDefPath, $utf8))
    if (-not $c.Contains("List<String> startingJutsu")) {
        $c = $c.Replace("String dojutsuHook`n)", "String dojutsuHook,`n    List<String> startingJutsu`n)")
        if (-not $c.Contains("import java.util.List;")) {
            $c = "import java.util.List;`n" + $c
        }
        [System.IO.File]::WriteAllText($clanDefPath, $c.Replace("`n", "`r`n"), $utf8)
        Write-Host "  [OK] Added startingJutsu to ClanDefinition record." -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] startingJutsu already exists." -ForegroundColor DarkGray
    }
}

# 3. Fix ClanRegistry.java (Fix 'id' scope and parse startingJutsu)
$clanRegPath = "$java\clan\ClanRegistry.java"
if (Test-Path $clanRegPath) {
    Write-Host "[3/3] Fixing ClanRegistry.java..." -ForegroundColor Yellow
    $c = Normalize([System.IO.File]::ReadAllText($clanRegPath, $utf8))
    
    # Fix lambda parameter shadowing
    $c = $c.Replace("id -> id.getNamespace()", "resId -> resId.getNamespace()")
    $c = $c.Replace("id.getPath().endsWith", "resId.getPath().endsWith")
    
    # Ensure loop variable exists
    if (-not $c.Contains("Identifier id = entry.getKey();")) {
        $c = $c.Replace("for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {",
                         "for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {`n            Identifier id = entry.getKey();")
    }
    
    # Add startingJutsu parsing if missing
    if (-not $c.Contains("List<String> startingJutsu =")) {
        $oldParse = "String dojutsuHook = json.has(""dojutsuHook"") && !json.get(""dojutsuHook"").isJsonNull()`n            ? json.get(""dojutsuHook"").getAsString() : null;"
        $newParse = "String dojutsuHook = json.has(""dojutsuHook"") && !json.get(""dojutsuHook"").isJsonNull()`n            ? json.get(""dojutsuHook"").getAsString() : null;`n`n        List<String> startingJutsu = new java.util.ArrayList<>();`n        if (json.has(""startingJutsu"")) {`n            com.google.gson.JsonArray arr = json.getAsJsonArray(""startingJutsu"");`n            for (int i = 0; i < arr.size(); i++) startingJutsu.add(arr.get(i).getAsString());`n        }"
        $c = $c.Replace($oldParse, $newParse)
        
        $oldConst = "return new ClanDefinition(id, name, affinity, extraAffinityCount,`n                statBonuses, natureBonuses, costMultiplier, fatigueMultiplier, reserveBonus, dojutsuHook);"
        $newConst = "return new ClanDefinition(id, name, affinity, extraAffinityCount,`n                statBonuses, natureBonuses, costMultiplier, fatigueMultiplier, reserveBonus, dojutsuHook, startingJutsu);"
        $c = $c.Replace($oldConst, $newConst)
        
        [System.IO.File]::WriteAllText($clanRegPath, $c.Replace("`n", "`r`n"), $utf8)
        Write-Host "  [OK] Fixed 'id' scope and added startingJutsu parsing." -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] startingJutsu parsing already exists." -ForegroundColor DarkGray
    }
}

Write-Host "`n=== ALL FIXES APPLIED ===" -ForegroundColor Cyan
Write-Host "Now run: .\gradlew.bat build" -ForegroundColor Yellow