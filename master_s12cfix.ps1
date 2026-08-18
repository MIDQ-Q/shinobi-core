$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

Write-Host "=== SPRINT 12 C1+C2: SAFE FIX ===" -ForegroundColor Cyan

# ============================================================
# FIX 1: Create ClanAuraRenderer.java
# ============================================================
Write-Host "`n[1/5] Creating ClanAuraRenderer..." -ForegroundColor Yellow

$auraFile = Join-Path $srcBase "client\ClanAuraRenderer.java"
$auraContent = @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

public class ClanAuraRenderer {
    private static int tickCounter = 0;

    private static final float[][] CLAN_COLORS = {
        {1.0f, 0.2f, 0.1f},
        {0.3f, 0.5f, 1.0f},
        {1.0f, 0.5f, 0.1f},
        {0.2f, 0.8f, 0.3f},
        {0.15f, 0.1f, 0.3f},
        {0.4f, 0.6f, 0.2f},
        {0.6f, 0.45f, 0.3f},
        {0.9f, 0.8f, 0.2f},
        {0.85f, 0.85f, 1.0f}
    };

    private static final String[] CLAN_IDS = {
        "uchiha", "hyuga", "uzumaki", "senju", "nara",
        "aburame", "inuzuka", "akimichi", "hatake"
    };

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ClanAuraRenderer::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.player == null || client.world == null) return;
        tickCounter++;
        if (tickCounter % 3 != 0) return;

        String clanId = ClientNinjaState.getClanId();
        if (clanId == null || clanId.isEmpty()) return;
        if (!ClientNinjaState.isChakraMode()) return;

        int clanIndex = -1;
        for (int i = 0; i < CLAN_IDS.length; i++) {
            if (CLAN_IDS[i].equals(clanId)) { clanIndex = i; break; }
        }
        if (clanIndex < 0) return;

        float[] color = CLAN_COLORS[clanIndex];
        ClientPlayerEntity player = client.player;
        Vec3d pos = player.getPos();

        int count = 3 + client.world.getRandom().nextInt(3);
        for (int i = 0; i < count; i++) {
            double angle = tickCounter * 0.12 + (i / (double) count) * Math.PI * 2;
            double radius = 0.4 + client.world.getRandom().nextDouble() * 0.4;
            double x = pos.x + Math.cos(angle) * radius;
            double y = pos.y + 0.3 + client.world.getRandom().nextDouble() * 1.2;
            double z = pos.z + Math.sin(angle) * radius;

            DustParticleEffect effect = new DustParticleEffect(
                new Vector3f(color[0], color[1], color[2]), 0.7f);
            client.world.addParticle(effect, x, y, z, 0, 0.02, 0);
        }
    }
}
'@
[System.IO.File]::WriteAllText($auraFile, $auraContent, $utf8)
Write-Host "  [OK] ClanAuraRenderer.java created" -ForegroundColor Green

# ============================================================
# FIX 2: Patch ClientNinjaState.java using line array (safe)
# ============================================================
Write-Host "`n[2/5] Patching ClientNinjaState..." -ForegroundColor Yellow

$csFile = Join-Path $srcBase "client\ClientNinjaState.java"
if (Test-Path $csFile) {
    $csLines = [System.IO.File]::ReadAllLines($csFile, $utf8)
    $csText = $csLines -join "`n"
    $modified = $false

    # Add clanId field
    if (-not $csText.Contains('private static String clanId')) {
        $newLines = @()
        foreach ($line in $csLines) {
            $newLines += $line
            if ($line.Contains('public class ClientNinjaState')) {
                $newLines += '    private static String clanId = "";'
            }
        }
        $csLines = $newLines
        $modified = $true
        Write-Host "  [OK] Added clanId field" -ForegroundColor Green
    }

    # Add getClanId / setClanId / isChakraMode methods
    $csText = $csLines -join "`n"
    if (-not $csText.Contains('getClanId')) {
        $newLines = @()
        $inserted = $false
        foreach ($line in $csLines) {
            $newLines += $line
            if (-not $inserted -and $line.Contains('public class ClientNinjaState')) {
                $newLines += ''
                $newLines += '    public static String getClanId() { return clanId; }'
                $newLines += '    public static void setClanId(String id) { clanId = id; }'
                $newLines += ''
                $newLines += '    public static boolean isChakraMode() { return "chakra".equals(mode); }'
                $inserted = $true
            }
        }
        $csLines = $newLines
        $modified = $true
        Write-Host "  [OK] Added getClanId/setClanId/isChakraMode" -ForegroundColor Green
    }

    if ($modified) {
        $finalText = $csLines -join "`n"
        [System.IO.File]::WriteAllText($csFile, $finalText, $utf8)
    } else {
        Write-Host "  [SKIP] ClientNinjaState already has all fields" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [MISS] ClientNinjaState.java not found" -ForegroundColor Red
}

# ============================================================
# FIX 3: Register ClanAuraRenderer in ShinobiCoreClient
# ============================================================
Write-Host "`n[3/5] Registering ClanAuraRenderer..." -ForegroundColor Yellow

$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"
$ccLines = [System.IO.File]::ReadAllLines($clientFile, $utf8)
$ccText = $ccLines -join "`n"

if (-not $ccText.Contains('ClanAuraRenderer')) {
    $newLines = @()
    foreach ($line in $ccLines) {
        $newLines += $line
        if ($line.Contains('GateClientState.clear()')) {
            $newLines += '        ClanAuraRenderer.register();'
        }
    }
    $finalText = $newLines -join "`n"
    [System.IO.File]::WriteAllText($clientFile, $finalText, $utf8)
    Write-Host "  [OK] Registered ClanAuraRenderer" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] ClanAuraRenderer already registered" -ForegroundColor Yellow
}

# ============================================================
# FIX 4: Fix Random type in C2 files
# ============================================================
Write-Host "`n[4/5] Fixing Random type in C2 files..." -ForegroundColor Yellow

# Fix ClanVillageFeature.java
$cvfFile = Join-Path $srcBase "world\feature\ClanVillageFeature.java"
if (Test-Path $cvfFile) {
    $cvfContent = [System.IO.File]::ReadAllText($cvfFile, $utf8)
    $cvfContent = $cvfContent.Replace('import java.util.Random;', 'import net.minecraft.util.math.random.Random;')
    [System.IO.File]::WriteAllText($cvfFile, $cvfContent, $utf8)
    Write-Host "  [OK] Fixed Random in ClanVillageFeature.java" -ForegroundColor Green
}

# Fix ClanVillageGenerator.java
$cvgFile = Join-Path $srcBase "world\structure\ClanVillageGenerator.java"
if (Test-Path $cvgFile) {
    $cvgContent = [System.IO.File]::ReadAllText($cvgFile, $utf8)
    $cvgContent = $cvgContent.Replace('import java.util.Random;', 'import net.minecraft.util.math.random.Random;')
    $cvgContent = $cvgContent.Replace('new java.util.Random()', 'new net.minecraft.util.math.random.Random()')
    [System.IO.File]::WriteAllText($cvgFile, $cvgContent, $utf8)
    Write-Host "  [OK] Fixed Random in ClanVillageGenerator.java" -ForegroundColor Green
}

# ============================================================
# BUILD
# ============================================================
Write-Host "`n[5/5] Building..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }