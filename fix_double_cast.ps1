$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\client\SkillTreeScreen.java"
$content = [System.IO.File]::ReadAllText($file, $utf8)

# Меняем float на double для viewX/viewY и dragViewX/dragViewY
$content = $content.Replace("private float viewX, viewY;", "private double viewX, viewY;")
$content = $content.Replace("private float dragViewX, dragViewY;", "private double dragViewX, dragViewY;")

[System.IO.File]::WriteAllText($file, $content, $utf8)
Write-Host "SkillTreeScreen.java fixed: float -> double for viewX/viewY" -ForegroundColor Green