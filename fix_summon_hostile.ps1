$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\custom\SummonBehavior.java"

$c = [System.IO.File]::ReadAllText($f, $utf8)
$c = $c.Replace("import net.minecraft.entity.mob.Hostile;", "import net.minecraft.entity.mob.Monster;")
$c = $c.Replace("t -> (t instanceof Hostile)", "t -> (t instanceof Monster)")
[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] SummonBehavior: Hostile -> Monster"