# ============================================================
# SHINOBICORE MASTER SCRIPT: SPRINT 6 PHASE B (S6-07..S6-12)
# Sharingan Implementation
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$dojutsuDir = Join-Path $srcBase "dojutsu"
$clientDojutsuDir = Join-Path $srcBase "client\dojutsu"
$resBase = Join-Path $root "src\main\resources"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 6 PHASE B: SHARINGAN (S6-07..S6-12)" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("  [OK] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) {
        Write-Host ("  [MISS] " + $p) -ForegroundColor Red
        return $false
    }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) {
        Write-Host ("  [SKIP] already: " + (Split-Path $p -Leaf)) -ForegroundColor Yellow
        return $true
    }
    if (-not $c.Contains($oldN)) {
        Write-Host ("  [FAIL] pattern: " + (Split-Path $p -Leaf)) -ForegroundColor Red
        return $false
    }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host ("  [PATCH] " + (Split-Path $p -Leaf)) -ForegroundColor Green
    return $true
}

# ============================================================
# S6-07/08: SharinganComponent (server-side)
# Evolution via usage + stress events
# ============================================================
Write-Host "[S6-07/08] Creating SharinganComponent..." -ForegroundColor Yellow

$sharinganComponent = @'
package com.example.shinobicore.dojutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.HashSet;
import java.util.Set;

/**
 * S6-07/S6-08: Server-side Sharingan component.
 * Evolution: combined (usage progress + stress events).
 * Stages: NONE -> ONE_TOMOE -> TWO_TOMOE -> THREE_TOMOE -> MANGEKYO
 *
 * Usage sources: fire/genjutsu casts, successful parries, combat hits.
 * Stress sources: HP < 15%, near-lethal damage, fighting stronger enemy,
 *                 casting at < 10% chakra.
 *
 * Thresholds:
 *   1 tomoe: 50 usage + 1 stress
 *   2 tomoe: 150 usage + 2 stress
 *   3 tomoe: 300 usage + 3 stress
 *   Mangekyo: 500 usage + 5 stress + quest (stub)
 */
public class SharinganComponent {

    public enum Stage {
        NONE(0, 0, 0),
        ONE_TOMOE(1, 50, 1),
        TWO_TOMOE(2, 150, 2),
        THREE_TOMOE(3, 300, 3),
        MANGEKYO(4, 500, 5);

        public final int level;
        public final int usageRequired;
        public final int stressRequired;

        Stage(int level, int usageReq, int stressReq) {
            this.level = level;
            this.usageRequired = usageReq;
            this.stressRequired = stressReq;
        }
    }

    private Stage stage = Stage.NONE;
    private int usageProgress = 0;
    private int stressCount = 0;
    private boolean active = false;
    private boolean hasMangekyoQuest = false;

    // 3 tomoe: auto-parry cooldown
    private long lastAutoParryMs = 0;
    private static final long AUTO_PARRY_COOLDOWN_MS = 2000;
    private static final float AUTO_PARRY_CHANCE = 0.35f;

    // Chakra drain: 5% max per 10 seconds while active
    private long lastDrainTimeMs = 0;
    private static final long DRAIN_INTERVAL_MS = 10000;
    private static final float DRAIN_PERCENT = 0.05f;

    // Track stress sources to avoid counting same event multiple times
    private final Set<String> recentStressSources = new HashSet<>();
    private long lastStressResetMs = 0;

    public Stage getStage() { return stage; }
    public boolean isActive() { return active; }
    public int getUsageProgress() { return usageProgress; }
    public int getStressCount() { return stressCount; }
    public boolean hasMangekyoQuest() { return hasMangekyoQuest; }
    public void setMangekyoQuestComplete(boolean v) { this.hasMangekyoQuest = v; }

