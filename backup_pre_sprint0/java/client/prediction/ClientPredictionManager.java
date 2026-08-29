package com.example.shinobicore.client.prediction;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;
import java.util.LinkedList;
import java.util.Queue;

/**
 * S0-07: Client-side prediction framework.
 * Tracks pending actions and handles smooth rollbacks on server correction.
 */
public class ClientPredictionManager {
    private static final Queue<PendingAction> pendingActions = new LinkedList<>();
    
    private static boolean correcting = false;
    private static Vec3d correctionStartPos = Vec3d.ZERO;
    private static Vec3d correctionTargetPos = Vec3d.ZERO;
    private static int correctionTicks = 0;
    private static final int CORRECTION_DURATION_TICKS = 5; // 0.25s smooth lerp

    public static void registerAction(String actionId, Vec3d appliedVelocity) {
        pendingActions.add(new PendingAction(actionId, System.currentTimeMillis(), appliedVelocity));
        if (pendingActions.size() > 20) {
            pendingActions.poll();
        }
    }

    public static void acknowledgeAction(String actionId) {
        pendingActions.removeIf(a -> a.actionId.equals(actionId));
    }

    public static void applyCorrection(ClientPlayerEntity player, Vec3d serverPos, Vec3d serverVel) {
        if (player == null) return;
        Vec3d currentPos = player.getPos();
        double distance = currentPos.distanceTo(serverPos);
        
        if (distance < 0.05) return; // Ignore micro-drifts
        
        if (distance > 10.0) {
            // Hard snap for huge divergence (anti-cheat/teleport)
            player.setPosition(serverPos.x, serverPos.y, serverPos.z);
            player.setVelocity(serverVel);
            pendingActions.clear();
            correcting = false;
            return;
        }

        // Smooth rollback (lerp)
        correcting = true;
        correctionStartPos = currentPos;
        correctionTargetPos = serverPos;
        correctionTicks = 0;
        player.setVelocity(serverVel);
        pendingActions.clear();
    }

    public static void tick(ClientPlayerEntity player) {
        if (player == null) return;
        
        if (correcting) {
            correctionTicks++;
            float progress = (float) correctionTicks / CORRECTION_DURATION_TICKS;
            if (progress >= 1.0f) {
                player.setPosition(correctionTargetPos.x, correctionTargetPos.y, correctionTargetPos.z);
                correcting = false;
            } else {
                double x = correctionStartPos.x + (correctionTargetPos.x - correctionStartPos.x) * progress;
                double y = correctionStartPos.y + (correctionTargetPos.y - correctionStartPos.y) * progress;
                double z = correctionStartPos.z + (correctionTargetPos.z - correctionStartPos.z) * progress;
                player.setPosition(x, y, z);
            }
        }
        
        long now = System.currentTimeMillis();
        pendingActions.removeIf(a -> now - a.timestamp > 1000);
    }
    
    public static boolean isCorrecting() {
        return correcting;
    }

    private record PendingAction(String actionId, long timestamp, Vec3d velocity) {}
}