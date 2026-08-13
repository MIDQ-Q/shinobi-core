$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$path = "E:\Games\mod\src\main\java\com\example\shinobicore\ShinobiCore.java"
$content = [System.IO.File]::ReadAllText($path, $utf8)
$sentinel = "PHASE_B_GENJUTSU_REGISTERED"

if ($content.Contains($sentinel)) {
    Write-Host "[SKIP] GenjutsuBehavior already registered"
    exit 0
}

# Add import
$importAnchor = "import com.example.shinobicore.jutsu.WallBehavior;"
if ($content.Contains($importAnchor)) {
    $content = $content.Replace($importAnchor, $importAnchor + "`nimport com.example.shinobicore.jutsu.GenjutsuBehavior;")
    Write-Host "[FIX] Added GenjutsuBehavior import"
} else {
    Write-Host "[ERROR] Import anchor not found"
    exit 1
}

# Add registration
$regAnchor = 'BehaviorRegistry.register("utility", new UtilityBehavior());'
if ($content.Contains($regAnchor)) {
    $content = $content.Replace($regAnchor, $regAnchor + "`n        BehaviorRegistry.register(`"genjutsu`", new GenjutsuBehavior()); // " + $sentinel)
    Write-Host "[FIX] Registered genjutsu behavior"
} else {
    Write-Host "[ERROR] Registration anchor not found"
    exit 1
}

[System.IO.File]::WriteAllText($path, $content, $utf8)
Write-Host "[OK] ShinobiCore.java updated"