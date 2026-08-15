$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$baseRes = "E:\Games\mod\src\main\resources\assets\shinobicore"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX PINK/BLACK CHECKERBOARDS (Armor & Items)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 1. ARMOR TEXTURES (Worn on player model)
# ============================================================
# Minecraft requires <namespace>:textures/models/armor/<material>_layer_1.png
$armorDir = "$baseRes\textures\models\armor"
if (-not (Test-Path $armorDir)) { New-Item -ItemType Directory -Path $armorDir -Force | Out-Null }

# Base64 of a valid 64x32 PNG (solid gray placeholder)
$b64Armor = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAWklEQVR4nO3QMQ0AMAzAsIItfworDB/L4T/K7O772egArQE6QGuADtAaoAO0BugArQE6QGuADtAaoAO0BugArQE6QGuADtAaoAO0BugArQE6QGuADtAaoAO0A69iWQDm6MdVAAAAAElFTkSuQmCC"
$armorBytes = [System.Convert]::FromBase64String($b64Armor)

# Create layer 1 and layer 2 for all possible armor material names
$armorMaterials = @("naruto_flak", "ninja", "flak", "ninja_armor", "flak_vest", "hood", "sandals", "ninja_pants")
foreach ($mat in $armorMaterials) {
    [System.IO.File]::WriteAllBytes("$armorDir\$($mat)_layer_1.png", $armorBytes)
    [System.IO.File]::WriteAllBytes("$armorDir\$($mat)_layer_2.png", $armorBytes)
}
Write-Host "[OK] Created armor layer textures (fixes pink/black on player model)" -ForegroundColor Green

# ============================================================
# 2. ITEM MODELS (Held in hand / Inventory)
# ============================================================
# Point JSONs to vanilla Minecraft textures instead of missing shinobicore:item/...
$modelsDir = "$baseRes\models\item"
if (-not (Test-Path $modelsDir)) { New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null }

$textureMap = @{
    "katana_iron"       = "minecraft:item/iron_sword"
    "katana_diamond"    = "minecraft:item/diamond_sword"
    "katana_netherite"  = "minecraft:item/netherite_sword"
    "katana_gold"       = "minecraft:item/golden_sword"
    "shuriken"          = "minecraft:item/iron_nugget"
    "kunai"             = "minecraft:item/iron_ingot"
    "scroll"            = "minecraft:item/paper"
    "ninja_hood"        = "minecraft:item/leather_helmet"
    "flak_vest"         = "minecraft:item/leather_chestplate"
    "ninja_pants"       = "minecraft:item/leather_leggings"
    "ninja_sandals"     = "minecraft:item/leather_boots"
    "ninja_armor"       = "minecraft:item/leather_chestplate"
    "explosive_tag"     = "minecraft:item/paper"
    "smoke_bomb"        = "minecraft:item/gunpowder"
    "flash_bomb"        = "minecraft:item/glowstone_dust"
    "senbon"            = "minecraft:item/iron_nugget"
    "kunai_explosive"   = "minecraft:item/tnt"
    "soldier_pill"      = "minecraft:item/redstone"
    "blood_pill"        = "minecraft:item/redstone"
    "food_pill"         = "minecraft:item/melon_slice"
}

foreach ($item in $textureMap.Keys) {
    $jsonPath = "$modelsDir\$item.json"
    $tex = $textureMap[$item]
    
    $json = @"
{
  "parent": "item/generated",
  "textures": {
    "layer0": "$tex"
  }
}
"@
    [System.IO.File]::WriteAllText($jsonPath, $json, $utf8)
}
Write-Host "[OK] Rewrote item models to use vanilla textures (fixes pink/black in hand)" -ForegroundColor Green

# ============================================================
# 3. KATANA (Built-in Entity Renderer)
# ============================================================
$katanaJson = @"
{
  "parent": "builtin/entity",
  "textures": {
    "particle": "minecraft:item/iron_ingot"
  },
  "display": {
    "gui": { "rotation": [ 30, 225, 0 ], "translation": [ 0, 0, 0], "scale":[ 0.625, 0.625, 0.625 ] },
    "ground": { "rotation": [ 0, 0, 0 ], "translation": [ 0, 3, 0], "scale":[ 0.25, 0.25, 0.25 ] },
    "fixed": { "rotation": [ 0, 0, 0 ], "translation": [ 0, 0, 0], "scale":[ 0.5, 0.5, 0.5 ] },
    "thirdperson_righthand": { "rotation": [ 0, -90, 55 ], "translation": [ 0, 4.0, 0.5 ], "scale": [ 0.85, 0.85, 0.85 ] },
    "thirdperson_lefthand": { "rotation": [ 0, 90, -55 ], "translation": [ 0, 4.0, 0.5 ], "scale": [ 0.85, 0.85, 0.85 ] },
    "firstperson_righthand": { "rotation": [ 0, -90, 25 ], "translation": [ 1.13, 3.2, 1.13 ], "scale": [ 0.68, 0.68, 0.68 ] },
    "firstperson_lefthand": { "rotation": [ 0, 90, -25 ], "translation": [ 1.13, 3.2, 1.13 ], "scale": [ 0.68, 0.68, 0.68 ] }
  }
}
"@
[System.IO.File]::WriteAllText("$modelsDir\katana.json", $katanaJson, $utf8)
Write-Host "[OK] Fixed katana.json for 3D BER" -ForegroundColor Green

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  ALL TEXTURES FIXED!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. .\gradlew.bat build" -ForegroundColor White
Write-Host "  2. .\gradlew.bat runClient" -ForegroundColor White