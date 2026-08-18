$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$resBase = Join-Path $root "src\main\resources"
$clansDir = Join-Path $resBase "data\shinobicore\clans"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 12: DIAGNOSIS + FIX" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# === DIAGNOSIS: Show context around line 90 of ClanRegistry.java ===
$clanRegFile = Join-Path $srcBase "clan\ClanRegistry.java"
if (Test-Path $clanRegFile) {
    $lines = [System.IO.File]::ReadAllLines($clanRegFile)
    Write-Host "[DIAG] ClanRegistry.java lines 75-105:" -ForegroundColor Yellow
    for ($i = 74; $i -le [Math]::Min(104, $lines.Count - 1); $i++) {
        $num = $i + 1
        $prefix = if ($num -eq 90) { ">>>" } else { "   " }
        Write-Host "$prefix $num`: $($lines[$i])"
    }
    Write-Host ""
}

# === FIX 1: Create missing clan JSON files ===
Write-Host "[1/3] Creating missing clan JSON files..." -ForegroundColor Yellow

$existingClans = @{
    "uchiha" = [System.IO.File]::ReadAllText((Join-Path $clansDir "uchiha.json"), $utf8)
    "hyuga" = [System.IO.File]::ReadAllText((Join-Path $clansDir "hyuga.json"), $utf8)
}

# Create akimichi based on uchiha structure
$akimichiJson = @'
{
    "id": "akimichi",
    "bonuses": {
      "max_health_mult": 1.20,
      "melee_damage_mult": 1.10
    },
    "name": "Akimichi Clan",
    "affinity": "earth",
    "extraAffinityCount": 0,
    "statBonuses": {
        "constitution": 2,
        "vitality": 1
    },
    "natureBonuses": {
        "earth": 1
    },
    "costMultiplier": {
        "earth": 0.9,
        "none": 1.0
    },
    "fatigueMultiplier": 1.0,
    "reserveBonus": 0,
    "dojutsuHook": "",
    "chakraCap": 600,
    "startingJutsu": [
        "akimichi_expansion"
    ]
}
'@
if (-not (Test-Path (Join-Path $clansDir "akimichi.json"))) {
    [System.IO.File]::WriteAllText((Join-Path $clansDir "akimichi.json"), $akimichiJson, $utf8)
    Write-Host "  [OK] Created akimichi.json" -ForegroundColor Green
}

# Create senju
$senjuJson = @'
{
    "id": "senju",
    "bonuses": {
      "regen_mult": 1.10,
      "max_health_mult": 1.15
    },
    "name": "Senju Clan",
    "affinity": "earth",
    "extraAffinityCount": 1,
    "statBonuses": {
        "constitution": 2,
        "chakra_control": 2
    },
    "natureBonuses": {
        "earth": 1,
        "water": 1
    },
    "costMultiplier": {
        "earth": 0.9,
        "water": 0.9
    },
    "fatigueMultiplier": 0.95,
    "reserveBonus": 1,
    "dojutsuHook": "",
    "chakraCap": 1000,
    "startingJutsu": [
        "senju_regeneration"
    ]
}
'@
if (-not (Test-Path (Join-Path $clansDir "senju.json"))) {
    [System.IO.File]::WriteAllText((Join-Path $clansDir "senju.json"), $senjuJson, $utf8)
    Write-Host "  [OK] Created senju.json" -ForegroundColor Green
}

# Create inuzuka
$inuzukaJson = @'
{
    "id": "inuzuka",
    "bonuses": {
      "move_speed_mult": 1.15,
      "dodge_mult": 1.10
    },
    "name": "Inuzuka Clan",
    "affinity": "none",
    "extraAffinityCount": 1,
    "statBonuses": {
        "agility": 2,
        "perception": 1
    },
    "natureBonuses": {},
    "costMultiplier": {
        "none": 0.95
    },
    "fatigueMultiplier": 0.95,
    "reserveBonus": 0,
    "dojutsuHook": "",
    "chakraCap": 500,
    "startingJutsu": [
        "inuzuka_wolf_fang"
    ]
}
'@
if (-not (Test-Path (Join-Path $clansDir "inuzuka.json"))) {
    [System.IO.File]::WriteAllText((Join-Path $clansDir "inuzuka.json"), $inuzukaJson, $utf8)
    Write-Host "  [OK] Created inuzuka.json" -ForegroundColor Green
}

