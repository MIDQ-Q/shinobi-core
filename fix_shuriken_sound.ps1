$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\entity\ShurikenEntity.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace('SoundEvents.ENTITY_ARROW_HIT_GROUND', 'SoundEvents.BLOCK_WOOD_HIT')
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "Fixed: ENTITY_ARROW_HIT_GROUND -> BLOCK_WOOD_HIT" -ForegroundColor Green