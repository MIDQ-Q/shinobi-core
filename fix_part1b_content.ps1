$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$jutsuDir = "$root\src\main\resources\data\shinobicore\jutsu"
$treeFile = "$root\src\main\resources\data\shinobicore\skill_tree\tree.json"

function Read-File($p) { return [System.IO.File]::ReadAllText($p, $utf8) }
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $($p.Replace($root, ''))" }

Write-Host "=============================================="
Write-Host "  PHASE G2.5 (Part B): CONTENT CLEANUP"
Write-Host "=============================================="

# ============ 1. Удаление дубликатов техник ============
# Формат: удаляемый файл -> причина (что остаётся вместо него)
$dupes = @{
    "fire_prison"           = "дубль fire_flame_prison (древо ссылается на flame_prison)"
    "fire_scorched"         = "дубль fire_scorched_earth (древо ссылается на scorched_earth)"
    "fire_explosive_flame"  = "дубль fire_exploding (у того реальный взрыв)"
    "water_prison"          = "дубль water_prison_tech (древо ссылается на _tech)"
    "water_maelstrom_tech"  = "дубль water_maelstrom (объединяем, узел древа удаляется)"
    "water_rain"            = "дубль water_rain_arrows (древо ссылается на arrows)"
}
$removed = 0
foreach ($k in $dupes.Keys) {
    $p = "$jutsuDir\$k.json"
    if (Test-Path $p) {
        Remove-Item $p -Force
        Write-Host "[DEL] $k.json  ($($dupes[$k]))"
        $removed++
    } else {
        Write-Host "[SKIP] $k.json not found"
    }
}
Write-Host "[OK] Removed $removed duplicate jutsu files"

# ============ 2. Древо навыков: удаляем осиротевший узел water_mael_t_n ============
$tree = Read-File $treeFile
$before = $tree
$tree = $tree -replace ',\s*\{"id":"water_mael_t_n"[^}]*\}', ''
$tree = $tree -replace '\{"id":"water_mael_t_n"[^}]*\},\s*', ''
if ($tree -ne $before) {
    Write-File $treeFile $tree
    Write-Host "[OK] tree.json: node water_mael_t_n removed"
} else {
    Write-Host "[SKIP] node water_mael_t_n not found in tree.json"
}

# ============ 3. Итоговая статистика ============
$count = @(Get-ChildItem -Path $jutsuDir -Filter *.json).Count
Write-Host ""
Write-Host "Jutsu files now: $count"

# ============ 4. Заметки фазы ============
$notes = @'
# Phase G2.5 — Технический долг (выполнено)

## Критичные фиксы
1. **SubstitutionBehavior** — кулдаун был `static long` (один на весь сервер).
   Теперь `Map<UUID, Long>` — у каждого игрока свой кулдаун. Критично для мультиплеера.
2. **MobEntityAccessor** — миксин не был зарегистрирован в shinobicore.mixins.json
   (прошлый скрипт вставлял его в несуществующую секцию "client").
   Без него призывы волков/голема крашились бы ClassCastException.

## Чистка кода
3. Удалены дублирующиеся import во всех Java-файлах
   (ShinobiCoreClient, ModPackets, NinjaProjectileEntity, TaijutsuClientHandler и др.)
4. ShinobiCoreClient: убран повторный `ChakraAuraRenderer.register()`
5. ShinobiCore: убрана повторная регистрация genjutsu-behavior
6. KatanaDeflectMixin: тройная дубль-строка проверки кулдауна -> одна
7. Удалён пустой файл client/combat/animations/TaijutsuAnimations.java

## Совместимость с 1.20.1
8. Java приведена к единому значению: байткод 17, fabric.mod.json ">=17",
   mixins.json "JAVA_17" (раньше: байткод 17, но требование >=21 — несоответствие)

## Контент
9. Удалены 6 дублирующихся техник:
   fire_prison, fire_scorched, fire_explosive_flame,
   water_prison, water_maelstrom_tech, water_rain
10. Из древа навыков удалён осиротевший узел water_mael_t_n

## Принятые решения (зафиксированы)
- Никаких новых зависимостей — только процедурный рендеринг (GeckoLib отклонён)
- Бой: souls-like в темпе Dark Souls 3
- Лор: оригинальная вселенная в духе Наруто + средневековая Япония
- Приоритет: мультиплеер; порядок фаз G3 -> G4 -> G2B -> G5
- Додрюцу/биджу/ранги — пре-релиз; фуиндзюцу — постепенно; проклятая печать — вместе с Sage Mode

## Следующий шаг
**Фаза G3: 3D-модели снарядов** (процедурный рендеринг, без зависимостей):
RasenganEntity -> FireBallEntity -> WaterDragonEntity -> Shuriken уже готов
'@
Write-File "$root\PHASE_G25_NOTES.md" $notes

Write-Host ""
Write-Host "=============================================="
Write-Host "  PART B DONE"
Write-Host "=============================================="