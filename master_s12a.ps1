# ============================================================
# SPRINT 12 PHASE A1: Clan Bonuses + Jutsu JSON + Tree
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$resBase = Join-Path $root "src\main\resources"
$jutsuDir = Join-Path $resBase "data\shinobicore\jutsu"
$treeFile = Join-Path $resBase "data\shinobicore\skill_tree\tree.json"
$clansFile = Join-Path $resBase "data\shinobicore\clans.json"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 12 PHASE A1: Bonuses + Jutsu JSON + Tree" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
}

# ============================================================
# SECTION 1: 42 NEW JUTSU JSON FILES
# ============================================================
Write-Host "[A1] Creating 42 jutsu JSON files..." -ForegroundColor Yellow

$jutsuDefs = @(
    # UCHIHA (4 new)
    @{ id="susanoo"; name="Susanoo"; nature="fire"; tier=4; cast=40; cd=200; cost=80; beh="SusanooBehavior"; tags=@("fire","defense","clan:uchiha") },
    @{ id="fire_sphere_v2"; name="Fire Sphere"; nature="fire"; tier=2; cast=20; cd=60; cost=25; beh="FireSphereBehavior"; tags=@("fire","projectile","clan:uchiha") },
    @{ id="genjutsu_coma"; name="Genjutsu Coma"; nature="none"; tier=3; cast=30; cd=120; cost=40; beh="GenjutsuComaBehavior"; tags=@("genjutsu","control","clan:uchiha") },
    @{ id="sharingan_foresight"; name="Sharingan Foresight"; nature="none"; tier=2; cast=10; cd=80; cost=20; beh="ForesightBehavior"; tags=@("utility","clan:uchiha") },
    # HYUGA (3 new)
    @{ id="hyu_sky_vortex"; name="Sky Vortex"; nature="none"; tier=3; cast=25; cd=90; cost=35; beh="SkyVortexBehavior"; tags=@("melee","clan:hyuga") },
    @{ id="hyu_hakke_shield"; name="Hakke Shield"; nature="none"; tier=2; cast=15; cd=60; cost=25; beh="HakkeShieldBehavior"; tags=@("defense","clan:hyuga") },
    @{ id="hyu_pressure_point"; name="Pressure Point Strike"; nature="none"; tier=2; cast=15; cd=40; cost=15; beh="PressurePointBehavior"; tags=@("melee","clan:hyuga") },
    # UZUMAKI (5 new)
    @{ id="uzumaki_chains"; name="Chakra Chains"; nature="none"; tier=3; cast=25; cd=100; cost=40; beh="ChakraChainsBehavior"; tags=@("control","clan:uzumaki") },
    @{ id="uzumaki_barrier"; name="Barrier Seal"; nature="none"; tier=3; cast=30; cd=120; cost=45; beh="BarrierSealBehavior"; tags=@("defense","clan:uzumaki") },
    @{ id="uzumaki_chakra_vortex"; name="Chakra Vortex"; nature="none"; tier=2; cast=20; cd=80; cost=30; beh="ChakraVortexBehavior"; tags=@("aoe","clan:uzumaki") },
    @{ id="uzumaki_life_force"; name="Life Force"; nature="none"; tier=2; cast=20; cd=100; cost=35; beh="LifeForceBehavior"; tags=@("heal","clan:uzumaki") },
    @{ id="uzumaki_suppression"; name="Suppression Seal"; nature="none"; tier=4; cast=40; cd=160; cost=60; beh="SuppressionSealBehavior"; tags=@("control","clan:uzumaki") },
    # SENJU (5 new)
    @{ id="senju_wood_dragon"; name="Wood Dragon"; nature="earth"; tier=4; cast=40; cd=180; cost=70; beh="WoodDragonBehavior"; tags=@("earth","aoe","clan:senju") },
    @{ id="senju_regeneration"; name="Regeneration"; nature="none"; tier=2; cast=20; cd=120; cost=30; beh="RegenerationBehavior"; tags=@("heal","clan:senju") },
    @{ id="senju_wood_wall"; name="Wood Wall"; nature="earth"; tier=2; cast=15; cd=60; cost=20; beh="WoodWallBehavior"; tags=@("earth","defense","clan:senju") },
    @{ id="senju_forest_march"; name="Forest March"; nature="earth"; tier=3; cast=25; cd=100; cost=35; beh="ForestMarchBehavior"; tags=@("earth","utility","clan:senju") },
    @{ id="senju_wood_golem"; name="Wood Golem"; nature="earth"; tier=5; cast=50; cd=240; cost=90; beh="WoodGolemBehavior"; tags=@("earth","summon","clan:senju") },
    # NARA (5 new)
    @{ id="nara_shadow_grab"; name="Shadow Grab"; nature="none"; tier=2; cast=20; cd=60; cost=20; beh="ShadowGrabBehavior"; tags=@("control","clan:nara") },
    @{ id="nara_shadow_loop"; name="Shadow Loop"; nature="none"; tier=3; cast=25; cd=90; cost=30; beh="ShadowLoopBehavior"; tags=@("control","clan:nara") },
    @{ id="nara_shadow_spike"; name="Shadow Spike"; nature="none"; tier=2; cast=15; cd=50; cost=15; beh="ShadowSpikeBehavior"; tags=@("projectile","clan:nara") },
    @{ id="nara_shadow_control"; name="Shadow Control"; nature="none"; tier=4; cast=35; cd=140; cost=50; beh="ShadowControlBehavior"; tags=@("control","clan:nara") },
    @{ id="nara_shadow_clone"; name="Shadow Clone"; nature="none"; tier=3; cast=25; cd=100; cost=35; beh="ShadowCloneNaraBehavior"; tags=@("utility","clan:nara") },
    # ABURAME (5 new)
    @{ id="aburame_swarm"; name="Insect Swarm"; nature="none"; tier=2; cast=20; cd=70; cost=20; beh="InsectSwarmBehavior"; tags=@("dot","clan:aburame") },
    @{ id="aburame_bug_shield"; name="Bug Shield"; nature="none"; tier=2; cast=15; cd=60; cost=20; beh="BugShieldBehavior"; tags=@("defense","clan:aburame") },
    @{ id="aburame_bug_bomb"; name="Bug Bomb"; nature="none"; tier=3; cast=25; cd=90; cost=30; beh="BugBombBehavior"; tags=@("aoe","clan:aburame") },
    @{ id="aburame_spore_cloud"; name="Spore Cloud"; nature="none"; tier=3; cast=25; cd=100; cost=35; beh="SporeCloudBehavior"; tags=@("dot","clan:aburame") },
    @{ id="aburame_bug_double"; name="Bug Double"; nature="none"; tier=3; cast=25; cd=100; cost=35; beh="BugDoubleBehavior"; tags=@("utility","clan:aburame") },
    # INUZUKA (5 new)
    @{ id="inuzuka_wolf_fang"; name="Wolf Fang"; nature="none"; tier=2; cast=15; cd=40; cost=15; beh="WolfFangBehavior"; tags=@("melee","clan:inuzuka") },
    @{ id="inuzuka_beast_sense"; name="Beast Sense"; nature="none"; tier=2; cast=10; cd=80; cost=15; beh="BeastSenseBehavior"; tags=@("utility","clan:inuzuka") },
    @{ id="inuzuka_spin_fang"; name="Spinning Fang"; nature="none"; tier=3; cast=20; cd=70; cost=25; beh="SpinFangBehavior"; tags=@("melee","clan:inuzuka") },
    @{ id="inuzuka_pair_attack"; name="Pair Attack"; nature="none"; tier=3; cast=25; cd=90; cost=30; beh="PairAttackBehavior"; tags=@("melee","clan:inuzuka") },
    @{ id="inuzuka_wild_rush"; name="Wild Rush"; nature="none"; tier=2; cast=10; cd=50; cost=15; beh="WildRushBehavior"; tags=@("mobility","clan:inuzuka") },
    # AKIMICHI (5 new)
    @{ id="akimichi_expansion"; name="Expansion"; nature="none"; tier=2; cast=15; cd=60; cost=20; beh="ExpansionBehavior"; tags=@("buff","clan:akimichi") },
    @{ id="akimichi_stone_fist"; name="Stone Fist"; nature="none"; tier=3; cast=20; cd=70; cost=25; beh="StoneFistBehavior"; tags=@("melee","clan:akimichi") },
    @{ id="akimichi_butterfly"; name="Butterfly Mode"; nature="none"; tier=4; cast=35; cd=160; cost=50; beh="ButterflyBehavior"; tags=@("buff","clan:akimichi") },
    @{ id="akimichi_giant_step"; name="Giant Step"; nature="none"; tier=3; cast=20; cd=80; cost=30; beh="GiantStepBehavior"; tags=@("aoe","clan:akimichi") },
    @{ id="akimichi_meat_ball"; name="Meat Ball"; nature="none"; tier=3; cast=20; cd=70; cost=25; beh="MeatBallBehavior"; tags=@("projectile","clan:akimichi") },
    # HATAKE (5 new)
    @{ id="hatake_lightning_blade"; name="Lightning Blade"; nature="lightning"; tier=3; cast=25; cd=80; cost=30; beh="LightningBladeBehavior"; tags=@("lightning","melee","clan:hatake") },
    @{ id="hatake_shadow_step"; name="Shadow Step"; nature="none"; tier=2; cast=10; cd=50; cost=15; beh="ShadowStepBehavior"; tags=@("mobility","clan:hatake") },
    @{ id="hatake_raikiri"; name="Raikiri"; nature="lightning"; tier=4; cast=35; cd=140; cost=50; beh="RaikiriBehavior"; tags=@("lightning","melee","clan:hatake") },
    @{ id="hatake_dog_nose"; name="Dog Nose"; nature="none"; tier=2; cast=10; cd=80; cost=15; beh="DogNoseBehavior"; tags=@("utility","clan:hatake") },
    @{ id="hatake_lightning_wall"; name="Lightning Wall"; nature="lightning"; tier=3; cast=25; cd=100; cost=35; beh="LightningWallBehavior"; tags=@("lightning","defense","clan:hatake") }
)

