package com.example.shinobicore.client.combat;

import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.entity.player.PlayerEntity;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class ThrowAnimations {
    private static final Map<UUID, Long> THROWS = new HashMap<>();
    private static final long DURATION = 260;

    public static void playThrow(PlayerEntity p) {
        THROWS.put(p.getUuid(), System.currentTimeMillis());
    }

    public static boolean isThrowing(AbstractClientPlayerEntity p) {
        Long t = THROWS.get(p.getUuid());
        if (t == null) return false;
        if (System.currentTimeMillis() - t >= DURATION) { THROWS.remove(p.getUuid()); return false; }
        return true;
    }

    public static void apply(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head) {
        Long t = THROWS.get(p.getUuid());
        if (t == null) return;
        float pr = Math.min(1f, (System.currentTimeMillis() - t) / (float) DURATION);
        float c;
        if (pr < 0.35f) c = -0.6f * (pr / 0.35f);
        else c = -0.6f + 2.0f * ((pr - 0.35f) / 0.65f);
        rArm.pitch = c;
        rArm.yaw = -0.15f;
        lArm.pitch = -0.4f;
        lArm.yaw = 0.3f;
        body.yaw += -0.15f + 0.3f * pr;
        head.pitch -= 0.05f;
    }

    public static void cleanupAll() {
        THROWS.clear();
    }
}
