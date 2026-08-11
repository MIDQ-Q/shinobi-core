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