$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\ShinobiCore.java"
$content = [System.IO.File]::ReadAllText($file, $utf8)

# Заменяем node.nature() на node.branch()
$content = $content.Replace("node.nature()", "node.branch()")

[System.IO.File]::WriteAllText($file, $content, $utf8)
Write-Host "ShinobiCore.java fixed: nature() -> branch()" -ForegroundColor Green

# Также проверим SkillTreeRegistry на случай если там осталось
$file2 = "E:\Games\mod\src\main\java\com\example\shinobicore\tree\SkillTreeRegistry.java"
if (Test-Path $file2) {
    $c2 = [System.IO.File]::ReadAllText($file2, $utf8)
    if ($c2.Contains("node.nature()")) {
        $c2 = $c2.Replace("node.nature()", "node.branch()")
        [System.IO.File]::WriteAllText($file2, $c2, $utf8)
        Write-Host "SkillTreeRegistry.java fixed too" -ForegroundColor Green
    } else {
        Write-Host "SkillTreeRegistry.java already OK" -ForegroundColor Gray
    }
}