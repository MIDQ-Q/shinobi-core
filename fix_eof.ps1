$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java"

if (-not (Test-Path $file)) {
    Write-Host "[FAIL] File not found: $file" -ForegroundColor Red
    exit 1
}

$c = [System.IO.File]::ReadAllText($file, $utf8)

# Ищем маркер, с которого начинается корректная концовка
$marker = "// === S0-01: Attribute delta sync receiver ==="
$idx = $c.IndexOf($marker)

if ($idx -ge 0) {
    $correctEnding = @"
// === S0-01: Attribute delta sync receiver ===
        ClientPlayNetworking.registerGlobalReceiver(AttributeSyncPacket.ID, (client, handler, buf, responseSender) -> {
            // RULE: Read ALL data from buf BEFORE client.execute()!
            final AttributeSyncPacket packet = AttributeSyncPacket.read(buf);
            client.execute(() -> {
                // Client-side attribute display update will go here in S0-07
                // For now, just log for debugging
                if (client.player != null) {
                    ShinobiCore.LOGGER.debug("[ATTR-SYNC] Received {} attribute changes", packet.changedAttributes().size());
                }
            });
        });

        NarutoArmorRenderer.register();

        LivingEntityFeatureRendererRegistrationCallback.EVENT.register((entityType, entityRenderer, registrationHelper, context) -> {
            if (entityRenderer instanceof net.minecraft.client.render.entity.PlayerEntityRenderer playerRenderer) {
                registrationHelper.register(new BackKatanaRenderer(playerRenderer));
            }
        });
    }
}
"@
    # Обрезаем всё после маркера и подставляем правильный конец
    $c = $c.Substring(0, $idx) + $correctEnding
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    
    Write-Host "[OK] End of ShinobiCoreClient.java reconstructed and fixed!" -ForegroundColor Green
    Write-Host "Run: .\gradlew.bat build" -ForegroundColor Cyan
} else {
    Write-Host "[FAIL] Could not find S0-01 marker. File might be severely corrupted." -ForegroundColor Red
}