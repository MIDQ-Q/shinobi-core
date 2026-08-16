# ============================================================
#  SPRINT 0 / S0-08: DEBUG OVERLAY AND PROFILING
#  Developer overlay: chakra, fatigue, VFX, packets/s, memory
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace($root, ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $cNorm.Contains($oldNorm)) { Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 0 / S0-08: DEBUG OVERLAY AND PROFILING" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. DebugProfiler.java - metrics collection
# ================================================================
Write-Host "[1/6] DebugProfiler.java..." -ForegroundColor White
$content1 = @'
package com.example.shinobicore.client.debug;

/**
 * S0-08: Debug profiler for developer overlay.
 * Collects metrics: VFX count, clones, packets/s, render time, memory.
 */
public class DebugProfiler {
    private static volatile boolean enabled = false;
    private static int activeVfxCount = 0;
    private static int activeCloneCount = 0;
    private static long lastFrameNs = 0;
    private static long frameTimeNs = 0;

    public static void setEnabled(boolean value) { enabled = value; }
    public static boolean isEnabled() { return enabled; }
    public static void toggle() { enabled = !enabled; }

    // VFX tracking
    public static void registerVfx() { activeVfxCount++; }
    public static void unregisterVfx() { activeVfxCount = Math.max(0, activeVfxCount - 1); }
    public static int getActiveVfxCount() { return activeVfxCount; }

    // Clone tracking
    public static void registerClone() { activeCloneCount++; }
    public static void unregisterClone() { activeCloneCount = Math.max(0, activeCloneCount - 1); }
    public static int getActiveCloneCount() { return activeCloneCount; }

    // Render time tracking
    public static void beginFrame() { lastFrameNs = System.nanoTime(); }
    public static void endFrame() { frameTimeNs = System.nanoTime() - lastFrameNs; }
    public static float getFrameTimeMs() { return frameTimeNs / 1_000_000f; }

    // Memory
    public static long getUsedMemoryMb() {
        Runtime rt = Runtime.getRuntime();
        return (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024);
    }
    public static long getMaxMemoryMb() {
        return Runtime.getRuntime().maxMemory() / (1024 * 1024);
    }
}
'@
Write-File "$java\client\debug\DebugProfiler.java" $content1

# ================================================================
# 2. DebugOverlayRenderer.java - HUD rendering
# ================================================================
Write-Host "[2/6] DebugOverlayRenderer.java..." -ForegroundColor White
$content2 = @'
package com.example.shinobicore.client.debug;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.network.NetworkDebugLogger;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;

/**
 * S0-08: Debug overlay for developers.
 * Toggle with F6. Shows chakra, fatigue, VFX, clones, packets/s, memory, FPS.
 */
public class DebugOverlayRenderer {

    private static int tickCounter = 0;

    public static void render(DrawContext ctx, float tickDelta) {
        if (!DebugProfiler.isEnabled()) return;

        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        tickCounter++;
        DebugProfiler.beginFrame();

        int sw = client.getWindow().getScaledWidth();
        int x = sw - 210;
        int y = 10;

        // Background
        ctx.fill(x - 8, y - 6, sw - 4, y + 195, 0xAA111111);
        ctx.fill(x - 8, y - 6, sw - 4, y - 5, 0xFFB4470F);

        // Title
        drawText(ctx, client, "SHINOBI DEBUG", x, y, 0xFFFFAA00);
        y += 16;

        // Resources
        float chakra = ChakraHudRenderer.currentChakra;
        float maxChakra = ChakraHudRenderer.maxChakra;
        drawText(ctx, client, String.format("Chakra: %.0f/%.0f", chakra, maxChakra), x, y, 0xFF4499FF);
        y += 12;

        drawText(ctx, client, String.format("Fatigue: %.1f%%", ChakraHudRenderer.fatigue), x, y, 0xFFEEBB33);
        y += 12;

        boolean exhausted = ChakraHudRenderer.exhausted;
        drawText(ctx, client, "Exhausted: " + (exhausted ? "YES" : "no"), x, y,
                 exhausted ? 0xFFFF4444 : 0xFF888888);
        y += 12;

        // Separator
        y += 3;
        ctx.fill(x, y, sw - 12, y + 1, 0xFF333333);
        y += 6;

        // Performance
        int vfxCount = DebugProfiler.getActiveVfxCount();
        int vfxColor = vfxCount > 50 ? 0xFFFF4444 : vfxCount > 20 ? 0xFFFFAA00 : 0xFF44FF44;
        drawText(ctx, client, "Active VFX: " + vfxCount, x, y, vfxColor);
        y += 12;

        int cloneCount = DebugProfiler.getActiveCloneCount();
        drawText(ctx, client, "Active Clones: " + cloneCount, x, y, 0xFFCCCCCC);
        y += 12;

        long pps = NetworkDebugLogger.getPacketsPerSecond();
        int ppsColor = pps > 100 ? 0xFFFF4444 : pps > 50 ? 0xFFFFAA00 : 0xFF44FF44;
        drawText(ctx, client, "Packets/s: " + pps, x, y, ppsColor);
        y += 12;

        float frameMs = DebugProfiler.getFrameTimeMs();
        int frameColor = frameMs > 8f ? 0xFFFF4444 : frameMs > 4f ? 0xFFFFAA00 : 0xFF44FF44;
        drawText(ctx, client, String.format("Frame: %.2f ms", frameMs), x, y, frameColor);
        y += 12;

        long usedMb = DebugProfiler.getUsedMemoryMb();
        long maxMb = DebugProfiler.getMaxMemoryMb();
        drawText(ctx, client, String.format("Memory: %d/%d MB", usedMb, maxMb), x, y, 0xFFAAAAAA);
        y += 12;

        // FPS
        int fps = client.fps;
        int fpsColor = fps < 30 ? 0xFFFF4444 : fps < 60 ? 0xFFFFAA00 : 0xFF44FF44;
        drawText(ctx, client, "FPS: " + fps, x, y, fpsColor);
        y += 12;

        // Separator
        y += 3;
        ctx.fill(x, y, sw - 12, y + 1, 0xFF333333);
        y += 6;

        // State
        boolean netDebug = NetworkDebugLogger.isEnabled();
        drawText(ctx, client, "Net Debug: " + (netDebug ? "ON" : "OFF"), x, y,
                 netDebug ? 0xFF44FF44 : 0xFF666666);
        y += 12;

        drawText(ctx, client, "SP: " + ClientNinjaState.skillPoints, x, y, 0xFFCCCCCC);
        y += 12;

        drawText(ctx, client, "Clan: " + ClientNinjaState.clanId, x, y, 0xFFCCCCCC);
        y += 12;

        drawText(ctx, client, "Tree Nodes: " + ClientNinjaState.unlockedNodes.size(), x, y, 0xFFCCCCCC);
        y += 12;

        drawText(ctx, client, "Learned: " + ClientNinjaState.learned.size(), x, y, 0xFFCCCCCC);
        y += 12;

        drawText(ctx, client, "Reserve Lv: " + ClientNinjaState.reserveLevel, x, y, 0xFFCCCCCC);

        DebugProfiler.endFrame();
    }

    private static void drawText(DrawContext ctx, MinecraftClient client,
                                  String text, int x, int y, int color) {
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(text), x, y, color);
    }
}
'@
Write-File "$java\client\debug\DebugOverlayRenderer.java" $content2

