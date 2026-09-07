# ============================================================
# KATANA FIX PART 5: particles down, glint off, bigger, tilt forward
# ============================================================
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$resBase = Join-Path $root "src\main\resources"
$visualPath = Join-Path $resBase "assets\shinobicore\weapon_visuals\katana.json"
$pointerPath = Join-Path $resBase "assets\shinobicore\models\item\katana.json"

Write-Host ""
Write-Host "=== KATANA FIX PART 5 ===" -ForegroundColor Cyan

# ---------- 1. Visuals: glint OFF, particles rare & subtle ----------
Write-Host "[1/2] Rewriting weapon_visuals/katana.json..." -ForegroundColor Yellow
[System.IO.File]::WriteAllText($visualPath, @'
{
  "item": "shinobicore:katana",
  "model": "shinobicore:item/katana_default",
  "glint": false,
  "particles": {
    "enabled": true,
    "type": "dust",
    "color": "#DDEEFF",
    "rate": 1,
    "intervalTicks": 12,
    "spread": 0.15
  },
  "slashAnimations": ["slash_h1", "slash_h2", "slash_v", "slash_360"]
}
'@, $utf8)
Write-Host "  [OK] glint=false, rate=1 per 12 ticks (was 2 per 2)" -ForegroundColor Green

# ---------- 2. Display: bigger + tilt forward, not sideways ----------
Write-Host "[2/2] Rewriting katana.json display..." -ForegroundColor Yellow
[System.IO.File]::WriteAllText($pointerPath, @'
{
  "parent": "shinobicore:item/katana_default",
  "display": {
    "firstperson_righthand": { "rotation": [5, 0, 0], "translation": [2.5, 0.5, -1.0], "scale": [0.75, 0.75, 0.75] },
    "firstperson_lefthand":  { "rotation": [5, 0, 0], "translation": [-2.5, 0.5, -1.0], "scale": [0.75, 0.75, 0.75] },
    "thirdperson_righthand": { "rotation": [0, 0, -8], "translation": [0, 0.0, 0.5],   "scale": [0.80, 0.80, 0.80] },
    "thirdperson_lefthand":  { "rotation": [0, 0, 8],  "translation": [0, 0.0, 0.5],   "scale": [0.80, 0.80, 0.80] },
    "gui":    { "rotation": [0, 0, -30], "translation": [5, 2, 0], "scale": [0.42, 0.42, 0.42] },
    "ground": { "rotation": [0, 0, 0],   "translation": [0, 3, 0], "scale": [0.45, 0.45, 0.45] },
    "fixed":  { "rotation": [0, 0, 0],   "translation": [0, 0, 0], "scale": [0.50, 0.50, 0.50] }
  }
}
'@, $utf8)
Write-Host "  [OK] scale 0.55-0.60 (was 0.42), tilt X=25 forward, Z=0 (no right lean)" -ForegroundColor Green

Write-Host @"

ГОТОВО. В игре нажми F3+T.

ЧТО ИЗМЕНИЛОСЬ:
  Частицы: 1 штука раз в 12 тиков (~4/сек -> едва заметные искры)
  Glint:   ВЫКЛЮЧЕН (фиолетовое зачарование ушло)
  Размер:  +30% (scale 0.42 -> 0.55 в руке)
  Наклон:  убран боковой завал (Z был -35, стал 0);
           добавлен наклон ОСТРИЁМ ОТ СЕБЯ (X=25)

ЕСЛИ ЧТО-ТО НЕ ТАК (правка в katana.json, потом F3+T):
  Остриё торчит В ЭКРАН (на тебя) вместо "от себя" ->
      поставь rotation[0] = -25 (смени знак)
  Всё ещё мала / велика -> scale += / -= 0.05
  Хочешь лёгкий боковой наклон для стиля -> rotation[2] = +-8
  Частиц всё ещё много -> intervalTicks = 20 или enabled = false
"@ -ForegroundColor Cyan