# ============================================================
# SPRINT 12 PHASE A: FINAL FIX SCRIPT
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$resBase = Join-Path $root "src\main\resources"
$clansDir = Join-Path $resBase "data\shinobicore\clans"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 12 PHASE A: FINAL FIX" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host ("  [MISS] " + $p) -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host ("  [SKIP] already: " + (Split-Path $p -Leaf)) -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host ("  [FAIL] pattern: " + (Split-Path $p -Leaf)) -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host ("  [PATCH] " + (Split-Path $p -Leaf)) -ForegroundColor Green
    return $true
}

# ============================================================
# SECTION 1: UPDATE INDIVIDUAL CLAN JSON FILES
# ============================================================
Write-Host "[1/5] Updating clan JSON files with bonuses..." -ForegroundColor Yellow

$clanBonuses = @{
    "uchiha"   = @{ "fire_damage_mult"=1.10; "genjutsu_resist"=1.15 }
    "hyuga"    = @{ "melee_damage_mult"=1.15; "accuracy_mult"=1.10 }
    "uzumaki"  = @{ "max_chakra_mult"=1.20; "regen_mult"=1.10 }
    "senju"    = @{ "regen_mult"=1.10; "max_health_mult"=1.15 }
    "nara"     = @{ "control_mult"=1.15; "cast_speed_mult"=1.10 }
    "aburame"  = @{ "dot_damage_mult"=1.10; "poison_resist"=1.15 }
    "inuzuka"  = @{ "move_speed_mult"=1.15; "dodge_mult"=1.10 }
    "akimichi" = @{ "max_health_mult"=1.20; "melee_damage_mult"=1.10 }
    "hatake"   = @{ "attack_speed_mult"=1.10; "lightning_damage_mult"=1.15 }
}

