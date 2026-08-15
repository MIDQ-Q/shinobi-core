$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$javaBase = "$root\src\main\java\com\example\shinobicore"
$resBase = "$root\src\main\resources"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SHINOBI CORE: CRASH & RESOURCE FIX SCRIPT" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# ---------------------------------------------------------
# FIX 1: KeyBindings.java (Добавляем TOGGLE_SCABBARD)
# ---------------------------------------------------------
Write-Host "`n[1/3] Fixing KeyBindings.java..." -ForegroundColor White
$kbFile = "$javaBase\client\KeyBindings.java"
if (Test-Path $kbFile) {
    $content = [System.IO.File]::ReadAllText($kbFile, $utf8)
    
    if (-not $content.Contains("TOGGLE_SCABBARD")) {
        # 1. Добавляем объявление переменной
        $content = $content -replace '(public static KeyBinding TOGGLE_SENSORY;)', "`$1`n    public static KeyBinding TOGGLE_SCABBARD;"
        
        # 2. Добавляем регистрацию (на клавишу O)
        $regPattern = '(TOGGLE_SENSORY\s*=\s*KeyBindingHelper\.registerKeyBinding\(new KeyBinding\([\s\S]*?CATEGORY\)\);)'
        $regReplacement = @"
`$1
        TOGGLE_SCABBARD = KeyBindingHelper.registerKeyBinding(new KeyBinding(
"key.shinobicore.toggle_scabbard", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_O, COMBAT_CATEGORY));
"@
        $content = $content -replace $regPattern, $regReplacement
        
        [System.IO.File]::WriteAllText($kbFile, $content, $utf8)
        Write-Host "  [+] Added TOGGLE_SCABBARD to KeyBindings.java" -ForegroundColor Green
    } else {
        Write-Host "  [=] TOGGLE_SCABBARD already exists in KeyBindings.java" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [!] KeyBindings.java not found!" -ForegroundColor Red
}

# ---------------------------------------------------------
# FIX 2: Создание отсутствующих JSON моделей
# ---------------------------------------------------------
Write-Host "`n[2/3] Creating missing item models..." -ForegroundColor White
$modelDir = "$resBase\assets\shinobicore\models\item"
if (-not (Test-Path $modelDir)) { New-Item -ItemType Directory -Path $modelDir -Force | Out-Null }

$handheldItems = @("katana_iron", "katana_diamond", "katana_steel", "katana")
$generatedItems = @("ninja_pants", "ninja_leggings", "ninja_chest", "ninja_chestplate", "ninja_helmet", "ninja_boots")

foreach ($item in $handheldItems) {
    $path = "$modelDir\$item.json"
    if (-not (Test-Path $path)) {
        $json = @"
{
  "parent": "minecraft:item/handheld",
  "textures": {
    "layer0": "shinobicore:item/$item"
  }
}
"@
        [System.IO.File]::WriteAllText($path, $json, $utf8)
        Write-Host "  [+] Created $item.json (handheld)" -ForegroundColor Green
    }
}

foreach ($item in $generatedItems) {
    $path = "$modelDir\$item.json"
    if (-not (Test-Path $path)) {
        $json = @"
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "shinobicore:item/$item"
  }
}
"@
        [System.IO.File]::WriteAllText($path, $json, $utf8)
        Write-Host "  [+] Created $item.json (generated)" -ForegroundColor Green
    }
}

# ---------------------------------------------------------
# FIX 3: Исправление рецептов (shinobicore:katana -> katana_iron)
# ---------------------------------------------------------
Write-Host "`n[3/3] Fixing recipe IDs..." -ForegroundColor White
$recipeDir = "$resBase\data\shinobicore\recipes"
if (Test-Path $recipeDir) {
    $recipeFiles = Get-ChildItem -Path $recipeDir -Filter "*.json"
    foreach ($file in $recipeFiles) {
        $content = [System.IO.File]::ReadAllText($file.FullName, $utf8)
        if ($content.Contains('"shinobicore:katana"')) {
            $content = $content.Replace('"shinobicore:katana"', '"shinobicore:katana_iron"')
            [System.IO.File]::WriteAllText($file.FullName, $content, $utf8)
            Write-Host "  [~] Updated $($file.Name): katana -> katana_iron" -ForegroundColor Yellow
            
            # Переименовываем файл рецепта, если он назывался katana.json
            if ($file.Name -eq "katana.json") {
                $newName = $file.FullName.Replace("katana.json", "katana_iron.json")
                if (-not (Test-Path $newName)) {
                    Rename-Item $file.FullName $newName
                    Write-Host "  [>] Renamed katana.json -> katana_iron.json" -ForegroundColor Cyan
                } else {
                    Remove-Item $file.FullName -Force
                    Write-Host "  [x] Deleted katana.json (katana_iron.json already exists)" -ForegroundColor DarkYellow
                }
            }
        }
    }
} else {
    Write-Host "  [!] Recipes directory not found!" -ForegroundColor Red
}

# ---------------------------------------------------------
# ИТОГ
# ---------------------------------------------------------
Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "  FIXES APPLIED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host "`nDon't forget to add the translation key to your lang files:" -ForegroundColor Yellow
Write-Host "  `"key.shinobicore.toggle_scabbard`": `"Toggle Scabbard`" (en_us.json)" -ForegroundColor White
Write-Host "  `"key.shinobicore.toggle_scabbard`": `"Достать/убрать катану`" (ru_ru.json)" -ForegroundColor White
Write-Host "`nNext step: .\gradlew.bat runClient" -ForegroundColor Cyan