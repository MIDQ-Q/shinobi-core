package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.MathHelper;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class LandingAnimations {
    private static final Map<UUID, Long> LANDINGS = new HashMap<>();
    private static final Map<UUID, Boolean> PREV_GROUND = new HashMap<>();
    private static final Map<UUID, Float> LAST_FALL_VEL = new HashMap<>();

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            ClientPlayerEntity p = client.player;
            if (p == null) return;
            UUID id = p.getUuid();
            if (!p.isOnGround()) {
                LAST_FALL_VEL.put(id, (float) p.getVelocity().y);
            }
            boolean prev = PREV_GROUND.getOrDefault(id, true);
            if (!prev && p.isOnGround()) {
                float v = LAST_FALL_VEL.getOrDefault(id, 0f);
                if (v < -0.6f) LANDINGS.put(id, System.currentTimeMillis());
            }
            PREV_GROUND.put(id, p.isOnGround());
        });
    }

    public static void apply(AbstractClientPlayerEntity p, ModelPart body, ModelPart rLeg, ModelPart lLeg,
                             ModelPart rArm, ModelPart lArm, ModelPart head) {
        Long t = LANDINGS.get(p.getUuid());
        if (t == null) return;
        long e = System.currentTimeMillis() - t;
        if (e > 400) { LANDINGS.remove(p.getUuid()); return; }
        float s = MathHelper.sin((e / 400f) * (float) Math.PI);
        body.pitch = 0.45f * s;
        rLeg.pitch = -0.7f * s;
        lLeg.pitch = -0.4f * s;
        rLeg.yaw = 0.2f * s;
        lLeg.yaw = -0.2f * s;
        rArm.pitch = 0.7f * s;
        lArm.pitch = 0.7f * s;
        rArm.yaw = -0.4f * s;
        lArm.yaw = 0.4f * s;
        head.pitch -= 0.25f * s;
    }
}