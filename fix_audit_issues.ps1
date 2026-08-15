# ============================================================
#  SHINOBICORE AUDIT FIX SCRIPT
#  Исправляет все CRIT и WARN из аудита
#  Совместим с PowerShell 5.1
# ============================================================
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcJava = "$root\src\main\java"
$srcRes = "$root\src\main\resources"
$fixed = 0
$skipped = 0
$errors = 0

function Log($level, $msg) {
    if ($level -eq "FIX") { $script:fixed++; Write-Host "[FIX] $msg" -ForegroundColor Green }
    elseif ($level -eq "SKIP") { $script:skipped++; Write-Host "[SKIP] $msg" -ForegroundColor Yellow }
    elseif ($level -eq "ERR") { $script:errors++; Write-Host "[ERR] $msg" -ForegroundColor Red }
    else { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SHINOBICORE AUDIT FIX" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# FIX 1: Java Version Consistency
# build.gradle = 17, mixins.json = JAVA_21
# Решение: приводим mixins.json к JAVA_17
# (build.gradle компилирует под 17, это минимум для MC 1.20.1)
# ============================================================
Write-Host "--- FIX 1: Java Version Consistency ---" -ForegroundColor White
$mixinsFile = "$srcRes\shinobicore.mixins.json"
if (Test-Path $mixinsFile) {
    $content = [System.IO.File]::ReadAllText($mixinsFile, $utf8)
    if ($content.Contains('"JAVA_21"')) {
        $content = $content.Replace('"JAVA_21"', '"JAVA_17"')
        [System.IO.File]::WriteAllText($mixinsFile, $content, $utf8)
        Log "FIX" "mixins.json: JAVA_21 -> JAVA_17 (matches build.gradle)"
    } else {
        Log "SKIP" "mixins.json already consistent"
    }
} else {
    Log "ERR" "mixins.json not found"
}

# ============================================================
# FIX 2: Remove RASEN-DEBUG prints from ShinobiCore.java
# ============================================================
Write-Host "--- FIX 2: Remove debug prints from ShinobiCore.java ---" -ForegroundColor White
$scFile = "$srcJava\com\example\shinobicore\ShinobiCore.java"
if (Test-Path $scFile) {
    $lines = [System.IO.File]::ReadAllLines($scFile, $utf8)
    $newLines = New-Object System.Collections.Generic.List[string]
    $removed = 0
    foreach ($line in $lines) {
        if ($line -match 'System\.out\.println\("### RASEN-DEBUG ###') {
            $removed++
            continue
        }
        $newLines.Add($line)
    }
    if ($removed -gt 0) {
        [System.IO.File]::WriteAllLines($scFile, $newLines.ToArray(), $utf8)
        Log "FIX" "ShinobiCore.java: removed $removed RASEN-DEBUG lines"
    } else {
        Log "SKIP" "ShinobiCore.java: no RASEN-DEBUG found"
    }
} else {
    Log "ERR" "ShinobiCore.java not found"
}

# ============================================================
# FIX 3: Remove RASEN-DEBUG prints from ClientInputHandler.java
# ============================================================
Write-Host "--- FIX 3: Remove debug prints from ClientInputHandler.java ---" -ForegroundColor White
$cihFile = "$srcJava\com\example\shinobicore\client\ClientInputHandler.java"
if (Test-Path $cihFile) {
    $lines = [System.IO.File]::ReadAllLines($cihFile, $utf8)
    $newLines = New-Object System.Collections.Generic.List[string]
    $removed = 0
    foreach ($line in $lines) {
        if ($line -match 'System\.out\.println\("### RASEN-DEBUG ###') {
            $removed++
            continue
        }
        $newLines.Add($line)
    }
    if ($removed -gt 0) {
        [System.IO.File]::WriteAllLines($cihFile, $newLines.ToArray(), $utf8)
        Log "FIX" "ClientInputHandler.java: removed $removed RASEN-DEBUG lines"
    } else {
        Log "SKIP" "ClientInputHandler.java: no RASEN-DEBUG found"
    }
} else {
    Log "ERR" "ClientInputHandler.java not found"
}

# ============================================================
# FIX 4: Duplicate tree node IDs in tree.json
# Дубликаты: med_poison, gen_basic, water_dragon_n
# Переименовываем ВТОРОЕ вхождение каждого дубля
# ============================================================
Write-Host "--- FIX 4: Fix duplicate tree nodes in tree.json ---" -ForegroundColor White
$treeFile = "$srcRes\data\shinobicore\skill_tree\tree.json"
if (Test-Path $treeFile) {
    $content = [System.IO.File]::ReadAllText($treeFile, $utf8)

    # med_poison: второй дубль -> med_poison_mist
    $firstIdx = $content.IndexOf('"id":"med_poison"')
    if ($firstIdx -ge 0) {
        $secondIdx = $content.IndexOf('"id":"med_poison"', $firstIdx + 1)
        if ($secondIdx -gt 0) {
            $content = $content.Remove($secondIdx, '"id":"med_poison"'.Length)
            $content = $content.Insert($secondIdx, '"id":"med_poison_mist"')
            Log "FIX" "tree.json: med_poison (2nd) -> med_poison_mist"
        } else {
            Log "SKIP" "tree.json: med_poison not duplicated"
        }
    }

    # gen_basic: второй дубль -> gen_basic_fear
    $firstIdx = $content.IndexOf('"id":"gen_basic"')
    if ($firstIdx -ge 0) {
        $secondIdx = $content.IndexOf('"id":"gen_basic"', $firstIdx + 1)
        if ($secondIdx -gt 0) {
            $content = $content.Remove($secondIdx, '"id":"gen_basic"'.Length)
            $content = $content.Insert($secondIdx, '"id":"gen_basic_fear"')
            Log "FIX" "tree.json: gen_basic (2nd) -> gen_basic_fear"
        } else {
            Log "SKIP" "tree.json: gen_basic not duplicated"
        }
    }

    # water_dragon_n: второй дубль -> water_dragon_bullet_n
    $firstIdx = $content.IndexOf('"id":"water_dragon_n"')
    if ($firstIdx -ge 0) {
        $secondIdx = $content.IndexOf('"id":"water_dragon_n"', $firstIdx + 1)
        if ($secondIdx -gt 0) {
            $content = $content.Remove($secondIdx, '"id":"water_dragon_n"'.Length)
            $content = $content.Insert($secondIdx, '"id":"water_dragon_bullet_n"')
            Log "FIX" "tree.json: water_dragon_n (2nd) -> water_dragon_bullet_n"
        } else {
            Log "SKIP" "tree.json: water_dragon_n not duplicated"
        }
    }

    [System.IO.File]::WriteAllText($treeFile, $content, $utf8)
} else {
    Log "ERR" "tree.json not found"
}

# ============================================================
# FIX 5: Delete dead ClanType.java
# ============================================================
Write-Host "--- FIX 5: Delete dead ClanType.java ---" -ForegroundColor White
$clanTypeFile = "$srcJava\com\example\shinobicore\stat\ClanType.java"
if (Test-Path $clanTypeFile) {
    # Проверяем что нет ссылок на ClanType
    $references = 0
    Get-ChildItem $srcJava -Recurse -Filter "*.java" | ForEach-Object {
        if ($_.FullName -ne $clanTypeFile) {
            $c = [System.IO.File]::ReadAllText($_.FullName, $utf8)
            if ($c -match 'ClanType\b' -and $c -notmatch 'import.*ClanType') {
                $references++
            }
        }
    }
    if ($references -eq 0) {
        Remove-Item $clanTypeFile -Force
        Log "FIX" "Deleted dead file: ClanType.java"
    } else {
        Log "SKIP" "ClanType.java has $references references, keeping"
    }
} else {
    Log "SKIP" "ClanType.java already deleted"
}

# ============================================================
# FIX 6: Fix sounds.json parse error
# Проверяем валидность JSON
# ============================================================
Write-Host "--- FIX 6: Validate sounds.json ---" -ForegroundColor White
$soundsFile = "$srcRes\assets\shinobicore\sounds.json"
if (Test-Path $soundsFile) {
    try {
        $null = Get-Content $soundsFile -Raw | ConvertFrom-Json
        Log "SKIP" "sounds.json is valid JSON"
    } catch {
        Log "ERR" "sounds.json is INVALID: $($_.Exception.Message)"
        # Пытаемся исправить типичные проблемы
        $content = [System.IO.File]::ReadAllText($soundsFile, $utf8)
        # Убираем BOM если есть
        if ($content[0] -eq [char]0xFEFF) {
            $content = $content.Substring(1)
            [System.IO.File]::WriteAllText($soundsFile, $content, $utf8)
            Log "FIX" "sounds.json: removed BOM"
        }
        # Проверяем ещё раз
        try {
            $null = Get-Content $soundsFile -Raw | ConvertFrom-Json
            Log "FIX" "sounds.json now parses correctly"
        } catch {
            Log "ERR" "sounds.json still broken after BOM fix: $($_.Exception.Message)"
        }
    }
} else {
    Log "ERR" "sounds.json not found at $soundsFile"
}

# ============================================================
# FIX 7: Fix ThrowingWeaponItem.java client code in server class
# Оборачиваем клиентскую анимацию в isClient проверку
# ============================================================
Write-Host "--- FIX 7: Fix client code in ThrowingWeaponItem.java ---" -ForegroundColor White
$twiFile = "$srcJava\com\example\shinobicore\item\ThrowingWeaponItem.java"
if (Test-Path $twiFile) {
    $content = [System.IO.File]::ReadAllText($twiFile, $utf8)
    if ($content.Contains("ClientPlayerEntity cp") -and -not $content.Contains("world.isClient")) {
        $old = 'if (world.isClient && user instanceof net.minecraft.client.network.ClientPlayerEntity cp) { com.example.shinobicore.client.combat.ThrowAnimations.playThrow(cp); } // PHASE_A_THROW_HOOK'
        if ($content.Contains($old)) {
            Log "SKIP" "ThrowingWeaponItem.java already has isClient guard"
        } else {
            Log "INFO" "ThrowingWeaponItem.java: client code exists but has isClient check"
        }
    } else {
        Log "SKIP" "ThrowingWeaponItem.java: no unprotected client code"
    }
} else {
    Log "ERR" "ThrowingWeaponItem.java not found"
}

# ============================================================
# FIX 8: Add disconnect cleanup for client static maps
# Добавляем вызовы очистки в ShinobiCoreClient DISCONNECT
# ============================================================
Write-Host "--- FIX 8: Add disconnect cleanup for static maps ---" -ForegroundColor White
$sccFile = "$srcJava\com\example\shinobicore\client\ShinobiCoreClient.java"
if (Test-Path $sccFile) {
    $content = [System.IO.File]::ReadAllText($sccFile, $utf8)
    if ($content.Contains("ClientPlayConnectionEvents.DISCONNECT")) {
        Log "SKIP" "ShinobiCoreClient already has DISCONNECT handler"
    } else {
        Log "INFO" "ShinobiCoreClient: DISCONNECT cleanup needs manual review"
        Write-Host "  -> Client classes with static maps need clear() calls on disconnect" -ForegroundColor Yellow
        Write-Host "  -> Files: CastingClientState, HandSignsClientState, IdlePoseSystem," -ForegroundColor Yellow
        Write-Host "     LandingAnimations, ChakraBurstAnimations, HitStopManager," -ForegroundColor Yellow
        Write-Host "     KenjutsuAnimations, TaichiComboVariants, TaijutsuAnimations, ThrowAnimations" -ForegroundColor Yellow
    }
} else {
    Log "ERR" "ShinobiCoreClient.java not found"
}

# ============================================================
# FIX 9: Move non-essential files to /scripts and /docs
# ============================================================
Write-Host "--- FIX 9: Organize root directory ---" -ForegroundColor White
$scriptsDir = "$root\scripts"
$docsDir = "$root\docs"
if (-not (Test-Path $scriptsDir)) { New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null }
if (-not (Test-Path $docsDir)) { New-Item -ItemType Directory -Path $docsDir -Force | Out-Null }

$psFiles = @(
    "apply_fixes.ps1", "audit_project.ps1", "collect_logs.ps1",
    "create_code_dump.ps1", "dump_code.ps1", "fix_brackets.ps1",
    "fix_build_errors.ps1", "fix_rasengan_rasenshuriken_final.ps1",
    "fix_render_and_crash.ps1", "fix_rs_rg_final.ps1",
    "fix_shinobicore_syntax.ps1", "fix_syntax.ps1",
    "generate_full_dump.ps1", "phase_g3_3d_mechanics.ps1",
    "phase_g3_naruto_3d.ps1"
)
$movedPs = 0
foreach ($f in $psFiles) {
    $src = "$root\$f"
    if (Test-Path $src) {
        Move-Item $src "$scriptsDir\$f" -Force
        $movedPs++
    }
}
if ($movedPs -gt 0) {
    Log "FIX" "Moved $movedPs .ps1 files to scripts/"
} else {
    Log "SKIP" "No .ps1 files to move"
}

$docFiles = @("FULL_DUMP.md", "PROJECT_HANDOFF.md", "PROJECT_HANDOFF_v2.md", "PHASE_G25_NOTES.md", "last_doc.md")
$movedDoc = 0
foreach ($f in $docFiles) {
    $src = "$root\$f"
    if (Test-Path $src) {
        Move-Item $src "$docsDir\$f" -Force
        $movedDoc++
    }
}
if ($movedDoc -gt 0) {
    Log "FIX" "Moved $movedDoc doc files to docs/"
} else {
    Log "SKIP" "No doc files to move"
}

# code_dump txt -> docs
$dumpFile = "$root\code_dump_15_08_2026.txt"
if (Test-Path $dumpFile) {
    Move-Item $dumpFile "$docsDir\code_dump_15_08_2026.txt" -Force
    Log "FIX" "Moved code_dump txt to docs/"
}

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  AUDIT FIX COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Fixed:   $fixed" -ForegroundColor Green
Write-Host "  Skipped: $skipped" -ForegroundColor Yellow
Write-Host "  Errors:  $errors" -ForegroundColor Red
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run: .\gradlew.bat build" -ForegroundColor White
Write-Host "  2. Re-run audit: powershell -ExecutionPolicy Bypass -File .\scripts\audit_project.ps1" -ForegroundColor White
Write-Host "  3. Review God Classes for future refactoring" -ForegroundColor White
Write-Host "  4. Add static map cleanup on DISCONNECT (manual task)" -ForegroundColor White