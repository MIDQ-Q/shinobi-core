$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"

# === [1] KatanaDeflectMixin: исправляем логику 360° + отладка ===
$file = "$src\mixin\KatanaDeflectMixin.java"
$code = @'
package com.example.shinobicore.mixin;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.ShinobiCore;
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
        
        // === ОТЛАДКА: логируем состояние ===
        Entity projectile = source.getSource();
        if (projectile instanceof PersistentProjectileEntity) {
            ShinobiCore.LOGGER.info("[DEFLECT] Damage tick: stance={}, tapActive={}, holdActive={}, canDeflect={}",
                    stance.getId(), tapActive, holdActive, stance.canDeflect());
        }
        
        if (!tapActive && !holdActive) return;
        if (now - data.getLastDeflectReflectMs() < 200) return;
        
        if (projectile == null) return;
        if (projectile instanceof ServerPlayerEntity) return;
        
        // === КЛЮЧЕВОЕ: Seigan + Hold = 360° защита (полностью пропускаем проверку фронта) ===
        boolean isSeiganShield = holdActive && stance == KenjutsuStance.SEIGAN;
        
        if (!isSeiganShield) {
            // Только для Aggressive tap или Seigan tap проверяем фронт 180°
            Vec3d toProj = projectile.getPos().subtract(player.getPos());
            Vec3d look = player.getRotationVector();
            Vec3d lookFlat = new Vec3d(look.x, 0, look.z);
            if (lookFlat.lengthSquared() > 0.001 && toProj.lengthSquared() > 0.001) {
                double dot = lookFlat.normalize().dotProduct(new Vec3d(toProj.x, 0, toProj.z).normalize());
                ShinobiCore.LOGGER.info("[DEFLECT] Front check: dot={}, threshold=-0.2", dot);
                if (dot < -0.2) {
                    ShinobiCore.LOGGER.info("[DEFLECT] Rejected: behind player");
                    return;
                }
            }
        } else {
            ShinobiCore.LOGGER.info("[DEFLECT] Seigan 360° shield ACTIVE - skipping front check");
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
            ShinobiCore.LOGGER.info("[DEFLECT] PersistentProjectile reflected!");
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
        ShinobiCore.LOGGER.info("[DEFLECT] SUCCESS: projectile reflected back to shooter");
        cir.setReturnValue(false);
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[OK] KatanaDeflectMixin: 360° logic + debug logging" -ForegroundColor Green

# === [2] NinjaTickHandler: Seigan slow (с отладкой) ===
$file = "$src\event\NinjaTickHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

$marker = @'
            double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
'@
$insert = @'
            // === SEIGAN SHIELD SLOW ===
            boolean seiganShield = data.isKatanaDeflectHeld()
                    && com.example.shinobicore.combat.KenjutsuStance.fromId(data.getKatanaStanceId()) == com.example.shinobicore.combat.KenjutsuStance.SEIGAN;
            if (seiganShield) {
                player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 5, 2, false, false, false));
                if (tickCounter % 20 == 0) {
                    ShinobiCore.LOGGER.info("[SEIGAN] Shield slow applied to {}", player.getName().getString());
                }
            }
            double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
'@

if ($c.Contains($marker)) {
    $c = $c.Replace($marker, $insert)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] NinjaTickHandler: Seigan slow + debug" -ForegroundColor Green
} else {
    Write-Host "[SKIP] NinjaTickHandler marker not found" -ForegroundColor Yellow
}

# === [3] ModItems: добавляем SHURIKEN/KUNAI ===
$file = "$src\item\ModItems.java"
$code = @'
package com.example.shinobicore.item;
import com.example.shinobicore.ShinobiCore;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;
public class ModItems {
    public static final Item KATANA = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana"), new KatanaItem());
    public static final Item SHURIKEN = Registry.register(Registries.ITEM,
            new Identifier(Shinobicore.MOD_ID, "shuriken"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 3f, 3.0f, 8));
    public static final Item KUNAI = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "kunai"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 5f, 2.2f, 12));
    public static void register() {
        ShinobiCore.LOGGER.info("Registered katana/shuriken/kunai items");
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[OK] ModItems: added SHURIKEN/KUNAI" -ForegroundColor Green

Write-Host "`nRun: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Cyan