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
        
        // === РћРўР›РђР”РљРђ: Р»РѕРіРёСЂСѓРµРј СЃРѕСЃС‚РѕСЏРЅРёРµ ===
        Entity projectile = source.getSource();
        if (projectile instanceof PersistentProjectileEntity) {
            ShinobiCore.LOGGER.info("[DEFLECT] Damage tick: stance={}, tapActive={}, holdActive={}, canDeflect={}",
                    stance.getId(), tapActive, holdActive, stance.canDeflect());
        }
        
        if (!tapActive && !holdActive) return;
        // cooldown moved below (shield ignores it)
        
        if (projectile == null) return;
        if (projectile instanceof ServerPlayerEntity) return;
        
        // === РљР›Р®Р§Р•Р’РћР•: Seigan + Hold = 360В° Р·Р°С‰РёС‚Р° (РїРѕР»РЅРѕСЃС‚СЊСЋ РїСЂРѕРїСѓСЃРєР°РµРј РїСЂРѕРІРµСЂРєСѓ С„СЂРѕРЅС‚Р°) ===
        boolean isSeiganShield = holdActive && stance == KenjutsuStance.SEIGAN;
        if (!isSeiganShield && now - data.getLastDeflectReflectMs() < 200) return;
        if (!isSeiganShield && now - data.getLastDeflectReflectMs() < 200) return;
        if (!isSeiganShield && now - data.getLastDeflectReflectMs() < 200) return;
        
        if (!isSeiganShield) {
            // РўРѕР»СЊРєРѕ РґР»СЏ Aggressive tap РёР»Рё Seigan tap РїСЂРѕРІРµСЂСЏРµРј С„СЂРѕРЅС‚ 180В°
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
            ShinobiCore.LOGGER.info("[DEFLECT] Seigan 360В° shield ACTIVE - skipping front check");
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
        player.sendMessage(Text.literal("В§eDEFLECTED!"), false);
        ShinobiCore.LOGGER.info("[DEFLECT] SUCCESS: projectile reflected back to shooter");
        cir.setReturnValue(false);
    }
}