# ================================================================
# 3. Patch KeyBindings.java - add DEBUG_OVERLAY keybind
# ================================================================
Write-Host "[3/6] Patching KeyBindings.java..." -ForegroundColor White

Patch-File "$java\client\KeyBindings.java" `
"public static KeyBinding TOGGLE_SENSORY;" `
"public static KeyBinding TOGGLE_SENSORY;`n    public static KeyBinding DEBUG_OVERLAY;"

Patch-File "$java\client\KeyBindings.java" `
"TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.toggle_sensory"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));" `
"TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.toggle_sensory"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));`n        DEBUG_OVERLAY = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.debug_overlay"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_F6, CATEGORY));"

# ================================================================
# 4. Patch ClientInputHandler.java - handle toggle
# ================================================================
Write-Host "[4/6] Patching ClientInputHandler.java..." -ForegroundColor White

Patch-File "$java\client\ClientInputHandler.java" `
"if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info(""[INPUT] CRAWL (N) pressed"");" `
"if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info(""[INPUT] CRAWL (N) pressed"");`n        if (KeyBindings.DEBUG_OVERLAY.wasPressed()) {`n            com.example.shinobicore.client.debug.DebugProfiler.toggle();`n        }"

# ================================================================
# 5. Patch ShinobiCoreClient.java - register overlay
# ================================================================
Write-Host "[5/6] Patching ShinobiCoreClient.java..." -ForegroundColor White

Patch-File "$java\client\ShinobiCoreClient.java" `
"HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);" `
"HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);`n        HudRenderCallback.EVENT.register(com.example.shinobicore.client.debug.DebugOverlayRenderer::render);"

# ================================================================
# 6. Patch lang files - add keybind translation
# ================================================================
Write-Host "[6/6] Patching lang files..." -ForegroundColor White

Patch-File "$root\src\main\resources\assets\shinobicore\lang\en_us.json" `
"""key.categories.shinobicore"": ""ShinobiCore""" `
"""key.categories.shinobicore"": ""ShinobiCore"",`n  ""key.shinobicore.debug_overlay"": ""Debug Overlay (F6)"""

Patch-File "$root\src\main\resources\assets\shinobicore\lang\ru_ru.json" `
"""key.categories.shinobicore"": ""ShinobiCore""" `
"""key.categories.shinobicore"": ""ShinobiCore"",`n  ""key.shinobicore.debug_overlay"": ""Debug Overlay (F6)"""

# ================================================================
# SUMMARY AND EXIT CODE
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S0-08 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Created:" -ForegroundColor White
Write-Host "    client/debug/DebugProfiler.java      - metrics collection" -ForegroundColor White
Write-Host "    client/debug/DebugOverlayRenderer.java - HUD overlay" -ForegroundColor White
Write-Host ""
Write-Host "  Patched:" -ForegroundColor White
Write-Host "    KeyBindings.java       - +DEBUG_OVERLAY (F6)" -ForegroundColor White
Write-Host "    ClientInputHandler.java - toggle handler" -ForegroundColor White
Write-Host "    ShinobiCoreClient.java  - overlay registration" -ForegroundColor White
Write-Host "    en_us.json / ru_ru.json - keybind translation" -ForegroundColor White
Write-Host ""
Write-Host "  Usage:" -ForegroundColor White
Write-Host "    Press F6 in-game to toggle debug overlay" -ForegroundColor Yellow
Write-Host "    Shows: chakra, fatigue, VFX, clones, packets/s," -ForegroundColor Yellow
Write-Host "           frame time, memory, FPS, SP, clan, tree nodes" -ForegroundColor Yellow
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  Then: sprint0_s09_configs.ps1" -ForegroundColor Yellow
exit 0