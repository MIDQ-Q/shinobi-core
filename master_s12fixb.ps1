$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$resBase = Join-Path $root "src\main\resources"

Write-Host "=== SPRINT 12: FIX + ADD CLAN NODES ===" -ForegroundColor Cyan

# === DIAG: Show SkillTreeRegistry line 29 ===
Write-Host "`n[DIAG] SkillTreeRegistry.java lines 20-40:" -ForegroundColor Yellow
$regFile = Join-Path $srcBase "tree\SkillTreeRegistry.java"
$lines = [System.IO.File]::ReadAllLines($regFile)
for ($i = 19; $i -le [Math]::Min(39, $lines.Count - 1); $i++) {
    $num = $i + 1
    $prefix = if ($num -eq 29) { ">>>" } else { "   " }
    Write-Host "$prefix $num`: $($lines[$i])"
}

# === FIX 1: Replace canUnlockWithClanCheck with correct implementation ===
Write-Host "`n[1/3] Fixing SkillTreeRegistry.java..." -ForegroundColor Yellow

$content = [System.IO.File]::ReadAllText($regFile, $utf8)
$content = $content.Replace("`r`n", "`n")

# Remove the wrong implementation with tags
$wrongMethod = @'
    public static boolean canUnlockWithClanCheck(
            com.example.shinobicore.stat.NinjaPlayerData data,
            com.example.shinobicore.tree.SkillTreeNode node) {
        // S12-10: Clan restriction check
        if (node.tags() != null) {
            for (String tag : node.tags()) {
                if (tag.startsWith("clan:")) {
                    String requiredClan = tag.substring(5);
                    if (!requiredClan.equals(data.getClanId())) {
                        return false; // Non-clan member cannot unlock clan techniques
                    }
                }
            }
        }
        return true;
    }
'@

$correctMethod = @'
    public static boolean canUnlockWithClanCheck(
            com.example.shinobicore.stat.NinjaPlayerData data,
            com.example.shinobicore.tree.SkillTreeNode node) {
        // S12-10: Clan restriction check using clanRequired field
        if (node.hasClanRestriction()) {
            if (!node.clanRequired().equals(data.getClanId())) {
                return false; // Non-clan member cannot unlock clan techniques
            }
        }
        return true;
    }
'@

$content = $content.Replace($wrongMethod, $correctMethod)
[System.IO.File]::WriteAllText($regFile, $content, $utf8)
Write-Host "  [OK] canUnlockWithClanCheck fixed" -ForegroundColor Green

# === FIX 2: Add 28 clan jutsu nodes to tree.json ===
Write-Host "`n[2/3] Adding 28 clan nodes to tree.json..." -ForegroundColor Yellow

$treeFile = Join-Path $resBase "data\shinobicore\skill_tree\tree.json"
$treeContent = [System.IO.File]::ReadAllText($treeFile, $utf8)

