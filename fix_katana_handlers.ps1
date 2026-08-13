$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ClientInputHandler.java"

$c = [System.IO.File]::ReadAllText($file, $utf8)

# Добавляем обработчик для F (SWITCH_STANCE) после обработчика B
$markerB = @'
        // === НОВОЕ: ПЕРЕКЛЮЧЕНИЕ СТИЛЯ (B) ===
        if (KeyBindings.SWITCH_STYLE.wasPressed()) {
            if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.cycleStance(client.player);
                return;
            }
'@

$insertB = @'
        // === НОВОЕ: ПЕРЕКЛЮЧЕНИЕ СТИЛЯ (B) ===
        if (KeyBindings.SWITCH_STYLE.wasPressed()) {
            if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.cycleStance(client.player);
                return;
            }
'@

# Добавляем обработчик для F (SWITCH_STANCE) перед обработчиком B
$markerF = @'
        // === НОВОЕ: ПЕРЕКЛЮЧЕНИЕ СТИЛЯ (B) ===
'@

$insertF = @'
        // === ПЕРЕКЛЮЧЕНИЕ СТОЙКИ КАТАНЫ (F) ===
        if (KeyBindings.SWITCH_STANCE.wasPressed()) {
            if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.cycleStance(client.player);
            }
        }

        // === ДЕФЛЕКТ КАТАНОЙ (X) ===
        if (KeyBindings.KATANA_DEFLECT.wasPressed()) {
            if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.tryDeflect(client.player);
            }
        }

        // === НОВОЕ: ПЕРЕКЛЮЧЕНИЕ СТИЛЯ (B) ===
'@

$c = $c.Replace($markerF, $insertF)
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "Added F and X handlers to ClientInputHandler" -ForegroundColor Green