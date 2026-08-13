$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
$res = "E:\Games\mod\src\main\resources"
Write-Host "=== FIX DEFLECT ===" -ForegroundColor Cyan

# === [1] ShurikenEntity: метод reflect() ===
$file = "$src\entity\ShurikenEntity.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("public void reflect")) {
    $marker = "public Entity getOwner() {"
    $insert = @'
public void reflect(ServerPlayerEntity newOwner) {
        this.ownerId = newOwner.getUuid();
        Vec3d v = this.getVelocity();
        this.setVelocity(v.multiply(-1.3));
        this.velocityDirty = true;
    }

    public Entity getOwner() {
'@
    $c = $c.Replace($marker, $insert)
    if (-not $c.Contains("import net.minecraft.server.network.ServerPlayerEntity;")) {
        $c = $c.Replace("import net.minecraft.server.world.ServerWorld;",
            "import net.minecraft.server.world.ServerWorld;
import net.minecraft.server.network.ServerPlayerEntity;")
    }
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] ShurikenEntity: reflect() added" -ForegroundColor Green
}

# === [2] NinjaProjectileEntity: метод reflect() ===
$file = "$src\entity\NinjaProjectileEntity.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("public void reflect")) {
    $marker = "public void setBounceCount"
    $insert = @'
public void reflect(ServerPlayerEntity newOwner) {
        this.ownerId = newOwner.getUuid();
        Vec3d v = this.getVelocity();
        this.setVelocity(v.multiply(-1.3));
        this.velocityDirty = true;
    }

    public void setBounceCount
'@
    $c = $c.Replace($marker, $insert)
    if (-not $c.Contains("import net.minecraft.server.network.ServerPlayerEntity;")) {
        $c = $c.Replace("import net.minecraft.server.world.ServerWorld;",
            "import net.minecraft.server.world.ServerWorld;
import net.minecraft.server.network.ServerPlayerEntity;")
    }
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] NinjaProjectileEntity: reflect() added" -ForegroundColor Green
}

# === [3] KatanaDeflectMixin: переписываем для ВСЕХ снарядов ===
$file = "$src\mixin\KatanaDeflectMixin.java"
$code = @'
package com.example.shinobicore.mixin;

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
        if (System.currentTimeMillis() >= data.getKatanaDeflectUntil()) return;

        Entity projectile = source.getSource();
        if (projectile == null) return;
        if (projectile instanceof ServerPlayerEntity) return;

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

        player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);
        if (player.getWorld() instanceof ServerWorld sw) {
            sw.spawnParticles(ParticleTypes.CRIT,
                    player.getX(), player.getY() + 1, player.getZ(),
                    12, 0.4, 0.4, 0.4, 0.05);
        }
        if (shooter != null) {
            shooter.damage(player.getDamageSources().playerAttack(player), 4f);
        }
        player.sendMessage(Text.literal("\u00a7eDEFLECTED!"), false);
        cir.setReturnValue(false);
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[OK] KatanaDeflectMixin: rewritten for all projectiles" -ForegroundColor Green

# === [4] mixins.json: регистрация ===
$file = "$res\shinobicore.mixins.json"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("KatanaDeflectMixin")) {
    $c = $c.Replace('"CameraMixin"', '"CameraMixin",
    "KatanaDeflectMixin"')
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] mixins.json: KatanaDeflectMixin registered" -ForegroundColor Green
}

# === [5] NinjaProjectileEntity: публичный getOwner() ===
$file = "$src\entity\NinjaProjectileEntity.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("public Entity getOwner()")) {
    $marker = "private UUID ownerId;"
    $insert = @'
private UUID ownerId;
    public Entity getOwner() {
        if (ownerId == null) return null;
        if (this.getWorld() instanceof ServerWorld sw) return sw.getPlayerByUuid(ownerId);
        return null;
    }
'@
    $c = $c.Replace($marker, $insert)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] NinjaProjectileEntity: public getOwner()" -ForegroundColor Green
}

Write-Host "`nRun: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Yellow