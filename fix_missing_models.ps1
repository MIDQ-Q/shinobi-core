$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$modelsDir = "$root\src\main\resources\assets\shinobicore\models\item"
$langDir = "$root\src\main\resources\assets\shinobicore\lang"

$created = 0
$skipped = 0

function Write-Model($name, $content) {
    if (-not (Test-Path $modelsDir)) {
        New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null
    }
    $path = "$modelsDir\$name.json"
    if (Test-Path $path) {
        Write-Host "[SKIP] Already exists: models/item/$name.json" -ForegroundColor Yellow
        $script:skipped++
        return
    }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "[OK]   Created: models/item/$name.json" -ForegroundColor Green
    $script:created++
}

function Write-Lang($name, $content) {
    if (-not (Test-Path $langDir)) {
        New-Item -ItemType Directory -Path $langDir -Force | Out-Null
    }
    $path = "$langDir\$name.json"
    if (Test-Path $path) {
        Write-Host "[SKIP] Already exists: lang/$name.json" -ForegroundColor Yellow
        $script:skipped++
        return
    }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "[OK]   Created: lang/$name.json" -ForegroundColor Green
    $script:created++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX MISSING MODELS & TEXTURES (vanilla placeholders)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. KATANA — uses BuiltinItemRendererRegistry (BER)
#    Model must use "builtin/entity" parent
# ================================================================
Write-Host "--- KATANA (BER - 3D rendered in code) ---" -ForegroundColor White

Write-Model "katana" @'
{
    "parent": "builtin/entity",
    "gui_light": "front",
    "display": {
        "thirdperson_righthand": {
            "rotation": [0, -90, 55],
            "translation": [0, 7.5, 0.5],
            "scale": [1.7, 1.7, 0.85]
        },
        "thirdperson_lefthand": {
            "rotation": [0, 90, -55],
            "translation": [0, 7.5, 0.5],
            "scale": [1.7, 1.7, 0.85]
        },
        "firstperson_righthand": {
            "rotation": [0, -90, 25],
            "translation": [1.13, 3.2, 1.13],
            "scale": [1.4, 1.4, 0.68]
        },
        "firstperson_lefthand": {
            "rotation": [0, 90, -25],
            "translation": [1.13, 3.2, 1.13],
            "scale": [1.4, 1.4, 0.68]
        },
        "gui": {
            "rotation": [0, 0, -45],
            "translation": [0, 0, 0],
            "scale": [1.2, 1.2, 1.2]
        },
        "ground": {
            "rotation": [0, 0, 0],
            "translation": [0, 3, 0],
            "scale": [0.7, 0.7, 0.35]
        },
        "fixed": {
            "rotation": [0, 0, 180],
            "translation": [0, 0, 0],
            "scale": [1.5, 1.5, 0.75]
        }
    }
}
'@

Write-Model "katana_iron" @'
{
    "parent": "item/handheld",
    "textures": {
        "layer0": "minecraft:item/iron_sword"
    }
}
'@

Write-Model "katana_diamond" @'
{
    "parent": "item/handheld",
    "textures": {
        "layer0": "minecraft:item/diamond_sword"
    }
}
'@

Write-Model "katana_netherite" @'
{
    "parent": "item/handheld",
    "textures": {
        "layer0": "minecraft:item/netherite_sword"
    }
}
'@

Write-Model "katana_gold" @'
{
    "parent": "item/handheld",
    "textures": {
        "layer0": "minecraft:item/golden_sword"
    }
}
'@

# ================================================================
# 2. SHURIKEN — use iron_nugget texture
# ================================================================
Write-Host "--- SHURIKEN ---" -ForegroundColor White

Write-Model "shuriken" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/iron_nugget"
    },
    "display": {
        "thirdperson_righthand": {
            "rotation": [0, -90, 0],
            "translation": [0, 2, 0],
            "scale": [0.8, 0.8, 0.8]
        },
        "firstperson_righthand": {
            "rotation": [0, -90, 0],
            "translation": [0, 3, -2],
            "scale": [0.6, 0.6, 0.6]
        }
    }
}
'@

# ================================================================
# 3. KUNAI — use iron_ingot texture
# ================================================================
Write-Host "--- KUNAI ---" -ForegroundColor White

