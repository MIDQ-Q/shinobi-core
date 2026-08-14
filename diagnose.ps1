$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"

# Find NinjaPlayerData and show its public methods
$npd = Get-ChildItem -Path $base -Recurse -Filter "NinjaPlayerData.java" | Select-Object -First 1
if ($npd) {
    Write-Host "=== NinjaPlayerData methods ==="
    $content = [System.IO.File]::ReadAllText($npd.FullName, $utf8)
    $methods = [regex]::Matches($content, 'public\s+\w+(?:<[^>]+>)?\s+(\w+)\s*\([^)]*\)')
    foreach ($m in $methods) { Write-Host "  " $m.Groups[1].Value }
}

# Find JutsuRegistry
$jr = Get-ChildItem -Path $base -Recurse -Filter "JutsuRegistry.java" | Select-Object -First 1
if ($jr) {
    Write-Host "`n=== JutsuRegistry methods ==="
    $content = [System.IO.File]::ReadAllText($jr.FullName, $utf8)
    $methods = [regex]::Matches($content, 'public\s+static\s+\w+(?:<[^>]+>)?\s+(\w+)\s*\([^)]*\)')
    foreach ($m in $methods) { Write-Host "  " $m.Groups[1].Value }
}

# Find where commands are registered
Write-Host "`n=== CommandRegistration places ==="
$found = Get-ChildItem -Path $base -Recurse -Filter "*.java" | Where-Object {
    $c = [System.IO.File]::ReadAllText($_.FullName, $utf8)
    $c.Contains("CommandRegistrationCallback") -or $c.Contains("literal(")
}
foreach ($f in $found) { Write-Host "  " $f.FullName.Replace($base, "") }

# Find the jutsu selection screen (K menu)
Write-Host "`n=== Screen files ==="
$screens = Get-ChildItem -Path $base -Recurse -Filter "*.java" | Where-Object {
    $_.Name -match "Screen|Gui|Menu"
}
foreach ($s in $screens) { Write-Host "  " $s.FullName.Replace($base, "") }

# Show ShinobiCore entrypoints
Write-Host "`n=== fabric.mod.json entrypoints ==="
$fabric = "E:\Games\mod\src\main\resources\fabric.mod.json"
[System.IO.File]::ReadAllText($fabric, $utf8) | Write-Host