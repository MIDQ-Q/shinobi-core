$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = "$root\src\main\java\com\example\shinobicore"
$clientDir = "$srcBase\client"
$configDir = "$srcBase\config"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  ROLLBACK: Removing S3-05 & S3-06 from code" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ============ 1. Delete S3-05/S3-06 files ============
Write-Host "[1/3] Deleting S3-05/S3-06 files..." -ForegroundColor Yellow

$filesToDelete = @(
    "$configDir\HudConfig.java",
    "$clientDir\HudSettings.java",
    "$clientDir\HudSettingsScreen.java"
)

foreach ($f in $filesToDelete) {
    if (Test-Path $f) {
        Remove-Item $f -Force
        Write-Host "  [DEL] $([System.IO.Path]::GetFileName($f))" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] $([System.IO.Path]::GetFileName($f)) not found" -ForegroundColor Gray
    }
}

# ============ 2. Revert ProgressionScreen.java ============
Write-Host ""
Write-Host "[2/3] Reverting ProgressionScreen.java..." -ForegroundColor Yellow

$progFile = "$clientDir\ProgressionScreen.java"
if (Test-Path $progFile) {
    $c = [System.IO.File]::ReadAllText($progFile, $utf8)
    $c = $c.Replace("`r`n", "`n")
    
    # Remove HUD button from render()
    $hudButtonBlock = @'
        // === S3 HUD SETTINGS BUTTON ===
        int btnX = x0 + w - 45;
        int btnY = y0 + 4;
        int btnW = 40;
        int btnH = 12;
        boolean hoverBtn = inRect(mouseX, mouseY, btnX, btnY, btnW, btnH);
        context.fill(btnX, btnY, btnX + btnW, btnY + btnH, hoverBtn ? ACCENT : WOOD_DARK);
        drawCentered(context, "HUD", btnX + btnW / 2, btnY + 2, 0xFFFFFFFF);
'@
    
    if ($c.Contains($hudButtonBlock)) {
        $c = $c.Replace($hudButtonBlock, "")
        Write-Host "  [OK] Removed HUD button from render()" -ForegroundColor Green
    } else {
        # Try alternative: maybe it was added differently
        if ($c.Contains("S3 HUD SETTINGS BUTTON")) {
            # Remove line by line
            $lines = $c.Split("`n")
            $newLines = New-Object System.Collections.Generic.List[string]
            $skipMode = $false
            foreach ($line in $lines) {
                if ($line.Contains("S3 HUD SETTINGS BUTTON")) { $skipMode = $true; continue }
                if ($skipMode -and ($line.Contains("int btnX") -or $line.Contains("int btnY") -or $line.Contains("int btnW") -or $line.Contains("int btnH") -or $line.Contains("boolean hoverBtn") -or $line.Contains("context.fill(btnX") -or $line.Contains('drawCentered(context, "HUD"'))) { continue }
                if ($skipMode -and -not ($line.Contains("int btnX") -or $line.Contains("int btnY") -or $line.Contains("int btnW") -or $line.Contains("int btnH") -or $line.Contains("boolean hoverBtn") -or $line.Contains("context.fill(btnX") -or $line.Contains('drawCentered(context, "HUD"'))) { $skipMode = $false }
                $newLines.Add($line)
            }
            $c = ($newLines -join "`n")
            Write-Host "  [OK] Removed HUD button from render() (alt mode)" -ForegroundColor Green
        } else {
            Write-Host "  [SKIP] HUD button not found in render()" -ForegroundColor Gray
        }
    }
    
    # Remove HUD button click handler from mouseClicked()
    $hudClickBlock = @'
        // === S3 HUD SETTINGS BUTTON CLICK ===
        int btnX = x0 + w - 45;
        int btnY = y0 + 4;
        int btnW = 40;
        int btnH = 12;
        if (inRect(mouseX, mouseY, btnX, btnY, btnW, btnH)) {
            if (this.client != null) {
                this.client.setScreen(new com.example.shinobicore.client.HudSettingsScreen(this));
            }
            return true;
        }
'@
    
    if ($c.Contains($hudClickBlock)) {
        $c = $c.Replace($hudClickBlock, "")
        Write-Host "  [OK] Removed HUD click handler from mouseClicked()" -ForegroundColor Green
    } else {
        if ($c.Contains("S3 HUD SETTINGS BUTTON CLICK")) {
            $lines = $c.Split("`n")
            $newLines = New-Object System.Collections.Generic.List[string]
            $skipMode = $false
            $braceCount = 0
            foreach ($line in $lines) {
                if ($line.Contains("S3 HUD SETTINGS BUTTON CLICK")) { $skipMode = $true; $braceCount = 0; continue }
                if ($skipMode) {
                    if ($line.Contains("{")) { $braceCount++ }
                    if ($line.Contains("}")) { $braceCount--; if ($braceCount -le 0) { $skipMode = $false; continue } }
                    continue
                }
                $newLines.Add($line)
            }
            $c = ($newLines -join "`n")
            Write-Host "  [OK] Removed HUD click handler from mouseClicked() (alt mode)" -ForegroundColor Green
        } else {
            Write-Host "  [SKIP] HUD click handler not found" -ForegroundColor Gray
        }
    }
    
    # Remove HudSettingsScreen import if present
    if ($c.Contains("import com.example.shinobicore.client.HudSettingsScreen;")) {
        $c = $c.Replace("import com.example.shinobicore.client.HudSettingsScreen;`n", "")
        Write-Host "  [OK] Removed HudSettingsScreen import" -ForegroundColor Green
    }
    
    # Remove HudConfig import if present
    if ($c.Contains("import com.example.shinobicore.config.HudConfig;")) {
        $c = $c.Replace("import com.example.shinobicore.config.HudConfig;`n", "")
        Write-Host "  [OK] Removed HudConfig import" -ForegroundColor Green
    }
    
    [System.IO.File]::WriteAllText($progFile, $c, $utf8)
    Write-Host "  [OK] ProgressionScreen.java saved" -ForegroundColor Green
} else {
    Write-Host "  [MISS] ProgressionScreen.java not found" -ForegroundColor Red
}

