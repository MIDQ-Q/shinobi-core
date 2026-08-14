$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$ps = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ProgressionScreen.java"

$c = [System.IO.File]::ReadAllText($ps, $utf8)

# 1. Add import
if (-not $c.Contains("import com.example.shinobicore.client.JutsuAssignmentScreen;")) {
    $c = $c.Replace(
        "import com.example.shinobicore.client.attunement.AttunementScreen;",
        "import com.example.shinobicore.client.attunement.AttunementScreen;`nimport com.example.shinobicore.client.JutsuAssignmentScreen;"
    )
    Write-Host "[OK] Added JutsuAssignmentScreen import"
}

# 2. Replace slot click to open new screen
$c = $c.Replace(
    "assignSlot = i; listOffset = 0; return true;",
    "client.setScreen(new JutsuAssignmentScreen(this, loadoutSet, i)); return true;"
)
Write-Host "[OK] Slot click -> JutsuAssignmentScreen"

[System.IO.File]::WriteAllText($ps, $c, $utf8)
Write-Host "=== MENU FIX APPLIED ==="