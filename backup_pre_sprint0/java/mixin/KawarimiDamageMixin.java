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