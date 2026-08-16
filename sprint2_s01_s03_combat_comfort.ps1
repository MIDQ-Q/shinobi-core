# ============================================================
#  SPRINT 2 / S2-01, S2-02, S2-03: COMBAT COMFORT
#  Caps, Control Inertia, Block Mechanic
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$res = "$root\src\main\resources"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] Created: $($p.Replace($root, ''))" -ForegroundColor Green
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
Write-Host "  SPRINT 2: COMBAT COMFORT (CAPS, CONTROL, BLOCK)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. S2-01: ModConfig.java (Movement Caps)
# ================================================================
Write-Host "[1/9] ModConfig.java (Movement Caps)..." -ForegroundColor White
Patch-File "$java\config\ModConfig.java" `
"public Hud hud = new Hud();" `
"public Hud hud = new Hud();`n    public Movement movement = new Movement();`n`n    public static class Movement {`n        public float speedCapNormal = 1.3f;`n        public float speedCapChakra = 1.6f;`n        public float jumpHorizCap = 1.8f;`n        public float jumpVertCap = 1.4f;`n    }"

# ================================================================
# 2. S2-01: NinjaFormula.java (Apply Caps)
# ================================================================
Write-Host "[2/9] NinjaFormula.java (Apply Caps)..." -ForegroundColor White
Patch-File "$java\stat\NinjaFormula.java" `
"public static float speedMultiplier(int speedLevel, boolean chakraMode) {`n        float base = 1.0f + speedLevel * 0.125f;`n        if (chakraMode) base *= 2.0f;`n        return Math.min(base, chakraMode ? 4.0f : 2.0f);`n    }" `
"public static float speedMultiplier(int speedLevel, boolean chakraMode) {`n        float base = 1.0f + speedLevel * 0.03f;`n        if (chakraMode) base *= 1.2f;`n        float cap = chakraMode ? cfg().movement.speedCapChakra : cfg().movement.speedCapNormal;`n        return Math.min(base, cap);`n    }"

Patch-File "$java\stat\NinjaFormula.java" `
"public static float jumpHorizontalMultiplier(int jumpLevel, boolean chakraMode) {`n        if (!chakraMode) return 1.0f + jumpLevel * 0.125f;`n        return 2.0f + jumpLevel * 0.5f;`n    }" `
"public static float jumpHorizontalMultiplier(int jumpLevel, boolean chakraMode) {`n        float base = chakraMode ? 1.2f + jumpLevel * 0.06f : 1.0f + jumpLevel * 0.02f;`n        return Math.min(base, cfg().movement.jumpHorizCap);`n    }"

Patch-File "$java\stat\NinjaFormula.java" `
"public static float jumpVerticalMultiplier(int jumpLevel, boolean chakraMode) {`n        if (!chakraMode) return 1.0f;`n        return 1.5f + jumpLevel * 0.15f;`n    }" `
"public static float jumpVerticalMultiplier(int jumpLevel, boolean chakraMode) {`n        if (!chakraMode) return 1.0f;`n        float base = 1.1f + jumpLevel * 0.03f;`n        return Math.min(base, cfg().movement.jumpVertCap);`n    }"

# ================================================================
# 3. S2-02: ChakraPhysicsClient.java (Control Inertia Damping)
# ================================================================
Write-Host "[3/9] ChakraPhysicsClient.java (Control Inertia)..." -ForegroundColor White
Patch-File "$java\client\ChakraPhysicsClient.java" `
"boolean onGroundOrWater = player.isOnGround() || standingOnWater;" `
"boolean onGroundOrWater = player.isOnGround() || standingOnWater;`n`n        // === S2-02: CONTROL INERTIA DAMPING ===`n        int controlLevel = ClientNinjaState.statLevels.getOrDefault(""control"", 0);`n        float inertiaDamping = 0.92f - (controlLevel * 0.0025f); // 0.92 -> 0.67 at 100 control`n        if (!player.input.pressingForward && !player.input.pressingBack && !player.input.pressingLeft && !player.input.pressingRight) {`n            if (player.isOnGround() && !player.isSneaking() && !ParkourManager.isSliding()) {`n                Vec3d v = player.getVelocity();`n                double horizSpeedSq = v.x * v.x + v.z * v.z;`n                if (horizSpeedSq > 0.02) {`n                    player.setVelocity(v.x * inertiaDamping, v.y, v.z * inertiaDamping);`n                    player.velocityModified = true;`n                }`n            }`n        }"

# ================================================================
# 4. S2-03: ClientNinjaState.java (Block State Flag)
# ================================================================
Write-Host "[4/9] ClientNinjaState.java (Block Flag)..." -ForegroundColor White
Patch-File "$java\client\ClientNinjaState.java" `
"public static String activeDojutsu = null;" `
"public static String activeDojutsu = null;`n    public static boolean isBlockingClient = false;"

# ================================================================
# 5. S2-03: ClientInputHandler.java (Send Block Packet)
# ================================================================
Write-Host "[5/9] ClientInputHandler.java (Block Input)..." -ForegroundColor White
Patch-File "$java\client\ClientInputHandler.java" `
"prevRmbDown = rmbDown;" `
"// === S2-03: BLOCK STATE ===`n        boolean handEmpty = client.player.getMainHandStack().isEmpty();`n        boolean hasKatana = client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;`n        boolean wantBlock = rmbDown && (handEmpty || hasKatana);`n        if (wantBlock != ClientNinjaState.isBlockingClient) {`n            ClientNinjaState.isBlockingClient = wantBlock;`n            PacketByteBuf blockBuf = new PacketByteBuf(Unpooled.buffer());`n            blockBuf.writeBoolean(wantBlock);`n            ClientPlayNetworking.send(ModPackets.BLOCK_STATE_ID, blockBuf);`n        }`n`n        prevRmbDown = rmbDown;"

