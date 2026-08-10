package com.example.shinobicore.client.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.TaijutsuStyle;
import net.minecraft.client.network.AbstractClientPlayerEntity;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class TaijutsuAnimations {

    private static final Map<UUID, AttackAnimationState> activeAnimations = new HashMap<>();

    public static class AttackAnimationState {
        public final int comboStep;
        public final TaijutsuStyle style;
        public final long startTime;

        public AttackAnimationState(int comboStep, TaijutsuStyle style) {
            this.comboStep = comboStep;
            this.style = style;
            this.startTime = System.currentTimeMillis();
            ShinobiCore.LOGGER.info("[ANIM] Created animation state: step={}, style={}", comboStep, style.getId());
        }

        public float getProgress() {
            long elapsed = System.currentTimeMillis() - startTime;
            float duration = getDuration(comboStep);
            float progress = Math.min(1.0f, elapsed / duration);
            return progress;
        }

        public boolean isFinished() {
            long elapsed = System.currentTimeMillis() - startTime;
            float duration = getDuration(comboStep);
            boolean finished = elapsed >= duration;
            return finished;
        }

        private float getDuration(int step) {
            switch (step) {
                case 0: return 280f;
                case 1: return 280f;
                case 2: return 380f;
                case 3: return 500f;
                default: return 300f;
            }
        }
    }

    public static void playAttackAnimation(AbstractClientPlayerEntity player, int comboStep, TaijutsuStyle style) {
        ShinobiCore.LOGGER.info("[ANIM] playAttackAnimation called: player={}, step={}, style={}",
            player.getName().getString(), comboStep, style.getId());
        activeAnimations.put(player.getUuid(), new AttackAnimationState(comboStep, style));
        ShinobiCore.LOGGER.info("[ANIM] Animation added to map. Map size: {}", activeAnimations.size());
    }

    public static AttackAnimationState getAnimationState(AbstractClientPlayerEntity player) {
        AttackAnimationState state = activeAnimations.get(player.getUuid());
        if (state != null && state.isFinished()) {
            ShinobiCore.LOGGER.info("[ANIM] Animation finished, removing from map");
            activeAnimations.remove(player.getUuid());
            return null;
        }
        return state;
    }

    public static float getArmRotation(AbstractClientPlayerEntity player, float tickDelta) {
        AttackAnimationState state = getAnimationState(player);
        if (state == null) {
            return 0f;
        }

        float progress = state.getProgress();
        int step = state.comboStep;

        float maxAngle;
        switch (step) {
            case 0: maxAngle = -85f;  break;
            case 1: maxAngle = -85f;  break;
            case 2: maxAngle = -105f; break;
            case 3: maxAngle = -130f; break;
            default: maxAngle = -85f;
        }

        if (state.style == TaijutsuStyle.STRONG_FIST) {
            maxAngle *= 1.15f;
        }

        float curve;
        if (progress < 0.4f) {
            curve = (float) Math.sin((progress / 0.4f) * (Math.PI / 2));
        } else {
            float t = (progress - 0.4f) / 0.6f;
            curve = (float) Math.cos(t * (Math.PI / 2));
        }

        float result = curve * maxAngle;
        return result;
    }

    public static boolean isAttacking(AbstractClientPlayerEntity player) {
        boolean result = getAnimationState(player) != null;
        return result;
    }
    private static final Map<UUID, KickAnimationState> activeKicks = new HashMap<>();

    public static class KickAnimationState {
        public final TaijutsuStyle style;
        public final long startTime;
        public static final long DURATION_MS = 400;

        public KickAnimationState(TaijutsuStyle style) {
            this.style = style;
            this.startTime = System.currentTimeMillis();
        }

        public float getProgress() {
            long elapsed = System.currentTimeMillis() - startTime;
            return Math.min(1.0f, elapsed / (float) DURATION_MS);
        }

        public boolean isFinished() {
            return System.currentTimeMillis() - startTime >= DURATION_MS;
        }
    }

    public static void playKickAnimation(AbstractClientPlayerEntity player, TaijutsuStyle style) {
        ShinobiCore.LOGGER.info("[ANIM] Playing kick animation, style={}", style.getId());
        activeKicks.put(player.getUuid(), new KickAnimationState(style));
    }

    public static KickAnimationState getKickState(AbstractClientPlayerEntity player) {
        KickAnimationState state = activeKicks.get(player.getUuid());
        if (state != null && state.isFinished()) {
            activeKicks.remove(player.getUuid());
            return null;
        }
        return state;
    }

    public static boolean isKicking(AbstractClientPlayerEntity player) {
        return getKickState(player) != null;
    }

    public static float getLegRotation(AbstractClientPlayerEntity player) {
        KickAnimationState state = getKickState(player);
        if (state == null) return 0f;

        float progress = state.getProgress();
        float maxAngle = -110f;
        if (state.style == TaijutsuStyle.STRONG_FIST) maxAngle *= 1.2f;

        // Плавная кривая
        float curve;
        if (progress < 0.4f) {
            curve = (float) Math.sin((progress / 0.4f) * (Math.PI / 2));
        } else {
            float t = (progress - 0.4f) / 0.6f;
            curve = (float) Math.cos(t * (Math.PI / 2));
        }
        return curve * maxAngle;
    }
}