package com.example.shinobicore.client.combat;

import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.util.math.MathHelper;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class ChakraBurstAnimations {
    private static final Map<UUID, Long> BURSTS = new HashMap<>();

    public static void playBurst(AbstractClientPlayerEntity p) {
        BURSTS.put(p.getUuid(), System.currentTimeMillis());
    }

    public static void apply(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head) {
        Long t = BURSTS.get(p.getUuid());
        if (t == null) return;
        long e = System.currentTimeMillis() - t;
        if (e > 500) { BURSTS.remove(p.getUuid()); return; }
        float s = MathHelper.sin((e / 500f) * (float) Math.PI);
        rArm.pitch = 0.3f * s;
        lArm.pitch = 0.3f * s;
        rArm.roll = -0.5f * s;
        lArm.roll = 0.5f * s;
        rArm.yaw = -0.3f * s;
        lArm.yaw = 0.3f * s;
        body.pitch = -0.1f * s;
        head.pitch += 0.15f * s;
    }
}