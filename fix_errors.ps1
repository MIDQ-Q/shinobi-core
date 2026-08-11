# ============================================================
# SHINOBI CORE — FIX COMPILATION ERRORS
# Исправляет: дубликат ATTUNEMENT_ID, отсутствующий SKILL_TREE
# ============================================================

$root = "E:\Games\mod"
$src = "$root\src\main\java\com\example\shinobicore"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host "=== FIXING COMPILATION ERRORS ===" -ForegroundColor Cyan

# ============================================================
# 1. ModPackets.java — убрать дубликат ATTUNEMENT_ID
# ============================================================
Write-Host "`n[1/3] Fixing ModPackets.java (duplicate ATTUNEMENT_ID)..." -ForegroundColor Yellow

$file = "$src\network\ModPackets.java"
$content = [System.IO.File]::ReadAllText($file, $utf8NoBom)
$original = $content

# Считаем вхождения ATTUNEMENT_ID
$matches = [regex]::Matches($content, 'public static final Identifier ATTUNEMENT_ID')
$count = $matches.Count
Write-Host "  Found $count occurrences of ATTUNEMENT_ID" -ForegroundColor Gray

if ($count -gt 1) {
    # Оставляем только первое вхождение, удаляем остальные строки
    $lines = $content -split "`r`n"
    $newLines = New-Object System.Collections.ArrayList
    $firstFound = $false
    foreach ($line in $lines) {
        if ($line -match 'public static final Identifier ATTUNEMENT_ID') {
            if (-not $firstFound) {
                [void]$newLines.Add($line)
                $firstFound = $true
                Write-Host "  Keeping first ATTUNEMENT_ID" -ForegroundColor Gray
            } else {
                Write-Host "  Removing duplicate: $($line.Trim())" -ForegroundColor Gray
                # пропускаем строку
            }
        } else {
            [void]$newLines.Add($line)
        }
    }
    $content = $newLines -join "`r`n"
}

# Также проверяем дубликаты TREE_SYNC_ID и UNLOCK_NODE_ID
foreach ($id in @("TREE_SYNC_ID", "UNLOCK_NODE_ID")) {
    $matches = [regex]::Matches($content, "public static final Identifier $id")
    if ($matches.Count -gt 1) {
        Write-Host "  Found $($matches.Count) occurrences of $id, deduplicating..." -ForegroundColor Gray
        $lines = $content -split "`r`n"
        $newLines = New-Object System.Collections.ArrayList
        $firstFound = $false
        foreach ($line in $lines) {
            if ($line -match "public static final Identifier $id") {
                if (-not $firstFound) {
                    [void]$newLines.Add($line)
                    $firstFound = $true
                }
            } else {
                [void]$newLines.Add($line)
            }
        }
        $content = $newLines -join "`r`n"
    }
}

if ($content -ne $original) {
    [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
    Write-Host "  ModPackets.java fixed!" -ForegroundColor Green
} else {
    Write-Host "  ModPackets.java was already OK" -ForegroundColor Gray
}

# ============================================================
# 2. KeyBindings.java — добавить SKILL_TREE
# ============================================================
Write-Host "`n[2/3] Fixing KeyBindings.java (missing SKILL_TREE)..." -ForegroundColor Yellow

$file = "$src\client\KeyBindings.java"
$content = [System.IO.File]::ReadAllText($file, $utf8NoBom)
$original = $content

# Проверка: есть ли уже SKILL_TREE?
if ($content -match 'public static KeyBinding SKILL_TREE') {
    Write-Host "  SKILL_TREE already declared" -ForegroundColor Gray
} else {
    # Вставляем ПОСЛЕ SWITCH_STYLE (любой комментарий)
    # Ищем строку содержащую "SWITCH_STYLE" в объявлении поля
    $lines = $content -split "`r`n"
    $newLines = New-Object System.Collections.ArrayList
    $inserted = $false
    foreach ($line in $lines) {
        [void]$newLines.Add($line)
        if ($line -match 'public static KeyBinding SWITCH_STYLE' -and -not $inserted) {
            [void]$newLines.Add("    public static KeyBinding SKILL_TREE;")
            $inserted = $true
            Write-Host "  Added SKILL_TREE declaration after SWITCH_STYLE" -ForegroundColor Gray
        }
    }
    $content = $newLines -join "`r`n"
}

# Проверка: есть ли регистрация SKILL_TREE?
if ($content -match 'SKILL_TREE = KeyBindingHelper.registerKeyBinding') {
    Write-Host "  SKILL_TREE already registered" -ForegroundColor Gray
} else {
    # Ищем блок SWITCH_STYLE регистрации и добавляем SKILL_TREE после него
    # Маркер: строка, заканчивающаяся на COMBAT_CATEGORY));
    $marker = '"key.shinobicore.switch_style", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, COMBAT_CATEGORY));'
    $insert = @'
"key.shinobicore.switch_style", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, COMBAT_CATEGORY));

        SKILL_TREE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.skill_tree", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_J, CATEGORY));