foreach ($j in $jutsuDefs) {
    $tagsJson = ($j.tags | ForEach-Object { "`"$_`"" }) -join ", "
    $json = @"
{
    "id": "$($j.id)",
    "name": "$($j.name)",
    "nature": "$($j.nature)",
    "tier": $($j.tier),
    "castTime": $($j.cast),
    "cooldown": $($j.cd),
    "chakraCost": $($j.cost),
    "behavior": "$($j.beh)",
    "tags": [$tagsJson]
}
"@
    Write-File (Join-Path $jutsuDir "$($j.id).json") $json
}
Write-Host ("  [OK] " + $jutsuDefs.Count + " jutsu JSON files created") -ForegroundColor Green

# ============================================================
# SECTION 2: UPDATE clans.json WITH BONUSES
# ============================================================
Write-Host "[A1] Updating clans.json with bonuses..." -ForegroundColor Yellow

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

$clanGranted = @{
    "uchiha"   = @("susanoo","fire_sphere_v2","genjutsu_coma","sharingan_foresight","shadow_clone")
    "hyuga"    = @("hyu_sky_vortex","hyu_hakke_shield","hyu_pressure_point","chakra_sense")
    "uzumaki"  = @("uzumaki_chains","uzumaki_barrier","uzumaki_chakra_vortex","uzumaki_life_force","uzumaki_suppression","shadow_clone")
    "senju"    = @("senju_wood_dragon","senju_regeneration","senju_wood_wall","senju_forest_march","senju_wood_golem","chakra_sense")
    "nara"     = @("nara_shadow_grab","nara_shadow_loop","nara_shadow_spike","nara_shadow_control","nara_shadow_clone","kawarimi")
    "aburame"  = @("aburame_swarm","aburame_bug_shield","aburame_bug_bomb","aburame_spore_cloud","aburame_bug_double","kawarimi")
    "inuzuka"  = @("inuzuka_wolf_fang","inuzuka_beast_sense","inuzuka_spin_fang","inuzuka_pair_attack","inuzuka_wild_rush","chakra_sense")
    "akimichi" = @("akimichi_expansion","akimichi_stone_fist","akimichi_butterfly","akimichi_giant_step","akimichi_meat_ball","shadow_clone")
    "hatake"   = @("hatake_lightning_blade","hatake_shadow_step","hatake_raikiri","hatake_dog_nose","hatake_lightning_wall","kawarimi")
}

$clansContent = [System.IO.File]::ReadAllText($clansFile, $utf8)

foreach ($clanId in $clanBonuses.Keys) {
    $bonuses = $clanBonuses[$clanId]
    $bonusEntries = @()
    foreach ($key in $bonuses.Keys) {
        $bonusEntries += "`"$key`": $($bonuses[$key])"
    }
    $bonusJson = "{`n            " + ($bonusEntries -join ",`n            ") + "`n        }"

    # Add bonuses field after forbiddenNodes
    $pattern = "`"forbiddenNodes`": \[[^\]]*\]"
    $clansContent = [regex]::Replace($clansContent, "(`"id`": `"$clanId`"[\s\S]*?`"forbiddenNodes`": \[[^\]]*\])", "`$1,`n        `"bonuses`": $bonusJson")
}

# Update grantedNodes for each clan
foreach ($clanId in $clanGranted.Keys) {
    $nodes = $clanGranted[$clanId]
    $nodesJson = ($nodes | ForEach-Object { "`"$_`"" }) -join ", "
    $clansContent = [regex]::Replace($clansContent,
        "(`"id`": `"$clanId`"[\s\S]*?`"grantedNodes`": )\[[^\]]*\]",
        "`${1}[$nodesJson]")
}

[System.IO.File]::WriteAllText($clansFile, $clansContent, $utf8)
Write-Host "  [OK] clans.json updated with bonuses and grantedNodes" -ForegroundColor Green

# ============================================================
# SECTION 3: UPDATE tree.json WITH NEW NODES
# ============================================================
Write-Host "[A1] Updating tree.json with new nodes..." -ForegroundColor Yellow

$treeContent = [System.IO.File]::ReadAllText($treeFile, $utf8)

$newNodes = @()
foreach ($j in $jutsuDefs) {
    $clanTag = ($j.tags | Where-Object { $_ -match "^clan:" }) -replace "^clan:", ""
    $branch = switch ($clanTag) {
        "uchiha" { "fire" }
        "hyuga" { "tai" }
        "uzumaki" { "fuuin" }
        "senju" { "earth" }
        "nara" { "control" }
        "aburame" { "dot" }
        "inuzuka" { "tai" }
        "akimichi" { "buff" }
        "hatake" { "lightning" }
        default { "general" }
    }
    $dist = $j.tier
    $newNodes += @"
{
            "id": "$($j.id)",
            "branch": "$branch",
            "distance": $dist,
            "type": "jutsu",
            "effect": "unlock_jutsu",
            "value": 1,
            "spCost": $($j.tier * 2),
            "requires": [],
            "icon": "\u00a7c\u25c6",
            "name": "$($j.name)",
            "description": "Clan technique: $($j.name)",
            "tags": ["clan_only", "clan:$clanTag"]
        }
"@
}

$nodesJson = $newNodes -join ",`n        "
$treeContent = $treeContent.Replace('"nodes": [', '"nodes": [
        ' + $nodesJson + ',')

[System.IO.File]::WriteAllText($treeFile, $treeContent, $utf8)
Write-Host ("  [OK] tree.json updated with " + $jutsuDefs.Count + " new nodes") -ForegroundColor Green

Write-Host ""
Write-Host "  [A1 COMPLETE] Run A2 for Behavior classes + Java patches" -ForegroundColor Cyan