#Requires -Version 5.1
<#
  tools/check_tree.ps1 — верификатор древа навыков против реестра дзюцу.

  Проверяет:
    1. jutsuId из tree.json без соответствующего файла в data/shinobicore/jutsu/
    2. файлы дзюцу, на которые древо не ссылается
    3. узлы с несуществующим prerequisite (requires) — ЭТО ОШИБКА
    4. дубликаты id узлов — ЭТО ОШИБКА
    5. идентификаторы узлов, на которые ссылается Java-код, но которых нет в дереве

  Exit code:
    0 — критических проблем нет (отсутствующие дзюцу = warning, пока контент не дописан)
    1 — найдены критические проблемы (п.3, п.4) или дерево/файлы не прочитались
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Strict
)
$ErrorActionPreference = 'Stop'

$treePath  = Join-Path $ProjectRoot 'src\main\resources\data\shinobicore\skill_tree\tree.json'
$jutsuDir  = Join-Path $ProjectRoot 'src\main\resources\data\shinobicore\jutsu'
$javaRoot  = Join-Path $ProjectRoot 'src\main\java'

if (-not (Test-Path -LiteralPath $treePath)) { Write-Host "tree.json not found: $treePath" -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $jutsuDir)) { Write-Host "jutsu dir not found: $jutsuDir" -ForegroundColor Red; exit 1 }

$treeRaw = [System.IO.File]::ReadAllText($treePath, [System.Text.Encoding]::UTF8)

# 1. Узлы древа
$nodeIds = New-Object System.Collections.ArrayList
foreach ($m in [regex]::Matches($treeRaw, '"id"\s*:\s*"([^"]+)"')) { [void]$nodeIds.Add($m.Groups[1].Value) }

# 2. jutsuId, на которые ссылается древо
$treeJutsu = New-Object System.Collections.ArrayList
foreach ($m in [regex]::Matches($treeRaw, '"jutsuId"\s*:\s*"([^"]+)"')) {
    $id = $m.Groups[1].Value -replace '^shinobicore:', ''
    if (-not $treeJutsu.Contains($id)) { [void]$treeJutsu.Add($id) }
}

# 3. id из файлов дзюцу
$fileJutsu = New-Object System.Collections.ArrayList
Get-ChildItem -LiteralPath $jutsuDir -Filter '*.json' -File | ForEach-Object {
    $raw = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    $m = [regex]::Match($raw, '"id"\s*:\s*"shinobicore:([^"]+)"')
    if ($m.Success) { [void]$fileJutsu.Add($m.Groups[1].Value) }
    else            { [void]$fileJutsu.Add([System.IO.Path]::GetFileNameWithoutExtension($_.Name)) }
}

$critical = 0

# ---------------------------------------------------------------------------
# BASELINE: известные отклонения, принятые ОСОЗНАННО и запланированные к fixe.
# Работает как lint-baseline: нарушения из списка дают WARNING (сборку не
# блокируют), ЛЮБОЕ НОВОЕ нарушение — CRITICAL. Уменьшайте список по мере
# реализации контента; пустой baseline = дерево полностью целостно.
# ---------------------------------------------------------------------------
$Baseline = @(
    # kek_ice_n УДАЛЁН (решение D): узел требовал несуществующий kg_ice
    # и был заблокирован навсегда. Вернуть в Спринте 29 вместе с узлом kg_ice,
    # TreePassives.kekkeiIce, NatureFusionRegistry и kekkei_ice_mirror.json.
    # JutsuCaster ссылается на sharingan_base в OR-ветке
    # (clan.contains("uchiha") || isNodeUnlocked("sharingan_base")).
    # Ветка мертва, но краша нет. Fix к Спринту 29: добавить узел в ветку uchiha.
    [pscustomobject]@{ Kind = 'coderef';  Value = 'sharingan_base';  Due = 'Sprint 29' }
)

function Test-Baselined {
    param([string]$Kind, [string]$Value)
    foreach ($b in $Baseline) {
        if ($b.Kind -eq $Kind -and $b.Value -eq $Value) { return $b.Due }
    }
    return $null
}

Write-Host ''
Write-Host '=== SKILL TREE VERIFICATION ===' -ForegroundColor Cyan
Write-Host ("nodes: {0}   jutsu referenced: {1}   jutsu files: {2}" -f $nodeIds.Count, $treeJutsu.Count, $fileJutsu.Count)

# --- Проверка 3: prerequisite ---
Write-Host ''
Write-Host '--- prerequisites ---'
$badReq = 0
$baseReq = 0
foreach ($m in [regex]::Matches($treeRaw, '"requires"\s*:\s*\[([^\]]*)\]')) {
    foreach ($r in [regex]::Matches($m.Groups[1].Value, '"([^"]+)"')) {
        $v = $r.Groups[1].Value
        if (-not $nodeIds.Contains($v)) {
            $due = Test-Baselined 'requires' $v
            if ($due) {
                Write-Host ("  baseline: requires unknown node '{0}'  (accepted, fix by {1})" -f $v, $due) -ForegroundColor DarkYellow
                $baseReq++
            } else {
                Write-Host ("  CRITICAL: requires unknown node '{0}'" -f $v) -ForegroundColor Red
                $badReq++
            }
        }
    }
}
if ($badReq -eq 0) { Write-Host ("  OK (baseline: {0})" -f $baseReq) -ForegroundColor Green } else { $critical += $badReq }

# --- Проверка 4: дубликаты id ---
Write-Host ''
Write-Host '--- duplicate node ids ---'
$dups = $nodeIds | Group-Object | Where-Object { $_.Count -gt 1 }
if ($dups) {
    foreach ($d in $dups) { Write-Host ("  CRITICAL: id '{0}' x{1}" -f $d.Name, $d.Count) -ForegroundColor Red; $critical++ }
} else { Write-Host '  OK' -ForegroundColor Green }

# --- Проверка 1: отсутствующие дзюцу ---
Write-Host ''
Write-Host '--- jutsu referenced by tree but missing ---'
$missing = @($treeJutsu | Where-Object { -not $fileJutsu.Contains($_) })
if ($missing.Count -eq 0) {
    Write-Host '  OK — все техники дерева существуют' -ForegroundColor Green
} else {
    Write-Host ("  WARNING: {0} missing" -f $missing.Count) -ForegroundColor Yellow
    $byBranch = $missing | ForEach-Object { ($_ -split '_')[0] } | Group-Object | Sort-Object Count -Descending
    foreach ($g in $byBranch) { Write-Host ("    {0,-14} {1}" -f $g.Name, $g.Count) }
    if ($Strict) { $critical += $missing.Count }
}

# --- Проверка 2: неиспользуемые файлы ---
Write-Host ''
Write-Host '--- jutsu files not referenced by tree ---'
$unused = @($fileJutsu | Where-Object { -not $treeJutsu.Contains($_) -and $_ -notlike 'test*' })
if ($unused.Count -eq 0) { Write-Host '  OK' -ForegroundColor Green }
else { Write-Host ("  INFO: {0} -> {1}" -f $unused.Count, ($unused -join ', ')) -ForegroundColor DarkGray }

# --- Проверка 5: ссылки из Java-кода ---
Write-Host ''
Write-Host '--- node ids referenced from Java but absent in tree ---'
$codeNodes = New-Object System.Collections.ArrayList
if (Test-Path -LiteralPath $javaRoot) {
    Get-ChildItem -LiteralPath $javaRoot -Recurse -Filter '*.java' -File | ForEach-Object {
        $raw = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
        foreach ($m in [regex]::Matches($raw, 'isNodeUnlocked\("([a-z0-9_]+)"\)')) {
            $id = $m.Groups[1].Value
            if (-not $codeNodes.Contains($id)) { [void]$codeNodes.Add($id) }
        }
    }
}
$absent = @($codeNodes | Where-Object { -not $nodeIds.Contains($_) })
if ($absent.Count -eq 0) {
    Write-Host '  OK' -ForegroundColor Green
} else {
    $badRef = 0; $baseRef = 0
    foreach ($a in $absent) {
        $due = Test-Baselined 'coderef' $a
        if ($due) {
            Write-Host ("  baseline: code references node '{0}' absent from tree.json  (accepted, fix by {1})" -f $a, $due) -ForegroundColor DarkYellow
            $baseRef++
        } else {
            Write-Host ("  CRITICAL: code references node '{0}' which is not in tree.json" -f $a) -ForegroundColor Red
            $badRef++
        }
    }
    if ($badRef -eq 0) { Write-Host ("  OK (baseline: {0})" -f $baseRef) -ForegroundColor Green } else { $critical += $badRef }
}

Write-Host ''
if ($critical -gt 0) {
    Write-Host ("RESULT: FAIL ({0} critical)" -f $critical) -ForegroundColor Red
    exit 1
}
if ($Baseline.Count -gt 0) {
    Write-Host ("RESULT: PASS (с {0} baseline-отклонениями; массив Baseline в начале файла)" -f $Baseline.Count) -ForegroundColor Green
} else {
    Write-Host 'RESULT: PASS (baseline пуст — дерево полностью целостно)' -ForegroundColor Green
}
exit 0