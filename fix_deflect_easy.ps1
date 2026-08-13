$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
Write-Host "=== DEFLECT: HOLD MODE ===" -ForegroundColor Cyan

# === [1] NinjaPlayerData: held + reflect cooldown ===
$file = "$src\stat\NinjaPlayerData.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace('private long katanaDeflectUntil = 0;', @'
private long katanaDeflectUntil = 0;
    private boolean katanaDeflectHeld = false;
    private long lastDeflectReflectMs = 0;
'@)
$c = $c.Replace('public void setKatanaDeflectUntil(long v) { this.katanaDeflectUntil = v; }', @'
public void setKatanaDeflectUntil(long v) { this.katanaDeflectUntil = v; }
    public boolean isKatanaDeflectHeld() { return katanaDeflectHeld; }
    public void setKatanaDeflectHeld(boolean v) { this.katanaDeflectHeld = v; }
    public long getLastDeflectReflectMs() { return lastDeflectReflectMs; }
    public void setLastDeflectReflectMs(long v) { this.lastDeflectReflectMs = v; }
'@)
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] NinjaPlayerData: deflect held fields" -ForegroundColor Green

# === [2] ModPackets: hold-пакет + запрет атаки при щите ===
$file = "$src\network\ModPackets.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$old = @'
        ServerPlayNetworking.registerGlobalReceiver(KATANA_DEFLECT_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (KenjutsuStance.fromId(data.getKatanaStanceId()).canDeflect()) {
                    data.setKatanaDeflectUntil(System.currentTimeMillis() + 300);
                }
            });
        });
'@
$new = @'
        ServerPlayNetworking.registerGlobalReceiver(KATANA_DEFLECT_ID, (server, player, handler, buf, responseSender) -> {
            boolean held = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                boolean can = KenjutsuStance.fromId(data.getKatanaStanceId()).canDeflect();
                data.setKatanaDeflectHeld(held && can);
                if (held && can) {
                    data.setKatanaDeflectUntil(System.currentTimeMillis() + 500);
                }
            });
        });
'@
$c = $c.Replace($old, $new)
$c = $c.Replace('if (step != data.getKatanaComboStep()) return;', @'
if (data.isKatanaDeflectHeld()) return;
                if (step != data.getKatanaComboStep()) return;
'@)
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] ModPackets: hold packet + no attack while shielding" -ForegroundColor Green

# === [3] KenjutsuClientHandler: tryDeflect -> setDeflectHeld ===
$file = "$src\client\combat\KenjutsuClientHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$m = [regex]::Match($c, "(?s)public static void tryDeflect\(ClientPlayerEntity player\) \{.*?\n    \}")
if ($m.Success) {
    $newMethod = @'
public static void setDeflectHeld(ClientPlayerEntity player, boolean held) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(held);
        ClientPlayNetworking.send(ModPackets.KATANA_DEFLECT_ID, buf);
        ClientNinjaState.deflectHeld = held;
        if (held) {
            KenjutsuAnimations.playDeflect(player);
            player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 0.4f, 1.5f);
        }
    }
'@
    $c = $c.Substring(0, $m.Index) + $newMethod + $c.Substring($m.Index + $m.Length)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] KenjutsuClientHandler: setDeflectHeld" -ForegroundColor Green
} else {
    Write-Host "[SKIP] tryDeflect not found" -ForegroundColor Red
}

# === [4] ClientNinjaState: deflectHeld ===
$file = "$src\client\ClientNinjaState.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace('public static String kenjutsuStance = "aggressive";', @'
public static String kenjutsuStance = "aggressive";
    public static boolean deflectHeld = false;
'@)
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] ClientNinjaState: deflectHeld" -ForegroundColor Green

# === [5] ClientInputHandler: hold-X + убрать V-дефлект ===
$file = "$src\client\ClientInputHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace(@'
            if (handEmpty) {
                TaijutsuKickHandler.tryKick(client.player);
            } else if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.tryDeflect(client.player);
            }
'@, @'
            if (handEmpty) {
                TaijutsuKickHandler.tryKick(client.player);
            }
'@)
$c = $c.Replace(@'
        // === ДЕФЛЕКТ КАТАНОЙ (X) ===
        if (KeyBindings.KATANA_DEFLECT.wasPressed()) {
            if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.tryDeflect(client.player);
            }
        }
'@, @'
        // === ДЕФЛЕКТ (X): удержание = щит, тап = парирование 500мс ===
        boolean deflectDown = KeyBindings.KATANA_DEFLECT.isPressed();
        if (deflectDown != prevDeflectDown) {
            prevDeflectDown = deflectDown;
            if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.setDeflectHeld(client.player, deflectDown);
            }
        }
'@)
$c = $c.Replace('private static boolean prevMeditatePressed = false;', @'
private static boolean prevMeditatePressed = false;
    private static boolean prevDeflectDown = false;
'@)
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] ClientInputHandler: hold-X deflect" -ForegroundColor Green

# === [6] KatanaDeflectMixin: hold + фронтальный конус + кулдаун ===
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
        boolean tapActive = now < data.getKatanaDeflectUntil();
        boolean holdActive = data.isKatanaDeflectHeld()
                && KenjutsuStance.fromId(data.getKatanaStanceId()).canDeflect();
        if (!tapActive && !holdActive) return;

        if (now - data.getLastDeflectReflectMs() < 200) return;

        Entity projectile = source.getSource();
        if (projectile == null) return;
        if (projectile instanceof ServerPlayerEntity) return;

        Vec3d toProj = projectile.getPos().subtract(player.getPos());
        Vec3d look = player.getRotationVector();
        Vec3d lookFlat = new Vec3d(look.x, 0, look.z);
        if (lookFlat.lengthSquared() > 0.001 && toProj.lengthSquared() > 0.001) {
            double dot = lookFlat.normalize().dotProduct(new Vec3d(toProj.x, 0, toProj.z).normalize());
            if (dot < -0.2) return;
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
Write-Host "[OK] KatanaDeflectMixin: hold + front cone + cooldown" -ForegroundColor Green

# === [7] PlayerRenderAnimationMixin: поза щита пока держишь X ===
$file = "$src\mixin\PlayerRenderAnimationMixin.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace('if (KenjutsuAnimations.isDeflecting(player)) {',
    'if (KenjutsuAnimations.isDeflecting(player) || ClientNinjaState.deflectHeld) {')
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] Mixin: shield pose while holding X" -ForegroundColor Green

Write-Host "`nRun: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Yellow