# ================================================================
# 6. S2-03: NinjaPlayerData.java (Server Block State + Stamina Sync)
# ================================================================
Write-Host "[6/9] NinjaPlayerData.java (Server Block State)..." -ForegroundColor White
Patch-File "$java\stat\NinjaPlayerData.java" `
"private float modeBuffer = 0f;" `
"private float modeBuffer = 0f;`n    private boolean isBlocking = false;"

Patch-File "$java\stat\NinjaPlayerData.java" `
"public void setModeBuffer(float v) { this.modeBuffer = Math.max(0, v); }" `
"public void setModeBuffer(float v) { this.modeBuffer = Math.max(0, v); }`n    public boolean isBlocking() { return isBlocking; }`n    public void setBlocking(boolean v) { this.isBlocking = v; }"

# ================================================================
# 7. S2-03: ModPackets.java (Block Packet ID + Server Receiver)
# ================================================================
Write-Host "[7/9] ModPackets.java (Block Network)..." -ForegroundColor White
Patch-File "$java\network\ModPackets.java" `
"public static final Identifier PREDICTION_CORRECTION_ID = new Identifier(""shinobicore"", ""prediction_correction"");" `
"public static final Identifier PREDICTION_CORRECTION_ID = new Identifier(""shinobicore"", ""prediction_correction"");`n    public static final Identifier BLOCK_STATE_ID = new Identifier(""shinobicore"", ""block_state"");"

Patch-File "$java\network\ModPackets.java" `
"S06NetworkLayer.register(); // S0-06" `
"S06NetworkLayer.register(); // S0-06`n`n        // === S2-03: Block State Receiver ===`n        net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.registerGlobalReceiver(BLOCK_STATE_ID, (server, player, handler, buf, responseSender) -> {`n            boolean blocking = buf.readBoolean();`n            server.execute(() -> {`n                com.example.shinobicore.stat.NinjaPlayerData data = ((com.example.shinobicore.stat.NinjaDataHolder)player).shinobicore_getData();`n                if (blocking && data.getCurrentStamina() <= 0) return; // Cannot block with 0 stamina`n                data.setBlocking(blocking);`n            });`n        });"

# ================================================================
# 8. S2-03: LivingEntityBlockMixin.java (Damage Reduction)
# ================================================================
Write-Host "[8/9] LivingEntityBlockMixin.java (Damage Interception)..." -ForegroundColor White
$mixinContent = @'
package com.example.shinobicore.mixin;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyArg;

@Mixin(LivingEntity.class)
public abstract class LivingEntityBlockMixin {
    @ModifyArg(method = "damage", at = @At(value = "INVOKE", target = "Lnet/minecraft/entity/LivingEntity;applyDamage(Lnet/minecraft/entity/damage/DamageSource;F)V"), index = 1)
    private float shinobicore_modifyBlockDamage(DamageSource source, float amount) {
        LivingEntity self = (LivingEntity)(Object)this;
        if (self instanceof ServerPlayerEntity player) {
            NinjaPlayerData data = ((NinjaDataHolder)player).shinobicore_getData();
            if (data.isBlocking() && amount > 0 && !source.isSourceCreativePlayer()) {
                float blockEfficiency = 0.6f; // 60% damage reduction
                float staminaCost = amount * 5.0f; // 5 stamina per 1 HP blocked
                if (data.getCurrentStamina() >= staminaCost) {
                    data.setCurrentStamina(data.getCurrentStamina() - staminaCost);
                    ShinobiCore.sendChakraSync(player);
                    return amount * (1.0f - blockEfficiency);
                } else {
                    // Guard break: stamina depleted
                    data.setBlocking(false);
                    ShinobiCore.sendChakraSync(player);
                }
            }
        }
        return amount;
    }
}
'@
Write-File "$java\mixin\LivingEntityBlockMixin.java" $mixinContent

# ================================================================
# 9. S2-03: shinobicore.mixins.json (Register Mixin)
# ================================================================
Write-Host "[9/9] shinobicore.mixins.json (Register Mixin)..." -ForegroundColor White
Patch-File "$res\shinobicore.mixins.json" `
"    ""MobEntityAccessor""" `
"    ""MobEntityAccessor"",`n    ""LivingEntityBlockMixin"""

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  SPRINT 2 (S2-01, S2-02, S2-03) COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Implemented:" -ForegroundColor White
Write-Host "    [S2-01] Movement caps (Speed 1.3/1.6, Jump 1.8/1.4) in ModConfig & NinjaFormula" -ForegroundColor White
Write-Host "    [S2-02] Control attribute now dampens inertia when stopping" -ForegroundColor White
Write-Host "    [S2-03] Block mechanic (RMB with empty hand/katana) reducing damage by 60%" -ForegroundColor White
Write-Host "    [S2-03] Block consumes stamina, guard breaks when stamina hits 0" -ForegroundColor White
Write-Host ""
if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}
Write-Host "  Next step: .\gradlew.bat build" -ForegroundColor Yellow
exit 0