foreach ($clanId in $clanBonuses.Keys) {
    $clanFile = Join-Path $clansDir "$clanId.json"
    if (-not (Test-Path $clanFile)) {
        Write-Host ("  [MISS] " + $clanFile) -ForegroundColor Red
        continue
    }
    
    $content = [System.IO.File]::ReadAllText($clanFile, $utf8)
    $content = $content.Replace("`r`n", "`n")
    
    # Check if bonuses already present
    if ($content.Contains('"bonuses"')) {
        Write-Host ("  [SKIP] " + $clanId + ".json already has bonuses") -ForegroundColor Yellow
        continue
    }
    
    # Build bonuses JSON
    $bonuses = $clanBonuses[$clanId]
    $bonusEntries = @()
    foreach ($key in $bonuses.Keys) {
        $bonusEntries += "      `"$key`": $($bonuses[$key])"
    }
    $bonusJson = "`"bonuses`": {`n" + ($bonusEntries -join ",`n") + "`n    }"
    
    # Insert bonuses after "id" field
    $content = [regex]::Replace($content, '("id":\s*"' + $clanId + '")', "`$1,`n    $bonusJson")
    
    [System.IO.File]::WriteAllText($clanFile, $content, $utf8)
    Write-Host ("  [OK] " + $clanId + ".json updated") -ForegroundColor Green
}

# ============================================================
# SECTION 2: FIX ClanRegistry.java CONSTRUCTOR
# ============================================================
Write-Host "`n[2/5] Fixing ClanRegistry.java constructor..." -ForegroundColor Yellow

$clanRegFile = Join-Path $srcBase "clan\ClanRegistry.java"

# First, add bonuses parsing
Patch-File $clanRegFile `
    "String dojutsuHook = obj.has(`"dojutsuHook`") ? obj.get(`"dojutsuHook`").getAsString() : null;" `
    "String dojutsuHook = obj.has(`"dojutsuHook`") ? obj.get(`"dojutsuHook`").getAsString() : null;`n        `n        // Parse bonuses map`n        java.util.Map<String, Float> bonuses = new java.util.HashMap<>();`n        if (obj.has(`"bonuses`")) {`n            com.google.gson.JsonObject bonusesObj = obj.getAsJsonObject(`"bonuses`");`n            for (String key : bonusesObj.keySet()) {`n                bonuses.put(key, bonusesObj.get(key).getAsFloat());`n            }`n        }"

# Then fix constructor call to include bonuses as first parameter
Patch-File $clanRegFile `
    "new ClanDefinition(id, name, affinity, extraAffinityCount," `
    "new ClanDefinition(bonuses, id, name, affinity, extraAffinityCount,"

# ============================================================
# SECTION 3: PATCH NinjaPlayerData.java
# ============================================================
Write-Host "`n[3/5] Patching NinjaPlayerData.java..." -ForegroundColor Yellow

$ninjaDataFile = Join-Path $srcBase "stat\NinjaPlayerData.java"

# Add getClanBonus method after getClanId
Patch-File $ninjaDataFile `
    "public String getClanId() { return clanId; }" `
    "public String getClanId() { return clanId; }`n`n    public float getClanBonus(String key) {`n        var clan = com.example.shinobicore.clan.ClanRegistry.get(this.clanId);`n        if (clan != null && clan.bonuses() != null) {`n            return clan.bonuses().getOrDefault(key, 1.0f);`n        }`n        return 1.0f;`n    }"

# ============================================================
# SECTION 4: PATCH SkillTreeRegistry.java
# ============================================================
Write-Host "`n[4/5] Patching SkillTreeRegistry.java..." -ForegroundColor Yellow

$treeRegFile = Join-Path $srcBase "tree\SkillTreeRegistry.java"

# Add clan restriction check method
Patch-File $treeRegFile `
    "public class SkillTreeRegistry {" `
    "public class SkillTreeRegistry {`n`n    public static boolean canUnlockWithClanCheck(`n            com.example.shinobicore.stat.NinjaPlayerData data,`n            com.example.shinobicore.tree.SkillTreeNode node) {`n        // S12-10: Clan restriction check`n        if (node.tags() != null) {`n            for (String tag : node.tags()) {`n                if (tag.startsWith(`"clan:`")) {`n                    String requiredClan = tag.substring(5);`n                    if (!requiredClan.equals(data.getClanId())) {`n                        return false; // Non-clan member cannot unlock clan techniques`n                    }`n                }`n            }`n        }`n        return true;`n    }"

# ============================================================
# SECTION 5: UPDATE tree.json WITH CLAN TAGS
# ============================================================
Write-Host "`n[5/5] Updating tree.json with clan tags..." -ForegroundColor Yellow

$treeFile = Join-Path $resBase "data\shinobicore\skill_tree\tree.json"
if (Test-Path $treeFile) {
    $treeContent = [System.IO.File]::ReadAllText($treeFile, $utf8)
    $treeContent = $treeContent.Replace("`r`n", "`n")
    
    # Add clan_only and clan:xxx tags to all clan jutsu nodes
    $clanJutsu = @(
        @{ id="susanoo"; clan="uchiha" },
        @{ id="fire_sphere_v2"; clan="uchiha" },
        @{ id="genjutsu_coma"; clan="uchiha" },
        @{ id="sharingan_foresight"; clan="uchiha" },
        @{ id="hyu_sky_vortex"; clan="hyuga" },
        @{ id="hyu_hakke_shield"; clan="hyuga" },
        @{ id="hyu_pressure_point"; clan="hyuga" },
        @{ id="uzumaki_chains"; clan="uzumaki" },
        @{ id="uzumaki_barrier"; clan="uzumaki" },
        @{ id="uzumaki_chakra_vortex"; clan="uzumaki" },
        @{ id="uzumaki_life_force"; clan="uzumaki" },
        @{ id="uzumaki_suppression"; clan="uzumaki" },
        @{ id="senju_wood_dragon"; clan="senju" },
        @{ id="senju_regeneration"; clan="senju" },
        @{ id="senju_wood_wall"; clan="senju" },
        @{ id="senju_forest_march"; clan="senju" },
        @{ id="senju_wood_golem"; clan="senju" },
        @{ id="nara_shadow_grab"; clan="nara" },
        @{ id="nara_shadow_loop"; clan="nara" },
        @{ id="nara_shadow_spike"; clan="nara" },
        @{ id="nara_shadow_control"; clan="nara" },
        @{ id="nara_shadow_clone"; clan="nara" },
        @{ id="aburame_swarm"; clan="aburame" },
        @{ id="aburame_bug_shield"; clan="aburame" },
        @{ id="aburame_bug_bomb"; clan="aburame" },
        @{ id="aburame_spore_cloud"; clan="aburame" },
        @{ id="aburame_bug_double"; clan="aburame" },
        @{ id="inuzuka_wolf_fang"; clan="inuzuka" },
        @{ id="inuzuka_beast_sense"; clan="inuzuka" },
        @{ id="inuzuka_spin_fang"; clan="inuzuka" },
        @{ id="inuzuka_pair_attack"; clan="inuzuka" },
        @{ id="inuzuka_wild_rush"; clan="inuzuka" },
        @{ id="akimichi_expansion"; clan="akimichi" },
        @{ id="akimichi_stone_fist"; clan="akimichi" },
        @{ id="akimichi_butterfly"; clan="akimichi" },
        @{ id="akimichi_giant_step"; clan="akimichi" },
        @{ id="akimichi_meat_ball"; clan="akimichi" },
        @{ id="hatake_lightning_blade"; clan="hatake" },
        @{ id="hatake_shadow_step"; clan="hatake" },
        @{ id="hatake_raikiri"; clan="hatake" },
        @{ id="hatake_dog_nose"; clan="hatake" },
        @{ id="hatake_lightning_wall"; clan="hatake" }
    )
    
    $updated = 0
    foreach ($j in $clanJutsu) {
        $pattern = '"id": "' + $j.id + '"[\s\S]*?"tags": \[([^\]]*)\]'
        if ($treeContent -match $pattern) {
            $replacement = '"tags": ["clan_only", "clan:' + $j.clan + '", $1]'
            $treeContent = [regex]::Replace($treeContent, $pattern, $replacement)
            $updated++
        }
    }
    
    [System.IO.File]::WriteAllText($treeFile, $treeContent, $utf8)
    Write-Host ("  [OK] Updated " + $updated + " nodes with clan tags") -ForegroundColor Green
} else {
    Write-Host "  [MISS] tree.json not found" -ForegroundColor Red
}

# ============================================================
# BUILD
# ============================================================
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

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 12 PHASE A COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green