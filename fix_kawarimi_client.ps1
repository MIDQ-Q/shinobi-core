$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java"

if (-not (Test-Path $file)) {
    Write-Host "[FAIL] File not found: $file" -ForegroundColor Red
    exit 1
}

Write-Host "Reading ShinobiCoreClient.java..." -ForegroundColor Cyan
$c = [System.IO.File]::ReadAllText($file, $utf8)
$marker = "// === S0-06: Network Layer Receivers ==="
$idx = $c.IndexOf($marker)

if ($idx -lt 0) {
    Write-Host "[FAIL] Marker not found! File structure might be severely corrupted." -ForegroundColor Red
    exit 1
}

$correctEnding = @"
// === S0-06: Network Layer Receivers ===
        registerS06ClientReceivers();
    }

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

        // Kawarimi FX (S2C) - S2-05 Implementation
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.KAWARIMI_FX_ID,
                (client, handler, buf, responseSender) -> {
            double x = buf.readDouble();
            double y = buf.readDouble();
            double z = buf.readDouble();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("kawarimi_fx", "S2C",
                        client.player != null ? client.player.getName().getString() : "?");
                if (client.world != null) {
                    // Smoke particles
                    for (int i = 0; i < 40; i++) {
                        client.world.addParticle(net.minecraft.particle.ParticleTypes.LARGE_SMOKE,
                                x + (Math.random() - 0.5) * 1.5,
                                y + Math.random() * 2.0,
                                z + (Math.random() - 0.5) * 1.5,
                                (Math.random() - 0.5) * 0.15,
                                Math.random() * 0.15,
                                (Math.random() - 0.5) * 0.15);
                    }
                    for (int i = 0; i < 20; i++) {
                        client.world.addParticle(net.minecraft.particle.ParticleTypes.CLOUD,
                                x + (Math.random() - 0.5) * 1.0,
                                y + Math.random() * 1.8,
                                z + (Math.random() - 0.5) * 1.0,
                                (Math.random() - 0.5) * 0.05,
                                Math.random() * 0.05,
                                (Math.random() - 0.5) * 0.05);
                    }
                    // Poof particles
                    for (int i = 0; i < 15; i++) {
                        client.world.addParticle(net.minecraft.particle.ParticleTypes.POOF,
                                x + (Math.random() - 0.5) * 1.2,
                                y + Math.random() * 1.8,
                                z + (Math.random() - 0.5) * 1.2,
                                (Math.random() - 0.5) * 0.2,
                                Math.random() * 0.2,
                                (Math.random() - 0.5) * 0.2);
                    }
                    // Wood break + extinguish sounds
                    client.world.playSound(x, y, z, net.minecraft.sound.SoundEvents.BLOCK_WOOD_BREAK, net.minecraft.sound.SoundCategory.PLAYERS, 1.5f, 0.8f, false);
                    client.world.playSound(x, y, z, net.minecraft.sound.SoundEvents.ENTITY_GENERIC_EXTINGUISH_FIRE, net.minecraft.sound.SoundCategory.PLAYERS, 0.8f, 1.2f, false);
                }
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

$c = $c.Substring(0, $idx) + $correctEnding
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] ShinobiCoreClient.java fixed and Kawarimi VFX implemented!" -ForegroundColor Green
Write-Host "Run: .\gradlew.bat build" -ForegroundColor Cyan