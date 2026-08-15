# ============================================================
#  PHASE 4: КОНФИГ, БАЛАНС, ДОКУМЕНТАЦИЯ
# ============================================================
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$java = "E:\Games\mod\src\main\java\com\example\shinobicore"
$root = "E:\Games\mod"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace('E:\Games\mod\', ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    if ($c.Contains($new)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $c.Contains($old)) { Write-Host "[FAIL] pattern: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host "`n=== PHASE 4: CONFIG + BALANCE + DOCS ===`n" -ForegroundColor Cyan

# ================================================================
# 1. ModConfig.java — секция kenjutsu
# ================================================================
Write-Host "[1/3] Patching ModConfig.java..." -ForegroundColor White

Patch-File "$java\config\ModConfig.java" `
    "public Taijutsu taijutsu = new Taijutsu();" `
    "public Taijutsu taijutsu = new Taijutsu();
    public Kenjutsu kenjutsu = new Kenjutsu();

    public static class Kenjutsu {
        public float baseDamage = 6.0f;
        public float damagePerLevel = 0.35f;
        public float jumpAttackMult = 2.5f;
        public float sprintAttackMult = 1.6f;
        public float chakraModeDamageMult = 1.3f;
        public float chakraCostPerHit = 0.5f;
        public float chakraCostJump = 3.0f;
        public float chakraCostSprint = 1.5f;
        public float parryChakraGainSeigan = 2.5f;
        public float iaiDashDamageMult = 3.0f;
        public float iaiDashChakraCost = 5.0f;
        public int maxComboSteps = 6;
        public float comboChakraScaling = 0.05f;
        public float maxComboChakraBonus = 0.5f;
    }"

# ================================================================
# 2. lang file — русские переводы
# ================================================================
Write-Host "[2/3] Creating ru_ru.json lang file..." -ForegroundColor White

$langDir = "$root\src\main\resources\assets\shinobicore\lang"
if (-not (Test-Path $langDir)) { New-Item -ItemType Directory -Path $langDir -Force | Out-Null }

Write-File "$langDir\ru_ru.json" @'
{
    "key.shinobicore.meditate": "Медитация (M)",
    "key.shinobicore.progression": "Прокачка ниндзя (K)",
    "key.shinobicore.chakra_mode": "Режим чакры (L)",
    "key.shinobicore.cast": "Каст A (R)",
    "key.shinobicore.cast_b": "Каст B (T)",
    "key.shinobicore.cycle_slot": "Цикл слотов A (G)",
    "key.shinobicore.cycle_b": "Цикл слотов B (H)",
    "key.shinobicore.dodge_left": "Уворот влево (Z)",
    "key.shinobicore.dodge_right": "Уворот вправо (C)",
    "key.shinobicore.crawl": "Ползание (N)",
    "key.shinobicore.kick": "Удар ногой (V)",
    "key.shinobicore.switch_style": "Смена стиля (B)",
    "key.shinobicore.switch_stance": "Смена стойки (F)",
    "key.shinobicore.katana_deflect": "Парирование (X)",
    "key.shinobicore.iai_dash": "Иай-рывок (R)",
    "key.shinobicore.toggle_sensory": "Сенсорика (Y)",
    "key.categories.shinobicore": "ShinobiCore",
    "key.categories.shinobicore.combat": "ShinobiCore - Бой",
    "item.shinobicore.katana": "Катана",
    "item.shinobicore.shuriken": "Сюрикен",
    "item.shinobicore.kunai": "Кунай",
    "item.shinobicore.scroll": "Свиток"
}
'@

Write-File "$langDir\en_us.json" @'
{
    "key.shinobicore.meditate": "Meditate (M)",
    "key.shinobicore.progression": "Ninja Progression (K)",
    "key.shinobicore.chakra_mode": "Chakra Mode (L)",
    "key.shinobicore.cast": "Cast A (R)",
    "key.shinobicore.cast_b": "Cast B (T)",
    "key.shinobicore.cycle_slot": "Cycle Slots A (G)",
    "key.shinobicore.cycle_b": "Cycle Slots B (H)",
    "key.shinobicore.dodge_left": "Dodge Left (Z)",
    "key.shinobicore.dodge_right": "Dodge Right (C)",
    "key.shinobicore.crawl": "Crawl (N)",
    "key.shinobicore.kick": "Kick (V)",
    "key.shinobicore.switch_style": "Switch Style (B)",
    "key.shinobicore.switch_stance": "Switch Stance (F)",
    "key.shinobicore.katana_deflect": "Parry (X)",
    "key.shinobicore.iai_dash": "Iai Dash (R)",
    "key.shinobicore.toggle_sensory": "Sensory (Y)",
    "key.categories.shinobicore": "ShinobiCore",
    "key.categories.shinobicore.combat": "ShinobiCore - Combat",
    "item.shinobicore.katana": "Katana",
    "item.shinobicore.shuriken": "Shuriken",
    "item.shinobicore.kunai": "Kunai",
    "item.shinobicore.scroll": "Scroll"
}
'@

# ================================================================
# 3. Обновить CONTEXT.md
# ================================================================
Write-Host "[3/3] Updating CONTEXT.md..." -ForegroundColor White

$contextFile = "$root\CONTEXT.md"
if (Test-Path $contextFile) {
    $ctx = [System.IO.File]::ReadAllText($contextFile, $utf8)
    $appendBlock = @'

## Фаза: Боевая система катаны v2 (Добавлено скриптами phase_combat_1-4)
### Комбо:
- 6 шагов комбо (вместо 4), шаг 5 = финишер 360°
- Удар в прыжке (LMB в воздухе): x2.5 урон, slam down
- Удар с бега (LMB при спринте): x1.6 урон, push forward
- Iai Dash (R в стойке Iai): рывок + x3.0 урон

### Стойки:
- AGGRESSIVE: x1.15 урон, x1.25 скорость, x1.4 усталость
- SEIGAN: x0.85 урон, парирование, +0.5 чакры за парирование, пассивный реген чакры
- IAI: x1.0 урон, x0.85 скорость, x1.5 чакра-урон, Iai Dash

### Чакра-интеграция:
- Чакра-режим усиливает удары (множитель зависит от стойки)
- Chakra Combo: последовательные удары в чакра-режиме дают +5% за удар (макс +50%)
- Спецудары стоят чакру (jump=3, sprint=1.5, iai dash=5)
- Парирование в Seigan генерирует чакру

### Клавиши:
- R (в стойке Iai): Iai Dash
- X: Парирование
- F: Смена стойки
'@
    if (-not $ctx.Contains("Боевая система катаны v2")) {
        $ctx += $appendBlock
        [System.IO.File]::WriteAllText($contextFile, $ctx, $utf8)
        Write-Host "[OK] CONTEXT.md updated" -ForegroundColor Green
        $ok++
    } else {
        Write-Host "[SKIP] CONTEXT.md already updated" -ForegroundColor Yellow
        $skip++
    }
}

# ================================================================
Write-Host "`n=== PHASE 4 COMPLETE: OK=$ok SKIP=$skip ERR=$err ===`n" -ForegroundColor Green
Write-Host "Final: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "Then:  .\gradlew.bat runClient" -ForegroundColor Yellow
Write-Host "Test:  /ninja set stat taijutsu 50 -> take katana -> LMB combos" -ForegroundColor Yellow
Write-Host "Test:  LMB in air = jump attack, LMB while sprinting = sprint attack" -ForegroundColor Yellow
Write-Host "Test:  F to switch stances, X to parry, R in Iai = dash" -ForegroundColor Yellow