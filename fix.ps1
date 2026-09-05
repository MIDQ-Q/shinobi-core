$root = "E:\Games\mod"
$names = @("ProgressionScreen.java","SkillTreeScreen.java","JutsuAssignmentScreen.java",
           "AttunementScreen.java","ClientNinjaStateHolder.java","ModPackets.java",
           "KeyBindings.java","KeyInputHandler.java","ClientNinjaState.java")
$sb = New-Object System.Text.StringBuilder
foreach ($n in $names) {
    $f = Get-ChildItem -Path (Join-Path $root "src\main\java") -Recurse -Filter $n | Select-Object -First 1
    if ($f) {
        [void]$sb.AppendLine("===FILE: " + $f.FullName + "===")
        [void]$sb.AppendLine([System.IO.File]::ReadAllText($f.FullName))
    } else {
        [void]$sb.AppendLine("===MISSING: $n===")
    }
}
[System.IO.File]::WriteAllText((Join-Path $root "ui_dump.txt"), $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "DONE: E:\Games\mod\ui_dump.txt - attach it" -ForegroundColor Green