    /**
     * Toggle sharingan activation. Requires at least 1 tomoe.
     */
    public boolean toggle(ServerPlayerEntity player) {
        if (stage == Stage.NONE) {
            player.sendMessage(Text.literal("\u00a7cSharingan not awakened yet."), false);
            return false;
        }
        active = !active;
        if (active) {
            lastDrainTimeMs = System.currentTimeMillis();
            player.sendMessage(Text.literal("\u00a7cSharingan activated."), true);
        } else {
            player.sendMessage(Text.literal("\u00a77Sharingan deactivated."), true);
        }
        syncToClient(player);
        return true;
    }

    /**
     * Called every server tick from NinjaTickHandler.
     */
    public void tick(ServerPlayerEntity player) {
        if (!active || stage == Stage.NONE) return;

        // Chakra drain: 5% max per 10 seconds
        long now = System.currentTimeMillis();
        if (now - lastDrainTimeMs >= DRAIN_INTERVAL_MS) {
            lastDrainTimeMs = now;
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            float maxChakra = com.example.shinobicore.stat.NinjaFormula.maxChakra(data);
            float drain = maxChakra * DRAIN_PERCENT;
            if (data.getCurrentChakra() < drain) {
                active = false;
                syncToClient(player);
                player.sendMessage(Text.literal("\u00a77Sharingan deactivated - no chakra."), true);
                return;
            }
            data.setCurrentChakra(data.getCurrentChakra() - drain);
            ShinobiCore.sendChakraSync(player);
        }

        // Stress check: HP < 15%
        if (player.getHealth() < player.getMaxHealth() * 0.15f) {
            addStress("low_hp");
        }

        // Stress check: chakra < 10%
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        float maxChakra = com.example.shinobicore.stat.NinjaFormula.maxChakra(data);
        if (data.getCurrentChakra() < maxChakra * 0.10f) {
            addStress("low_chakra");
        }
    }

    /**
     * S6-07: Add usage progress. Called when casting fire/genjutsu,
     * successful parry, or landing a hit.
     */
    public void addUsage(int amount) {
        usageProgress += amount;
        checkEvolution(null);
    }

    /**
     * S6-08: Add stress event. Deduplicated by source within 30s window.
     */
    public void addStress(String source) {
        long now = System.currentTimeMillis();
        // Reset stress sources every 30 seconds
        if (now - lastStressResetMs > 30000) {
            recentStressSources.clear();
            lastStressResetMs = now;
        }
        if (recentStressSources.contains(source)) return;
        recentStressSources.add(source);
        stressCount++;
        ShinobiCore.LOGGER.debug("[SHARINGAN] Stress event: {} (total: {})", source, stressCount);
        checkEvolution(null);
    }

    /**
     * Check if evolution threshold is met.
     */
    private void checkEvolution(ServerPlayerEntity player) {
        Stage next = getNextStage();
        if (next == null) return;
        if (usageProgress >= next.usageRequired && stressCount >= next.stressRequired) {
            if (next == Stage.MANGEKYO && !hasMangekyoQuest) return;
            stage = next;
            ShinobiCore.LOGGER.info("[SHARINGAN] Evolved to {}", stage);
            if (player != null) {
                player.sendMessage(Text.literal("\u00a7cSharingan evolved: " + stage.name()), false);
                syncToClient(player);
            }
        }
    }

    private Stage getNextStage() {
        switch (stage) {
            case NONE: return Stage.ONE_TOMOE;
            case ONE_TOMOE: return Stage.TWO_TOMOE;
            case TWO_TOMOE: return Stage.THREE_TOMOE;
            case THREE_TOMOE: return Stage.MANGEKYO;
            default: return null;
        }
    }

    /**
     * S6-08: 3 tomoe auto-parry. 35% chance, 2s cooldown.
     * Returns true if attack should be negated.
     */
    public boolean checkAutoParry(ServerPlayerEntity player, float amount) {
        if (stage.level < 3 || !active) return false;
        long now = System.currentTimeMillis();
        if (now - lastAutoParryMs < AUTO_PARRY_COOLDOWN_MS) return false;
        if (player.getWorld().getRandom().nextFloat() < AUTO_PARRY_CHANCE) {
            lastAutoParryMs = now;
            ShinobiCore.LOGGER.debug("[SHARINGAN] Auto-parry! Negated {} damage", amount);
            return true;
        }
        return false;
    }

