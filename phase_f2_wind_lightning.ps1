$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$jutsuDir = "$base\resources\data\shinobicore\jutsu"
$treeFile = "$base\resources\data\shinobicore\skill_tree\tree.json"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============================================================
# WIND RELEASE (12 techniques)
# ============================================================
$jsons = @{}

$jsons["wind_vacuum_bullet"] = @'
{"id":"shinobicore:wind_vacuum_bullet","name":"Wind Release: Vacuum Bullet","category":"elemental_ninjutsu","nature":"wind","type":"projectile","params":{"speed":3.2,"radius":1,"particle":"none","lifetime":60},"baseCost":26,"baseDamage":8,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"control":20,"nature_wind":25,"ninjutsu":18}}
'@
$jsons["wind_dust_cloud"] = @'
{"id":"shinobicore:wind_dust_cloud","name":"Wind Release: Dust Cloud","category":"elemental_ninjutsu","nature":"wind","type":"aoe","params":{"radius":6,"particle":"smoke","particleCount":80,"statusEffect":"blindness","statusDuration":100,"statusAmplifier":1},"baseCost":30,"baseDamage":3,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":20,"nature_wind":26,"ninjutsu":18}}
'@
$jsons["wind_spiral_shuriken"] = @'
{"id":"shinobicore:wind_spiral_shuriken","name":"Wind Release: Spiral Shuriken","category":"elemental_ninjutsu","nature":"wind","type":"projectile","params":{"speed":2.0,"radius":1.2,"particle":"wind","lifetime":80,"bounce":1,"pierce":1},"baseCost":28,"baseDamage":7,"strain":7,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_wind":26,"ninjutsu":18}}
'@
$jsons["wind_great_sickle"] = @'
{"id":"shinobicore:wind_great_sickle","name":"Wind Release: Great Sickle Weasel","category":"elemental_ninjutsu","nature":"wind","type":"dash","params":{"distance":9,"knockback":1.5,"hitRadius":2.5,"particle":"wind","particleCount":50,"statusEffect":"slowness","statusDuration":40},"baseCost":32,"baseDamage":9,"strain":8,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_wind":28,"ninjutsu":20}}
'@
$jsons["wind_air_bullet"] = @'
{"id":"shinobicore:wind_air_bullet","name":"Wind Release: Air Bullet","category":"elemental_ninjutsu","nature":"wind","type":"projectile","params":{"speed":4.0,"radius":0.8,"particle":"none","lifetime":50},"baseCost":24,"baseDamage":6,"strain":6,"requiredUsesForFullProficiency":40,"requirements":{"control":18,"nature_wind":24,"ninjutsu":16}}
'@
$jsons["wind_breakthrough_x5"] = @'
{"id":"shinobicore:wind_breakthrough_x5","name":"Wind Release: Breakthrough (x5)","category":"elemental_ninjutsu","nature":"wind","type":"projectile","params":{"speed":2.2,"radius":2,"particle":"wind","lifetime":70,"count":5,"spread":0.2},"baseCost":34,"baseDamage":6,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_wind":30,"ninjutsu":20}}
'@
$jsons["wind_vacuum_serial"] = @'
{"id":"shinobicore:wind_vacuum_serial","name":"Wind Release: Vacuum Serial Waves","category":"elemental_ninjutsu","nature":"wind","type":"aoe","params":{"radius":7,"particle":"wind","particleCount":90,"knockback":2.5,"chainExplosion":true,"chainCount":3},"baseCost":40,"baseDamage":8,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_wind":32,"ninjutsu":22}}
'@
$jsons["wind_flower_storm"] = @'
{"id":"shinobicore:wind_flower_storm","name":"Wind Release: Flower Storm","category":"elemental_ninjutsu","nature":"wind","type":"aoe","params":{"radius":5,"particle":"enchant","particleCount":70,"statusEffect":"blindness","statusDuration":80},"baseCost":30,"baseDamage":4,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_wind":28,"ninjutsu":18}}
'@
$jsons["wind_silent_hurricane"] = @'
{"id":"shinobicore:wind_silent_hurricane","name":"Wind Release: Silent Hurricane","category":"elemental_ninjutsu","nature":"wind","type":"aoe","params":{"radius":8,"particle":"none","particleCount":0,"knockback":3.0,"statusEffect":"slowness","statusDuration":60},"baseCost":38,"baseDamage":10,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_wind":34,"ninjutsu":24}}
'@
$jsons["wind_vacuum_blade"] = @'
{"id":"shinobicore:wind_vacuum_blade","name":"Wind Release: Vacuum Blade","category":"elemental_ninjutsu","nature":"wind","type":"projectile","params":{"speed":2.6,"radius":1.5,"particle":"wind","lifetime":70,"pierce":2,"homing":false},"baseCost":30,"baseDamage":9,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_wind":28,"ninjutsu":20}}
'@
$jsons["wind_gale_armor"] = @'
{"id":"shinobicore:wind_gale_armor","name":"Wind Release: Gale Armor","category":"elemental_ninjutsu","nature":"wind","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"speed","amplifier":2,"duration":300},"baseCost":32,"baseDamage":0,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_wind":28,"ninjutsu":20}}
'@
$jsons["wind_tornado"] = @'
{"id":"shinobicore:wind_tornado","name":"Wind Release: Tornado","category":"elemental_ninjutsu","nature":"wind","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.PullBehavior","params":{"range":12,"radius":5,"pullStrength":0.7,"duration":80},"baseCost":40,"baseDamage":5,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_wind":34,"ninjutsu":24}}
'@

foreach ($k in $jsons.Keys) {
    Write-File "$jutsuDir\$k.json" $jsons[$k]
}

# ============================================================
# LIGHTNING RELEASE (12 techniques)
# ============================================================
$jsons = @{}

$jsons["light_thunderbolt"] = @'
{"id":"shinobicore:light_thunderbolt","name":"Lightning Release: Thunderbolt","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ChainLightningBehavior","params":{"maxTargets":1,"chainRange":20,"damageFalloff":1.0},"baseCost":30,"baseDamage":14,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_lightning":28,"ninjutsu":20}}
'@
$jsons["light_electromagnetic"] = @'
{"id":"shinobicore:light_electromagnetic","name":"Lightning Release: Electromagnetic Murder","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ZoneBehavior","params":{"range":0,"radius":5,"duration":100,"tickDamage":3,"tickInterval":20,"burn":false},"baseCost":34,"baseDamage":0,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_lightning":30,"ninjutsu":20}}
'@
$jsons["light_four_pillar"] = @'
{"id":"shinobicore:light_four_pillar","name":"Lightning Release: Four Pillar Bind","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.RootBehavior","params":{"range":12,"radius":4,"duration":80,"fromTarget":true},"baseCost":36,"baseDamage":4,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_lightning":30,"ninjutsu":22}}
'@
$jsons["light_tornado"] = @'
{"id":"shinobicore:light_tornado","name":"Lightning Release: Lightning Tornado","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.PullBehavior","params":{"range":10,"radius":5,"pullStrength":0.6,"duration":60},"baseCost":38,"baseDamage":6,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_lightning":32,"ninjutsu":22}}
'@
$jsons["light_ball"] = @'
{"id":"shinobicore:light_ball","name":"Lightning Release: Lightning Ball","category":"elemental_ninjutsu","nature":"lightning","type":"projectile","params":{"speed":0.8,"radius":6,"particle":"lightning","lifetime":120,"pierce":3},"baseCost":42,"baseDamage":14,"strain":11,"requiredUsesForFullProficiency":60,"requirements":{"control":26,"nature_lightning":34,"ninjutsu":24}}
'@
$jsons["light_spear"] = @'
{"id":"shinobicore:light_spear","name":"Lightning Release: False Darkness Spear","category":"elemental_ninjutsu","nature":"lightning","type":"projectile","params":{"speed":5.0,"radius":1,"particle":"lightning","lifetime":40,"pierce":4},"baseCost":36,"baseDamage":12,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_lightning":32,"ninjutsu":22}}
'@
$jsons["light_signal"] = @'
{"id":"shinobicore:light_signal","name":"Lightning Release: Lightning Signal","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.TrackingKunaiBehavior","params":{"range":20,"markMs":30000},"baseCost":20,"baseDamage":0,"strain":5,"requiredUsesForFullProficiency":30,"requirements":{"control":18,"nature_lightning":24,"perception":20}}
'@
$jsons["light_nagashi"] = @'
{"id":"shinobicore:light_nagashi","name":"Lightning Release: Chidori Nagashi","category":"elemental_ninjutsu","nature":"lightning","type":"aoe","params":{"radius":5,"particle":"lightning","particleCount":80,"statusEffect":"slowness","statusDuration":60,"statusAmplifier":2},"baseCost":36,"baseDamage":10,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":24,"nature_lightning":32,"ninjutsu":22}}
'@
$jsons["light_thunderclap"] = @'
{"id":"shinobicore:light_thunderclap","name":"Lightning Release: Thunderclap Arrow","category":"elemental_ninjutsu","nature":"lightning","type":"dash","params":{"distance":15,"knockback":2.0,"hitRadius":2,"particle":"lightning","particleCount":60,"statusEffect":"slowness","statusDuration":40},"baseCost":40,"baseDamage":14,"strain":11,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_lightning":34,"ninjutsu":24}}
'@
$jsons["light_storm"] = @'
{"id":"shinobicore:light_storm","name":"Lightning Release: Lightning Storm","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ArrowRainBehavior","params":{"count":10,"area":8,"arrowDamage":6},"baseCost":44,"baseDamage":0,"strain":12,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"nature_lightning":36,"ninjutsu":26}}
'@
$jsons["light_armor_plus"] = @'
{"id":"shinobicore:light_armor_plus","name":"Lightning Release: Armor+","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"resistance","amplifier":2,"duration":300},"baseCost":38,"baseDamage":0,"strain":10,"requiredUsesForFullProficiency":50,"requirements":{"control":26,"nature_lightning":32,"ninjutsu":22}}
'@
$jsons["light_golem"] = @'
{"id":"shinobicore:light_golem","name":"Lightning Release: Lightning Beast","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.SummonBehavior","params":{"entity":"minecraft:allay","count":2},"baseCost":40,"baseDamage":0,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_lightning":32,"ninjutsu":24}}
'@

foreach ($k in $jsons.Keys) {
    Write-File "$jutsuDir\$k.json" $jsons[$k]
}

# ============================================================
# PATCH TREE.JSON (23 new nodes)
# ============================================================
$tree = [System.IO.File]::ReadAllText($treeFile, $utf8)
if (-not $tree.Contains('"wind_vacuum_bullet"')) {
    $newNodes = @'
,
{"id":"wind_vac_bullet_n","branch":"wind","distance":6,"type":"jutsu","jutsuId":"shinobicore:wind_vacuum_bullet","spCost":6,"requires":["wind_sickle_n"],"icon":"~","name":"Vacuum Bullet","description":"Invisible fast shot"},
{"id":"wind_dust_n","branch":"wind","distance":6,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:wind_dust_cloud","spCost":7,"requires":["wind_pressure_n"],"icon":"~","name":"Dust Cloud","description":"Blinding dust AOE"},
{"id":"wind_spiral_n","branch":"wind","distance":6,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:wind_spiral_shuriken","spCost":6,"requires":["wind_sickle_n"],"icon":"~","name":"Spiral Shuriken","description":"Returning blade"},
{"id":"wind_great_sickle_n","branch":"wind","distance":6,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:wind_great_sickle","spCost":7,"requires":["wind_divine_n"],"icon":"~","name":"Great Sickle","description":"Cutting dash"},
{"id":"wind_air_n","branch":"wind","distance":5,"angleOffset":18,"type":"jutsu","jutsuId":"shinobicore:wind_air_bullet","spCost":5,"requires":["wind_breakthrough"],"icon":"~","name":"Air Bullet","description":"Silent compressed air"},
{"id":"wind_x5_n","branch":"wind","distance":7,"type":"jutsu","jutsuId":"shinobicore:wind_breakthrough_x5","spCost":8,"requires":["wind_vac_n"],"icon":"~","name":"Breakthrough x5","description":"5 wind volleys"},
{"id":"wind_serial_n","branch":"wind","distance":7,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:wind_vacuum_serial","spCost":9,"requires":["wind_vac_n"],"icon":"~","name":"Serial Waves","description":"3 chained blasts"},
{"id":"wind_flower_n","branch":"wind","distance":7,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:wind_flower_storm","spCost":7,"requires":["wind_pressure_n"],"icon":"~","name":"Flower Storm","description":"Blinding vortex"},
{"id":"wind_silent_n","branch":"wind","distance":7,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:wind_silent_hurricane","spCost":9,"requires":["wind_divine_n"],"icon":"~","name":"Silent Hurricane","description":"No-warning blast"},
{"id":"wind_blade_n","branch":"wind","distance":6,"angleOffset":-20,"type":"jutsu","jutsuId":"shinobicore:wind_vacuum_blade","spCost":7,"requires":["wind_sickle_n"],"icon":"~","name":"Vacuum Blade","description":"Curved cutting wave"},
{"id":"wind_gale_armor_n","branch":"wind","distance":6,"angleOffset":24,"type":"jutsu","jutsuId":"shinobicore:wind_gale_armor","spCost":7,"requires":["wind_cage_n"],"icon":"~","name":"Gale Armor","description":"Speed III buff"},
{"id":"wind_tornado_n","branch":"wind","distance":7,"angleOffset":-20,"type":"jutsu","jutsuId":"shinobicore:wind_tornado","spCost":9,"requires":["wind_cage_n"],"icon":"~","name":"Tornado","description":"Pulling vortex"},
{"id":"light_thunderbolt_n","branch":"lightning","distance":6,"type":"jutsu","jutsuId":"shinobicore:light_thunderbolt","spCost":7,"requires":["light_cut_n"],"icon":"L","name":"Thunderbolt","description":"Instant single strike"},
{"id":"light_electro_n","branch":"lightning","distance":6,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:light_electromagnetic","spCost":8,"requires":["light_armor_n"],"icon":"L","name":"Electromagnetic","description":"Electric field aura"},
{"id":"light_pillar_n","branch":"lightning","distance":6,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:light_four_pillar","spCost":8,"requires":["light_chain_n"],"icon":"L","name":"Four Pillar Bind","description":"Immobilize target"},
{"id":"light_tornado_n","branch":"lightning","distance":6,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:light_tornado","spCost":8,"requires":["light_depth_n"],"icon":"L","name":"Lightning Tornado","description":"Electric vortex"},
{"id":"light_ball_n","branch":"lightning","distance":7,"type":"jutsu","jutsuId":"shinobicore:light_ball","spCost":10,"requires":["light_chain_n"],"icon":"L","name":"Lightning Ball","description":"Slow huge AOE"},
{"id":"light_spear_n","branch":"lightning","distance":7,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:light_spear","spCost":8,"requires":["light_cut_n"],"icon":"L","name":"Darkness Spear","description":"Fast piercing beam"},
{"id":"light_signal_n","branch":"lightning","distance":5,"angleOffset":18,"type":"jutsu","jutsuId":"shinobicore:light_signal","spCost":4,"requires":["light_darkness"],"icon":"L","name":"Lightning Signal","description":"Mark for x2 lightning"},
{"id":"light_nagashi_n","branch":"lightning","distance":6,"angleOffset":-20,"type":"jutsu","jutsuId":"shinobicore:light_nagashi","spCost":8,"requires":["light_armor_n"],"icon":"L","name":"Chidori Nagashi","description":"360 discharge"},
{"id":"light_thunderclap_n","branch":"lightning","distance":7,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:light_thunderclap","spCost":9,"requires":["light_depth_n"],"icon":"L","name":"Thunderclap Arrow","description":"Teleport strike"},
{"id":"light_storm_n","branch":"lightning","distance":7,"angleOffset":-20,"type":"jutsu","jutsuId":"shinobicore:light_storm","spCost":10,"requires":["light_chain_n"],"icon":"L","name":"Lightning Storm","description":"Sky bolts rain"},
{"id":"light_armor_plus_n","branch":"lightning","distance":6,"angleOffset":24,"type":"jutsu","jutsuId":"shinobicore:light_armor_plus","spCost":8,"requires":["light_armor_n"],"icon":"L","name":"Armor+","description":"Resistance III"},
{"id":"light_golem_n","branch":"lightning","distance":7,"angleOffset":24,"type":"jutsu","jutsuId":"shinobicore:light_golem","spCost":9,"requires":["light_beast_n"],"icon":"L","name":"Lightning Beast","description":"Summon spark pets"}
'@
    $tree = $tree.Replace('"description":"Geyser launch"}', '"description":"Geyser launch"}' + $newNodes)
    [System.IO.File]::WriteAllText($treeFile, $tree, $utf8)
    Write-Host "[OK] tree.json patched with 24 new nodes (Wind + Lightning)"
}

Write-Host "=== PHASE F2 (WIND + LIGHTNING) DONE ==="
Write-Host "Created 24 JSONs + 24 tree nodes"