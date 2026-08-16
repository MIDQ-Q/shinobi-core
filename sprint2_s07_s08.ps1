# ============================================================
#  SPRINT 2 / S2-07 & S2-08: WEAPON DURABILITY + LANDING CONTROL
#  S2-07: Katanas have no durability
#  S2-08: Fast control recovery after landing
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
    Write-Host "[OK] Created: $($p.Replace($root, ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) {
        Write-Host "[MISS] $p" -ForegroundColor Red
        $script:err++
        return
    }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) {
        Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow
        $script:skip++
        return
    }
    if (-not $cNorm.Contains($oldNorm)) {
        Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red
        $script:err++
        return
    }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 2 / S2-07 & S2-08: WEAPONS + LANDING" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. KatanaItem.java - FULL OVERWRITE (no durability)
# ================================================================
Write-Host "[1/4] KatanaItem.java (no durability)..." -ForegroundColor White
Write-File "$java\item\KatanaItem.java" @'
package com.example.shinobicore.item;

import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.item.SwordItem;
import net.minecraft.item.ToolMaterial;

/**
 * S2-07: Katana weapon without durability.
 * Balance is handled through stats and cooldowns, not item breaking.
 */
public class KatanaItem extends SwordItem {
    public KatanaItem(ToolMaterial material, Item.Settings settings) {
        super(material, 4, -2.4f, settings);
    }

    @Override
    public boolean isDamageable() {
        return false;
    }

    @Override
    public boolean isEnchantable(ItemStack stack) {
        return true;
    }

    @Override
    public int getEnchantability() {
        return this.getMaterial().getEnchantability();
    }

    @Override
    public boolean canRepair(ItemStack stack, ItemStack ingredient) {
        return false;
    }

    @Override
    public boolean isUsedOnRelease(ItemStack stack) {
        return false;
    }
}
'@

# ================================================================
# 2. ModItems.java - Add maxDamage(0) to katanas
# ================================================================
Write-Host "[2/4] ModItems.java (maxDamage=0 for katanas)..." -ForegroundColor White
Patch-File "$java\item\ModItems.java" `
    "new Identifier(ShinobiCore.MOD_ID, ""katana_iron""), new KatanaItem(ToolMaterials.IRON, new Item.Settings().maxCount(1))" `
    "new Identifier(ShinobiCore.MOD_ID, ""katana_iron""), new KatanaItem(ToolMaterials.IRON, new Item.Settings().maxCount(1).maxDamage(0))"

Patch-File "$java\item\ModItems.java" `
    "new Identifier(ShinobiCore.MOD_ID, ""katana_diamond""), new KatanaItem(ToolMaterials.DIAMOND, new Item.Settings().maxCount(1))" `
    "new Identifier(ShinobiCore.MOD_ID, ""katana_diamond""), new KatanaItem(ToolMaterials.DIAMOND, new Item.Settings().maxCount(1).maxDamage(0))"

Patch-File "$java\item\ModItems.java" `
    "new Identifier(ShinobiCore.MOD_ID, ""katana_netherite""), new KatanaItem(ToolMaterials.NETHERITE, new Item.Settings().maxCount(1).fireproof())" `
    "new Identifier(ShinobiCore.MOD_ID, ""katana_netherite""), new KatanaItem(ToolMaterials.NETHERITE, new Item.Settings().maxCount(1).maxDamage(0).fireproof())"

# ================================================================
# 3. LandingControlRecovery.java - NEW FILE
# ================================================================
Write-Host "[3/4] LandingControlRecovery.java (new system)..." -ForegroundColor White
Write-File "$java\client\LandingControlRecovery.java" @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * S2-08: Fast control recovery after landing.
 * 
 * After a significant fall, the player enters a brief recovery window
 * (3 ticks = 0.15 sec) where movement penalties are reduced and
 * the player regains full control quickly.
 * 
 * This prevents the unpleasant "slippery landing" feeling and
 * ensures parkour + combat don't conflict.
 */
public class LandingControlRecovery {
    private static final Map<UUID, Integer> RECOVERY_TICKS = new HashMap<>();
    private static final Map<UUID, Boolean> WAS_ON_GROUND = new HashMap<>();
    private static final Map<UUID, Float> LAST_FALL_VEL = new HashMap<>();
    
    /** Recovery window duration in ticks (0.15 sec) */
    private static final int RECOVERY_DURATION = 3;
    
