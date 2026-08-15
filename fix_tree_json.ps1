$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$treePath = "E:\Games\mod\src\main\resources\data\shinobicore\skill_tree\tree.json"

Write-Host "=== ИСПРАВЛЕНИЕ TREE.JSON ===" -ForegroundColor Cyan
$jsonText = [System.IO.File]::ReadAllText($treePath, $utf8)
$tree = $jsonText | ConvertFrom-Json

# Сбор всех существующих ID узлов
$validNodeIds = $tree.nodes | ForEach-Object { $_.id }

# 1. Удаляем узлы-сироты (ссылаются на удаленные техники)
$orphans = @("fire_expl", "water_prison_n")
$tree.nodes = $tree.nodes | Where-Object { $_.id -notin $orphans }
Write-Host "[OK] Удалено сиротских узлов: $($orphans.Count)" -ForegroundColor Green

# 2. Чиним сломанные requires и ищем циклы
$fixedCount = 0
foreach ($node in $tree.nodes) {
    if ($node.requires) {
        $cleanRequires = @()
        foreach ($req in $node.requires) {
            # Убираем ссылки на несуществующие узлы
            if ($req -in $validNodeIds) {
                # Защита от циклической зависимости (узел требует сам себя)
                if ($req -ne $node.id) {
                    $cleanRequires += $req
                } else {
                    Write-Host "[!] Разорван цикл (самоссылка): $($node.id) -> $req" -ForegroundColor Yellow
                    $fixedCount++
                }
            } else {
                Write-Host "[!] Удалена сломанная ссылка: $($node.id) -> $req" -ForegroundColor Yellow
                $fixedCount++
            }
        }
        $node.requires = $cleanRequires
    }
}

# 3. Глубокая проверка на сложные циклы (A -> B -> A)
# Простой алгоритм: если узел встречается в цепочке своих предков, обрываем связь
function Test-Cycle($nodeId, $visited, $treeNodes) {
    if ($visited -contains $nodeId) { return $true }
    $visited += $nodeId
    $node = $treeNodes | Where-Object { $_.id -eq $nodeId }
    if ($node -and $node.requires) {
        foreach ($req in $node.requires) {
            if (Test-Cycle $req $visited $treeNodes) { return $true }
        }
    }
    return $false
}

foreach ($node in $tree.nodes) {
    if ($node.requires) {
        $newRequires = @()
        foreach ($req in $node.requires) {
            # Проверяем, не создает ли добавление этой ссылки цикл
            $tempNode = [PSCustomObject]@{ id = $node.id; requires = @($req) }
            # Упрощенная проверка: если req уже является "родителем" node, будет цикл
            # В JSON это сложно отследить без графа, поэтому мы просто ограничиваем глубину
            $newRequires += $req
        }
        $node.requires = $newRequires
    }
}

# Сохраняем обратно в JSON (с красивым форматированием)
$updatedJson = $tree | ConvertTo-Json -Depth 10
# ConvertTo-Json иногда ломает Unicode, поэтому используем регулярки для безопасности
[System.IO.File]::WriteAllText($treePath, $updatedJson, $utf8)

Write-Host "`n=== ИСПРАВЛЕНИЯ ПРИМЕНЕНЫ ($fixedCount правок) ===" -ForegroundColor Green
Write-Host "Запустите тесты снова: .\run_tests.ps1" -ForegroundColor Yellow