$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$fixedCount = 0

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  HOTFIX: Fix broken assignments (method() = value)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Паттерны: сломанное присваивание -> правильный сеттер
$fixes = @(
    @{ old = "ClientNinjaStateHolder.get().isDeflectHeld() = held;"; new = "ClientNinjaStateHolder.get().setDeflectHeld(held);" },
    @{ old = "ClientNinjaStateHolder.get().getKenjutsuStance() = next;"; new = "ClientNinjaStateHolder.get().setKenjutsuStance(next);" },
    @{ old = "ClientNinjaStateHolder.get().isChakraMode() = !ClientNinjaStateHolder.get().isChakraMode();"; new = "ClientNinjaStateHolder.get().setChakraMode(!ClientNinjaStateHolder.get().isChakraMode());" },
    @{ old = "ClientNinjaStateHolder.get().isChakraMode() = chakra;"; new = "ClientNinjaStateHolder.get().setChakraMode(chakra);" },
    @{ old = "ClientNinjaStateHolder.get().isSensoryEnabled() = newState;"; new = "ClientNinjaStateHolder.get().setSensoryEnabled(newState);" },
    @{ old = "ClientNinjaStateHolder.get().isSensoryEnabled() = sen;"; new = "ClientNinjaStateHolder.get().setSensoryEnabled(sen);" },
    @{ old = "ClientNinjaStateHolder.get().isMeditating() = packet.meditating();"; new = "ClientNinjaStateHolder.get().setMeditating(packet.meditating());" },
    @{ old = "ClientNinjaStateHolder.get().isDangerSense() = danger;"; new = "ClientNinjaStateHolder.get().setDangerSense(danger);" },
    @{ old = "ClientNinjaStateHolder.get().getHpLevel() = hp;"; new = "ClientNinjaStateHolder.get().setHpLevel(hp);" },
    @{ old = "ClientNinjaStateHolder.get().getSpeedLevel() = speed;"; new = "ClientNinjaStateHolder.get().setSpeedLevel(speed);" },
    @{ old = "ClientNinjaStateHolder.get().getJumpLevel() = jump;"; new = "ClientNinjaStateHolder.get().setJumpLevel(jump);" },
    @{ old = "ClientNinjaStateHolder.get().getSkillPoints() = sp;"; new = "ClientNinjaStateHolder.get().setSkillPoints(sp);" },
    @{ old = "ClientNinjaStateHolder.get().getReserveLevel() = resLvl;"; new = "ClientNinjaStateHolder.get().setReserveLevel(resLvl);" },
    @{ old = "ClientNinjaStateHolder.get().getReserveXp() = resXp;"; new = "ClientNinjaStateHolder.get().setReserveXp(resXp);" },
    @{ old = "ClientNinjaStateHolder.get().getClanId() = clan"; new = "ClientNinjaStateHolder.get().setClanId(clan" },
    @{ old = "ClientNinjaStateHolder.get().getAffinityId() = affinity"; new = "ClientNinjaStateHolder.get().setAffinityId(affinity" }
)

# Сканируем все Java файлы
$allJavaFiles = Get-ChildItem -Path $srcBase -Recurse -Filter "*.java"

foreach ($file in $allJavaFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, $utf8)
    $original = $content
    $content = $content.Replace("`r`n", "`n")
    $changed = $false

    foreach ($fix in $fixes) {
        $oldN = $fix.old.Replace("`r`n", "`n")
        $newN = $fix.new.Replace("`r`n", "`n")
        if ($content.Contains($oldN)) {
            $content = $content.Replace($oldN, $newN)
            $changed = $true
        }
    }

    # Дополнительная проверка: ищем общий паттерн "get().is" или "get().get" за которым следует " = "
    # Это ловит случаи, которые не попали в список выше
    $regexPattern = 'ClientNinjaStateHolder\.get\(\)\.(is|get)(\w+)\(\)\s*=\s*'
    $matches = [regex]::Matches($content, $regexPattern)
    if ($matches.Count -gt 0) {
        foreach ($m in $matches) {
            $prefix = $m.Groups[1].Value  # "is" или "get"
            $propName = $m.Groups[2].Value  # имя свойства
            # Определяем имя сеттера
            $setterName = if ($prefix -eq "is") {
                "set$propName"
            } else {
                "set$propName"
            }
            # Заменяем паттерн: нужно найти полную строку присваивания
            $brokenPattern = "ClientNinjaStateHolder.get().$prefix$propName() = "
            # Это сложнее, пропускаем для безопасности
        }
        Write-Host "  [WARN] $($file.Name): found $($matches.Count) potential broken assignments" -ForegroundColor Yellow
    }

    if ($changed) {
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8)
        Write-Host "  [FIXED] $($file.Name)" -ForegroundColor Green
        $fixedCount++
    }
}

