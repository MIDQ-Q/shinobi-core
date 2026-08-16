$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java"

Write-Host "Reading broken file..." -ForegroundColor Cyan
$c = [System.IO.File]::ReadAllText($file, $utf8)

# Находим последний корректный блок внутри onInitializeClient()
$anchor = "LivingEntityFeatureRendererRegistrationCallback.EVENT.register"
$idx = $c.LastIndexOf($anchor)

if ($idx -lt 0) {
    Write-Host "[FAIL] Anchor not found!" -ForegroundColor Red
    exit 1
}

# Находим конец этого лямбда-блока `});`
$endOfAnchorBlock = $c.IndexOf("});", $idx)
if ($endOfAnchorBlock -lt 0) {
    Write-Host "[FAIL] Could not find end of anchor block!" -ForegroundColor Red
    exit 1
}

# Оставляем всё, что было до этого места (включая `});`)
$keep = $c.Substring(0, $endOfAnchorBlock + 3) 

# Формируем правильное окончание файла:
# 1. Вызов метода
# 2. Закрытие onInitializeClient() скобкой }
# 3. Сам метод registerS06ClientReceivers()
# 4. Закрытие класса скобкой }
$correctEnding = @"

        // === S0-06: Network Layer Receivers ===
        registerS06ClientReceivers();
    }

    // === S0-06: Client receivers for new packets ===
    private void registerS06ClientReceivers() {
        // VFX Spawn (S2C)
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.VFX_SPAWN_ID,
                (client, handler, buf, responseSender) -> {
            int vfxType = buf.readByte() & 0xFF;
            double x = buf.readDouble();
            double y = buf.readDouble();
            double z = buf.readDouble();
            float scale = buf.readFloat();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("vfx_spawn", "S2C",
                        client.player != null ? client.player.getName().getString() : "?",
                        "type=" + vfxType);
            });
        });

        // Hit Result (S2C)
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.HIT_RESULT_ID,
                (client, handler, buf, responseSender) -> {
            int attackerId = buf.readVarInt();
            int targetId = buf.readVarInt();
            float damage = buf.readFloat();
            boolean crit = buf.readBoolean();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("hit_result", "S2C",
                        client.player != null ? client.player.getName().getString() : "?",
                        "dmg=" + damage + " crit=" + crit);
            });
        });

        // Dojutsu State (S2C)
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.DOJUTSU_STATE_ID,
                (client, handler, buf, responseSender) -> {
            String dojutsuId = buf.readString();
            int stage = buf.readByte();
            boolean active = buf.readBoolean();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("dojutsu_state", "S2C",
                        client.player != null ? client.player.getName().getString() : "?",
                        "id=" + dojutsuId + " stage=" + stage);
                ClientNinjaState.activeDojutsu = dojutsuId.isEmpty() ? null : dojutsuId;
            });
        });

        // Kawarimi FX (S2C)
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.KAWARIMI_FX_ID,
                (client, handler, buf, responseSender) -> {
            double x = buf.readDouble();
            double y = buf.readDouble();
            double z = buf.readDouble();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("kawarimi_fx", "S2C",
                        client.player != null ? client.player.getName().getString() : "?");
            });
        });

        // Clone Spawn (S2C)
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CLONE_SPAWN_ID,
                (client, handler, buf, responseSender) -> {
            int ownerId = buf.readVarInt();
            int cloneId = buf.readVarInt();
            double x = buf.readDouble();
            double y = buf.readDouble();
            double z = buf.readDouble();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("clone_spawn", "S2C",
                        client.player != null ? client.player.getName().getString() : "?",
                        "clone=" + cloneId);
            });
        });

        // Clone Despawn (S2C)
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CLONE_DESPAWN_ID,
                (client, handler, buf, responseSender) -> {
            int cloneId = buf.readVarInt();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("clone_despawn", "S2C",
                        client.player != null ? client.player.getName().getString() : "?",
                        "clone=" + cloneId);
            });
        });

        // Cast Complete (S2C)
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CAST_COMPLETE_ID,
                (client, handler, buf, responseSender) -> {
            String jutsuId = buf.readString();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("cast_complete", "S2C",
                        client.player != null ? client.player.getName().getString() : "?",
                        "jutsu=" + jutsuId);
            });
        });

        // Sensory State (S2C)
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.SENSORY_STATE_ID,
                (client, handler, buf, responseSender) -> {
            int tier = buf.readByte();
            int radius = buf.readVarInt();
            boolean active = buf.readBoolean();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("sensory_state", "S2C",
                        client.player != null ? client.player.getName().getString() : "?",
                        "tier=" + tier + " radius=" + radius);
            });
        });

        ShinobiCore.LOGGER.info("[S0-06] Network layer client receivers registered");
    }
}
"@

# Собираем и записываем
$finalContent = $keep + $correctEnding
[System.IO.File]::WriteAllText($file, $finalContent, $utf8)

Write-Host "[OK] File reconstructed and braces fixed!" -ForegroundColor Green
Write-Host "Run: .\gradlew.bat build" -ForegroundColor Cyan