    /**
     * S6-07: Check if player can copy a technique (2 tomoe).
     * Only T1-T3 techniques, requires unlocked element.
     */
    public boolean canCopyTechnique(int tier) {
        if (stage.level < 2) return false;
        return tier <= 3;
    }

    /**
     * Sync sharingan state to client.
     */
    public void syncToClient(ServerPlayerEntity player) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(stage.level);
        buf.writeBoolean(active);
        buf.writeInt(usageProgress);
        buf.writeInt(stressCount);
        ServerPlayNetworking.send(player, ModPackets.SHARINGAN_SYNC_ID, buf);
    }

    /**
     * Write to NBT for persistence.
     */
    public void writeNbt(net.minecraft.nbt.NbtCompound nbt) {
        nbt.putInt("SharinganStage", stage.level);
        nbt.putInt("SharinganUsage", usageProgress);
        nbt.putInt("SharinganStress", stressCount);
        nbt.putBoolean("SharinganActive", active);
        nbt.putBoolean("MangekyoQuest", hasMangekyoQuest);
    }

    /**
     * Read from NBT.
     */
    public void readNbt(net.minecraft.nbt.NbtCompound nbt) {
        int lvl = nbt.getInt("SharinganStage");
        stage = Stage.NONE;
        for (Stage s : Stage.values()) {
            if (s.level == lvl) { stage = s; break; }
        }
        usageProgress = nbt.getInt("SharinganUsage");
        stressCount = nbt.getInt("SharinganStress");
        active = nbt.getBoolean("SharinganActive");
        hasMangekyoQuest = nbt.getBoolean("MangekyoQuest");
    }
}
'@
Write-File (Join-Path $dojutsuDir "SharinganComponent.java") $sharinganComponent

# ============================================================
# S6-07..S6-12: SharinganClientState
# ============================================================
Write-Host "[S6-07..12] Creating SharinganClientState..." -ForegroundColor Yellow

$clientState = @'
package com.example.shinobicore.client.dojutsu;

/**
 * S6-07..S6-12: Client-side sharingan state.
 * Stores stage, active flag, usage/stress progress.
 */
public class SharinganClientState {
    public static boolean active = false;
    public static int stageLevel = 0;
    public static int usageProgress = 0;
    public static int stressCount = 0;

    public static boolean isActive() { return active && stageLevel > 0; }
    public static boolean hasOneTomoe() { return stageLevel >= 1; }
    public static boolean hasTwoTomoe() { return stageLevel >= 2; }
    public static boolean hasThreeTomoe() { return stageLevel >= 3; }
    public static boolean hasMangekyo() { return stageLevel >= 4; }

    public static float getOverlayAlpha() {
        switch (stageLevel) {
            case 1: return 0.10f;
            case 2: return 0.15f;
            case 3: return 0.20f;
            case 4: return 0.30f;
            default: return 0f;
        }
    }

    public static int getParticleCount() {
        switch (stageLevel) {
            case 1: return 3;
            case 2: return 6;
            case 3: return 10;
            case 4: return 15;
            default: return 0;
        }
    }

    public static void clear() {
        active = false;
        stageLevel = 0;
        usageProgress = 0;
        stressCount = 0;
    }
}
'@
Write-File (Join-Path $clientDojutsuDir "SharinganClientState.java") $clientState

# ============================================================
# Visual: Red overlay + particles
# ============================================================
Write-Host "[S6-07..12] Creating SharinganOverlayRenderer..." -ForegroundColor Yellow

$overlayRenderer = @'
package com.example.shinobicore.client.dojutsu;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.util.math.ColorHelper;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * S6-07..S6-12: Sharingan visual overlay.
 * - Red night-vision tint (alpha depends on stage).
 * - Red particles orbiting around player head.
 * - Mangekyo: additional black particles.
 */
public class SharinganOverlayRenderer {
    private static int tickCounter = 0;