Write-Model "kunai" @'
{
    "parent": "item/handheld",
    "textures": {
        "layer0": "minecraft:item/iron_ingot"
    },
    "display": {
        "thirdperson_righthand": {
            "rotation": [0, -90, 55],
            "translation": [0, 4, 0.5],
            "scale": [0.85, 0.85, 0.85]
        },
        "firstperson_righthand": {
            "rotation": [0, -90, 25],
            "translation": [1.13, 3.2, 1.13],
            "scale": [0.68, 0.68, 0.68]
        }
    }
}
'@

# ================================================================
# 4. SCROLL — use paper texture
# ================================================================
Write-Host "--- SCROLL ---" -ForegroundColor White

Write-Model "scroll" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/paper"
    }
}
'@

# ================================================================
# 5. ARMOR ITEMS
# ================================================================
Write-Host "--- ARMOR ITEMS ---" -ForegroundColor White

Write-Model "ninja_hood" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/leather_helmet"
    }
}
'@

Write-Model "flak_vest" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/leather_chestplate"
    }
}
'@

Write-Model "ninja_pants" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/leather_leggings"
    }
}
'@

Write-Model "ninja_sandals" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/leather_boots"
    }
}
'@

Write-Model "ninja_armor" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/leather_chestplate"
    }
}
'@

# ================================================================
# 6. OTHER POSSIBLE ITEMS
# ================================================================
Write-Host "--- OTHER ITEMS ---" -ForegroundColor White

Write-Model "explosive_tag" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/fire_charge"
    }
}
'@

Write-Model "smoke_bomb" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/coal"
    }
}
'@

Write-Model "flash_bomb" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/glowstone_dust"
    }
}
'@

Write-Model "senbon" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/iron_nugget"
    }
}
'@

Write-Model "kunai_explosive" @'
{
    "parent": "item/handheld",
    "textures": {
        "layer0": "minecraft:item/iron_ingot"
    }
}
'@

Write-Model "soldier_pill" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/redstone"
    }
}
'@

Write-Model "blood_pill" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/nether_wart"
    }
}
'@

Write-Model "food_pill" @'
{
    "parent": "item/generated",
    "textures": {
        "layer0": "minecraft:item/wheat"
    }
}
'@

# ================================================================
# 7. LANG FILES
# ================================================================
Write-Host ""
Write-Host "--- LANG FILES ---" -ForegroundColor White

Write-Lang "en_us" @'
{
    "item.shinobicore.katana": "Katana",
    "item.shinobicore.katana_iron": "Iron Katana",
    "item.shinobicore.katana_diamond": "Diamond Katana",
    "item.shinobicore.katana_netherite": "Netherite Katana",
    "item.shinobicore.katana_gold": "Gold Katana",
    "item.shinobicore.shuriken": "Shuriken",
    "item.shinobicore.kunai": "Kunai",
    "item.shinobicore.kunai_explosive": "Explosive Kunai",
    "item.shinobicore.scroll": "Jutsu Scroll",
    "item.shinobicore.ninja_hood": "Ninja Hood",
    "item.shinobicore.flak_vest": "Flak Vest",
    "item.shinobicore.ninja_pants": "Ninja Pants",
    "item.shinobicore.ninja_sandals": "Ninja Sandals",
    "item.shinobicore.ninja_armor": "Ninja Armor",
    "item.shinobicore.explosive_tag": "Explosive Tag",
    "item.shinobicore.smoke_bomb": "Smoke Bomb",
    "item.shinobicore.flash_bomb": "Flash Bomb",
    "item.shinobicore.senbon": "Senbon",
    "item.shinobicore.soldier_pill": "Soldier Pill",
    "item.shinobicore.blood_pill": "Blood Pill",
    "item.shinobicore.food_pill": "Food Pill",
    "itemGroup.shinobicore.main": "Shinobi Core",
    "key.categories.shinobicore": "Shinobi Core",
    "key.categories.shinobicore.combat": "Shinobi Core - Combat",
    "key.shinobicore.meditate": "Meditate",
    "key.shinobicore.cast": "Cast Slot A",
    "key.shinobicore.cast_b": "Cast Slot B",
    "key.shinobicore.cycle_slot": "Cycle Slot A",
    "key.shinobicore.cycle_b": "Cycle Slot B",
    "key.shinobicore.progression": "Progression Menu",
    "key.shinobicore.chakra_mode": "Chakra Mode",
    "key.shinobicore.kick": "Kick",
    "key.shinobicore.switch_style": "Switch Taijutsu Style",
    "key.shinobicore.switch_stance": "Switch Kenjutsu Stance",
    "key.shinobicore.katana_deflect": "Katana Deflect",
    "key.shinobicore.toggle_sensory": "Toggle Sensory",
    "key.shinobicore.dodge_left": "Dodge Left",
    "key.shinobicore.dodge_right": "Dodge Right",
    "key.shinobicore.crawl": "Crawl"
}
'@

