$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$jutsuDir = "E:\Games\mod\src\main\resources\data\shinobicore\jutsu"
$treeFile = "E:\Games\mod\src\main\resources\data\shinobicore\skill_tree\tree.json"

# === 1. genjutsu_fear.json ===
$fear = @"
{
 "id": "shinobicore:genjutsu_fear",
 "name": "Genjutsu: Fear",
 "category": "genjutsu",
 "type": "genjutsu",
 "params": {
   "range": 12.0,
   "duration": 100,
   "amplifier": 0,
   "effect": "fear"
 },
 "baseCost": 20,
 "baseDamage": 0,
 "strain": 5,
 "requiredUsesForFullProficiency": 30,
 "requirements": {
   "control": 15,
   "genjutsu": 10
 }
}
"@

# === 2. genjutsu_blindness.json ===
$blind = @"
{
 "id": "shinobicore:genjutsu_blindness",
 "name": "Genjutsu: Darkness",
 "category": "genjutsu",
 "type": "genjutsu",
 "params": {
   "range": 10.0,
   "duration": 120,
   "amplifier": 1,
   "effect": "blindness"
 },
 "baseCost": 25,
 "baseDamage": 0,
 "strain": 6,
 "requiredUsesForFullProficiency": 40,
 "requirements": {
   "control": 20,
   "genjutsu": 20
 }
}
"@

# === 3. genjutsu_nightmare.json ===
$night = @"
{
 "id": "shinobicore:genjutsu_nightmare",
 "name": "Genjutsu: Nightmare",
 "category": "genjutsu",
 "type": "genjutsu",
 "params": {
   "range": 8.0,
   "duration": 160,
   "amplifier": 1,
   "effect": "nightmare"
 },
 "baseCost": 35,
 "baseDamage": 0,
 "strain": 10,
 "requiredUsesForFullProficiency": 50,
 "requirements": {
   "control": 30,
   "genjutsu": 35
 }
}
"@

# Write jutsu files
$files = @(
    @{ name = "genjutsu_fear.json"; content = $fear },
    @{ name = "genjutsu_blindness.json"; content = $blind },
    @{ name = "genjutsu_nightmare.json"; content = $night }
)
foreach ($f in $files) {
    $path = Join-Path $jutsuDir $f.name
    if (Test-Path $path) {
        Write-Host "[SKIP] $($f.name) already exists"
    } else {
        [System.IO.File]::WriteAllText($path, $f.content, $utf8)
        Write-Host "[FIX] Created $($f.name)"
    }
}

# === 4. Patch tree.json: add genjutsu branch and nodes ===
$sentinel = "PHASE_B_GENJUTSU_TREE_DONE"
$content = [System.IO.File]::ReadAllText($treeFile, $utf8)

if ($content.Contains($sentinel)) {
    Write-Host "[SKIP] Genjutsu tree nodes already present"
} else {
    # Add branch after "sensory"
    $branchAnchor = '"sensory":   {"angle": 0,   "color": "#66DDFF", "label": "Sensory"},'
    $branchAdd = @"
`n"genjutsu":  {"angle": 0,   "color": "#CC66FF", "label": "Genjutsu"},
"@
    if ($content.Contains($branchAnchor)) {
        $content = $content.Replace($branchAnchor, $branchAnchor + $branchAdd)
        Write-Host "[FIX] Added genjutsu branch"
    } else {
        Write-Host "[ERROR] Branch anchor not found"
        exit 1
    }

    # Add nodes before closing bracket of nodes array
    # Insert before the last ] of "nodes"
    $nodesJson = @"

{"id":"gen_basic","branch":"genjutsu","distance":1,"type":"jutsu","jutsuId":"shinobicore:genjutsu_fear","spCost":3,"requires":[],"icon":"G","name":"Fear Genjutsu","description":"Slows and nauseates target"},
{"id":"gen_mid","branch":"genjutsu","distance":2,"type":"jutsu","jutsuId":"shinobicore:genjutsu_blindness","spCost":5,"requires":["gen_basic"],"icon":"G","name":"Darkness Genjutsu","description":"Blinds and weakens target"},
{"id":"gen_advanced","branch":"genjutsu","distance":3,"type":"jutsu","jutsuId":"shinobicore:genjutsu_nightmare","spCost":8,"requires":["gen_mid"],"icon":"G","name":"Nightmare Genjutsu","description":"All debuffs, long duration"},
{"id":"gen_resist","branch":"genjutsu","distance":4,"type":"passive","effect":"genjutsu_resist","value":0.10,"spCost":6,"requires":["gen_advanced"],"icon":"G","name":"Mental Fortress","description":"-10% genjutsu resist chance for targets"}
"@
    # Find last node before ] and insert after it
    $insertMarker = '"shuriken_double","branch":"shuriken","distance":3,"type":"passive","effect":"double_throw","value":1,"spCost":7,"requires":["shuriken_mark"],"icon":"x","name":"Shadow Shuriken","description":"Throw a second shuriken"}'
    if ($content.Contains($insertMarker)) {
        $content = $content.Replace($insertMarker, $insertMarker + "," + $nodesJson)
        Write-Host "[FIX] Added genjutsu tree nodes"
    } else {
        Write-Host "[ERROR] Node insert marker not found"
        exit 1
    }

    # Add sentinel comment
    $content = $content + "`n// " + $sentinel
    [System.IO.File]::WriteAllText($treeFile, $content, $utf8)
    Write-Host "[OK] tree.json updated"
}