'@
    if ($content.Contains($marker)) {
        $content = $content.Replace($marker, $insert)
        Write-Host "  Added SKILL_TREE registration (J key)" -ForegroundColor Gray
    } else {
        # Запасной вариант: вставить в конец метода register()
        Write-Host "  WARNING: could not find SWITCH_STYLE marker, trying fallback..." -ForegroundColor Yellow
        $lines = $content -split "`r`n"
        $newLines = New-Object System.Collections.ArrayList
        $inserted = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            [void]$newLines.Add($lines[$i])
            # Ищем последнюю строку с registerKeyBinding в методе register()
            if (-not $inserted -and $lines[$i] -match 'registerKeyBinding' -and $lines[$i] -match 'COMBAT_CATEGORY') {
                [void]$newLines.Add("")
                [void]$newLines.Add('        SKILL_TREE = KeyBindingHelper.registerKeyBinding(new KeyBinding(')
                [void]$newLines.Add('            "key.shinobicore.skill_tree", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_J, CATEGORY));')
                $inserted = $true
                Write-Host "  Added SKILL_TREE via fallback" -ForegroundColor Gray
            }
        }
        $content = $newLines -join "`r`n"
    }
}

if ($content -ne $original) {
    [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
    Write-Host "  KeyBindings.java fixed!" -ForegroundColor Green
} else {
    Write-Host "  KeyBindings.java was already OK" -ForegroundColor Gray
}

# ============================================================
# 3. ClientInputHandler.java — добавить обработчик SKILL_TREE
# ============================================================
Write-Host "`n[3/3] Fixing ClientInputHandler.java (SKILL_TREE handler)..." -ForegroundColor Yellow

$file = "$src\client\ClientInputHandler.java"
$content = [System.IO.File]::ReadAllText($file, $utf8NoBom)
$original = $content

# Проверка: есть ли уже обработчик?
if ($content -match 'KeyBindings\.SKILL_TREE\.wasPressed') {
    Write-Host "  SKILL_TREE handler already present" -ForegroundColor Gray
} else {
    # Ищем блок PROGRESSION и добавляем SKILL_TREE после него
    $marker = 'client.setScreen(new ProgressionScreen());'
    $insert = @'
client.setScreen(new ProgressionScreen());
        }

        // === ДРЕВО ПРОКАЧКИ (J) ===
        if (KeyBindings.SKILL_TREE.wasPressed()) {
            ShinobiCore.LOGGER.info("[INPUT] SKILL_TREE (J) pressed");
            client.setScreen(new SkillTreeScreen());
'@
    if ($content.Contains($marker)) {
        $content = $content.Replace($marker, $insert)
        Write-Host "  Added SKILL_TREE handler" -ForegroundColor Gray
    } else {
        Write-Host "  ERROR: could not find ProgressionScreen marker!" -ForegroundColor Red
    }
}

# Проверка импорта SkillTreeScreen
if ($content -match 'import com\.example\.shinobicore\.client\.SkillTreeScreen') {
    Write-Host "  SkillTreeScreen import already present" -ForegroundColor Gray
} else {
    # Добавить импорт
    $importMarker = "import com.example.shinobicore.client.ShinobiCoreClient;"
    if ($content.Contains($importMarker)) {
        $content = $content.Replace($importMarker, $importMarker + "`nimport com.example.shinobicore.client.SkillTreeScreen;")
    } else {
        # Ищем любой import
        $content = $content.Replace("import com.example.shinobicore.ShinobiCore;",
            "import com.example.shinobicore.ShinobiCore;`nimport com.example.shinobicore.client.SkillTreeScreen;")
    }
    Write-Host "  Added SkillTreeScreen import" -ForegroundColor Gray
}

if ($content -ne $original) {
    [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
    Write-Host "  ClientInputHandler.java fixed!" -ForegroundColor Green
} else {
    Write-Host "  ClientInputHandler.java was already OK" -ForegroundColor Gray
}

# ============================================================
# ГОТОВО
# ============================================================
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  FIXES APPLIED!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run: cd E:\Games\mod; .\gradlew.bat build" -ForegroundColor Cyan