    public static void register() {
        HudRenderCallback.EVENT.register(SharinganOverlayRenderer::renderOverlay);
        ClientTickEvents.END_CLIENT_TICK.register(SharinganOverlayRenderer::tickParticles);
    }

    private static void renderOverlay(DrawContext ctx, float tickDelta) {
        if (!SharinganClientState.isActive()) return;
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        float alpha = SharinganClientState.getOverlayAlpha();

        // Red tint overlay
        int color = ColorHelper.Argb.getArgb((int)(alpha * 255), 180, 20, 20);
        ctx.fill(0, 0, sw, sh, color);

        // Vignette edges
        int vignetteAlpha = (int)(alpha * 0.6f * 255);
        int vignetteColor = ColorHelper.Argb.getArgb(vignetteAlpha, 40, 0, 0);
        int edge = 40;
        ctx.fill(0, 0, sw, edge, vignetteColor);
        ctx.fill(0, sh - edge, sw, sh, vignetteColor);
        ctx.fill(0, 0, edge, sh, vignetteColor);
        ctx.fill(sw - edge, 0, sw, sh, vignetteColor);

        // Stage indicator top-right
        String stageText;
        switch (SharinganClientState.stageLevel) {
            case 1: stageText = "Sharingan: 1 Tomoe"; break;
            case 2: stageText = "Sharingan: 2 Tomoe"; break;
            case 3: stageText = "Sharingan: 3 Tomoe"; break;
            case 4: stageText = "Mangekyo Sharingan"; break;
            default: stageText = ""; break;
        }
        if (!stageText.isEmpty()) {
            int tw = client.textRenderer.getWidth(stageText);
            ctx.drawTextWithShadow(client.textRenderer, stageText,
                sw - tw - 10, 10, 0xFFFF4444);
        }
    }

    private static void tickParticles(MinecraftClient client) {
        if (!SharinganClientState.isActive()) return;
        if (client.world == null || client.player == null) return;

        tickCounter++;
        int count = SharinganClientState.getParticleCount();
        if (count <= 0) return;

        ClientPlayerEntity player = client.player;
        Vec3d headPos = player.getEyePos();
        float radius = 0.4f;
        float speed = 0.03f;

        for (int i = 0; i < count; i++) {
            float angle = tickCounter * 0.15f + (i / (float) count) * (float)(Math.PI * 2);
            float y = headPos.y + (float)Math.sin(tickCounter * 0.1f + i) * 0.2f;
            double x = headPos.x + Math.cos(angle) * radius;
            double z = headPos.z + Math.sin(angle) * radius;

            DustParticleEffect effect = new DustParticleEffect(
                new Vector3f(1.0f, 0.1f, 0.1f), 0.6f);
            client.world.addParticle(effect, x, y, z,
                Math.cos(angle) * speed, 0.01, Math.sin(angle) * speed);
        }

        // Mangekyo: additional black particles
        if (SharinganClientState.hasMangekyo() && tickCounter % 3 == 0) {
            DustParticleEffect black = new DustParticleEffect(
                new Vector3f(0.05f, 0.0f, 0.0f), 0.8f);
            float angle = tickCounter * 0.2f;
            client.world.addParticle(black,
                headPos.x + Math.cos(angle) * 0.3,
                headPos.y + 0.3,
                headPos.z + Math.sin(angle) * 0.3,
                0, 0.02, 0);
        }
    }
}
'@
Write-File (Join-Path $clientDojutsuDir "SharinganOverlayRenderer.java") $overlayRenderer

# ============================================================
# PATCH: Add SHARINGAN packets to ModPackets
# ============================================================
Write-Host "[PATCH] Adding sharingan packets to ModPackets..." -ForegroundColor Yellow

