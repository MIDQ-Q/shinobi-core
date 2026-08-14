$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$jutsuDir = "$base\resources\data\shinobicore\jutsu"
$treeFile = "$base\resources\data\shinobicore\skill_tree\tree.json"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============================================================
# EARTH RELEASE (13 techniques)
# ============================================================
$jsons = @{}

$jsons["earth_flow_river"] = @'
{"id":"shinobicore:earth_flow_river","name":"Earth Release: Earth Flow River","category":"elemental_ninjutsu","nature":"earth","type":"dash","params":{"distance":10,"knockback":2.0,"hitRadius":3,"particle":"earth","particleCount":60,"statusEffect":"slowness","statusDuration":60},"baseCost":36,"baseDamage":7,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_earth":30,"ninjutsu":20}}
'@
$jsons["earth_dragon_bullet"] = @'
{"id":"shinobicore:earth_dragon_bullet","name":"Earth Release: Earth Dragon Bullet","category":"elemental_ninjutsu","nature":"earth","type":"projectile","params":{"speed":1.6,"radius":1.5,"particle":"earth","lifetime":70,"count":5,"spread":0.3},"baseCost":34,"baseDamage":8,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_earth":28,"ninjutsu":20}}
'@
$jsons["earth_dome"] = @'
{"id":"shinobicore:earth_dome","name":"Earth Release: Earth Dome","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"resistance","amplifier":3,"duration":60},"baseCost":40,"baseDamage":0,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_earth":32,"ninjutsu":22}}
'@
$jsons["earth_headhunter"] = @'
{"id":"shinobicore:earth_headhunter","name":"Earth Release: Headhunter","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.RootBehavior","params":{"range":10,"radius":3,"duration":60,"fromTarget":true},"baseCost":32,"baseDamage":2,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_earth":28,"ninjutsu":18}}
'@
$jsons["earth_shore"] = @'
{"id":"shinobicore:earth_shore","name":"Earth Release: Earth Shore","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.WaterMirrorBehavior","params":{"range":4,"radius":2,"lifetime":100},"baseCost":28,"baseDamage":0,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"control":20,"nature_earth":26,"ninjutsu":16}}
'@
$jsons["earth_rock_lodging"] = @'
{"id":"shinobicore:earth_rock_lodging","name":"Earth Release: Rock Lodging","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"invisibility","amplifier":0,"duration":40},"baseCost":34,"baseDamage":0,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_earth":30,"ninjutsu":20}}
'@
$jsons["earth_mole"] = @'
{"id":"shinobicore:earth_mole","name":"Earth Release: Hiding Like a Mole","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"haste","amplifier":3,"duration":200},"baseCost":30,"baseDamage":0,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_earth":28,"ninjutsu":18}}
'@
$jsons["earth_iron_wall"] = @'
{"id":"shinobicore:earth_iron_wall","name":"Earth Release: Iron Wall","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"resistance","amplifier":4,"duration":100},"baseCost":44,"baseDamage":0,"strain":11,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"nature_earth":34,"ninjutsu":24}}
'@
$jsons["earth_added_weight"] = @'
{"id":"shinobicore:earth_added_weight","name":"Earth Release: Ultra Added Weight","category":"elemental_ninjutsu","nature":"earth","type":"aoe","params":{"radius":8,"particle":"earth","particleCount":90,"statusEffect":"slowness","statusDuration":120,"statusAmplifier":3},"baseCost":40,"baseDamage":4,"strain":10,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_earth":32,"ninjutsu":22}}
'@
$jsons["earth_light_weight"] = @'
{"id":"shinobicore:earth_light_weight","name":"Earth Release: Light-Weight Rock","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"jump_boost","amplifier":2,"duration":300},"baseCost":32,"baseDamage":0,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_earth":28,"ninjutsu":20}}
'@
$jsons["earth_rock_pillar"] = @'
{"id":"shinobicore:earth_rock_pillar","name":"Earth Release: Rock Pillar","category":"elemental_ninjutsu","nature":"earth","type":"aoe","params":{"radius":4,"particle":"earth","particleCount":70,"knockback":2.5,"statusEffect":"levitation","statusDuration":40},"baseCost":38,"baseDamage":8,"strain":10,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_earth":30,"ninjutsu":22}}
'@
$jsons["earth_mausoleum"] = @'
{"id":"shinobicore:earth_mausoleum","name":"Earth Release: Earth Mausoleum","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.RootBehavior","params":{"range":12,"radius":4,"duration":120,"fromTarget":true},"baseCost":42,"baseDamage":4,"strain":11,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"nature_earth":34,"ninjutsu":24}}
'@
$jsons["earth_stone_armor"] = @'
{"id":"shinobicore:earth_stone_armor","name":"Earth Release: Stone Armor","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BuffSelfBehavior","params":{"effect":"resistance","amplifier":1,"duration":400},"baseCost":34,"baseDamage":0,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_earth":30,"ninjutsu":20}}
'@

foreach ($k in $jsons.Keys) {
    Write-File "$jutsuDir\$k.json" $jsons[$k]
}

# ============================================================
# PATCH TREE.JSON (13 new nodes)
# ============================================================
$tree = [System.IO.File]::ReadAllText($treeFile, $utf8)
if (-not $tree.Contains('"earth_flow_river"')) {
    $newNodes = @'
,
{"id":"earth_flow_n","branch":"earth","distance":6,"type":"jutsu","jutsuId":"shinobicore:earth_flow_river","spCost":8,"requires":["earth_mud"],"icon":"#","name":"Flow River","description":"Mud dash sweep"},
{"id":"earth_dragon_n","branch":"earth","distance":6,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:earth_dragon_bullet","spCost":7,"requires":["earth_spear_n"],"icon":"#","name":"Dragon Bullet","description":"5 earth shots"},
{"id":"earth_dome_n","branch":"earth","distance":6,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:earth_dome","spCost":9,"requires":["earth_wall"],"icon":"#","name":"Earth Dome","description":"Full protection 3s"},
{"id":"earth_head_n","branch":"earth","distance":5,"angleOffset":18,"type":"jutsu","jutsuId":"shinobicore:earth_headhunter","spCost":7,"requires":["earth_spear_n"],"icon":"#","name":"Headhunter","description":"Bury target"},
{"id":"earth_shore_n","branch":"earth","distance":5,"angleOffset":-18,"type":"jutsu","jutsuId":"shinobicore:earth_shore","spCost":6,"requires":["earth_wall"],"icon":"#","name":"Earth Shore","description":"Raise ramp"},
{"id":"earth_lodging_n","branch":"earth","distance":6,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:earth_rock_lodging","spCost":8,"requires":["earth_head_n"],"icon":"#","name":"Rock Lodging","description":"Sink + invis"},
{"id":"earth_mole_n","branch":"earth","distance":6,"angleOffset":-20,"type":"jutsu","jutsuId":"shinobicore:earth_mole","spCost":7,"requires":["earth_shore_n"],"icon":"#","name":"Mole","description":"Fast digging"},
{"id":"earth_iron_n","branch":"earth","distance":7,"type":"jutsu","jutsuId":"shinobicore:earth_iron_wall","spCost":10,"requires":["earth_dome_n"],"icon":"#","name":"Iron Wall","description":"Resistance V 5s"},
{"id":"earth_weight_n","branch":"earth","distance":7,"angleOffset":12,"type":"jutsu","jutsuId":"shinobicore:earth_added_weight","spCost":9,"requires":["earth_quake_n"],"icon":"#","name":"Added Weight","description":"Gravity x3 AOE"},
{"id":"earth_light_n","branch":"earth","distance":6,"angleOffset":24,"type":"jutsu","jutsuId":"shinobicore:earth_light_weight","spCost":7,"requires":["earth_mole_n"],"icon":"#","name":"Light-Weight","description":"Jump boost"},
{"id":"earth_pillar_n","branch":"earth","distance":7,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:earth_rock_pillar","spCost":8,"requires":["earth_quake_n"],"icon":"#","name":"Rock Pillar","description":"Launch enemies"},
{"id":"earth_maus_n","branch":"earth","distance":7,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:earth_mausoleum","spCost":10,"requires":["earth_sand_n"],"icon":"#","name":"Mausoleum","description":"Earth prison"},
{"id":"earth_stone_n","branch":"earth","distance":6,"angleOffset":-24,"type":"jutsu","jutsuId":"shinobicore:earth_stone_armor","spCost":7,"requires":["earth_dome_n"],"icon":"#","name":"Stone Armor","description":"Long resistance"}
'@
    $tree = $tree.Replace('"description":"Summon spark pets"}', '"description":"Summon spark pets"}' + $newNodes)
    [System.IO.File]::WriteAllText($treeFile, $tree, $utf8)
    Write-Host "[OK] tree.json patched with 13 new nodes (Earth)"
}

Write-Host "=== PHASE F3 (EARTH) DONE ==="
Write-Host "Created 13 JSONs + 13 tree nodes"
Write-Host "=== PHASE F COMPLETE: ALL 5 ELEMENTS AT 20+ TECHNIQUES ==="