# Define clan nodes with proper format matching existing tree.json style
$clanNodes = @(
    @{ id="susanoo"; clan="uchiha"; branch="fire"; dist=5; jutsuId="shinobicore:susanoo"; cost=25; req=@("fire_dragon","fire_release_great_fireball") },
    @{ id="fire_sphere_v2"; clan="uchiha"; branch="fire"; dist=3; jutsuId="shinobicore:fire_sphere_v2"; cost=15; req=@("fire_release_flame_bullet") },
    @{ id="genjutsu_coma"; clan="uchiha"; branch="general"; dist=4; jutsuId="shinobicore:genjutsu_coma"; cost=20; req=@("genjutsu_paralysis") },
    @{ id="sharingan_foresight"; clan="uchiha"; branch="general"; dist=3; jutsuId="shinobicore:sharingan_foresight"; cost=15; req=@() },
    @{ id="hyu_sky_vortex"; clan="hyuga"; branch="general"; dist=3; jutsuId="shinobicore:hyu_sky_vortex"; cost=15; req=@("hyuga_rotation") },
    @{ id="hyu_hakke_shield"; clan="hyuga"; branch="general"; dist=2; jutsuId="shinobicore:hyu_hakke_shield"; cost=12; req=@("hyuga_rotation") },
    @{ id="hyu_pressure_point"; clan="hyuga"; branch="general"; dist=2; jutsuId="shinobicore:hyu_pressure_point"; cost=10; req=@() },
    @{ id="uzumaki_chains"; clan="uzumaki"; branch="general"; dist=3; jutsuId="shinobicore:uzumaki_chains"; cost=15; req=@("gen_chakra_surge") },
    @{ id="uzumaki_barrier"; clan="uzumaki"; branch="general"; dist=3; jutsuId="shinobicore:uzumaki_barrier"; cost=15; req=@("sealing_bind") },
    @{ id="uzumaki_chakra_vortex"; clan="uzumaki"; branch="general"; dist=2; jutsuId="shinobicore:uzumaki_chakra_vortex"; cost=12; req=@() },
    @{ id="senju_wood_dragon"; clan="senju"; branch="earth"; dist=5; jutsuId="shinobicore:senju_wood_dragon"; cost=25; req=@("earth_golem","water_dragon_bullet") },
    @{ id="senju_regeneration"; clan="senju"; branch="general"; dist=2; jutsuId="shinobicore:senju_regeneration"; cost=12; req=@() },
    @{ id="senju_wood_wall"; clan="senju"; branch="earth"; dist=2; jutsuId="shinobicore:senju_wood_wall"; cost=12; req=@("earth_release_earth_wall") },
    @{ id="nara_shadow_grab"; clan="nara"; branch="general"; dist=2; jutsuId="shinobicore:nara_shadow_grab"; cost=10; req=@() },
    @{ id="nara_shadow_loop"; clan="nara"; branch="general"; dist=3; jutsuId="shinobicore:nara_shadow_loop"; cost=15; req=@("nara_shadow_grab") },
    @{ id="nara_shadow_spike"; clan="nara"; branch="general"; dist=2; jutsuId="shinobicore:nara_shadow_spike"; cost=12; req=@("nara_shadow_grab") },
    @{ id="aburame_swarm"; clan="aburame"; branch="general"; dist=2; jutsuId="shinobicore:aburame_swarm"; cost=10; req=@() },
    @{ id="aburame_bug_shield"; clan="aburame"; branch="general"; dist=2; jutsuId="shinobicore:aburame_bug_shield"; cost=10; req=@() },
    @{ id="aburame_bug_bomb"; clan="aburame"; branch="general"; dist=3; jutsuId="shinobicore:aburame_bug_bomb"; cost=15; req=@("aburame_swarm") },
    @{ id="inuzuka_wolf_fang"; clan="inuzuka"; branch="general"; dist=2; jutsuId="shinobicore:inuzuka_wolf_fang"; cost=10; req=@() },
    @{ id="inuzuka_beast_sense"; clan="inuzuka"; branch="general"; dist=2; jutsuId="shinobicore:inuzuka_beast_sense"; cost=10; req=@() },
    @{ id="inuzuka_spin_fang"; clan="inuzuka"; branch="general"; dist=3; jutsuId="shinobicore:inuzuka_spin_fang"; cost=15; req=@("inuzuka_wolf_fang") },
    @{ id="akimichi_expansion"; clan="akimichi"; branch="general"; dist=2; jutsuId="shinobicore:akimichi_expansion"; cost=12; req=@() },
    @{ id="akimichi_stone_fist"; clan="akimichi"; branch="general"; dist=3; jutsuId="shinobicore:akimichi_stone_fist"; cost=15; req=@("akimichi_expansion") },
    @{ id="akimichi_butterfly"; clan="akimichi"; branch="general"; dist=5; jutsuId="shinobicore:akimichi_butterfly"; cost=25; req=@("akimichi_expansion","akimichi_stone_fist") },
    @{ id="hatake_lightning_blade"; clan="hatake"; branch="lightning"; dist=3; jutsuId="shinobicore:hatake_lightning_blade"; cost=15; req=@("lightning_release_shock") },
    @{ id="hatake_shadow_step"; clan="hatake"; branch="general"; dist=2; jutsuId="shinobicore:hatake_shadow_step"; cost=12; req=@("shunshin_no_jutsu") },
    @{ id="hatake_raikiri"; clan="hatake"; branch="lightning"; dist=5; jutsuId="shinobicore:hatake_raikiri"; cost=25; req=@("hatake_lightning_blade","lightning_release_kirin") }
)

# Build JSON entries matching existing format
$nodesToAdd = @()
foreach ($n in $clanNodes) {
    $reqJson = if ($n.req.Count -eq 0) { "[]" } else {
        $reqItems = ($n.req | ForEach-Object { "`"$_`"" }) -join ", "
        "[ $reqItems ]"
    }
    
    $nodesToAdd += @"
                  {
                      "id":  "$($n.id)",
                      "branch":  "$($n.branch)",
                      "distance":  $($n.dist),
                      "type":  "jutsu",
                      "jutsuId":  "$($n.jutsuId)",
                      "spCost":  $($n.cost),
                      "requires":  $reqJson,
                      "icon":  "\u25C6",
                      "clanRequired":  "$($n.clan)"
                  }
"@
}

# Insert nodes before the closing bracket of nodes array
# Find last node entry and append
$allNodesJson = $nodesToAdd -join ",`n"

# Find position of last closing bracket of nodes array
$lastBracket = $treeContent.LastIndexOf(']')
if ($lastBracket -gt 0) {
    # Find the comma before the last ] to insert after last node
    # Insert before the last ]
    $treeContent = $treeContent.Substring(0, $lastBracket) + ",`n" + $allNodesJson + "`n    ]" + $treeContent.Substring($lastBracket + 1)
    [System.IO.File]::WriteAllText($treeFile, $treeContent, $utf8)
    Write-Host ("  [OK] Added " + $clanNodes.Count + " clan nodes to tree.json") -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Could not find insertion point" -ForegroundColor Red
}

# === BUILD ===
Write-Host "`n[3/3] Building..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }