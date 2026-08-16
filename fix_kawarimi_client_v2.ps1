# ============================================================
#  FIX: ShinobiCoreClient.java - Safe S0-06 Client Receivers
#  Injects receivers before closing brace of onInitializeClient
#  PS 5.1 compatible. ASCII only. UTF8 no BOM. Idempotent.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX: ShinobiCoreClient.java S0-06 Client Receivers (v2)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $file)) {
    Write-Host "[FAIL] File not found: $file" -ForegroundColor Red
    exit 1
}

$c = [System.IO.File]::ReadAllText($file, $utf8)
$cNorm = $c.Replace("`r`n", "`n")

# === IDEMPOTENCY CHECK ===
if ($cNorm.Contains("registerS06ClientReceivers")) {
    Write-Host "[SKIP] S0-06 client receivers already present" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
    exit 0
}

# === CHECK IMPORTS ===
$importsAdded = $false
if (-not $cNorm.Contains("import com.example.shinobicore.network.S06NetworkLayer;")) {
    $c = $c.Replace(
        "import com.example.shinobicore.ShinobiCore;",
        "import com.example.shinobicore.ShinobiCore;`nimport com.example.shinobicore.network.S06NetworkLayer;`nimport com.example.shinobicore.network.NetworkDebugLogger;"
    )
    $importsAdded = $true
    Write-Host "[OK] Added S06NetworkLayer + NetworkDebugLogger imports" -ForegroundColor Green
} else {
    Write-Host "[SKIP] Imports already present" -ForegroundColor Yellow
}

# === INJECT METHOD CALL + METHOD BODY ===
# Strategy: Find the LAST occurrence of "}" that closes onInitializeClient()
# We look for the pattern: registration callback followed by closing braces
# The safest anchor is the LivingEntityFeatureRendererRegistrationCallback block

$anchor = "LivingEntityFeatureRendererRegistrationCallback.EVENT.register"
$anchorIdx = $cNorm.IndexOf($anchor)

if ($anchorIdx -lt 0) {
    # Fallback: try to find NarutoArmorRenderer.register()
    $anchor = "NarutoArmorRenderer.register()"
    $anchorIdx = $cNorm.IndexOf($anchor)
}

if ($anchorIdx -lt 0) {
    # Last resort: find "public void onInitializeClient()" and work from there
    $methodStart = $cNorm.IndexOf("public void onInitializeClient()")
    if ($methodStart -lt 0) {
        Write-Host "[FAIL] Cannot find onInitializeClient() method!" -ForegroundColor Red
        Write-Host "  File structure is too corrupted for automatic fix." -ForegroundColor Red
        Write-Host "  Please check ShinobiCoreClient.java manually." -ForegroundColor Red
        exit 1
    }
    # Find the matching closing brace by counting braces from method start
    $braceCount = 0
    $foundOpen = $false
    $closeIdx = -1
    for ($i = $methodStart; $i -lt $cNorm.Length; $i++) {
        if ($cNorm[$i] -eq '{') { $braceCount++; $foundOpen = $true }
        if ($cNorm[$i] -eq '}') {
            $braceCount--
            if ($foundOpen -and $braceCount -eq 0) {
                $closeIdx = $i
                break
            }
        }
    }
    if ($closeIdx -lt 0) {
        Write-Host "[FAIL] Cannot find closing brace of onInitializeClient()!" -ForegroundColor Red
        exit 1
    }
    $injectPoint = $closeIdx
} else {
    # Find the end of the anchor block (the ");" after the lambda)
    # Then find the next "}" which closes onInitializeClient
    $searchFrom = $anchorIdx
    $braceCount = 0
    $foundOpen = $false
    $closeIdx = -1
    for ($i = $searchFrom; $i -lt $cNorm.Length; $i++) {
        if ($cNorm[$i] -eq '{') { $braceCount++; $foundOpen = $true }
        if ($cNorm[$i] -eq '}') {
            if ($foundOpen) {
                $braceCount--
                if ($braceCount -eq 0) {
                    # This closes the lambda/block, keep searching for method close
                    $foundOpen = $false
                    continue
                }
            }
        }
    }
    # Simpler approach: just find last "}" before class closing "}"
    # Class closing is the very last "}" in file
    $lastBrace = $cNorm.LastIndexOf("}")
    $secondLastBrace = $cNorm.LastIndexOf("}", $lastBrace - 1)
    $injectPoint = $secondLastBrace
}

# Re-read with original line endings preserved
$c = [System.IO.File]::ReadAllText($file, $utf8)

# Build the injection block
$injection = @"

        // === S0-06: Network layer client receivers ===
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
"@

# Now we need to replace the closing "}" of onInitializeClient + class closing "}"
# with: injection + "}" + "}"
# Find the second-to-last "}" in the ORIGINAL content
$cNormCheck = $c.Replace("`r`n", "`n")
$lastBrace = $cNormCheck.LastIndexOf("}")
$secondLastBrace = $cNormCheck.LastIndexOf("}", $lastBrace - 1)

if ($secondLastBrace -lt 0) {
    Write-Host "[FAIL] Cannot locate method/class closing braces!" -ForegroundColor Red
    exit 1
}

# Replace from secondLastBrace to end with injection + proper closing
$before = $c.Substring(0, $secondLastBrace)
$after = "}`n}`n"

$newContent = $before + $injection + "`n" + $after

[System.IO.File]::WriteAllText($file, $newContent, $utf8)

Write-Host "[OK] S0-06 client receivers injected into ShinobiCoreClient.java" -ForegroundColor Green
Write-Host ""
Write-Host "  Injected:" -ForegroundColor White
Write-Host "    - registerS06ClientReceivers() call" -ForegroundColor White
Write-Host "    - 8 client packet receivers (VFX, Hit, Dojutsu," -ForegroundColor White
Write-Host "      Kawarimi, Clone Spawn/Despawn, Cast, Sensory)" -ForegroundColor White
Write-Host ""
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0