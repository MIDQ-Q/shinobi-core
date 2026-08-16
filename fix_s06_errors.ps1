$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java"

Write-Host "Reading broken file..." -ForegroundColor Cyan
$broken = [System.IO.File]::ReadAllText($file, $utf8)

# 1. Извлекаем внедрённый S06 метод
$methodPattern = '(?ms)^[ \t]*private void registerS06ClientReceivers\(\)[ \t]*\{.*?^[ \t]*\}'
$methodMatch = [regex]::Match($broken, $methodPattern)
if (-not $methodMatch.Success) {
    Write-Host "[FAIL] Could not find registerS06ClientReceivers method!" -ForegroundColor Red
    exit 1
}
$s06Method = $methodMatch.Value
Write-Host "Extracted S06 method ($($s06Method.Length) chars)" -ForegroundColor Green

# 2. Находим маркер PHASE5 (всё, что до него — импорты и начало onInitializeClient, их не трогаем)
$marker = "// === PHASE5 HAND SIGNS ==="
$markerIndex = $broken.IndexOf($marker)
if ($markerIndex -lt 0) {
    Write-Host "[FAIL] Could not find PHASE5 marker!" -ForegroundColor Red
    exit 1
}

$keptPart = $broken.Substring(0, $markerIndex)

# 3. Формируем правильное окончание файла
$correctEnding = @"
        // === PHASE5 HAND SIGNS ===
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CAST_START_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            String jutsuId = buf.readString();
            int durationTicks = buf.readInt();
            client.execute(() -> HandSignsClientState.startCasting(entityId, jutsuId, durationTicks));
        });
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CAST_INTERRUPT_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            client.execute(() -> HandSignsClientState.interruptCasting(entityId));
        });
        // HUD registration now inside ChakraHudRenderer.register() (self-guarded)
        HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);
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
        
        // === S0-06: Network Layer Receivers ===
        registerS06ClientReceivers();
    }

$s06Method
}
"@

# 4. Собираем и записываем
$finalContent = $keptPart + $correctEnding
[System.IO.File]::WriteAllText($file, $finalContent, $utf8)

Write-Host "[OK] File reconstructed and fixed!" -ForegroundColor Green
Write-Host "Run: .\gradlew.bat build" -ForegroundColor Cyan