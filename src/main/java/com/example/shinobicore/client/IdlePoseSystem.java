package com.example.shinobicore.client;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.item.ItemStack;
import net.minecraft.item.SwordItem;
import net.minecraft.util.math.MathHelper;
import com.example.shinobicore.util.TimedCache;
import java.util.UUID;
import com.example.shinobicore.client.ClientNinjaStateHolder;
public class IdlePoseSystem {
    private static final TimedCache<UUID, FidgetState> STATES = new TimedCache<>(30000);
    private static class FidgetState {
        long nextFidgetAt = 0;
        int fidget = -1;
        long fidgetStart = 0;
    }
    public static void apply(AbstractClientPlayerEntity player, BipedEntityModel<?> model,
                             float moveAmount, float animProgress) {
        if (moveAmount > 0.1f) return;
        float breath = MathHelper.sin(animProgress * 0.07f) * 0.03f;
        if (ClientNinjaStateHolder.get().isMeditating()) { applyMeditate(model, breath); return; }
        if (ChakraPhysicsClient.stickingToWall) { applyWallStick(model); return; }
        ItemStack main = player.getMainHandStack();
        if (main.getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            applyKatanaStance(model, breath);
            return;
        }
        boolean isThrowing = main.getItem() instanceof com.example.shinobicore.item.ThrowingWeaponItem;
        boolean weapon = !main.isEmpty() && (main.getItem() instanceof SwordItem || isThrowing);
        boolean chakra = ClientNinjaStateHolder.get().isChakraMode() && ChakraHudRenderer.currentChakra > 0;
        if (weapon) applyWeaponStance(model, breath);
        else if (chakra) applyNinjaGuard(model, breath);
        else applyNormalIdle(model, breath, player);
    }
    private static void applyMeditate(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -0.9f + breath;
        m.leftArm.pitch = -0.9f + breath;
        m.rightArm.yaw = -0.5f;
        m.leftArm.yaw = 0.5f;
        m.head.pitch += 0.25f;
        m.body.pitch += 0.12f;
        m.rightLeg.yaw = 0.5f;
        m.leftLeg.yaw = -0.5f;
        m.rightLeg.pitch = -1.1f;
        m.leftLeg.pitch = -1.1f;
    }
    private static void applyWallStick(BipedEntityModel<?> m) {
        m.rightArm.pitch = -1.5f;
        m.leftArm.pitch = -1.5f;
        m.rightArm.yaw = -0.15f;
        m.leftArm.yaw = 0.15f;
        m.head.pitch -= 0.1f;
    }
    private static void applyWeaponStance(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -1.15f + breath;
        m.rightArm.yaw = -0.25f;
        m.leftArm.pitch = -0.75f + breath;
        m.leftArm.yaw = 0.45f;
        m.body.pitch += 0.10f;
        m.rightLeg.yaw = -0.25f;
        m.leftLeg.yaw = 0.25f;
        m.head.pitch -= 0.08f;
    }
    private static void applyNinjaGuard(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -0.95f + breath;
        m.rightArm.yaw = -0.40f;
        m.leftArm.pitch = -0.70f + breath;
        m.leftArm.yaw = 0.50f;
        m.body.pitch += 0.12f;
        m.rightLeg.yaw = -0.22f;
        m.leftLeg.yaw = 0.22f;
        m.rightLeg.pitch += 0.08f;
        m.leftLeg.pitch += 0.08f;
        m.head.pitch -= 0.10f;
    }
    private static void applyKatanaStance(BipedEntityModel<?> m, float breath) {
        String st = ClientNinjaStateHolder.get().getKenjutsuStance();
        switch (st) {
            case "seigan" -> {
                m.rightArm.pitch = -1.2f + breath;
                m.rightArm.yaw = -0.2f;
                m.leftArm.pitch = -0.7f + breath;
                m.leftArm.yaw = 0.3f;
            }
            case "iai" -> {
                m.rightArm.pitch = 0.15f + breath;
                m.rightArm.yaw = -0.5f;
                m.leftArm.pitch = -0.9f + breath;
                m.leftArm.yaw = 0.6f;
            }
            default -> {
                m.rightArm.pitch = -1.1f + breath;
                m.rightArm.yaw = -0.3f;
                m.leftArm.pitch = -1.0f + breath;
                m.leftArm.yaw = 0.2f;
            }
        }
        m.body.pitch += 0.08f;
        m.rightLeg.yaw = -0.2f;
        m.leftLeg.yaw = 0.2f;
        m.head.pitch -= 0.06f;
    }
    private static void applyNormalIdle(BipedEntityModel<?> m, float breath, AbstractClientPlayerEntity player) {
        m.body.pitch += breath * 0.6f;
        m.rightArm.pitch += breath;
        m.leftArm.pitch += breath;
        FidgetState st = STATES.computeIfAbsent(player.getUuid(), u -> new FidgetState());
        long now = System.currentTimeMillis();
        if (st.fidget >= 0) {
            float p = (now - st.fidgetStart) / 2500f;
            if (p >= 1f) {
                st.fidget = -1;
                st.nextFidgetAt = now + 5000 + (long)(Math.random() * 7000);
            } else {
                float f = MathHelper.sin(p * (float) Math.PI);
                switch (st.fidget) {
                    case 0 -> m.head.yaw += f * 0.6f;
                    case 1 -> {
                        m.body.roll += f * 0.06f;
                        m.rightLeg.yaw -= f * 0.15f;
                        m.leftLeg.yaw += f * 0.15f;
                    }
                    case 2 -> {
                        m.rightArm.pitch += f * -1.6f;
                        m.rightArm.yaw += f * -0.5f;
                    }
                }
            }
        } else if (now >= st.nextFidgetAt) {
            st.fidget = (int)(Math.random() * 3);
            st.fidgetStart = now;
        }
    }

    public static void cleanup(UUID id) {
        STATES.remove(id);
    }

    public static void cleanupAll() {
        STATES.clear();
    }

    public static int size() {
        return STATES.size();
    }
}