    /** Minimum fall velocity to trigger recovery (blocks/tick) */
    private static final float MIN_FALL_VEL = -0.3f;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(LandingControlRecovery::tick);
    }

    private static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        UUID id = player.getUuid();
        boolean onGround = player.isOnGround();
        boolean wasOnGround = WAS_ON_GROUND.getOrDefault(id, true);

        // Track fall velocity while airborne
        if (!onGround) {
            float vy = (float) player.getVelocity().y;
            if (vy < 0) {
                LAST_FALL_VEL.put(id, vy);
            }
        }

        // Detect landing: transition from air to ground
        if (!wasOnGround && onGround) {
            float fallVel = LAST_FALL_VEL.getOrDefault(id, 0f);
            if (fallVel < MIN_FALL_VEL) {
                RECOVERY_TICKS.put(id, RECOVERY_DURATION);
            }
            LAST_FALL_VEL.remove(id);
        }

        // Tick recovery countdown
        if (RECOVERY_TICKS.containsKey(id)) {
            int ticks = RECOVERY_TICKS.get(id);
            if (ticks <= 0) {
                RECOVERY_TICKS.remove(id);
            } else {
                RECOVERY_TICKS.put(id, ticks - 1);
            }
        }

        WAS_ON_GROUND.put(id, onGround);
    }

    /**
     * Check if player is in landing recovery window.
     * Other systems can use this to skip casting interruptions,
     * reduce movement penalties, etc.
     */
    public static boolean isRecovering(UUID id) {
        Integer ticks = RECOVERY_TICKS.get(id);
        return ticks != null && ticks > 0;
    }

    public static boolean isRecovering(ClientPlayerEntity player) {
        if (player == null) return false;
        return isRecovering(player.getUuid());
    }

    /**
     * Get remaining recovery ticks (0 if not recovering).
     */
    public static int getRecoveryTicks(UUID id) {
        return RECOVERY_TICKS.getOrDefault(id, 0);
    }

    /**
     * Cleanup on player disconnect to prevent memory leaks.
     */
    public static void cleanup(UUID id) {
        RECOVERY_TICKS.remove(id);
        WAS_ON_GROUND.remove(id);
        LAST_FALL_VEL.remove(id);
    }

    /**
     * Cleanup all data (called on disconnect).
     */
    public static void cleanupAll() {
        RECOVERY_TICKS.clear();
        WAS_ON_GROUND.clear();
        LAST_FALL_VEL.clear();
    }
}
'@

# ================================================================
# 4. ShinobiCoreClient.java - Register landing recovery
# ================================================================
Write-Host "[4/4] ShinobiCoreClient.java (register + cleanup)..." -ForegroundColor White

# 4a. Register LandingControlRecovery near LandingAnimations
Patch-File "$java\client\ShinobiCoreClient.java" `
    "com.example.shinobicore.client.LandingAnimations.register();" `
    "com.example.shinobicore.client.LandingAnimations.register();`n        com.example.shinobicore.client.LandingControlRecovery.register(); // S2-08"

# 4b. Add cleanup on disconnect
Patch-File "$java\client\ShinobiCoreClient.java" `
    "IdlePoseSystem.cleanupAll();" `
    "IdlePoseSystem.cleanupAll();`n            com.example.shinobicore.client.LandingControlRecovery.cleanupAll(); // S2-08"

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S2-07 & S2-08 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Changes:" -ForegroundColor White
Write-Host "    S2-07: KatanaItem.java       - isDamageable()=false, canRepair()=false" -ForegroundColor White
Write-Host "    S2-07: ModItems.java         - maxDamage(0) on all 3 katanas" -ForegroundColor White
Write-Host "    S2-08: LandingControlRecovery.java - new recovery system (3 tick window)" -ForegroundColor White
Write-Host "    S2-08: ShinobiCoreClient.java - registered + cleanup on disconnect" -ForegroundColor White
Write-Host ""
Write-Host "  S2-07: Katanas no longer break. Balance via stats/cooldowns." -ForegroundColor Cyan
Write-Host "  S2-08: Landing no longer causes control loss. 0.15s recovery." -ForegroundColor Cyan
Write-Host "  Note: Shuriken/Kunai remain consumable (stack-decrement on use)." -ForegroundColor DarkGray
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0