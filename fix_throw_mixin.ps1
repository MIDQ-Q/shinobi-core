$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\mixin\PlayerRenderAnimationMixin.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
$c = $c.Replace(
    "com.example.shinobicore.client.combat.ThrowAnimations.apply(player, rightArm, leftArm, body);",
    "com.example.shinobicore.client.combat.ThrowAnimations.apply(player, rightArm, leftArm, body, head);"
)
[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] Fixed ThrowAnimations.apply signature in mixin"