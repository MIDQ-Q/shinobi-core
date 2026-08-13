$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
$logFile = "E:\Games\mod\katana_diag2.txt"
$lines = New-Object System.Collections.ArrayList

function Add($s) { [void]$lines.Add($s); Write-Host $s }

Add "=== DIAGNOSTICS ==="
Add ""

# 1. TaijutsuKickHandler
Add "=== TaijutsuKickHandler.java ==="
$kick = "$src\client\combat\TaijutsuKickHandler.java"
if (Test-Path $kick) {
    $c = [System.IO.File]::ReadAllText($kick, $utf8)
    if ($c.Contains("boolean hasKatana")) {
        Add "[OK] Katana check present"
    } else {
        Add "[FAIL] Katana check MISSING"
    }
} else {
    Add "[FAIL] File not found"
}
Add ""

# 2. ClientInputHandler
Add "=== ClientInputHandler.java ==="
$input = "$src\client\ClientInputHandler.java"
if (Test-Path $input) {
    $c = [System.IO.File]::ReadAllText($input, $utf8)
    if ($c.Contains("KeyBindings.KICK.wasPressed()")) {
        Add "[OK] KICK handler present"
        if ($c.Contains("hasKatana")) {
            Add "[OK] Katana branch in KICK"
        } else {
            Add "[FAIL] Katana branch MISSING in KICK"
        }
    } else {
        Add "[FAIL] KICK handler MISSING"
    }
} else {
    Add "[FAIL] File not found"
}
Add ""

# 3. KatanaDeflectMixin
Add "=== KatanaDeflectMixin.java ==="
$deflect = "$src\mixin\KatanaDeflectMixin.java"
if (Test-Path $deflect) {
    $c = [System.IO.File]::ReadAllText($deflect, $utf8)
    if ($c.Contains("isSeiganShield")) {
        Add "[OK] Seigan 360 logic present"
    } else {
        Add "[FAIL] Seigan 360 logic MISSING"
    }
} else {
    Add "[FAIL] File not found"
}
Add ""

# 4. NinjaTickHandler
Add "=== NinjaTickHandler.java ==="
$tick = "$src\event\NinjaTickHandler.java"
if (Test-Path $tick) {
    $c = [System.IO.File]::ReadAllText($tick, $utf8)
    if ($c.Contains("seiganShield")) {
        Add "[OK] Seigan slow logic present"
    } else {
        Add "[FAIL] Seigan slow logic MISSING"
    }
} else {
    Add "[FAIL] File not found"
}
Add ""

# Сохраняем
[System.IO.File]::WriteAllLines($logFile, $lines.ToArray(), $utf8)
Write-Host "`nDiagnostics saved to $logFile" -ForegroundColor Cyan

# === ПРИМЕНЯЕМ НЕДОСТАЮЩИЕ ПАТЧИ ===

# 1. TaijutsuKickHandler: разрешаем пинок с катаной
$kickFile = "$src\client\combat\TaijutsuKickHandler.java"
$kickCode = @'
package com.example.shinobicore.client.combat;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Hand;
public class TaijutsuKickHandler {
    private static long kickCooldownEnd = 0;
    public static final long KICK_COOLDOWN_MS = 500;
    public static boolean tryKick(ClientPlayerEntity player) {
        ShinobiCore.LOGGER.debug("[KICK] tryKick called");
        boolean handEmpty = player.getMainHandStack().isEmpty();
        boolean hasKatana = player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
        if (!handEmpty && !hasKatana) {
            ShinobiCore.LOGGER.debug("[KICK] Hand has non-katana item, aborting");
            return false;
        }
        long now = System.currentTimeMillis();
        long remaining = kickCooldownEnd - now;
        if (now < kickCooldownEnd) {
            ShinobiCore.LOGGER.debug("[KICK] On cooldown, {}ms remaining", remaining);
            return false;
        }
        TaijutsuStyle style = TaijutsuClientHandler.getCurrentStyle();
        boolean chakraMode = ClientNinjaState.chakraMode;
        int taijutsuLevel = ClientNinjaState.statLevels.getOrDefault("taijutsu", 0);
        ShinobiCore.LOGGER.debug("[KICK] Performing kick: style={}, chakra={}, level={}",
                style.getId(), chakraMode, taijutsuLevel);
        ShinobiCore.LOGGER.debug("[KICK] Sending packet to server");
        sendKickPacket(style);
        ShinobiCore.LOGGER.debug("[KICK] Playing animation");
        TaijutsuAnimations.playKickAnimation(player, style);
        ShinobiCore.LOGGER.debug("[KICK] Playing particles");
        TaijutsuParticleEffects.playKickParticles(player, style);
        ShinobiCore.LOGGER.debug("[KICK] Swinging hand");
        player.swingHand(Hand.MAIN_HAND);
        TaijutsuSounds.playKickSound();
        TaijutsuSounds.playWhoosh();
        kickCooldownEnd = now + KICK_COOLDOWN_MS;
        ShinobiCore.LOGGER.debug("[KICK] Cooldown set until {}", kickCooldownEnd);
        ShinobiCore.LOGGER.debug("[KICK] SUCCESS");
        return true;
    }
    private static void sendKickPacket(TaijutsuStyle style) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(style.getId());
        ClientPlayNetworking.send(ModPackets.TAIJUTSU_KICK_ID, buf);
    }
    public static long getCooldownRemainingMs() {
        long now = System.currentTimeMillis();
        return Math.max(0, kickCooldownEnd - now);
    }
    public static float getCooldownRatio() {
        return getCooldownRemainingMs() / (float) KICK_COOLDOWN_MS;
    }
    public static boolean isOnCooldown() {
        return System.currentTimeMillis() < kickCooldownEnd;
    }
}
'@
[System.IO.File]::WriteAllText($kickFile, $kickCode, $utf8)
Write-Host "[FIX] TaijutsuKickHandler: allows kick with katana" -ForegroundColor Green