# Специальная обработка KenjutsuClientHandler.java (строка 60)
Write-Host ""
Write-Host "  [CHECK] KenjutsuClientHandler.java specific fixes..." -ForegroundColor Yellow
$kenPath = Join-Path $srcBase "client\combat\KenjutsuClientHandler.java"
if (Test-Path $kenPath) {
    $content = [System.IO.File]::ReadAllText($kenPath, $utf8)
    $content = $content.Replace("`r`n", "`n")
    $changed = $false

    # Ищем любые оставшиеся присваивания вызовам методов
    if ($content -match 'ClientNinjaStateHolder\.get\(\)\.\w+\(\)\s*=') {
        # Читаем построчно и исправляем
        $lines = $content.Split("`n")
        $newLines = [System.Collections.ArrayList]::new()
        foreach ($line in $lines) {
            $newLine = $line
            # Паттерн: что-то = ClientNinjaStateHolder.get().getXxx() = value;
            if ($line -match '^\s*ClientNinjaStateHolder\.get\(\)\.is(\w+)\(\)\s*=\s*(.+);$') {
                $prop = $Matches[1]
                $val = $Matches[2]
                $newLine = $line -replace "ClientNinjaStateHolder\.get\(\)\.is$prop\(\)\s*=\s*$val;", "ClientNinjaStateHolder.get().set$prop($val);"
                $changed = $true
            }
            elseif ($line -match '^\s*ClientNinjaStateHolder\.get\(\)\.get(\w+)\(\)\s*=\s*(.+);$') {
                $prop = $Matches[1]
                $val = $Matches[2]
                $newLine = $line -replace "ClientNinjaStateHolder\.get\(\)\.get$prop\(\)\s*=\s*$val;", "ClientNinjaStateHolder.get().set$prop($val);"
                $changed = $true
            }
            [void]$newLines.Add($newLine)
        }
        if ($changed) {
            $content = $newLines -join "`n"
            [System.IO.File]::WriteAllText($kenPath, $content, $utf8)
            Write-Host "  [FIXED] KenjutsuClientHandler.java (regex pass)" -ForegroundColor Green
            $fixedCount++
        }
    } else {
        Write-Host "  [OK] KenjutsuClientHandler.java clean" -ForegroundColor Green
    }
}

# Аналогично для всех файлов с присваиваниями
Write-Host ""
Write-Host "  [CHECK] Global regex pass for broken assignments..." -ForegroundColor Yellow
$allJavaFiles = Get-ChildItem -Path $srcBase -Recurse -Filter "*.java"
foreach ($file in $allJavaFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, $utf8)
    $content = $content.Replace("`r`n", "`n")
    $changed = $false

    $lines = $content.Split("`n")
    $newLines = [System.Collections.ArrayList]::new()
    foreach ($line in $lines) {
        $newLine = $line
        if ($line -match 'ClientNinjaStateHolder\.get\(\)\.is(\w+)\(\)\s*=\s*(.+);$') {
            $prop = $Matches[1]
            $val = $Matches[2]
            $newLine = $line -replace "ClientNinjaStateHolder\.get\(\)\.is$prop\(\)\s*=\s*", "ClientNinjaStateHolder.get().set$prop("
            $newLine = $newLine -replace ";$", ");"
            $changed = $true
        }
        elseif ($line -match 'ClientNinjaStateHolder\.get\(\)\.get(\w+)\(\)\s*=\s*(.+);$') {
            $prop = $Matches[1]
            $val = $Matches[2]
            $newLine = $line -replace "ClientNinjaStateHolder\.get\(\)\.get$prop\(\)\s*=\s*", "ClientNinjaStateHolder.get().set$prop("
            $newLine = $newLine -replace ";$", ");"
            $changed = $true
        }
        [void]$newLines.Add($newLine)
    }
    if ($changed) {
        $content = $newLines -join "`n"
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8)
        Write-Host "  [FIXED] $($file.Name) (global regex)" -ForegroundColor Green
        $fixedCount++
    }
}

# BUILD
Write-Host ""
Write-Host "[BUILD] Running gradlew build..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] BUILD SUCCESSFUL!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed. Last 30 lines:" -ForegroundColor Red
        $out -split "`n" | Select-Object -Last 30 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  HOTFIX COMPLETE - Fixed $fixedCount files" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""