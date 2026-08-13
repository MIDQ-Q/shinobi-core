$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
Write-Host "=== KATANA V2: AGGRESSIVE DEFLECT + SEIGAN SHIELD ===" -ForegroundColor Cyan

# === [1] KenjutsuStance: Aggressive canDeflect + Seigan shieldSlow ===
$file = "$src\combat\KenjutsuStance.java"
$code = @'
package com.example.shinobicore.combat;
public enum KenjutsuStance {
    AGGRESSIVE("aggressive", 1.15f, 1.15f, true, 1.0f),
    SEIGAN("seigan", 0.85f, 1.0f, true, 0.5f),
    IAI("iai", 1.0f, 0.9f, false, 1.0f);
    private final String id;
    private final float damageMult;
    private final float speedMult;
    private final boolean canDeflect;
    private final float shieldSlow;
    KenjutsuStance(String id, float damageMult, float speedMult, boolean canDeflect, float shieldSlow) {
        this.id = id; this.damageMult = damageMult; this.speedMult = speedMult;
        this.canDeflect = canDeflect; this.shieldSlow = shieldSlow;
    }
    public String getId() { return id; }
    public float getDamageMult() { return damageMult; }
    public float getSpeedMult() { return speedMult; }
    public boolean canDeflect() { return canDeflect; }
    public float getShieldSlow() { return shieldSlow; }
    public static KenjutsuStance fromId(String id) {
        for (KenjutsuStance s : values()) if (s.id.equals(id)) return s;
        return AGGRESSIVE;
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[OK] KenjutsuStance: aggressive canDeflect + seigan shieldSlow" -ForegroundColor Green

# === [2] KatanaDeflectMixin: Aggressive 650ms + Seigan 360 shield ===
$file = "$src\mixin\KatanaDeflectMixin.java"
$code = @'
package com.example.shinobicore.mixin;

import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.entity.ShurikenEntity;
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

        // === SEIGAN HOLD: 360° защита (без проверки фронта) ===
        boolean isSeiganShield = holdActive && stance == KenjutsuStance.SEIGAN;
        if (!isSeiganShield) {
            // === AGGRESSIVE TAP / SEIGAN TAP: только фронт 180° ===
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
        } else if (projectile instanceof ShurikenEntity sh) {
            Entity owner = sh.getOwner();
            if (owner == player) return;
            if (owner instanceof LivingEntity l) shooter = l;
            sh.reflect(player);
            reflected = true;
        } else if (projectile instanceof NinjaProjectileEntity np) {
            Entity owner = np.getOwner();
            if (owner == player) return;
            if (owner instanceof LivingEntity l) shooter = l;
            np.reflect(player);
            reflected = true;
        }

        if (!reflected) return;

        data.setLastDeflectReflectMs(now);
        player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);
        if (player.getWorld() instanceof ServerWorld sw) {
            sw.spawnParticles(ParticleTypes.CRIT,
                    player.getX(), player.getY() + 1, player.getZ(),
                    12, 0.4, 0.4, 0.4, 0.05);
        }
        if (shooter != null) {
            shooter.damage(player.getDamageSources().playerAttack(player), 4f);
        }
        player.sendMessage(Text.literal("§eDEFLECTED!"), false);
        cir.setReturnValue(false);
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[OK] KatanaDeflectMixin: aggressive tap + seigan 360 shield" -ForegroundColor Green

# === [3] ModPackets: Aggressive 650ms окно ===
$file = "$src\network\ModPackets.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace('data.setKatanaDeflectUntil(System.currentTimeMillis() + 500);',
    'long windowMs = stance == KenjutsuStance.SEIGAN ? 500 : 650;
                    data.setKatanaDeflectUntil(System.currentTimeMillis() + windowMs);')
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] ModPackets: aggressive 650ms window" -ForegroundColor Green

# === [4] NinjaTickHandler: Seigan shield slow ===
$file = "$src\event\NinjaTickHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$marker = 'if (data.isChakraMode()) {'
$insert = @'
// === SEIGAN SHIELD SLOW ===
        boolean seiganShield = data.isKatanaDeflectHeld()
                && com.example.shinobicore.combat.KenjutsuStance.fromId(data.getKatanaStanceId()) == com.example.shinobicore.combat.KenjutsuStance.SEIGAN;
        if (seiganShield) {
            player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 5, 2, false, false, false));
        }
        if (data.isChakraMode()) {
'@
$c = $c.Replace($marker, $insert)
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] NinjaTickHandler: seigan shield slow" -ForegroundColor Green

# === [5] TaijutsuKickHandler: пинок с катаной ===
$file = "$src\client\combat\TaijutsuKickHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace('if (!player.getMainHandStack().isEmpty()) {
            ShinobiCore.LOGGER.debug("[KICK] Hand not empty, aborting");
            return false;
        }',
    '// === ПИНОК РАБОТАЕТ С ПУСТОЙ РУКОЙ ИЛИ КАТАНОЙ ===
        boolean handEmpty = player.getMainHandStack().isEmpty();
        boolean hasKatana = player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
        if (!handEmpty && !hasKatana) {
            ShinobiCore.LOGGER.debug("[KICK] Hand has non-katana item, aborting");
            return false;
        }')
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] TaijutsuKickHandler: kick works with katana" -ForegroundColor Green

# === [6] ClientInputHandler: V с катаной вызывает пинок ===
$file = "$src\client\ClientInputHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace(@'
            if (handEmpty) {
                TaijutsuKickHandler.tryKick(client.player);
            }
'@, @'
            boolean handEmpty = client.player.getMainHandStack().isEmpty();
            boolean hasKatana = client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
            if (handEmpty || hasKatana) {
                TaijutsuKickHandler.tryKick(client.player);
            }
'@)
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] ClientInputHandler: V triggers kick with katana" -ForegroundColor Green

Write-Host "`nRun: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Yellow