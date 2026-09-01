package com.example.shinobicore.client.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.TaijutsuStyle;
import net.minecraft.client.network.AbstractClientPlayerEntity;

import com.example.shinobicore.util.TimedCache;
import java.util.UUID;

public class TaijutsuAnimations {

    private static final TimedCache<UUID, AttackAnimationState> activeAnimations = new TimedCache<>(1000);

    public static class AttackAnimationState {
        public final int comboStep;
        public final TaijutsuStyle style;
        public final long startTime;

        public AttackAnimationState(int comboStep, TaijutsuStyle style) {
            this.comboStep = comboStep;
            this.style = style;
            this.startTime = System.currentTimeMillis();
            ShinobiCore.LOGGER.debug("[ANIM] Created animation state: step={}, style={}", comboStep, style.getId());
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
        ShinobiCore.LOGGER.debug("[ANIM] playAttackAnimation called: player={}, step={}, style={}",
            player.getName().getString(), comboStep, style.getId());
        activeAnimations.put(player.getUuid(), new AttackAnimationState(comboStep, style));
        ShinobiCore.LOGGER.debug("[ANIM] Animation added to map. Map size: {}", activeAnimations.size());
    }

    public static AttackAnimationState getAnimationState(AbstractClientPlayerEntity player) {
        AttackAnimationState state = activeAnimations.get(player.getUuid());
        if (state != null && state.isFinished()) {
            ShinobiCore.LOGGER.debug("[ANIM] Animation finished, removing from map");
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

        // === УЛУЧШЕННАЯ КРИВАЯ: ease-in-out с overshoot ===
        float curve;
        if (progress < 0.3f) {
            // Замах (0 -> 0.3) — ease-in (ускорение)
            float t = progress / 0.3f;
            curve = (float) Math.sin(t * (Math.PI / 2));
        } else if (progress < 0.5f) {
            // Удар (0.3 -> 0.5) — overshoot (небольшой перебор)
            float t = (progress - 0.3f) / 0.2f;
            curve = 1.0f + 0.15f * (float) Math.sin(t * Math.PI);
        } else {
            // Возврат (0.5 -> 1.0) — ease-out (замедление)
            float t = (progress - 0.5f) / 0.5f;
            curve = 1.0f - (float) Math.sin(t * (Math.PI / 2));
        }

        float result = curve * maxAngle;
        return result;
    }

    public static boolean isAttacking(AbstractClientPlayerEntity player) {
        boolean result = getAnimationState(player) != null;
        return result;
    }
    private static final TimedCache<UUID, KickAnimationState> activeKicks = new TimedCache<>(1000);

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
        ShinobiCore.LOGGER.debug("[ANIM] Playing kick animation, style={}", style.getId());
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

        // === УЛУЧШЕННАЯ КРИВАЯ ДЛЯ УДАРА НОГОЙ ===
        float curve;
        if (progress < 0.25f) {
            // Замах (0 -> 0.25) — быстрый ease-in
            float t = progress / 0.25f;
            curve = (float) Math.sin(t * (Math.PI / 2));
        } else if (progress < 0.45f) {
            // Удар (0.25 -> 0.45) — overshoot
            float t = (progress - 0.25f) / 0.2f;
            curve = 1.0f + 0.2f * (float) Math.sin(t * Math.PI);
        } else {
            // Возврат (0.45 -> 1.0) — плавный ease-out
            float t = (progress - 0.45f) / 0.55f;
            curve = 1.0f - (float) Math.sin(t * (Math.PI / 2));
        }

        return curve * maxAngle;
    }

    public static void cleanup(UUID id) {
        activeAnimations.remove(id);
        activeKicks.remove(id);
    }

    public static int size() {
        return activeAnimations.size() + activeKicks.size();
    }

    public static void cleanupAll() {
        activeAnimations.clear();
        activeKicks.clear();
    }
}