Write-Lang "ru_ru" @'
{
    "item.shinobicore.katana": "Катана",
    "item.shinobicore.katana_iron": "Железная катана",
    "item.shinobicore.katana_diamond": "Алмазная катана",
    "item.shinobicore.katana_netherite": "Незеритовая катана",
    "item.shinobicore.katana_gold": "Золотая катана",
    "item.shinobicore.shuriken": "Сюрикен",
    "item.shinobicore.kunai": "Кунай",
    "item.shinobicore.kunai_explosive": "Взрывной кунай",
    "item.shinobicore.scroll": "Свиток дзюцу",
    "item.shinobicore.ninja_hood": "Капюшон ниндзя",
    "item.shinobicore.flak_vest": "Жилет ниндзя",
    "item.shinobicore.ninja_pants": "Штаны ниндзя",
    "item.shinobicore.ninja_sandals": "Сандалии ниндзя",
    "item.shinobicore.ninja_armor": "Броня ниндзя",
    "item.shinobicore.explosive_tag": "Взрывная печать",
    "item.shinobicore.smoke_bomb": "Дымовая бомба",
    "item.shinobicore.flash_bomb": "Световая бомба",
    "item.shinobicore.senbon": "Сенбон",
    "item.shinobicore.soldier_pill": "Пилюля солдата",
    "item.shinobicore.blood_pill": "Пилюля крови",
    "item.shinobicore.food_pill": "Пилюля сытости",
    "itemGroup.shinobicore.main": "Shinobi Core",
    "key.categories.shinobicore": "Shinobi Core",
    "key.categories.shinobicore.combat": "Shinobi Core - Бой",
    "key.shinobicore.meditate": "Медитация",
    "key.shinobicore.cast": "Каст слот A",
    "key.shinobicore.cast_b": "Каст слот B",
    "key.shinobicore.cycle_slot": "Цикл слот A",
    "key.shinobicore.cycle_b": "Цикл слот B",
    "key.shinobicore.progression": "Меню прокачки",
    "key.shinobicore.chakra_mode": "Режим чакры",
    "key.shinobicore.kick": "Удар ногой",
    "key.shinobicore.switch_style": "Смена стиля тай-дзюцу",
    "key.shinobicore.switch_stance": "Смена стойки кен-дзюцу",
    "key.shinobicore.katana_deflect": "Отражение катаной",
    "key.shinobicore.toggle_sensory": "Переключить сенсорику",
    "key.shinobicore.dodge_left": "Уклонение влево",
    "key.shinobicore.dodge_right": "Уклонение вправо",
    "key.shinobicore.crawl": "Ползти"
}
'@

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  DONE!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Created: $created files" -ForegroundColor Green
Write-Host "  Skipped: $skipped files (already existed)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Texture mapping:" -ForegroundColor White
Write-Host "    katana          -> builtin/entity (3D BER)" -ForegroundColor White
Write-Host "    katana_iron     -> minecraft:item/iron_sword" -ForegroundColor White
Write-Host "    katana_nether   -> minecraft:item/netherite_sword" -ForegroundColor White
Write-Host "    shuriken        -> minecraft:item/iron_nugget" -ForegroundColor White
Write-Host "    kunai           -> minecraft:item/iron_ingot" -ForegroundColor White
Write-Host "    scroll          -> minecraft:item/paper" -ForegroundColor White
Write-Host "    ninja_hood      -> minecraft:item/leather_helmet" -ForegroundColor White
Write-Host "    flak_vest       -> minecraft:item/leather_chestplate" -ForegroundColor White
Write-Host ""
Write-Host "  No more pink/black checkerboards!" -ForegroundColor Green
Write-Host ""
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow