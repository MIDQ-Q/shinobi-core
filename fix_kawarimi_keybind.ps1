$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$res = "$root\src\main\resources\assets\shinobicore"

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; return $true }
    if (-not $cNorm.Contains($oldNorm)) { Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; return $false }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    return $true
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX: KAWARIMI KeyBinding Missing" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Объявляем поле
Patch-File "$java\client\KeyBindings.java" `
    "public static KeyBinding TOGGLE_SCABBARD;" `
    "public static KeyBinding TOGGLE_SCABBARD;`n    public static KeyBinding KAWARIMI;"

# 2. Регистрируем (на клавишу J)
Patch-File "$java\client\KeyBindings.java" `
    "TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.toggle_sensory"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));" `
    "TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.toggle_sensory"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));`n        KAWARIMI = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.kawarimi"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_J, COMBAT_CATEGORY));"

# 3. Локализация EN
Patch-File "$res\lang\en_us.json" `
    """key.shinobicore.toggle_scabbard"": ""Sheathe / Draw Katana (O)""," `
    """key.shinobicore.toggle_scabbard"": ""Sheathe / Draw Katana (O)"",`n  ""key.shinobicore.kawarimi"": ""Kawarimi (J)"","

# 4. Локализация RU
Patch-File "$res\lang\ru_ru.json" `
    """key.shinobicore.toggle_scabbard"": ""РќРѕР¶РЅС‹ / РґРѕСЃС‚Р°С‚СЊ РєР°С‚Р°РЅСѓ (O)""," `
    """key.shinobicore.toggle_scabbard"": ""РќРѕР¶РЅС‹ / РґРѕСЃС‚Р°С‚СЊ РєР°С‚Р°РЅСѓ (O)"",`n  ""key.shinobicore.kawarimi"": ""РљР°РІР°СЂРёРјРё (J)"","

Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Done! Next steps:" -ForegroundColor Green
Write-Host "  1. .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  2. .\gradlew.bat runClient" -ForegroundColor Yellow