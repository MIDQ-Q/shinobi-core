$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"

$files = @(
    "$base\jutsu\ProjectileBehavior.java",
    "$base\jutsu\custom\RasenshurikenBehavior.java",
    "$base\jutsu\custom\ExplodingProjectileBehavior.java",
    "$base\jutsu\custom\HomingProjectileBehavior.java"
)

foreach ($f in $files) {
    $c = [System.IO.File]::ReadAllText($f, $utf8)
    
    # Добавляем "default" как недостающий String параметр (model/texture)
    $c = $c.Replace("particle, lifetime", "particle, `"default`", lifetime")
    $c = $c.Replace("`"wind`", 80", "`"wind`", `"default`", 80")
    $c = $c.Replace("`"fire`", 100", "`"fire`", `"default`", 100")
    $c = $c.Replace("`"fire`", 80", "`"fire`", `"default`", 80")
    
    [System.IO.File]::WriteAllText($f, $c, $utf8)
    Write-Host "[OK] Fixed constructor args in $f"
}
Write-Host "=== CONSTRUCTOR FIX DONE ==="