# Create aburame
$aburameJson = @'
{
    "id": "aburame",
    "bonuses": {
      "dot_damage_mult": 1.10,
      "poison_resist": 1.15
    },
    "name": "Aburame Clan",
    "affinity": "none",
    "extraAffinityCount": 1,
    "statBonuses": {
        "perception": 2,
        "constitution": 1
    },
    "natureBonuses": {},
    "costMultiplier": {
        "none": 0.95
    },
    "fatigueMultiplier": 1.0,
    "reserveBonus": 0,
    "dojutsuHook": "",
    "chakraCap": 550,
    "startingJutsu": [
        "aburame_swarm"
    ]
}
'@
if (-not (Test-Path (Join-Path $clansDir "aburame.json"))) {
    [System.IO.File]::WriteAllText((Join-Path $clansDir "aburame.json"), $aburameJson, $utf8)
    Write-Host "  [OK] Created aburame.json" -ForegroundColor Green
}

# === FIX 2: Fix ClanRegistry.java ===
Write-Host "`n[2/3] Fixing ClanRegistry.java..." -ForegroundColor Yellow

$content = [System.IO.File]::ReadAllText($clanRegFile, $utf8)
$content = $content.Replace("`r`n", "`n")

# Check if bonuses parsing already exists
if (-not $content.Contains("java.util.Map<String, Float> bonuses")) {
    # Find the right place to insert bonuses parsing (after dojutsuHook parsing)
    $pattern = "String dojutsuHook = obj\.has\(`"dojutsuHook`"\)[^;]*;"
    $replacement = @'
String dojutsuHook = obj.has("dojutsuHook") ? obj.get("dojutsuHook").getAsString() : null;

        // Parse bonuses map
        java.util.Map<String, Float> bonuses = new java.util.HashMap<>();
        if (obj.has("bonuses")) {
            com.google.gson.JsonObject bonusesObj = obj.getAsJsonObject("bonuses");
            for (String key : bonusesObj.keySet()) {
                bonuses.put(key, bonusesObj.get(key).getAsFloat());
            }
        }
'@
    $content = [regex]::Replace($content, $pattern, $replacement)
    Write-Host "  [OK] Added bonuses parsing" -ForegroundColor Green
}

# Ensure constructor call uses bonuses
if ($content.Contains("new ClanDefinition(id, name, affinity")) {
    $content = $content.Replace(
        "new ClanDefinition(id, name, affinity",
        "new ClanDefinition(bonuses, id, name, affinity"
    )
    Write-Host "  [OK] Fixed constructor call" -ForegroundColor Green
} elseif (-not $content.Contains("new ClanDefinition(bonuses, id, name")) {
    Write-Host "  [WARN] Constructor pattern not found, showing context" -ForegroundColor Yellow
}

[System.IO.File]::WriteAllText($clanRegFile, $content, $utf8)

# === FIX 3: Update tree.json with clan tags ===
Write-Host "`n[3/3] Updating tree.json with clan tags..." -ForegroundColor Yellow

$treeFile = Join-Path $resBase "data\shinobicore\skill_tree\tree.json"
if (Test-Path $treeFile) {
    $treeContent = [System.IO.File]::ReadAllText($treeFile, $utf8)
    $treeContent = $treeContent.Replace("`r`n", "`n")
    
    # Show sample of tree structure for diagnosis
    $sample = $treeContent.Substring(0, [Math]::Min(1500, $treeContent.Length))
    Write-Host "  [DIAG] tree.json sample (first 1500 chars):" -ForegroundColor Yellow
    Write-Host $sample.Substring(0, [Math]::Min(800, $sample.Length))
    
    # Clan jutsu list
    $clanJutsu = @(
        "susanoo", "fire_sphere_v2", "genjutsu_coma", "sharingan_foresight",
        "hyu_sky_vortex", "hyu_hakke_shield", "hyu_pressure_point",
        "uzumaki_chains", "uzumaki_barrier", "uzumaki_chakra_vortex", "uzumaki_life_force", "uzumaki_suppression",
        "senju_wood_dragon", "senju_regeneration", "senju_wood_wall", "senju_forest_march", "senju_wood_golem",
        "nara_shadow_grab", "nara_shadow_loop", "nara_shadow_spike", "nara_shadow_control", "nara_shadow_clone",
        "aburame_swarm", "aburame_bug_shield", "aburame_bug_bomb", "aburame_spore_cloud", "aburame_bug_double",
        "inuzuka_wolf_fang", "inuzuka_beast_sense", "inuzuka_spin_fang", "inuzuka_pair_attack", "inuzuka_wild_rush",
        "akimichi_expansion", "akimichi_stone_fist", "akimichi_butterfly", "akimichi_giant_step", "akimichi_meat_ball",
        "hatake_lightning_blade", "hatake_shadow_step", "hatake_raikiri", "hatake_dog_nose", "hatake_lightning_wall"
    )
    
    $clanMap = @{
        "uchiha" = @("susanoo", "fire_sphere_v2", "genjutsu_coma", "sharingan_foresight")
        "hyuga" = @("hyu_sky_vortex", "hyu_hakke_shield", "hyu_pressure_point")
        "uzumaki" = @("uzumaki_chains", "uzumaki_barrier", "uzumaki_chakra_vortex", "uzumaki_life_force", "uzumaki_suppression")
        "senju" = @("senju_wood_dragon", "senju_regeneration", "senju_wood_wall", "senju_forest_march", "senju_wood_golem")
        "nara" = @("nara_shadow_grab", "nara_shadow_loop", "nara_shadow_spike", "nara_shadow_control", "nara_shadow_clone")
        "aburame" = @("aburame_swarm", "aburame_bug_shield", "aburame_bug_bomb", "aburame_spore_cloud", "aburame_bug_double")
        "inuzuka" = @("inuzuka_wolf_fang", "inuzuka_beast_sense", "inuzuka_spin_fang", "inuzuka_pair_attack", "inuzuka_wild_rush")
        "akimichi" = @("akimichi_expansion", "akimichi_stone_fist", "akimichi_butterfly", "akimichi_giant_step", "akimichi_meat_ball")
        "hatake" = @("hatake_lightning_blade", "hatake_shadow_step", "hatake_raikiri", "hatake_dog_nose", "hatake_lightning_wall")
    }
    
    $updated = 0
    foreach ($clanId in $clanMap.Keys) {
        foreach ($jutsuId in $clanMap[$clanId]) {
            # Try multiple patterns since JSON format may vary
            $patterns = @(
                '("id":\s*"' + $jutsuId + '"[\s\S]*?"tags":\s*\[)([^\]]*)(\])',
                '("id":\s*"' + $jutsuId + '"[\s\S]*?)(,\s*"tags")'
            )
            
            $matched = $false
            foreach ($p in $patterns) {
                if ($treeContent -match $p) {
                    $matched = $true
                    break
                }
            }
            
            if ($treeContent -match '"id":\s*"' + $jutsuId + '"') {
                # Node exists, try to add tags
                if ($treeContent -match '("id":\s*"' + $jutsuId + '"[\s\S]*?"tags":\s*\[)([^\]]*)(\])') {
                    # Node has tags array - add clan tags
                    $treeContent = [regex]::Replace($treeContent, 
                        '("id":\s*"' + $jutsuId + '"[\s\S]*?"tags":\s*\[)([^\]]*)(\])',
                        "`${1}`"clan_only`", `"clan:$clanId`", `${2}]")
                    $updated++
                } elseif ($treeContent -match '"id":\s*"' + $jutsuId + '"') {
                    # Node exists but no tags - insert tags before next property
                    $treeContent = [regex]::Replace($treeContent,
                        '("id":\s*"' + $jutsuId + '")',
                        "`${1},`n            `"tags`": [`"clan_only`", `"clan:$clanId`"]")
                    $updated++
                }
            }
        }
    }
    
    [System.IO.File]::WriteAllText($treeFile, $treeContent, $utf8)
    Write-Host ("  [OK] Updated " + $updated + " nodes with clan tags") -ForegroundColor Green
}

Write-Host ""
Write-Host "=== BUILD ===" -ForegroundColor Cyan
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }