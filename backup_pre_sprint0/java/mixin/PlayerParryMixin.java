package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.tree.TreePassives;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(LivingEntity.class)
public abstract class PlayerParryMixin {
    @Inject(method = "damage", at = @At("HEAD"), cancellable = true)
    private void shinobicore_autoParry(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (!(self instanceof ServerPlayerEntity player)) return;
        if (amount <= 0) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        TreePassives.Bonuses b = TreePassives.collectServer(data);
        // Sharingan 3 tomoe: 35% auto-parry for melee
        var sharinganData = ((com.example.shinobicore.stat.NinjaDataHolder) self).shinobicore_getData();
        var sharinganComp = sharinganData.getSharinganComponent();
        if (sharinganComp != null && sharinganComp.checkAutoParry(
                (ServerPlayerEntity) self, amount)) {
            if (self.getWorld() instanceof net.minecraft.server.world.ServerWorld sw) {
                sw.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT,
                    self.getX(), self.getY() + 1, self.getZ(),
                    15, 0.4, 0.4, 0.4, 0.08);
            }
            player.sendMessage(net.minecraft.text.Text.literal("\u00a7eSHARINGAN PARRY!"), false);
            cir.setReturnValue(false);
            return;
        }
        if (b.autoParryChance <= 0) return;
        if (player.getWorld().getRandom().nextFloat() < b.autoParryChance) {
            if (player.getWorld() instanceof ServerWorld sw) {
                sw.spawnParticles(ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(),
                        12, 0.3, 0.3, 0.3, 0.05);
            }
            player.sendMessage(Text.literal("В§ePARRIED!"), false);
            cir.setReturnValue(false);
        }
    }
}