# ============ 3. Clean ChakraHudRenderer.java ============
Write-Host ""
Write-Host "[3/3] Checking ChakraHudRenderer.java for S3-05 references..." -ForegroundColor Yellow

$chakraFile = "$clientDir\ChakraHudRenderer.java"
if (Test-Path $chakraFile) {
    $c = [System.IO.File]::ReadAllText($chakraFile, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $changed = $false
    
    # Remove HudConfig import
    if ($c.Contains("import com.example.shinobicore.config.HudConfig;")) {
        $c = $c.Replace("import com.example.shinobicore.config.HudConfig;`n", "")
        $changed = $true
        Write-Host "  [OK] Removed HudConfig import" -ForegroundColor Green
    }
    
    # Remove HudSettings references
    if ($c.Contains("HudConfig")) {
        $lines = $c.Split("`n")
        $newLines = New-Object System.Collections.Generic.List[string]
        foreach ($line in $lines) {
            if ($line.Contains("HudConfig")) { continue }
            $newLines.Add($line)
        }
        $c = ($newLines -join "`n")
        $changed = $true
        Write-Host "  [OK] Removed HudConfig references" -ForegroundColor Green
    }
    
    if ($changed) {
        [System.IO.File]::WriteAllText($chakraFile, $c, $utf8)
        Write-Host "  [OK] ChakraHudRenderer.java saved" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] No S3-05 references found" -ForegroundColor Gray
    }
} else {
    Write-Host "  [MISS] ChakraHudRenderer.java not found" -ForegroundColor Red
}

# ============ 4. Also clean ShinobiCoreClient.java if needed ============
$clientMainFile = "$clientDir\ShinobiCoreClient.java"
if (Test-Path $clientMainFile) {
    $c = [System.IO.File]::ReadAllText($clientMainFile, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $changed = $false
    
    if ($c.Contains("import com.example.shinobicore.config.HudConfig;")) {
        $c = $c.Replace("import com.example.shinobicore.config.HudConfig;`n", "")
        $changed = $true
    }
    if ($c.Contains("import com.example.shinobicore.client.HudSettings;")) {
        $c = $c.Replace("import com.example.shinobicore.client.HudSettings;`n", "")
        $changed = $true
    }
    if ($c.Contains("HudConfig.load()")) {
        $lines = $c.Split("`n")
        $newLines = New-Object System.Collections.Generic.List[string]
        foreach ($line in $lines) {
            if ($line.Contains("HudConfig.load()")) { continue }
            $newLines.Add($line)
        }
        $c = ($newLines -join "`n")
        $changed = $true
    }
    
    if ($changed) {
        [System.IO.File]::WriteAllText($clientMainFile, $c, $utf8)
        Write-Host "  [OK] Cleaned ShinobiCoreClient.java" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] ShinobiCoreClient.java already clean" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  ROLLBACK COMPLETE" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "S3-05 & S3-06 fully removed from codebase." -ForegroundColor White
Write-Host "Next: Run .\gradlew.bat build to verify." -ForegroundColor Yellow
Write-Host ""