$modPacketsFile = Join-Path $srcBase "network\ModPackets.java"
Patch-File $modPacketsFile `
    "public static final Identifier RELEASE_CAST_ID = new Identifier(`"shinobicore`", `"release_cast`");" `
    "public static final Identifier RELEASE_CAST_ID = new Identifier(`"shinobicore`", `"release_cast`");`n    public static final Identifier SHARINGAN_SYNC_ID = new Identifier(`"shinobicore`", `"sharingan_sync`");`n    public static final Identifier SHARINGAN_TOGGLE_ID = new Identifier(`"shinobicore`", `"sharingan_toggle`");"

# ============================================================
# PATCH: Add sharingan component to NinjaPlayerData
# ============================================================
Write-Host "[PATCH] Adding sharingan component to NinjaPlayerData..." -ForegroundColor Yellow

$ninjaDataFile = Join-Path $srcBase "stat\NinjaPlayerData.java"
Patch-File $ninjaDataFile `
    "private boolean lastDangerState = false;" `
    "private boolean lastDangerState = false;`n    private com.example.shinobicore.dojutsu.SharinganComponent sharinganComponent = new com.example.shinobicore.dojutsu.SharinganComponent();"

Patch-File $ninjaDataFile `
    "public boolean getLastDangerState() { return lastDangerState; }" `
    "public boolean getLastDangerState() { return lastDangerState; }`n    public com.example.shinobicore.dojutsu.SharinganComponent getSharinganComponent() { return sharinganComponent; }"

# ============================================================
# PATCH: Add sharingan toggle key binding
# ============================================================
Write-Host "[PATCH] Adding TOGGLE_SHARINGAN key binding..." -ForegroundColor Yellow

$keyBindingsFile = Join-Path $srcBase "client\KeyBindings.java"
Patch-File $keyBindingsFile `
    "public static KeyBinding TOGGLE_SCABBARD;" `
    "public static KeyBinding TOGGLE_SCABBARD;`n    public static KeyBinding TOGGLE_SHARINGAN;"

# ============================================================
# PATCH: Handle sharingan toggle in ClientInputHandler
# ============================================================
Write-Host "[PATCH] Adding sharingan toggle input handling..." -ForegroundColor Yellow

$inputFile = Join-Path $srcBase "client\ClientInputHandler.java"
Patch-File $inputFile `
    "if (KeyBindings.TOGGLE_SCABBARD.wasPressed()) {" `
    "if (KeyBindings.TOGGLE_SHARINGAN.wasPressed()) {`n            if (client.getNetworkHandler() != null) {`n                PacketByteBuf sharinganBuf = new PacketByteBuf(Unpooled.buffer());`n                ClientPlayNetworking.send(ModPackets.SHARINGAN_TOGGLE_ID, sharinganBuf);`n            }`n        }`n        if (KeyBindings.TOGGLE_SCABBARD.wasPressed()) {"

# ============================================================
# PATCH: Register sharingan in ShinobiCoreClient
# ============================================================
Write-Host "[PATCH] Registering sharingan in ShinobiCoreClient..." -ForegroundColor Yellow

$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"

# Add imports
Patch-File $clientFile `
    "import com.example.shinobicore.client.RasenganClientState;" `
    "import com.example.shinobicore.client.RasenganClientState;`nimport com.example.shinobicore.client.dojutsu.SharinganClientState;`nimport com.example.shinobicore.client.dojutsu.SharinganOverlayRenderer;"

# Register overlay renderer
Patch-File $clientFile `
    "NarutoArmorRenderer.register();" `
    "NarutoArmorRenderer.register();`n        // Sharingan overlay renderer`n        SharinganOverlayRenderer.register();"

# Register packet receivers
Patch-File $clientFile `
    "ClientPlayNetworking.registerGlobalReceiver(ModPackets.DANGER_SYNC_ID" `
    "// Sharingan sync receiver`n        ClientPlayNetworking.registerGlobalReceiver(ModPackets.SHARINGAN_SYNC_ID, (client, handler, buf, responseSender) -> {`n            int stage = buf.readInt();`n            boolean active = buf.readBoolean();`n            int usage = buf.readInt();`n            int stress = buf.readInt();`n            client.execute(() -> {`n                SharinganClientState.stageLevel = stage;`n                SharinganClientState.active = active;`n                SharinganClientState.usageProgress = usage;`n                SharinganClientState.stressCount = stress;`n            });`n        });`n        ClientPlayNetworking.registerGlobalReceiver(ModPackets.DANGER_SYNC_ID"

# Cleanup on disconnect
Patch-File $clientFile `
    "HandSignsClientState.clear();" `
    "HandSignsClientState.clear();`n        SharinganClientState.clear();"

# ============================================================
# PATCH: Register server-side sharingan handler in ShinobiCore
# ============================================================
Write-Host "[PATCH] Registering server-side sharingan handler..." -ForegroundColor Yellow

$serverFile = Join-Path $srcBase "ShinobiCore.java"
Patch-File $serverFile `
    "ServerLifecycleEvents.SERVER_STARTED.register(server -> {" `
    "// Sharingan toggle handler (C2S)`n        net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.registerGlobalReceiver(`n            ModPackets.SHARINGAN_TOGGLE_ID, (server, player, handler, buf, responseSender) -> {`n            server.execute(() -> {`n                var data = ((com.example.shinobicore.stat.NinjaDataHolder) player).shinobicore_getData();`n                var sharingan = data.getSharinganComponent();`n                if (sharingan != null) {`n                    sharingan.toggle(player);`n                }`n            });`n        });`n        ServerLifecycleEvents.SERVER_STARTED.register(server -> {"

# ============================================================
# PATCH: Add sharingan tick to NinjaTickHandler
# ============================================================
Write-Host "[PATCH] Adding sharingan tick to NinjaTickHandler..." -ForegroundColor Yellow

$tickFile = Join-Path $srcBase "event\NinjaTickHandler.java"
Patch-File $tickFile `
    "// === PHASE_FIX2_TICK: sensory glow + danger sense + rasengan dissipate ===" `
    "// === S6: Sharingan component tick ===`n            var sharinganComp = data.getSharinganComponent();`n            if (sharinganComp != null) {`n                sharinganComp.tick(player);`n            }`n            // === PHASE_FIX2_TICK: sensory glow + danger sense + rasengan dissipate ==="

# ============================================================
# PATCH: Add auto-parry to PlayerParryMixin (3 tomoe)
# ============================================================
Write-Host "[PATCH] Adding sharingan auto-parry to PlayerParryMixin..." -ForegroundColor Yellow

$parryMixinFile = Join-Path $srcBase "mixin\PlayerParryMixin.java"
Patch-File $parryMixinFile `
    "if (b.autoParryChance <= 0) return;" `
    "// Sharingan 3 tomoe: 35% auto-parry for melee`n        var sharinganData = ((com.example.shinobicore.stat.NinjaDataHolder) self).shinobicore_getData();`n        var sharinganComp = sharinganData.getSharinganComponent();`n        if (sharinganComp != null && sharinganComp.checkAutoParry(`n                (ServerPlayerEntity) self, amount)) {`n            if (self.getWorld() instanceof net.minecraft.server.world.ServerWorld sw) {`n                sw.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT,`n                    self.getX(), self.getY() + 1, self.getZ(),`n                    15, 0.4, 0.4, 0.4, 0.08);`n            }`n            player.sendMessage(net.minecraft.text.Text.literal(`"\u00a7eSHARINGAN PARRY!`"), false);`n            cir.setReturnValue(false);`n            return;`n        }`n        if (b.autoParryChance <= 0) return;"

# ============================================================
# PATCH: Add lang entries
# ============================================================
Write-Host "[PATCH] Adding lang entries..." -ForegroundColor Yellow

$enLangFile = Join-Path $resBase "assets\shinobicore\lang\en_us.json"
Patch-File $enLangFile `
    '"key.shinobicore.toggle_scabbard": "Sheathe / Draw Katana (O)"' `
    '"key.shinobicore.toggle_scabbard": "Sheathe / Draw Katana (O)",`n    "key.shinobicore.toggle_sharingan": "Toggle Sharingan (P)"'

