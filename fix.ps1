# ============================================================
# MASTER SCRIPT: VARIANT 1 + ARTIFACTS INTEGRATION
# Полный первый срез + интеграция слотов артефактов
# ============================================================
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $fullPath = Join-Path $root $Path
    $dir = Split-Path $fullPath -Parent
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
    Write-Host "[OK] $Path" -ForegroundColor Green
}

function Patch-File {
    param([string]$Path, [scriptblock]$Transform)
    $fullPath = Join-Path $root $Path
    if (!(Test-Path $fullPath)) {
        Write-Host "[SKIP] $Path not found" -ForegroundColor Yellow
        return
    }
    $content = [System.IO.File]::ReadAllText($fullPath, $utf8NoBom)
    $newContent = & $Transform $content
    if ($content -ne $newContent) {
        [System.IO.File]::WriteAllText($fullPath, $newContent, $utf8NoBom)
        Write-Host "[PATCHED] $Path" -ForegroundColor Green
    } else {
        Write-Host "[NO CHANGE] $Path" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  MASTER SCRIPT: VARIANT 1 + ARTIFACTS INTEGRATION" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# PHASE 0: BUILD CONFIG - Add Curios dependency
# ============================================================
Write-Host "--- Phase 0: Build Configuration ---" -ForegroundColor Yellow

Patch-File "build.gradle" {
    param($c)
    if ($c -match 'curios') { return $c }
    $c = $c -replace '(repositories \{)', "`$1`n        maven { name = 'Curios'; url = 'https://maven.theillusivec4.top/' }"
    $c = $c -replace '(dependencies \{)', "`$1`n    // === CURIOS API (Artifacts mod dependency) ===`n    modImplementation `"top.theillusivec4.curios:curios-fabric:5.9.1+1.20.1`"`n    include `"top.theillusivec4.curios:curios-fabric:5.9.1+1.20.1`""
    return $c
}

Patch-File "src\main\resources\fabric.mod.json" {
    param($c)
    if ($c -match '"curios"') { return $c }
    $c = $c -replace '("depends": \{)', "`$1`n        `"curios`": `"*`","
    return $c
}

Patch-File "gradle.properties" {
    param($c)
    if ($c -match 'curios_version') { return $c }
    $c += "`ncurios_version=5.9.1+1.20.1"
    return $c
}

# ============================================================
# PHASE 1: CORE INFRASTRUCTURE
# ============================================================
Write-Host "`n--- Phase 1: Core Infrastructure ---" -ForegroundColor Yellow

# FeatureFlags
Write-Utf8NoBom "src\main\java\com\example\shinobicore\util\FeatureFlags.java" @'
package com.example.shinobicore.util;

public final class FeatureFlags {
    private FeatureFlags() {}
    
    public static boolean enableCore = true;
    public static boolean enableCommands = true;
    public static boolean enableDataLoading = true;
    public static boolean enableJutsuCasting = true;
    public static boolean enableSkillTree = true;
    public static boolean enableAttunement = true;
    public static boolean enableGenjutsu = true;
    public static boolean enableSensory = true;
    public static boolean enableClans = true;
    public static boolean enableWorldModification = true;
    public static boolean enableCuriosIntegration = true;
    
    // Legacy flags (disabled)
    public static boolean enableLegacyTaijutsu = false;
    public static boolean enableLegacyParkour = false;
    public static boolean enableLegacyHud = false;
}
'@

# ============================================================
# PHASE 2: CURIOS INTEGRATION - Artifact Slots
# ============================================================
Write-Host "`n--- Phase 2: Curios Integration ---" -ForegroundColor Yellow

# CuriosCompat - checks if Curios is loaded
Write-Utf8NoBom "src\main\java\com\example\shinobicore\compat\CuriosCompat.java" @'
package com.example.shinobicore.compat;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.entity.player.PlayerInventory;
import net.minecraft.item.ItemStack;
import net.minecraft.screen.slot.Slot;
import top.theillusivec4.curios.api.CuriosApi;
import top.theillusivec4.curios.api.type.inventory.ICurioStacksHandler;
import top.theillusivec4.curios.api.type.inventory.IDynamicStackHandler;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public final class CuriosCompat {
    private static Boolean cached = null;
    
    public static boolean isLoaded() {
        if (cached == null) {
            cached = FabricLoader.getInstance().isModLoaded("curios");
            if (cached) {
                ShinobiCore.LOGGER.info("[CuriosCompat] Curios API detected - artifact slots enabled");
            } else {
                ShinobiCore.LOGGER.info("[CuriosCompat] Curios API not found - artifact slots disabled");
            }
        }
        return cached;
    }
    
    public static List<ArtifactSlotInfo> getArtifactSlots() {
        List<ArtifactSlotInfo> slots = new ArrayList<>();
        if (!isLoaded()) return slots;
        
        // Standard artifact slot types from Artifacts mod
        slots.add(new ArtifactSlotInfo("necklace", "Necklace", 0xFFD78AFF));
        slots.add(new ArtifactSlotInfo("ring", "Ring", 0xFFFF9EC4));
        slots.add(new ArtifactSlotInfo("belt", "Belt", 0xFF8AE08A));
        slots.add(new ArtifactSlotInfo("head", "Head", 0xFF7EB7FF));
        slots.add(new ArtifactSlotInfo("hands", "Hands", 0xFFFFD75E));
        slots.add(new ArtifactSlotInfo("feet", "Feet", 0xFF9A8FA6));
        
        return slots;
    }
    
    public static ItemStack getArtifactStack(net.minecraft.entity.player.PlayerEntity player, String slotType, int index) {
        if (!isLoaded()) return ItemStack.EMPTY;
        try {
            Optional<ICurioStacksHandler> handler = CuriosApi.getCuriosInventory(player)
                .map(h -> h.getCurios().get(slotType));
            if (handler.isPresent()) {
                IDynamicStackHandler stacks = handler.get().getStacks();
                if (index < stacks.getSlots()) {
                    return stacks.getStackInSlot(index);
                }
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[CuriosCompat] Error getting artifact stack", e);
        }
        return ItemStack.EMPTY;
    }
    
    public static void setArtifactStack(net.minecraft.entity.player.PlayerEntity player, String slotType, int index, ItemStack stack) {
        if (!isLoaded()) return;
        try {
            Optional<ICurioStacksHandler> handler = CuriosApi.getCuriosInventory(player)
                .map(h -> h.getCurios().get(slotType));
            if (handler.isPresent()) {
                IDynamicStackHandler stacks = handler.get().getStacks();
                if (index < stacks.getSlots()) {
                    stacks.setStackInSlot(index, stack);
                }
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[CuriosCompat] Error setting artifact stack", e);
        }
    }
    
    public static class ArtifactSlotInfo {
        public final String id;
        public final String displayName;
        public final int accentColor;
        
        public ArtifactSlotInfo(String id, String displayName, int accentColor) {
            this.id = id;
            this.displayName = displayName;
            this.accentColor = accentColor;
        }
    }
}
'@

# CuriosSlot - custom slot for artifacts
Write-Utf8NoBom "src\main\java\com\example\shinobicore\client\sakura\CuriosSlot.java" @'
package com.example.shinobicore.client.sakura;

import com.example.shinobicore.compat.CuriosCompat;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.screen.slot.Slot;

public class CuriosSlot extends Slot {
    private final String slotType;
    private final int curiosIndex;
    private final PlayerEntity player;
    
    public CuriosSlot(PlayerEntity player, String slotType, int curiosIndex, int x, int y) {
        super(player.getInventory(), -1, x, y); // -1 index since we handle it manually
        this.player = player;
        this.slotType = slotType;
        this.curiosIndex = curiosIndex;
    }
    
    @Override
    public ItemStack getStack() {
        return CuriosCompat.getArtifactStack(player, slotType, curiosIndex);
    }
    
    @Override
    public void setStack(ItemStack stack) {
        CuriosCompat.setArtifactStack(player, slotType, curiosIndex, stack);
        this.markDirty();
    }
    
    @Override
    public void setStackNoCallbacks(ItemStack stack) {
        this.setStack(stack);
    }
    
    @Override
    public ItemStack takeStack(int amount) {
        ItemStack current = this.getStack();
        if (current.isEmpty()) return ItemStack.EMPTY;
        ItemStack taken = current.split(amount);
        this.setStack(current);
        return taken;
    }
    
    @Override
    public boolean canInsert(ItemStack stack) {
        if (!CuriosCompat.isLoaded()) return false;
        // Check if item is valid for this slot type via Curios API
        try {
            return top.theillusivec4.curios.api.CuriosApi.getItemStackSlots(stack, player)
                .containsKey(slotType);
        } catch (Exception e) {
            return false;
        }
    }
    
    @Override
    public boolean canTakeItems(PlayerEntity playerEntity) {
        return !this.getStack().isEmpty();
    }
    
    @Override
    public int getMaxItemCount() {
        return 1;
    }
    
    @Override
    public void markDirty() {
        // Sync with Curios
    }
    
    public String getSlotType() { return slotType; }
}
'@

# ============================================================
# PHASE 3: SAKURA HANDLER - Add Artifact Slots
# ============================================================
Write-Host "`n--- Phase 3: Sakura Handler with Artifacts ---" -ForegroundColor Yellow

Write-Utf8NoBom "src\main\java\com\example\shinobicore\client\sakura\SakuraHandler.java" @'
package com.example.shinobicore.client.sakura;

import com.example.shinobicore.compat.CuriosCompat;
import net.minecraft.entity.EquipmentSlot;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.entity.player.PlayerInventory;
import net.minecraft.item.ItemStack;
import net.minecraft.screen.ScreenHandler;
import net.minecraft.screen.slot.Slot;

import java.util.ArrayList;
import java.util.List;

public class SakuraHandler extends ScreenHandler {
    public final PlayerInventory inv;
    public final List<CuriosSlot> artifactSlots = new ArrayList<>();
    
    // ==== LAYOUT (coords relative to GUI origin) ====
    public static final int BG_W = 320;
    public static final int BG_H = 220;
    
    // Left panel: Armor + Artifacts
    public static final int ARMOR_X = 12;
    public static final int ARMOR_Y0 = 26;
    public static final int ARMOR_DY = 22;
    
    // Artifacts panel (right of armor)
    public static final int ARTIFACT_X = 60;
    public static final int ARTIFACT_Y0 = 26;
    public static final int ARTIFACT_DY = 22;
    
    // Right panel: Stash + Hotbar
    public static final int STASH_X = 135;
    public static final int STASH_Y = 30;
    public static final int SEP_Y = 94;
    public static final int HOTBAR_Y = 110;
    
    public SakuraHandler(int syncId, PlayerInventory inv) {
        super(SakuraNetwork.TYPE, syncId);
        this.inv = inv;
        
        // 0..3: armor HEAD/CHEST/LEGS/FEET
        EquipmentSlot[] eq = {EquipmentSlot.HEAD, EquipmentSlot.CHEST, EquipmentSlot.LEGS, EquipmentSlot.FEET};
        for (int i = 0; i < 4; i++) {
            addSlot(new ArmorSlot(inv, 39 - i, ARMOR_X, ARMOR_Y0 + i * ARMOR_DY, eq[i]));
        }
        
        // 4: offhand
        addSlot(new Slot(inv, 40, ARMOR_X, ARMOR_Y0 + 4 * ARMOR_DY));
        
        // 5..N: Artifact slots (Curios integration)
        if (CuriosCompat.isLoaded()) {
            List<CuriosCompat.ArtifactSlotInfo> artifacts = CuriosCompat.getArtifactSlots();
            for (int i = 0; i < artifacts.size(); i++) {
                CuriosSlot slot = new CuriosSlot(
                    inv.player,
                    artifacts.get(i).id,
                    0,
                    ARTIFACT_X,
                    ARTIFACT_Y0 + i * ARTIFACT_DY
                );
                artifactSlots.add(slot);
                addSlot(slot);
            }
        }
        
        // Stash: 9x3
        int stashStart = 5 + artifactSlots.size();
        for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 9; c++) {
                addSlot(new Slot(inv, 9 + r * 9 + c, STASH_X + c * 18, STASH_Y + r * 18));
            }
        }
        
        // Hotbar: 9 slots
        for (int i = 0; i < 9; i++) {
            addSlot(new Slot(inv, i, STASH_X + i * 18, HOTBAR_Y));
        }
    }
    
    @Override
    public boolean canUse(PlayerEntity player) { return true; }
    
    @Override
    public ItemStack quickMove(PlayerEntity player, int index) {
        ItemStack result = ItemStack.EMPTY;
        Slot slot = this.slots.get(index);
        if (slot != null && slot.hasStack()) {
            ItemStack stack = slot.getStack();
            result = stack.copy();
            
            int armorEnd = 5;
            int artifactEnd = armorEnd + artifactSlots.size();
            int stashEnd = artifactEnd + 27;
            
            if (index < armorEnd) {
                // armor/offhand -> stash/hotbar
                if (!this.insertItem(stack, artifactEnd, stashEnd + 9, true)) return ItemStack.EMPTY;
            } else if (index < artifactEnd) {
                // artifact -> stash/hotbar
                if (!this.insertItem(stack, artifactEnd, stashEnd + 9, true)) return ItemStack.EMPTY;
            } else if (index < stashEnd) {
                // stash -> hotbar, else try armor, else try artifacts
                if (!this.insertItem(stack, stashEnd, stashEnd + 9, false)) {
                    if (!this.insertItem(stack, 0, armorEnd, false)) {
                        if (!tryInsertArtifact(stack)) return ItemStack.EMPTY;
                    }
                }
            } else {
                // hotbar -> stash, else armor, else artifacts
                if (!this.insertItem(stack, artifactEnd, stashEnd, false)) {
                    if (!this.insertItem(stack, 0, armorEnd, false)) {
                        if (!tryInsertArtifact(stack)) return ItemStack.EMPTY;
                    }
                }
            }
            
            if (stack.isEmpty()) slot.setStack(ItemStack.EMPTY);
            else slot.markDirty();
            if (stack.getCount() == result.getCount()) return ItemStack.EMPTY;
            slot.onTakeItem(player, stack);
        }
        return result;
    }
    
    private boolean tryInsertArtifact(ItemStack stack) {
        if (!CuriosCompat.isLoaded()) return false;
        for (CuriosSlot slot : artifactSlots) {
            if (slot.canInsert(stack) && slot.getStack().isEmpty()) {
                slot.setStack(stack.copy());
                stack.setCount(0);
                return true;
            }
        }
        return false;
    }
    
    private static class ArmorSlot extends Slot {
        private final EquipmentSlot eq;
        public ArmorSlot(PlayerInventory inv, int index, int x, int y, EquipmentSlot eq) {
            super(inv, index, x, y);
            this.eq = eq;
        }
        @Override public int getMaxItemCount() { return 1; }
        @Override public boolean canInsert(ItemStack stack) {
            return LivingEntity.getPreferredEquipmentSlot(stack) == eq;
        }
    }
}
'@

# ============================================================
# PHASE 4: SAKURA HUB SCREEN - Render Artifact Slots with Style
# ============================================================
Write-Host "`n--- Phase 4: Styled Artifact Slot Rendering ---" -ForegroundColor Yellow

# ArtifactPanel - renders artifact slots with sakura styling
Write-Utf8NoBom "src\main\java\com\example\shinobicore\client\sakura\ui\ArtifactPanel.java" @'
package com.example.shinobicore.client.sakura.ui;

import com.example.shinobicore.client.sakura.CuriosSlot;
import com.example.shinobicore.client.sakura.SakuraHandler;
import com.example.shinobicore.compat.CuriosCompat;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.item.ItemStack;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;

import java.util.List;

public final class ArtifactPanel {
    private ArtifactPanel() {}
    
    public static void render(DrawContext ctx, SakuraHandler handler, int gx, int gy, int mx, int my, long now) {
        if (!CuriosCompat.isLoaded() || handler.artifactSlots.isEmpty()) return;
        
        MinecraftClient client = MinecraftClient.getInstance();
        List<CuriosCompat.ArtifactSlotInfo> infos = CuriosCompat.getArtifactSlots();
        
        // Panel background
        int panelX = gx + SakuraHandler.ARTIFACT_X - 6;
        int panelY = gy + SakuraHandler.ARTIFACT_Y0 - 6;
        int panelW = 28;
        int panelH = handler.artifactSlots.size() * SakuraHandler.ARTIFACT_DY + 12;
        
        SakuraTextures.drawPanel(ctx, panelX, panelY, panelW, panelH);
        
        // Header
        ctx.drawTextWithShadow(client.textRenderer, 
            Text.translatable("gui.shinobicore.artifacts"),
            panelX + 4, panelY + 4, SakuraTheme.SAKURA);
        
        // Render each artifact slot
        for (int i = 0; i < handler.artifactSlots.size(); i++) {
            CuriosSlot slot = handler.artifactSlots.get(i);
            CuriosCompat.ArtifactSlotInfo info = i < infos.size() ? infos.get(i) : null;
            
            int slotX = gx + slot.x;
            int slotY = gy + slot.y;
            int slotSize = 16;
            
            boolean hovered = mx >= slotX && mx < slotX + slotSize && my >= slotY && my < slotY + slotSize;
            
            // Slot background with accent color
            int accentColor = info != null ? info.accentColor : SakuraTheme.SAKURA;
            int bgAlpha = hovered ? 0x55 : 0x22;
            int bgColor = ColorHelper.Argb.getArgb(bgAlpha * 255 / 255, 
                (accentColor >> 16) & 0xFF,
                (accentColor >> 8) & 0xFF,
                accentColor & 0xFF);
            
            ctx.fill(slotX, slotY, slotX + slotSize, slotY + slotSize, bgColor);
            
            // Border with accent
            int borderColor = hovered ? accentColor : withAlpha(accentColor, 0.5f);
            ctx.fill(slotX, slotY, slotX + slotSize, slotY + 1, borderColor);
            ctx.fill(slotX, slotY + slotSize - 1, slotX + slotSize, slotY + slotSize, borderColor);
            ctx.fill(slotX, slotY, slotX + 1, slotY + slotSize, borderColor);
            ctx.fill(slotX + slotSize - 1, slotY, slotX + slotSize, slotY + slotSize, borderColor);
            
            // Draw item or placeholder icon
            ItemStack stack = slot.getStack();
            if (!stack.isEmpty()) {
                ctx.drawItem(stack, slotX, slotY);
                if (stack.getCount() > 1) {
                    ctx.drawItemInSlot(client.textRenderer, stack, slotX, slotY);
                }
            } else {
                // Draw placeholder glyph
                drawArtifactGlyph(ctx, info != null ? info.id : "", slotX + 8, slotY + 8, 
                    withAlpha(accentColor, 0.4f));
            }
            
            // Hover tooltip
            if (hovered && stack.isEmpty() && info != null) {
                ctx.drawTooltip(client.textRenderer, 
                    Text.literal(info.displayName), mx, my);
            }
        }
    }
    
    private static void drawArtifactGlyph(DrawContext ctx, String type, int cx, int cy, int color) {
        // Procedural glyphs for artifact types
        switch (type) {
            case "necklace" -> {
                // Circle with pendant
                for (int i = 0; i < 12; i++) {
                    double a = i * Math.PI * 2 / 12;
                    int x = cx + (int)(Math.cos(a) * 4);
                    int y = cy - 2 + (int)(Math.sin(a) * 3);
                    ctx.fill(x, y, x + 1, y + 1, color);
                }
                ctx.fill(cx, cy + 2, cx + 1, cy + 5, color);
            }
            case "ring" -> {
                // Simple ring
                for (int i = 0; i < 8; i++) {
                    double a = i * Math.PI * 2 / 8;
                    int x = cx + (int)(Math.cos(a) * 3);
                    int y = cy + (int)(Math.sin(a) * 3);
                    ctx.fill(x, y, x + 1, y + 1, color);
                }
            }
            case "belt" -> {
                // Horizontal belt
                ctx.fill(cx - 4, cy - 1, cx + 4, cy + 1, color);
                ctx.fill(cx - 1, cy - 2, cx + 1, cy + 2, color);
            }
            case "head" -> {
                // Crown/helmet
                ctx.fill(cx - 3, cy + 1, cx + 3, cy + 2, color);
                ctx.fill(cx - 2, cy - 1, cx - 1, cy + 1, color);
                ctx.fill(cx, cy - 2, cx + 1, cy, color);
                ctx.fill(cx + 2, cy - 1, cx + 3, cy + 1, color);
            }
            case "hands" -> {
                // Gauntlet
                ctx.fill(cx - 2, cy - 2, cx + 2, cy + 2, color);
                ctx.fill(cx - 3, cy - 1, cx - 2, cy + 1, color);
                ctx.fill(cx + 2, cy - 1, cx + 3, cy + 1, color);
            }
            case "feet" -> {
                // Boot
                ctx.fill(cx - 2, cy - 2, cx + 1, cy + 1, color);
                ctx.fill(cx - 1, cy + 1, cx + 3, cy + 2, color);
            }
            default -> ctx.fill(cx - 1, cy - 1, cx + 1, cy + 1, color);
        }
    }
    
    private static int withAlpha(int color, float alpha) {
        int a = (int)(alpha * 255);
        return (a << 24) | (color & 0x00FFFFFF);
    }
}
'@

# ============================================================
# --- Phase 5: Patching SakuraHubScreen (Artifacts Integration) ---
# ============================================================
$hubPath = Join-Path $root "src\main\java\com\example\shinobicore\client\sakura\SakuraHubScreen.java"
if (Test-Path $hubPath) {
    $c = [System.IO.File]::ReadAllText($hubPath, $utf8NoBom)
    
    # Точка вставки (используем точный текст из SakuraHubScreen.java)
    $insertPoint = 'ctx.drawTextWithShadow(textRenderer, Text.translatable("gui.shinobicore.equipment"),'
    
    $insertCode = @"
            // Integrating Curios / Artifacts Panel
            com.example.shinobicore.client.sakura.ui.ArtifactPanel.render(ctx, gx + 120, gy + 6, 100, lh, mx, my);
            
"@

    # ИСПРАВЛЕНИЕ: Используем .Replace() вместо -replace, чтобы избежать ошибок Regex со скобками
    if ($c.Contains($insertPoint) -and -not $c.Contains("ArtifactPanel.render")) {
        $c = $c.Replace($insertPoint, $insertCode + $insertPoint)
        [System.IO.File]::WriteAllText($hubPath, $c, $utf8NoBom)
        Write-Host "[PATCHED] SakuraHubScreen.java (Artifacts integrated)" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] SakuraHubScreen.java already patched or target string not found." -ForegroundColor Yellow
    }
} else {
    Write-Host "[WARN] SakuraHubScreen.java not found!" -ForegroundColor Red
}

# ============================================================
# PHASE 6: TRANSLATION KEYS
# ============================================================
Write-Host "`n--- Phase 6: Translation Keys ---" -ForegroundColor Yellow

Patch-File "src\main\resources\assets\shinobicore\lang\en_us.json" {
    param($c)
    if ($c -match 'gui.shinobicore.artifacts') { return $c }
    
    $c = $c -replace '(\}\s*)$', @'
,
  "gui.shinobicore.artifacts": "Artifacts",
  "gui.shinobicore.artifact.necklace": "Necklace",
  "gui.shinobicore.artifact.ring": "Ring",
  "gui.shinobicore.artifact.belt": "Belt",
  "gui.shinobicore.artifact.head": "Head",
  "gui.shinobicore.artifact.hands": "Hands",
  "gui.shinobicore.artifact.feet": "Feet"
}
'@
    return $c
}

