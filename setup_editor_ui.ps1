# ============================================================
# DIAGNOSE + FIX: /shinobicore jutsu command registration
# ============================================================

$ErrorActionPreference = "Stop"
$root = "E:\Games\mod"
$path = Join-Path $root "src\main\java\com\example\shinobicore\ShinobiCore.java"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSE + FIX jutsu command" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ============================================================
# STEP 1: DIAGNOSTICS - show current registration lines
# ============================================================
Write-Host ""
Write-Host "[1/3] Current state of ShinobiCore.java:" -ForegroundColor Yellow
$c = [System.IO.File]::ReadAllText($path, $utf8NoBom)
$lines = $c -split "`n"
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'CommandRegistrationCallback|JutsuTestCommand|JutsuRuntime\.register|NinjaCommand\.register|DiagnosticCommands\.register') {
        Write-Host ("  {0,4}: {1}" -f ($i + 1), $lines[$i].TrimEnd()) -ForegroundColor Gray
    }
}

$hasJutsuCmd = $c.Contains("JutsuTestCommand.register(dispatcher)")
Write-Host ""
Write-Host "  JutsuTestCommand wired: $hasJutsuCmd" -ForegroundColor $(if ($hasJutsuCmd) { "Green" } else { "Red" })

# ============================================================
# STEP 2: FIX - convert lambda to braced block with both commands
# ============================================================
Write-Host ""
Write-Host "[2/3] Applying fix..." -ForegroundColor Yellow

if (-not $hasJutsuCmd) {
    $search = "(dispatcher, registryAccess, environment) -> NinjaCommand.register(dispatcher));"
    $replace = @"
(dispatcher, registryAccess, environment) -> {
            NinjaCommand.register(dispatcher);
            com.example.shinobicore.command.JutsuTestCommand.register(dispatcher);
        });
"@

    if ($c.Contains($search)) {
        $c = $c.Replace($search, $replace)
        [System.IO.File]::WriteAllText($path, $c, $utf8NoBom)
        Write-Host "[FIXED] Lambda converted to braced block, JutsuTestCommand registered" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Exact lambda not found. Trying fallback..." -ForegroundColor Yellow
        # Fallback: insert a brand-new callback registration after the NinjaCommand line
        $search2 = "NinjaCommand.register(dispatcher));"
        $replace2 = @"
NinjaCommand.register(dispatcher));
        CommandRegistrationCallback.EVENT.register((d2, r2, e2) -> com.example.shinobicore.command.JutsuTestCommand.register(d2));
"@
        if ($c.Contains($search2)) {
            $c = $c.Replace($search2, $replace2)
            [System.IO.File]::WriteAllText($path, $c, $utf8NoBom)
            Write-Host "[FIXED] Added separate callback for JutsuTestCommand" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Could not find registration line. Manual edit needed!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "[OK] Already wired, nothing to do" -ForegroundColor Green
}

# ============================================================
# STEP 3: VERIFY - show patched region
# ============================================================
Write-Host ""
Write-Host "[3/3] Verification:" -ForegroundColor Yellow
$c2 = [System.IO.File]::ReadAllText($path, $utf8NoBom)
$lines2 = $c2 -split "`n"
for ($i = 0; $i -lt $lines2.Count; $i++) {
    if ($lines2[$i] -match 'CommandRegistrationCallback|JutsuTestCommand|NinjaCommand\.register') {
        Write-Host ("  {0,4}: {1}" -f ($i + 1), $lines2[$i].TrimEnd()) -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Done. Run:" -ForegroundColor Cyan
Write-Host "    .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "    .\gradlew.bat runClient" -ForegroundColor Yellow
Write-Host "  Then test: /shinobicore jutsu list" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan