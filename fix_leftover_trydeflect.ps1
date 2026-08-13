$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ClientInputHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

# Убираем старый блок tryDeflect (V с катаной) - оставляем только кик
$old = @'
            if (handEmpty) {
                TaijutsuKickHandler.tryKick(client.player);
            } else if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.tryDeflect(client.player);
            }
'@.Replace("`r`n", "`n")

$new = @'
            if (handEmpty) {
                TaijutsuKickHandler.tryKick(client.player);
            }
'@.Replace("`r`n", "`n")

$cn = $c.Replace("`r`n", "`n")
if ($cn.Contains($old)) {
    $cn = $cn.Replace($old, $new)
    [System.IO.File]::WriteAllText($file, $cn, $utf8)
    Write-Host "[OK] ClientInputHandler: removed leftover tryDeflect call" -ForegroundColor Green
} else {
    Write-Host "[SKIP] marker not found - already fixed or different state" -ForegroundColor Yellow
}

Write-Host "`nRun: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Cyan