# ============================================================
# PHASE 7: VARIANT 1 CORE - Basic Systems
# ============================================================
Write-Host "`n--- Phase 7: Variant 1 Core Systems ---" -ForegroundColor Yellow

# Basic jutsu definition for testing
Write-Utf8NoBom "src\main\resources\data\shinobicore\jutsu\test_point_heal.json" @'
{
  "id": "shinobicore:test_point_heal",
  "name": "Test: Point Heal",
  "category": "utility",
  "element": "none",
  "rank": "D",
  "behaviorType": "projectile",
  "targetMode": "self",
  "castTime": 0.0,
  "cooldown": 2.0,
  "baseCost": 10,
  "baseDamage": -8,
  "baseRange": 0,
  "strain": 2,
  "requirements": {},
  "leveling": {
    "maxLevel": 1,
    "usesPerLevel": [0]
  },
  "params": {},
  "scaling": {},
  "visual": {
    "particle": "happy_villager"
  },
  "sound": {
    "cast": "entity.player.levelup"
  },
  "tags": ["test", "heal"]
}
'@

# ============================================================
# BUILD
# ============================================================
Write-Host "`n--- Building ---" -ForegroundColor Yellow
Push-Location $root
try {
    $buildOut = & cmd /c "gradlew.bat build 2>&1" | Out-String
    if ($buildOut -match "BUILD SUCCESSFUL") {
        Write-Host "[PASS] BUILD SUCCESSFUL!" -ForegroundColor Green
        Write-Host ""
        Write-Host "VARIANT 1 + ARTIFACTS INTEGRATION COMPLETE:" -ForegroundColor Yellow
        Write-Host "  [OK] Core infrastructure (FeatureFlags)" -ForegroundColor Gray
        Write-Host "  [OK] Curios API dependency added" -ForegroundColor Gray
        Write-Host "  [OK] CuriosCompat - detects and interfaces with Curios" -ForegroundColor Gray
        Write-Host "  [OK] CuriosSlot - custom slot for artifacts" -ForegroundColor Gray
        Write-Host "  [OK] SakuraHandler - 6 artifact slots (necklace, ring, belt, head, hands, feet)" -ForegroundColor Gray
        Write-Host "  [OK] ArtifactPanel - styled rendering with sakura theme" -ForegroundColor Gray
        Write-Host "  [OK] Translation keys for artifact UI" -ForegroundColor Gray
        Write-Host "  [OK] Test jutsu for basic validation" -ForegroundColor Gray
        Write-Host ""
        Write-Host "ARTIFACT SLOTS ADDED:" -ForegroundColor Cyan
        Write-Host "  - Necklace (purple accent)" -ForegroundColor White
        Write-Host "  - Ring (pink accent)" -ForegroundColor White
        Write-Host "  - Belt (green accent)" -ForegroundColor White
        Write-Host "  - Head (blue accent)" -ForegroundColor White
        Write-Host "  - Hands (gold accent)" -ForegroundColor White
        Write-Host "  - Feet (gray accent)" -ForegroundColor White
        Write-Host ""
        Write-Host "NEXT STEPS:" -ForegroundColor Yellow
        Write-Host "  1. Run: .\gradlew.bat runClient" -ForegroundColor White
        Write-Host "  2. Install Artifacts mod + Curios API in mods folder" -ForegroundColor White
        Write-Host "  3. Open inventory (K) to see artifact slots" -ForegroundColor White
        Write-Host "  4. Find artifacts in dungeon chests and equip them" -ForegroundColor White
    } else {
        Write-Host "[FAIL] Build errors:" -ForegroundColor Red
        ($buildOut -split "`n") | Where-Object { $_ -match "error:" } | Select-Object -First 20 | ForEach-Object { 
            Write-Host "  $_" -ForegroundColor Red 
        }
    }
} finally { 
    Pop-Location 
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  MASTER SCRIPT COMPLETE" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan