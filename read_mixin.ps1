$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\mixin\PlayerRenderAnimationMixin.java"

Write-Host "========== PlayerRenderAnimationMixin.java =========="
[System.IO.File]::ReadAllText($f, $utf8) | Write-Host