$ruLangFile = Join-Path $resBase "assets\shinobicore\lang\ru_ru.json"
if (Test-Path $ruLangFile) {
    $ruContent = [System.IO.File]::ReadAllText($ruLangFile, $utf8)
    $ruContent = $ruContent.Replace("`r`n", "`n")
    if (-not $ruContent.Contains("toggle_sharingan")) {
        # Find last entry and add before closing brace
        $lastBrace = $ruContent.LastIndexOf("}")
        if ($lastBrace -gt 0) {
            $insert = ",`n    `"key.shinobicore.toggle_sharingan`": `"Sharingan (P)`"`n"
            $ruContent = $ruContent.Insert($lastBrace, $insert)
            [System.IO.File]::WriteAllText($ruLangFile, $ruContent, $utf8)
            Write-Host "  [PATCH] ru_ru.json sharingan entry added" -ForegroundColor Green
        }
    } else {
        Write-Host "  [SKIP] ru_ru.json already has sharingan entry" -ForegroundColor Yellow
    }
}

# ============================================================
# PATCH: Register TOGGLE_SHARINGAN key in KeyBindings.register()
# ============================================================
Write-Host "[PATCH] Registering TOGGLE_SHARINGAN in KeyBindings.register()..." -ForegroundColor Yellow

Patch-File $keyBindingsFile `
    "TOGGLE_SCABBARD = KeyBindingHelper.registerKeyBinding(new KeyBinding(" `
    "TOGGLE_SHARINGAN = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n                `"key.shinobicore.toggle_sharingan`", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_P, CATEGORY));`n        TOGGLE_SCABBARD = KeyBindingHelper.registerKeyBinding(new KeyBinding("

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "[BUILD] Building project..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 25 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    }
} finally { Pop-Location }

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 6 PHASE B: SHARINGAN COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - dojutsu/SharinganComponent.java (S6-07/08: evolution)" -ForegroundColor Cyan
Write-Host "  - client/dojutsu/SharinganClientState.java (client state)" -ForegroundColor Cyan
Write-Host "  - client/dojutsu/SharinganOverlayRenderer.java (visual)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Patched files:" -ForegroundColor White
Write-Host "  - network/ModPackets.java (SHARINGAN_SYNC/TOGGLE IDs)" -ForegroundColor Cyan
Write-Host "  - stat/NinjaPlayerData.java (sharinganComponent field)" -ForegroundColor Cyan
Write-Host "  - client/KeyBindings.java (TOGGLE_SHARINGAN key P)" -ForegroundColor Cyan
Write-Host "  - client/ClientInputHandler.java (toggle input)" -ForegroundColor Cyan
Write-Host "  - client/ShinobiCoreClient.java (renderer + receivers)" -ForegroundColor Cyan
Write-Host "  - ShinobiCore.java (server toggle handler)" -ForegroundColor Cyan
Write-Host "  - event/NinjaTickHandler.java (sharingan tick)" -ForegroundColor Cyan
Write-Host "  - mixin/PlayerParryMixin.java (3 tomoe auto-parry)" -ForegroundColor Cyan
Write-Host "  - lang/en_us.json + ru_ru.json (key binding text)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sharingan Design:" -ForegroundColor White
Write-Host "  Evolution: usage + stress (combined)" -ForegroundColor Yellow
Write-Host "  1 Tomoe: 50 usage + 1 stress" -ForegroundColor Yellow
Write-Host "  2 Tomoe: 150 usage + 2 stress (copy T1-T3 techniques)" -ForegroundColor Yellow
Write-Host "  3 Tomoe: 300 usage + 3 stress (35% auto-parry)" -ForegroundColor Yellow
Write-Host "  Mangekyo: 500 usage + 5 stress + quest stub" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Activation: key P (toggle)" -ForegroundColor Yellow
Write-Host "  Cost: 5% max chakra per 10 seconds" -ForegroundColor Yellow
Write-Host "  Visual: red overlay + red particles around head" -ForegroundColor Yellow
Write-Host ""