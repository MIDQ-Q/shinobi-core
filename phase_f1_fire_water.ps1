$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$jutsuDir = "$base\resources\data\shinobicore\jutsu"
$treeFile = "$base\resources\data\shinobicore\skill_tree\tree.json"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============================================================
# FIRE RELEASE (14 techniques)
# ============================================================
$jsons = @{}

$jsons["fire_barrage"] = @'
{"id":"shinobicore:fire_barrage","name":"Fire Release: Fireball Barrage","category":"elemental_ninjutsu","nature":"fire","type":"projectile","params":{"speed":1.8,"radius":0.8,"particle":"flame","lifetime":60,"count":8,"spread":0.3},"baseCost":30,"baseDamage":6,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":20,"nature_fire":25,"ninjutsu":18}}
'@
$jsons["fire_running"] = @'
{"id":"shinobicore:fire_running","name":"Fire Release: Running Fire","category":"elemental_ninjutsu","nature":"fire","type":"dash","params":{"distance":8,"knockback":0.8,"hitRadius":2,"particle":"flame","particleCount":40,"statusEffect":"fire","statusDuration":3},"baseCost":28,"baseDamage":5,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"control":18,"nature_fire":22,"ninjutsu":15}}
'@
$jsons["fire_cloak"] = @'
{"id":"shinobicore:fire_cloak","name":"Fire Release: Flame Cloak","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"fire_resistance","amplifier":0,"duration":300},"baseCost":32,"baseDamage":0,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":20,"nature_fire":26,"ninjutsu":18}}
'@
$jsons["fire_ash_hide"] = @'
{"id":"shinobicore:fire_ash_hide","name":"Fire Release: Hiding in Ash","category":"elemental_ninjutsu","nature":"fire","type":"aoe","params":{"radius":5,"particle":"smoke","particleCount":70,"statusEffect":"blindness","statusDuration":80},"baseCost":26,"baseDamage":2,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"control":18,"nature_fire":24,"ninjutsu":16}}
'@
$jsons["fire_toad_oil"] = @'
{"id":"shinobicore:fire_toad_oil","name":"Fire Release: Toad Oil Flame","category":"elemental_ninjutsu","nature":"fire","type":"projectile","params":{"speed":1.6,"radius":3,"particle":"flame","lifetime":80,"statusEffect":"slowness","statusDuration":60},"baseCost":30,"baseDamage":7,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":20,"nature_fire":26,"ninjutsu":18}}
'@
$jsons["fire_flower"] = @'
{"id":"shinobicore:fire_flower","name":"Fire Release: Great Flame Flower","category":"elemental_ninjutsu","nature":"fire","type":"aoe","params":{"radius":4,"particle":"flame","particleCount":60,"knockback":2.0,"statusEffect":"levitation","statusDuration":20},"baseCost":34,"baseDamage":8,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_fire":28,"ninjutsu":20}}
'@
$jsons["fire_phoenix_sage_f"] = @'
{"id":"shinobicore:fire_phoenix_sage_f","name":"Fire Release: Phoenix Sage Flower","category":"elemental_ninjutsu","nature":"fire","type":"projectile","params":{"speed":2.0,"radius":0.6,"particle":"flame","lifetime":70,"count":12,"homing":true},"baseCost":32,"baseDamage":4,"strain":8,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_fire":28,"ninjutsu":18,"perception":15}}
'@
$jsons["fire_prison"] = @'
{"id":"shinobicore:fire_prison","name":"Fire Release: Flame Prison","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ZoneBehavior","params":{"range":10,"radius":5,"duration":160,"tickDamage":3,"tickInterval":20,"burn":true},"baseCost":38,"baseDamage":0,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":24,"nature_fire":30,"ninjutsu":22}}
'@
$jsons["fire_scorched"] = @'
{"id":"shinobicore:fire_scorched","name":"Fire Release: Scorched Earth","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ZoneBehavior","params":{"range":8,"radius":6,"duration":200,"tickDamage":2,"tickInterval":25,"burn":true},"baseCost":40,"baseDamage":0,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":24,"nature_fire":32,"ninjutsu":22}}
'@
$jsons["fire_exploding"] = @'
{"id":"shinobicore:fire_exploding","name":"Fire Release: Exploding Flame","category":"elemental_ninjutsu","nature":"fire","type":"projectile","params":{"speed":1.8,"radius":4,"particle":"flame","lifetime":70,"explode":true},"baseCost":32,"baseDamage":10,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_fire":28,"ninjutsu":20}}
'@
$jsons["fire_ash_pile"] = @'
{"id":"shinobicore:fire_ash_pile","name":"Fire Release: Ash Pile Burn","category":"elemental_ninjutsu","nature":"fire","type":"aoe","params":{"radius":6,"particle":"smoke","particleCount":80,"statusEffect":"blindness","statusDuration":100,"statusAmplifier":1},"baseCost":34,"baseDamage":4,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_fire":28,"ninjutsu":20}}
'@
$jsons["fire_hard_work"] = @'
{"id":"shinobicore:fire_hard_work","name":"Fire Release: Intelligent Hard Work","category":"elemental_ninjutsu","nature":"fire","type":"projectile","params":{"speed":1.2,"radius":6,"particle":"flame","lifetime":100,"pierce":2},"baseCost":45,"baseDamage":16,"strain":12,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"nature_fire":35,"ninjutsu":26}}
'@
$jsons["fire_vacuum"] = @'
{"id":"shinobicore:fire_vacuum","name":"Fire Release: Vacuum Flame","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.PullBehavior","params":{"range":12,"radius":7,"pullStrength":0.5,"duration":60},"baseCost":38,"baseDamage":4,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":25,"nature_fire":32,"ninjutsu":22}}
'@
$jsons["fire_bakuton"] = @'
{"id":"shinobicore:fire_bakuton","name":"Fire Release: Bakuton","category":"elemental_ninjutsu","nature":"fire","type":"aoe","params":{"radius":8,"particle":"explosion","particleCount":50,"chainExplosion":true,"chainCount":3},"baseCost":48,"baseDamage":12,"strain":13,"requiredUsesForFullProficiency":65,"requirements":{"control":30,"nature_fire":38,"ninjutsu":28}}
'@

foreach ($k in $jsons.Keys) {
    Write-File "$jutsuDir\$k.json" $jsons[$k]
}

# ============================================================
# WATER RELEASE (15 techniques)
# ============================================================
$jsons = @{}

$jsons["water_clone"] = @'
{"id":"shinobicore:water_clone","name":"Water Release: Water Clone","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.SummonBehavior","params":{"entity":"minecraft:drowned","count":1},"baseCost":40,"baseDamage":0,"strain":10,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_water":30,"ninjutsu":22}}
'@
$jsons["water_prison_tech"] = @'
{"id":"shinobicore:water_prison_tech","name":"Water Release: Water Prison","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.RootBehavior","params":{"range":10,"radius":3,"duration":100,"fromTarget":true},"baseCost":36,"baseDamage":2,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_water":30,"ninjutsu":20}}
'@
$jsons["water_shark_bullet"] = @'
{"id":"shinobicore:water_shark_bullet","name":"Water Release: Water Shark Bullet","category":"elemental_ninjutsu","nature":"water","type":"projectile","params":{"speed":2.8,"radius":2,"particle":"water","lifetime":70,"pierce":1},"baseCost":32,"baseDamage":10,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_water":28,"ninjutsu":20}}
'@
$jsons["water_colliding"] = @'
{"id":"shinobicore:water_colliding","name":"Water Release: Colliding Wave","category":"elemental_ninjutsu","nature":"water","type":"dash","params":{"distance":10,"knockback":2.0,"hitRadius":3,"particle":"water","particleCount":60,"statusEffect":"slowness","statusDuration":60},"baseCost":38,"baseDamage":8,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":25,"nature_water":32,"ninjutsu":22}}
'@
$jsons["water_whip"] = @'
{"id":"shinobicore:water_whip","name":"Water Release: Water Dragon Whip","category":"elemental_ninjutsu","nature":"water","type":"projectile","params":{"speed":3.0,"radius":1.5,"particle":"water","lifetime":50,"pierce":2},"baseCost":30,"baseDamage":8,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_water":28,"ninjutsu":18}}
'@
$jsons["water_five_sharks"] = @'
{"id":"shinobicore:water_five_sharks","name":"Water Release: Five Feeding Sharks","category":"elemental_ninjutsu","nature":"water","type":"projectile","params":{"speed":2.4,"radius":1.2,"particle":"water","lifetime":60,"count":5,"spread":0.4},"baseCost":36,"baseDamage":6,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_water":30,"ninjutsu":22}}
'@
$jsons["water_tearing"] = @'
{"id":"shinobicore:water_tearing","name":"Water Release: Tearing Torrent","category":"elemental_ninjutsu","nature":"water","type":"dash","params":{"distance":12,"knockback":1.5,"hitRadius":2,"particle":"water","particleCount":50},"baseCost":34,"baseDamage":7,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_water":28,"ninjutsu":20}}
'@
$jsons["water_starch"] = @'
{"id":"shinobicore:water_starch","name":"Water Release: Starch Syrup Field","category":"elemental_ninjutsu","nature":"water","type":"aoe","params":{"radius":7,"particle":"water","particleCount":80,"statusEffect":"slowness","statusDuration":160,"statusAmplifier":2},"baseCost":38,"baseDamage":0,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":25,"nature_water":32,"ninjutsu":22}}
'@
$jsons["water_formation"] = @'
{"id":"shinobicore:water_formation","name":"Water Release: Water Formation Wall","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.WaterMirrorBehavior","params":{"range":6,"radius":3,"lifetime":120},"baseCost":32,"baseDamage":0,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_water":28,"ninjutsu":18}}
'@
$jsons["water_rain"] = @'
{"id":"shinobicore:water_rain","name":"Water Release: Rain of Arrows","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ArrowRainBehavior","params":{"count":20,"area":8,"arrowDamage":3},"baseCost":42,"baseDamage":0,"strain":11,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_water":32,"ninjutsu":22}}
'@
$jsons["water_mirror_tech"] = @'
{"id":"shinobicore:water_mirror_tech","name":"Water Release: Water Mirror","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.WaterMirrorBehavior","params":{"range":10,"radius":5,"lifetime":150},"baseCost":36,"baseDamage":0,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_water":30,"ninjutsu":22}}
'@
$jsons["water_hardliner"] = @'
{"id":"shinobicore:water_hardliner","name":"Water Release: Hardliner Rain","category":"elemental_ninjutsu","nature":"water","type":"aoe","params":{"radius":8,"particle":"water","particleCount":90,"statusEffect":"weakness","statusDuration":120,"statusAmplifier":1},"baseCost":40,"baseDamage":4,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_water":34,"ninjutsu":24}}
'@
$jsons["water_gun"] = @'
{"id":"shinobicore:water_gun","name":"Water Release: Water Gun","category":"elemental_ninjutsu","nature":"water","type":"projectile","params":{"speed":3.5,"radius":1,"particle":"water","lifetime":80,"pierce":3},"baseCost":34,"baseDamage":12,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_water":30,"ninjutsu":22,"perception":15}}
'@
$jsons["water_maelstrom_tech"] = @'
{"id":"shinobicore:water_maelstrom_tech","name":"Water Release: Maelstrom Vortex","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.PullBehavior","params":{"range":10,"radius":6,"pullStrength":0.6,"duration":80},"baseCost":40,"baseDamage":3,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_water":32,"ninjutsu":22}}
'@
$jsons["water_spout"] = @'
{"id":"shinobicore:water_spout","name":"Water Release: Water Spout","category":"elemental_ninjutsu","nature":"water","type":"aoe","params":{"radius":4,"particle":"water","particleCount":70,"knockback":2.5,"statusEffect":"levitation","statusDuration":30},"baseCost":38,"baseDamage":8,"strain":10,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_water":30,"ninjutsu":22}}
'@

foreach ($k in $jsons.Keys) {
    Write-File "$jutsuDir\$k.json" $jsons[$k]
}

# ============================================================
# PATCH TREE.JSON (29 new nodes)
# ============================================================
$tree = [System.IO.File]::ReadAllText($treeFile, $utf8)
if (-not $tree.Contains('"fire_barrage"')) {
    $newNodes = @'
,
{"id":"fire_barrage_n","branch":"fire","distance":6,"type":"jutsu","jutsuId":"shinobicore:fire_barrage","spCost":7,"requires":["fire_prison_n"],"icon":"F","name":"Fireball Barrage","description":"8 fireballs cone"},
{"id":"fire_running_n","branch":"fire","distance":6,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:fire_running","spCost":6,"requires":["fire_scorch_n"],"icon":"F","name":"Running Fire","description":"Fire dash trail"},
{"id":"fire_cloak_n","branch":"fire","distance":6,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:fire_cloak","spCost":7,"requires":["fire_expl"],"icon":"F","name":"Flame Cloak","description":"Fire resistance buff"},
{"id":"fire_ash_hide_n","branch":"fire","distance":5,"angleOffset":18,"type":"jutsu","jutsuId":"shinobicore:fire_ash_hide","spCost":6,"requires":["fire_ash_n"],"icon":"F","name":"Hiding in Ash","description":"Blind smoke cloud"},
{"id":"fire_toad_n","branch":"fire","distance":5,"angleOffset":-18,"type":"jutsu","jutsuId":"shinobicore:fire_toad_oil","spCost":7,"requires":["fire_exploding"],"icon":"F","name":"Toad Oil Flame","description":"Slowing fireball"},
{"id":"fire_flower_n","branch":"fire","distance":6,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:fire_flower","spCost":8,"requires":["fire_prison_n"],"icon":"F","name":"Flame Flower","description":"Upward explosion"},
{"id":"fire_phoenix_f_n","branch":"fire","distance":6,"angleOffset":-20,"type":"jutsu","jutsuId":"shinobicore:fire_phoenix_sage_f","spCost":7,"requires":["fire_ash_n"],"icon":"F","name":"Phoenix Sage","description":"12 homing flames"},
{"id":"fire_exploding_n","branch":"fire","distance":5,"type":"jutsu","jutsuId":"shinobicore:fire_exploding","spCost":7,"requires":["fire_advanced"],"icon":"F","name":"Exploding Flame","description":"AOE fireball"},
{"id":"fire_hard_n","branch":"fire","distance":7,"type":"jutsu","jutsuId":"shinobicore:fire_hard_work","spCost":10,"requires":["fire_prison_n","fire_scorch_n"],"icon":"F","name":"Hard Work","description":"Massive fire wave"},
{"id":"fire_vacuum_n","branch":"fire","distance":7,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:fire_vacuum","spCost":8,"requires":["fire_scorch_n"],"icon":"F","name":"Vacuum Flame","description":"Pulls enemies"},
{"id":"fire_bakuton_n","branch":"fire","distance":7,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:fire_bakuton","spCost":11,"requires":["fire_prison_n","fire_exploding_n"],"icon":"F","name":"Bakuton","description":"Chain explosions"},
{"id":"water_clone_n","branch":"water","distance":5,"type":"jutsu","jutsuId":"shinobicore:water_clone","spCost":8,"requires":["water_prison_n"],"icon":"W","name":"Water Clone","description":"Summon drowned"},
{"id":"water_prison_t_n","branch":"water","distance":5,"angleOffset":15,"type":"jutsu","jutsuId":"shinobicore:water_prison_tech","spCost":7,"requires":["water_raging"],"icon":"W","name":"Water Prison","description":"Trap target"},
{"id":"water_shark_b_n","branch":"water","distance":5,"angleOffset":-15,"type":"jutsu","jutsuId":"shinobicore:water_shark_bullet","spCost":7,"requires":["water_shark_n"],"icon":"W","name":"Shark Bullet","description":"Fast piercing"},
{"id":"water_colliding_n","branch":"water","distance":6,"type":"jutsu","jutsuId":"shinobicore:water_colliding","spCost":8,"requires":["water_mael_n"],"icon":"W","name":"Colliding Wave","description":"Knockback dash"},
{"id":"water_whip_n","branch":"water","distance":6,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:water_whip","spCost":7,"requires":["water_shark_n"],"icon":"W","name":"Water Whip","description":"Long-range pierce"},
{"id":"water_five_n","branch":"water","distance":6,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:water_five_sharks","spCost":8,"requires":["water_shark_n"],"icon":"W","name":"Five Sharks","description":"5 shark spread"},
{"id":"water_tearing_n","branch":"water","distance":6,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:water_tearing","spCost":7,"requires":["water_colliding_n"],"icon":"W","name":"Tearing Torrent","description":"Water dash"},
{"id":"water_starch_n","branch":"water","distance":6,"angleOffset":-20,"type":"jutsu","jutsuId":"shinobicore:water_starch","spCost":8,"requires":["water_mael_n"],"icon":"W","name":"Starch Field","description":"Massive slow AOE"},
{"id":"water_formation_n","branch":"water","distance":5,"angleOffset":18,"type":"jutsu","jutsuId":"shinobicore:water_formation","spCost":7,"requires":["water_prison_n"],"icon":"W","name":"Formation Wall","description":"Water barrier"},
{"id":"water_hardliner_n","branch":"water","distance":7,"type":"jutsu","jutsuId":"shinobicore:water_hardliner","spCost":9,"requires":["water_starch_n"],"icon":"W","name":"Hardliner Rain","description":"Weakness rain"},
{"id":"water_gun_n","branch":"water","distance":7,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:water_gun","spCost":8,"requires":["water_shark_b_n"],"icon":"W","name":"Water Gun","description":"Sniper pierce"},
{"id":"water_mael_t_n","branch":"water","distance":7,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:water_maelstrom_tech","spCost":9,"requires":["water_mael_n"],"icon":"W","name":"Maelstrom+","description":"Stronger pull"},
{"id":"water_spout_n","branch":"water","distance":7,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:water_spout","spCost":8,"requires":["water_mael_n"],"icon":"W","name":"Water Spout","description":"Geyser launch"}
'@
    $tree = $tree.Replace('"description":"Regen III 15s"}', '"description":"Regen III 15s"}' + $newNodes)
    [System.IO.File]::WriteAllText($treeFile, $tree, $utf8)
    Write-Host "[OK] tree.json patched with 29 new nodes (Fire + Water)"
}

Write-Host "=== PHASE F1 (FIRE + WATER) DONE ==="
Write-Host "Created 29 JSONs + 29 tree nodes"