package com.example.shinobicore.mixin;

import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.PoseHelper;
import com.example.shinobicore.pose.LowPoseTracker;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

@Mixin(PlayerEntity.class)
public abstract class SlidePoseMixin {

    @Redirect(
        method = "updatePose",
        at = @At(value = "INVOKE", target = "Lnet/minecraft/entity/player/PlayerEntity;setPose(Lnet/minecraft/entity/EntityPose;)V")
    )
    private void shinobicore_overridePose(PlayerEntity self, EntityPose vanillaPose) {
        // === РЎР•Р Р’Р•Р РќРђРЇ Р§РђРЎРўР¬: С‡РёС‚Р°РµРј С„Р»Р°Рі РёР· С‚СЂРµРєРµСЂР° ===
        if (self instanceof ServerPlayerEntity sp) {
            if (LowPoseTracker.isLow(sp.getUuid())) {
                if (self.getPose() != EntityPose.SWIMMING) {
                    self.setPose(EntityPose.SWIMMING);
                    self.calculateDimensions();
                }
            } else {
                self.setPose(vanillaPose);
            }
            return;
        }

        // === РљР›РР•РќРўРЎРљРђРЇ Р§РђРЎРўР¬ ===
        if (self instanceof ClientPlayerEntity cp) {
            boolean needsLow = ParkourManager.isSliding()
                || ParkourManager.isCrawling()
                || PoseHelper.cannotStand(cp);

            if (needsLow) {
                PoseHelper.forceLowPose(cp);
            } else {
                self.setPose(vanillaPose);
            }
        } else {
            self.setPose(vanillaPose);
        }
    }
}
