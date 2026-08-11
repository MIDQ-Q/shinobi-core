$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
Write-Host "=== FIX SENSORY ===" -ForegroundColor Cyan

function Patch($file, $marker, $insert, $name) {
    $c = [System.IO.File]::ReadAllText($file, $utf8)
    if ($c.Contains($marker)) {
        $c = $c.Replace($marker, $insert)
        [System.IO.File]::WriteAllText($file, $c, $utf8)
        Write-Host "[OK] $name" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] $name - marker not found (already applied?)" -ForegroundColor Yellow
    }
}

# === [1] ClientInputHandler: обработчик Y (ASCII-маркер!) ===
$file = "$src\client\ClientInputHandler.java"
$marker = '        if (KeyBindings.CAST_A.wasPressed()) {'
$insert = @'
        // === SENSORY TOGGLE (Y) ===
        if (KeyBindings.TOGGLE_SENSORY.wasPressed()) {
            boolean newState = !ClientNinjaState.sensoryEnabled;
            ClientNinjaState.sensoryEnabled = newState;
            ShinobiCore.LOGGER.info("[SENSORY] Toggled: {}", newState);
            if (client.getNetworkHandler() != null) {
                PacketByteBuf senBuf = new PacketByteBuf(Unpooled.buffer());
                senBuf.writeBoolean(newState);
                ClientPlayNetworking.send(ModPackets.SENSORY_TOGGLE_ID, senBuf);
            }
            client.player.sendMessage(Text.literal(newState ? "§aSensory: ON" : "§7Sensory: OFF"), false);
        }

        if (KeyBindings.CAST_A.wasPressed()) {
'@
Patch $file $marker $insert "ClientInputHandler: Y handler"

# === [2] NinjaPlayerData: в старых сейвах default = true ===
$file = "$src\stat\NinjaPlayerData.java"
$marker = 'sensoryEnabled = nbt.getBoolean("SensoryEnabled");'
$insert = 'sensoryEnabled = !nbt.contains("SensoryEnabled") || nbt.getBoolean("SensoryEnabled");'
Patch $file $marker $insert "NinjaPlayerData: old saves default ON"

# === [3] ShinobiCoreClient: читаем buf ДО client.execute() ===
$file = "$src\client\ShinobiCoreClient.java"
$marker = 'for (ElementType e : ElementType.values()) nu.put(e.getId(), buf.readBoolean());'
$insert = @'
for (ElementType e : ElementType.values()) nu.put(e.getId(), buf.readBoolean());
        boolean sen = buf.readBoolean();
'@
Patch $file $marker $insert "ShinobiCoreClient: read sensory before execute"

$marker = 'ClientNinjaState.sensoryEnabled = buf.readBoolean();'
$insert = 'ClientNinjaState.sensoryEnabled = sen;'
Patch $file $marker $insert "ShinobiCoreClient: use pre-read value"

# === [4] HUD: индикатор состояния Sensory ===
$file = "$src\client\ChakraHudRenderer.java"
$marker = '        if (ClientNinjaState.dangerSense) {'
$insert = @'
        if (ClientNinjaState.unlockedNodes.contains("sen_glow")) {
            context.drawTextWithShadow(client.textRenderer,
                    Text.literal(ClientNinjaState.sensoryEnabled ? "SENSORY ON" : "SENSORY OFF"),
                    10, y, ClientNinjaState.sensoryEnabled ? 0xFF66DDFF : 0xFF666666);
            y += 10;
        }
        if (ClientNinjaState.dangerSense) {
'@
Patch $file $marker $insert "ChakraHudRenderer: sensory indicator"

Write-Host "`n=== DONE ===" -ForegroundColor Cyan
Write-Host "Run: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Yellow