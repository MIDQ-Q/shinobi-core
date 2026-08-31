package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementPose;
import net.minecraft.client.network.ClientPlayerEntity;

public final class CrawlService {
    private CrawlService() {}

    public static void toggle(ClientPlayerEntity player) {
        if (ClientMovementState.getPose() == MovementPose.CRAWLING) {
            ClientMovementState.setPose(MovementPose.NORMAL);
            player.setSwimming(false);
        } else {
            ClientMovementState.setPose(MovementPose.CRAWLING);
            player.setSwimming(true);
        }
    }

    public static void tick(ClientPlayerEntity player) {
        if (ClientMovementState.getPose() == MovementPose.CRAWLING) {
            if (!player.isSwimming()) player.setSwimming(true);
        }
    }
}