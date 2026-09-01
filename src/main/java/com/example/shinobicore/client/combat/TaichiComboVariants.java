package com.example.shinobicore.client.combat;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.util.math.MathHelper;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;
import com.example.shinobicore.util.TimedCache;
import java.util.UUID;

/**
 * Procedural taijutsu combo variants.
 * Each LMB attack picks a random style from 4 variants:
 *   0: Leaf Hurricane (360 spin + kick up)
 *   1: Leaf Rising Wind (shoryuken uppercut)
 *   2: Dynamic Action (3-fast-punches + kick)
 *   3: Front Lotus (air combo starter)
 */
public class TaichiComboVariants {
    private static final Map<UUID, Integer> VARIANTS = new HashMap<>();
    private static final Map<UUID, Long> LAST_ATTACK = new HashMap<>();
    private static final Random RNG = new Random();

    public static int rollVariant(AbstractClientPlayerEntity p) {
        long now = System.currentTimeMillis();
        long last = LAST_ATTACK.getOrDefault(p.getUuid(), 0L);
        if (now - last < 3000) {
            return VARIANTS.getOrDefault(p.getUuid(), 0);
        }
        int v = RNG.nextInt(4);
        VARIANTS.put(p.getUuid(), v);
        LAST_ATTACK.put(p.getUuid(), now);
        return v;
    }

    public static void apply(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm,
                             ModelPart rLeg, ModelPart lLeg, ModelPart body, ModelPart head) {
        Integer v = VARIANTS.get(p.getUuid());
        if (v == null) return;
        Long last = LAST_ATTACK.get(p.getUuid());
        if (last == null) return;
        long elapsed = System.currentTimeMillis() - last;
        if (elapsed > 450) return;
        float pr = elapsed / 450f;
        float c = (float) Math.sin(pr * Math.PI);
        switch (v) {
            case 0 -> applyHurricane(rArm, lArm, rLeg, lLeg, body, head, c);
            case 1 -> applyRisingWind(rArm, lArm, rLeg, body, c);
            case 2 -> applyDynamicAction(rArm, lArm, rLeg, body, head, pr);
            case 3 -> applyFrontLotus(rArm, lArm, rLeg, lLeg, body, c);
        }
    }

    private static void applyHurricane(ModelPart rArm, ModelPart lArm, ModelPart rLeg, ModelPart lLeg,
                                        ModelPart body, ModelPart head, float c) {
        body.yaw += c * 6.28f;
        rLeg.pitch = -1.2f * c;
        rLeg.yaw = 0.6f * c;
        lLeg.pitch = 0.3f * c;
        rArm.pitch = 0.8f * c;
        lArm.pitch = 0.8f * c;
        rArm.yaw = -1.2f * c;
        lArm.yaw = 1.2f * c;
    }

    private static void applyRisingWind(ModelPart rArm, ModelPart lArm, ModelPart rLeg,
                                         ModelPart body, float c) {
        rArm.pitch = -2.8f * c;
        rArm.yaw = -0.3f * c;
        lArm.pitch = 0.5f * c;
        rLeg.pitch = -0.3f * c;
        body.pitch = -0.4f * c;
    }

    private static void applyDynamicAction(ModelPart rArm, ModelPart lArm, ModelPart rLeg,
                                            ModelPart body, ModelPart head, float pr) {
        if (pr < 0.7f) {
            float punch = MathHelper.sin(pr * 18f);
            rArm.pitch = -1.5f + punch * 0.3f;
            lArm.pitch = -1.5f - punch * 0.3f;
            rArm.yaw = -0.2f;
            lArm.yaw = 0.2f;
        } else {
            float kick = MathHelper.sin((pr - 0.7f) / 0.3f * (float) Math.PI);
            rLeg.pitch = -1.8f * kick;
            rLeg.yaw = -0.2f * kick;
            body.pitch = 0.3f * kick;
        }
    }

    private static void applyFrontLotus(ModelPart rArm, ModelPart lArm, ModelPart rLeg, ModelPart lLeg,
                                         ModelPart body, float c) {
        rArm.pitch = -1.4f * c;
        lArm.pitch = -1.4f * c;
        rArm.yaw = -0.5f * c;
        lArm.yaw = 0.5f * c;
        rLeg.pitch = 0.6f * c;
        lLeg.pitch = 0.6f * c;
        body.pitch = -0.2f * c;
        body.yaw += c * 1.5f;
    }

    public static boolean isActive(AbstractClientPlayerEntity p) {
        Long last = LAST_ATTACK.get(p.getUuid());
        if (last == null) return false;
        return System.currentTimeMillis() - last < 450;
    }

    public static void cleanupAll() {
        VARIANTS.clear();
        LAST_ATTACK.clear();
    }
}
