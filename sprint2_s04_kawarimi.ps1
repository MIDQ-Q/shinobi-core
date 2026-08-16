# ============================================================
#  SPRINT 2 / S2-04, S2-05, S2-06: KAWARIMI (SUBSTITUTION)
#  Implements the defensive timing mechanic, visual log, and balance
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint2_s04_kawarimi.ps1
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
Write-Host "  SPRINT 2 / S2-04,05,06: KAWARIMI IMPLEMENTATION" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. ModConfig.java - Add Kawarimi balance parameters
# ================================================================
Write-Host "[1/9] ModConfig.java (Kawarimi config)..." -ForegroundColor White
Patch-File "$java\config\ModConfig.java" `
"public Stamina stamina = new Stamina();" `
"public Stamina stamina = new Stamina();`n    public Kawarimi kawarimi = new Kawarimi();`n`n    public static class Kawarimi {`n        public float windowDuration = 3.0f;`n        public float cooldown = 15.0f;`n        public float lethalCooldown = 60.0f;`n        public float chakraCost = 50.0f;`n        public float staminaCost = 30.0f;`n    }"

# ================================================================
# 2. NinjaPlayerData.java - Add state tracking fields
# ================================================================
Write-Host "[2/9] NinjaPlayerData.java (Kawarimi state)..." -ForegroundColor White
$kawarimiFields = @"

    // === S2-04: Kawarimi State ===
    private long kawarimiWindowEndMs = 0;
    private long kawarimiCooldownEndMs = 0;

    public boolean isKawarimiWindowActive() { return System.currentTimeMillis() < kawarimiWindowEndMs; }
    public void setKawarimiWindow(long durationMs) { this.kawarimiWindowEndMs = System.currentTimeMillis() + durationMs; }
    public boolean isKawarimiOnCooldown() { return System.currentTimeMillis() < kawarimiCooldownEndMs; }
    public void setKawarimiCooldown(long durationMs) { this.kawarimiCooldownEndMs = System.currentTimeMillis() + durationMs; }
"@
# Inject before the last closing brace of the class
Patch-File "$java\stat\NinjaPlayerData.java" `
"public void setMeditating(boolean v) { this.meditating = v; }" `
"public void setMeditating(boolean v) { this.meditating = v; }$kawarimiFields"

# ================================================================
# 3. KeyBindings.java - Add Kawarimi Keybind (Q)
# ================================================================
Write-Host "[3/9] KeyBindings.java..." -ForegroundColor White
Patch-File "$java\client\KeyBindings.java" `
"public static KeyBinding DODGE_RIGHT;" `
"public static KeyBinding DODGE_RIGHT;`n    public static KeyBinding KAWARIMI;"
Patch-File "$java\client\KeyBindings.java" `
"DODGE_RIGHT = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.dodge_right"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_C, CATEGORY));" `
"DODGE_RIGHT = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.dodge_right"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_C, CATEGORY));`n        KAWARIMI = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.kawarimi"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Q, CATEGORY));"

# ================================================================
# 4. Lang files - Add translations
# ================================================================
Write-Host "[4/9] Lang files..." -ForegroundColor White
Patch-File "$res\assets\shinobicore\lang\en_us.json" `
"""key.shinobicore.dodge_right"": ""Dodge Right (C)""," `
"""key.shinobicore.dodge_right"": ""Dodge Right (C)"",`n  ""key.shinobicore.kawarimi"": ""Kawarimi (Q)"","
Patch-File "$res\assets\shinobicore\lang\ru_ru.json" `
"""key.shinobicore.dodge_right"": ""Уворот вправо (C)""," `
"""key.shinobicore.dodge_right"": ""Уворот вправо (C)"",`n  ""key.shinobicore.kawarimi"": ""Каварами (Q)"","

# ================================================================
# 5. ClientInputHandler.java - Send Kawarimi Packet
# ================================================================
Write-Host "[5/9] ClientInputHandler.java..." -ForegroundColor White
Patch-File "$java\client\ClientInputHandler.java" `
"if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info(""[INPUT] CRAWL (N) pressed"");" `
"if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info(""[INPUT] CRAWL (N) pressed"");`n        if (KeyBindings.KAWARIMI.wasPressed()) {`n            net.minecraft.network.PacketByteBuf buf = new net.minecraft.network.PacketByteBuf(io.netty.buffer.Unpooled.buffer());`n            net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking.send(com.example.shinobicore.network.S06NetworkLayer.KAWARIMI_ID, buf);`n        }"

# ================================================================
# 6. KawarimiDamageMixin.java - Intercept Damage & Substitute
# ================================================================
Write-Host "[6/9] KawarimiDamageMixin.java..." -ForegroundColor White
$mixinContent = @'
package com.example.shinobicore.mixin;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.network.S06NetworkLayer;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import net.minecraft.block.Blocks;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.EquipmentSlot;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.decoration.ArmorStandEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(LivingEntity.class)
public abstract class KawarimiDamageMixin {

    @Inject(method = "damage", at = @At("HEAD"), cancellable = true)
    private void shinobicore_kawarimiIntercept(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (!(self instanceof ServerPlayerEntity player)) return;
        if (self.getWorld().isClient) return;

        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (!data.isKawarimiWindowActive()) return;

        // Cancel the damage
        cir.setReturnValue(false);

        Vec3d originalPos = player.getPos();
        boolean wasLethal = amount >= player.getHealth();

        // Find safe spot
        Vec3d safePos = findSafeSpot(player.getWorld(), originalPos);
        if (safePos != null) {
            player.teleport(safePos.x, safePos.y, safePos.z);
        } else {
            player.teleport(originalPos.x + 3, originalPos.y, originalPos.z);
        }
        
        player.setVelocity(0, 0, 0);
        player.velocityModified = true;
        player.fallDistance = 0f;

        // Clear window and apply cooldown
        data.setKawarimiWindow(0);
        float cd = wasLethal ? ModConfig.instance.kawarimi.lethalCooldown : ModConfig.instance.kawarimi.cooldown;
        data.setKawarimiCooldown((long)(cd * 1000));

        // VFX and Sound at original position
        ServerWorld sw = (ServerWorld) player.getWorld();
        sw.playSound(null, originalPos.x, originalPos.y, originalPos.z,
            SoundEvents.ENTITY_GENERIC_EXTINGUISH_FIRE, SoundCategory.PLAYERS, 2.0f, 1.0f);
        sw.playSound(null, originalPos.x, originalPos.y, originalPos.z,
            SoundEvents.BLOCK_WOOD_BREAK, SoundCategory.PLAYERS, 1.5f, 0.8f);

        sw.spawnParticles(ParticleTypes.LARGE_SMOKE, originalPos.x, originalPos.y + 1, originalPos.z, 30, 0.5, 0.5, 0.5, 0.1);
        sw.spawnParticles(ParticleTypes.CLOUD, originalPos.x, originalPos.y + 1, originalPos.z, 20, 0.5, 0.5, 0.5, 0.1);

        spawnKawarimiLog(sw, originalPos);

        // Broadcast FX to clients
        S06NetworkLayer.broadcastKawarimiFx(player, originalPos.x, originalPos.y, originalPos.z);

        ShinobiCore.sendChakraSync(player);
    }

    private Vec3d findSafeSpot(World world, Vec3d origin) {
        for (int i = 0; i < 15; i++) {
            double angle = Math.random() * Math.PI * 2;
            double dist = 2.5 + Math.random() * 3.5;
            double dx = Math.cos(angle) * dist;
            double dz = Math.sin(angle) * dist;
            BlockHitResult hit = world.raycast(new RaycastContext(
                origin.add(dx, 2, dz), origin.add(dx, -5, dz),
                RaycastContext.ShapeType.COLLIDER, RaycastContext.FluidHandling.NONE, null));
            if (hit.getType() == HitResult.Type.BLOCK) {
                BlockPos ground = hit.getBlockPos().up();
                if (world.isAir(ground) && world.isAir(ground.up())) {
                    return new Vec3d(ground.getX() + 0.5, ground.getY(), ground.getZ() + 0.5);
                }
            }
        }
        return null;
    }

    private void spawnKawarimiLog(ServerWorld world, Vec3d pos) {
        ArmorStandEntity stand = EntityType.ARMOR_STAND.create(world);
        if (stand != null) {
            stand.setPosition(pos.x, pos.y, pos.z);
            stand.setInvisible(true);
            stand.setNoGravity(true);
            stand.setSilent(true);
            stand.setInvulnerable(true);
            stand.equipStack(EquipmentSlot.HEAD, new ItemStack(Blocks.STRIPPED_OAK_LOG));
            stand.setHideBasePlate(true);
            stand.setShowArms(false);
            world.spawnEntity(stand);
            TickScheduler.schedule(world, 40, 40, 1, w -> {
                if (!stand.isRemoved()) stand.discard();
            });
        }
    }
}
'@
Write-File "$java\mixin\KawarimiDamageMixin.java" $mixinContent

# ================================================================
# 7. shinobicore.mixins.json - Register Mixin
# ================================================================
Write-Host "[7/9] shinobicore.mixins.json..." -ForegroundColor White
Patch-File "$res\shinobicore.mixins.json" `
"""MobEntityAccessor""" `
"""MobEntityAccessor",`n        "KawarimiDamageMixin"""

# ================================================================
# 8. S06NetworkLayer.java - Server Receiver Logic
# ================================================================
Write-Host "[8/9] S06NetworkLayer.java (Server logic)..." -ForegroundColor White
$serverLogicOld = @"
server.execute(() -> {
                NetworkDebugLogger.logPacket("kawarimi", "C2S",
                        player.getName().getString());
                // TODO S2-04: Implement kawarimi window logic
                // 1. Check cooldown
                // 2. Open 3-second window
                // 3. If damage received during window -> substitute
            });
"@
$serverLogicNew = @"
server.execute(() -> {
                NetworkDebugLogger.logPacket("kawarimi", "C2S", player.getName().getString());
                NinjaPlayerData data = ((com.example.shinobicore.stat.NinjaDataHolder) player).shinobicore_getData();
                com.example.shinobicore.config.ModConfig.Kawarimi cfg = com.example.shinobicore.config.ModConfig.instance.kawarimi;

                if (data.isKawarimiOnCooldown() || data.isKawarimiWindowActive()) return;
                if (data.getCurrentChakra() < cfg.chakraCost || data.getCurrentStamina() < cfg.staminaCost) return;
                
                // S2-06: Penalty for being restrained
                if (player.hasStatusEffect(net.minecraft.entity.effect.StatusEffects.SLOWNESS) || 
                    player.hasStatusEffect(net.minecraft.entity.effect.StatusEffects.WEAKNESS)) {
                    player.sendMessage(net.minecraft.text.Text.literal("\u00a7cCannot use Kawarimi while restrained!"), true);
                    return;
                }

                data.setCurrentChakra(data.getCurrentChakra() - cfg.chakraCost);
                data.setCurrentStamina(data.getCurrentStamina() - cfg.staminaCost);
                data.setKawarimiWindow((long)(cfg.windowDuration * 1000));
                com.example.shinobicore.ShinobiCore.sendChakraSync(player);
                
                player.getWorld().playSound(null, player.getBlockPos(), net.minecraft.sound.SoundEvents.ENTITY_ENDERMAN_TELEPORT, net.minecraft.sound.SoundCategory.PLAYERS, 0.8f, 1.5f);
            });
"@
Patch-File "$java\network\S06NetworkLayer.java" $serverLogicOld $serverLogicNew

# ================================================================
# 9. ShinobiCoreClient.java - Client VFX Receiver
# ================================================================
Write-Host "[9/9] ShinobiCoreClient.java (Client VFX)..." -ForegroundColor White
$clientLogicOld = @"
client.execute(() -> {
                NetworkDebugLogger.logPacket("kawarimi_fx", "S2C",
                        client.player != null ? client.player.getName().getString() : "?");
                // TODO S2-05: Spawn smoke + log at position
            });
"@
$clientLogicNew = @"
client.execute(() -> {
                NetworkDebugLogger.logPacket("kawarimi_fx", "S2C",
                        client.player != null ? client.player.getName().getString() : "?");
                if (client.world != null) {
                    client.world.playSound(x, y, z, net.minecraft.sound.SoundEvents.ENTITY_GENERIC_EXTINGUISH_FIRE, net.minecraft.sound.SoundCategory.PLAYERS, 2.0f, 1.0f, false);
                    client.world.playSound(x, y, z, net.minecraft.sound.SoundEvents.BLOCK_WOOD_BREAK, net.minecraft.sound.SoundCategory.PLAYERS, 1.5f, 0.8f, false);
                    for(int i=0; i<30; i++) {
                        client.world.addParticle(net.minecraft.particle.ParticleTypes.LARGE_SMOKE, x + (Math.random()-0.5)*0.5, y + 1 + Math.random()*0.5, z + (Math.random()-0.5)*0.5, 0, 0.1, 0);
                        client.world.addParticle(net.minecraft.particle.ParticleTypes.CLOUD, x + (Math.random()-0.5)*0.5, y + 1 + Math.random()*0.5, z + (Math.random()-0.5)*0.5, 0, 0.1, 0);
                    }
                }
            });
"@
Patch-File "$java\client\ShinobiCoreClient.java" $clientLogicOld $clientLogicNew

# ================================================================
# SUMMARY & EXIT CODE
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S2-04, S2-05, S2-06 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Implemented:" -ForegroundColor White
Write-Host "    - S2-04: 3s active window, server-side damage interception, safe teleport" -ForegroundColor White
Write-Host "    - S2-05: Smoke particles, wood break sound, temporary ArmorStand log" -ForegroundColor White
Write-Host "    - S2-06: Chakra/Stamina costs, normal/lethal cooldowns, CC penalty" -ForegroundColor White
Write-Host ""
if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0