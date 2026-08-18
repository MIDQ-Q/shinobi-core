# ============================================================
# SPRINT 12 PHASE C1: Clan Aura Particles
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 12 PHASE C1: Clan Aura Particles" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("  [OK] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host ("  [MISS] " + $p) -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host ("  [SKIP] already: " + (Split-Path $p -Leaf)) -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host ("  [FAIL] pattern: " + (Split-Path $p -Leaf)) -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host ("  [PATCH] " + (Split-Path $p -Leaf)) -ForegroundColor Green
    return $true
}

# ============================================================
# SECTION 1: ClanAuraRenderer
# ============================================================
Write-Host "[C1] Creating ClanAuraRenderer..." -ForegroundColor Yellow

$auraRenderer = @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * S12-03: Clan aura particles.
 * Each clan has a unique particle color.
 * Particles spawn around the player when in chakra mode.
 */
public class ClanAuraRenderer {
    private static int tickCounter = 0;

    // Clan colors: {r, g, b}
    private static final float[][] CLAN_COLORS = {
        {1.0f, 0.2f, 0.1f},  // uchiha - red
        {0.3f, 0.5f, 1.0f},  // hyuga - blue
        {1.0f, 0.5f, 0.1f},  // uzumaki - orange
        {0.2f, 0.8f, 0.3f},  // senju - green
        {0.15f, 0.1f, 0.3f}, // nara - dark purple
        {0.4f, 0.6f, 0.2f},  // aburame - green-brown
        {0.6f, 0.45f, 0.3f}, // inuzuka - brown
        {0.9f, 0.8f, 0.2f},  // akimichi - yellow
        {0.85f, 0.85f, 1.0f} // hatake - silver
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

        // Only show aura in chakra mode
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
Write-File (Join-Path $srcBase "client\ClanAuraRenderer.java") $auraRenderer

# ============================================================
# SECTION 2: PATCHES
# ============================================================
Write-Host "[C1] Patching registration files..." -ForegroundColor Yellow

# Check if ClientNinjaState has clanId and isChakraMode
$clientStateFile = Join-Path $srcBase "client\ClientNinjaState.java"
if (Test-Path $clientStateFile) {
    $csContent = [System.IO.File]::ReadAllText($clientStateFile, $utf8)
    
    if (-not $csContent.Contains("clanId")) {
        Write-Host "  [INFO] ClientNinjaState missing clanId - will patch" -ForegroundColor Yellow
        Patch-File $clientStateFile `
            "public class ClientNinjaState {" `
            "public class ClientNinjaState {`n    private static String clanId = `"\";`n`n    public static String getClanId() { return clanId; }`n    public static void setClanId(String id) { clanId = id; }"
    } else {
        Write-Host "  [SKIP] ClientNinjaState already has clanId" -ForegroundColor Yellow
    }
    
    if (-not $csContent.Contains("isChakraMode")) {
        Write-Host "  [INFO] ClientNinjaState missing isChakraMode - will patch" -ForegroundColor Yellow
        Patch-File $clientStateFile `
            "public static String getClanId() { return clanId; }" `
            "public static String getClanId() { return clanId; }`n`n    public static boolean isChakraMode() { return `"chakra\".equals(mode); }"
    } else {
        Write-Host "  [SKIP] ClientNinjaState already has isChakraMode" -ForegroundColor Yellow
    }
}

# Register ClanAuraRenderer in ShinobiCoreClient
$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"
Patch-File $clientFile `
    "import com.example.shinobicore.client.modes.GateClientState;" `
    "import com.example.shinobicore.client.modes.GateClientState;`nimport com.example.shinobicore.client.ClanAuraRenderer;"

Patch-File $clientFile `
    "GateClientState.clear();" `
    "GateClientState.clear();`n        ClanAuraRenderer.register();"

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 20 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    }
} finally { Pop-Location }

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 12 PHASE C1 COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Clan aura colors:" -ForegroundColor White
Write-Host "  Uchiha: red | Hyuga: blue | Uzumaki: orange" -ForegroundColor Yellow
Write-Host "  Senju: green | Nara: dark purple | Aburame: green-brown" -ForegroundColor Yellow
Write-Host "  Inuzuka: brown | Akimichi: yellow | Hatake: silver" -ForegroundColor Yellow
Write-Host ""
Write-Host "Particles spawn around player in chakra mode only." -ForegroundColor Cyan
Write-Host ""