# 2. KatanaDeflectMixin: 360° для Seigan
$deflectFile = "$src\mixin\KatanaDeflectMixin.java"
$deflectCode = @'
package com.example.shinobicore.mixin;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.projectile.PersistentProjectileEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
@Mixin(LivingEntity.class)
public abstract class KatanaDeflectMixin {
    @Inject(method = "damage", at = @At("HEAD"), cancellable = true)
    private void shinobicore_katanaDeflect(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (!(self instanceof ServerPlayerEntity player)) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (data == null) return;
        long now = System.currentTimeMillis();
        KenjutsuStance stance = KenjutsuStance.fromId(data.getKatanaStanceId());
        boolean tapActive = now < data.getKatanaDeflectUntil();
        boolean holdActive = data.isKatanaDeflectHeld() && stance.canDeflect();
        if (!tapActive && !holdActive) return;
        if (now - data.getLastDeflectReflectMs() < 200) return;
        Entity projectile = source.getSource();
        if (projectile == null) return;
        if (projectile instanceof ServerPlayerEntity) return;
        boolean isSeiganShield = holdActive && stance == KenjutsuStance.SEIGAN;
        if (!isSeiganShield) {
            Vec3d toProj = projectile.getPos().subtract(player.getPos());
            Vec3d look = player.getRotationVector();
            Vec3d lookFlat = new Vec3d(look.x, 0, look.z);
            if (lookFlat.lengthSquared() > 0.001 && toProj.lengthSquared() > 0.001) {
                double dot = lookFlat.normalize().dotProduct(new Vec3d(toProj.x, 0, toProj.z).normalize());
                if (dot < -0.2) return;
            }
        }
        LivingEntity shooter = null;
        boolean reflected = false;
        if (projectile instanceof PersistentProjectileEntity proj) {
            Entity owner = proj.getOwner();
            if (owner == player) return;
            if (owner instanceof LivingEntity l) shooter = l;
            proj.setVelocity(proj.getVelocity().multiply(-1.3));
            proj.setOwner(player);
            proj.velocityDirty = true;
            reflected = true;
        }
        if (!reflected) return;
        data.setLastDeflectReflectMs(now);
        player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);
        if (player.getWorld() instanceof ServerWorld sw) {
            sw.spawnParticles(ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(), 12, 0.4, 0.4, 0.4, 0.05);
        }
        if (shooter != null) {
            shooter.damage(player.getDamageSources().playerAttack(player), 4f);
        }
        player.sendMessage(Text.literal("§eDEFLECTED!"), false);
        cir.setReturnValue(false);
    }
}
'@
[System.IO.File]::WriteAllText($deflectFile, $deflectCode, $utf8)
Write-Host "[FIX] KatanaDeflectMixin: 360° Seigan shield" -ForegroundColor Green

Write-Host "`nRun: .\gradlew.bat build" -ForegroundColor Cyan