$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java"

Write-Host "Reading broken file..." -ForegroundColor Cyan
$broken = [System.IO.File]::ReadAllText($file, $utf8)

# Гарантируем наличие нужных импортов
if (-not $broken.Contains("import com.example.shinobicore.network.S06NetworkLayer;")) {
    $broken = $broken.Replace("import com.example.shinobicore.network.AttributeSyncPacket;", "import com.example.shinobicore.network.AttributeSyncPacket;`nimport com.example.shinobicore.network.S06NetworkLayer;`nimport com.example.shinobicore.network.NetworkDebugLogger;")
}

$marker = "// === PHASE5 HAND SIGNS ==="
$idx = $broken.IndexOf($marker)

if ($idx -lt 0) {
    Write-Host "[FAIL] Could not find PHASE5 marker!" -ForegroundColor Red
    exit 1
}

# Оставляем всё, что идет до маркера
$keptPart = $broken.Substring(0, $idx)

# Правильное окончание файла с вынесенным методом
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
        HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);
        HudRenderCallback.EVENT.register(com.example.shinobicore.client.debug.DebugOverlayRenderer::render);

        // === S0-01: Attribute delta sync receiver ===
        ClientPlayNetworking.registerGlobalReceiver(AttributeSyncPacket.ID, (client, handler, buf, responseSender) -> {
            final AttributeSyncPacket packet = AttributeSyncPacket.read(buf);
            client.execute(() -> {
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

    // === S0-06: Client receivers for new packets ===
    private void registerS06ClientReceivers() {
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.VFX_SPAWN_ID, (client, handler, buf, responseSender) -> {
            int vfxType = buf.readByte() & 0xFF;
            double x = buf.readDouble(); double y = buf.readDouble(); double z = buf.readDouble();
            float scale = buf.readFloat();
            client.execute(() -> NetworkDebugLogger.logPacket("vfx_spawn", "S2C", client.player != null ? client.player.getName().getString() : "?", "type=" + vfxType));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.HIT_RESULT_ID, (client, handler, buf, responseSender) -> {
            int attackerId = buf.readVarInt(); int targetId = buf.readVarInt();
            float damage = buf.readFloat(); boolean crit = buf.readBoolean();
            client.execute(() -> NetworkDebugLogger.logPacket("hit_result", "S2C", client.player != null ? client.player.getName().getString() : "?", "dmg=" + damage + " crit=" + crit));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.DOJUTSU_STATE_ID, (client, handler, buf, responseSender) -> {
            String dojutsuId = buf.readString(); int stage = buf.readByte(); boolean active = buf.readBoolean();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("dojutsu_state", "S2C", client.player != null ? client.player.getName().getString() : "?", "id=" + dojutsuId + " stage=" + stage);
                ClientNinjaState.activeDojutsu = dojutsuId.isEmpty() ? null : dojutsuId;
            });
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.KAWARIMI_FX_ID, (client, handler, buf, responseSender) -> {
            double x = buf.readDouble(); double y = buf.readDouble(); double z = buf.readDouble();
            client.execute(() -> NetworkDebugLogger.logPacket("kawarimi_fx", "S2C", client.player != null ? client.player.getName().getString() : "?"));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CLONE_SPAWN_ID, (client, handler, buf, responseSender) -> {
            int ownerId = buf.readVarInt(); int cloneId = buf.readVarInt();
            double x = buf.readDouble(); double y = buf.readDouble(); double z = buf.readDouble();
            client.execute(() -> NetworkDebugLogger.logPacket("clone_spawn", "S2C", client.player != null ? client.player.getName().getString() : "?", "clone=" + cloneId));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CLONE_DESPAWN_ID, (client, handler, buf, responseSender) -> {
            int cloneId = buf.readVarInt();
            client.execute(() -> NetworkDebugLogger.logPacket("clone_despawn", "S2C", client.player != null ? client.player.getName().getString() : "?", "clone=" + cloneId));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CAST_COMPLETE_ID, (client, handler, buf, responseSender) -> {
            String jutsuId = buf.readString();
            client.execute(() -> NetworkDebugLogger.logPacket("cast_complete", "S2C", client.player != null ? client.player.getName().getString() : "?", "jutsu=" + jutsuId));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.SENSORY_STATE_ID, (client, handler, buf, responseSender) -> {
            int tier = buf.readByte(); int radius = buf.readVarInt(); boolean active = buf.readBoolean();
            client.execute(() -> NetworkDebugLogger.logPacket("sensory_state", "S2C", client.player != null ? client.player.getName().getString() : "?", "tier=" + tier + " radius=" + radius));
        });
        
        ShinobiCore.LOGGER.info("[S0-06] Network layer client receivers registered");
    }
}
"@

$finalContent = $keptPart + $correctEnding
[System.IO.File]::WriteAllText($file, $finalContent, $utf8)
Write-Host "[OK] File reconstructed and fixed!" -ForegroundColor Green
Write-Host "Run: .\gradlew.bat build" -ForegroundColor Cyan