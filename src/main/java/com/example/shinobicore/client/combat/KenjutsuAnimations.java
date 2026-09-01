package com.example.shinobicore.client.combat;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import com.example.shinobicore.util.TimedCache;
import java.util.UUID;
public class KenjutsuAnimations {
    private static final TimedCache<UUID, SlashState> SLASHES = new TimedCache<>(2000);
    private static final TimedCache<UUID, Long> DEFLECTS = new TimedCache<>(500);
    public static class SlashState {
        public final int step; public final long start;
        public SlashState(int step) { this.step = step; this.start = System.currentTimeMillis(); }
        public float getProgress() { return Math.min(1f, (System.currentTimeMillis() - start) / duration(step)); }
        public boolean isFinished() { return System.currentTimeMillis() - start >= duration(step); }
        private float duration(int s) { return switch (s) { case 0, 1 -> 260f; case 2 -> 340f; case 4 -> 350f; default -> 520f; }; }
    }
    public static void playSlash(AbstractClientPlayerEntity p, int step) { SLASHES.put(p.getUuid(), new SlashState(step)); }
    public static void playIaiSlash(AbstractClientPlayerEntity p) { SLASHES.put(p.getUuid(), new SlashState(4)); }
    public static void playDeflect(AbstractClientPlayerEntity p) { DEFLECTS.put(p.getUuid(), System.currentTimeMillis() + 300); }
    public static boolean isDeflecting(AbstractClientPlayerEntity p) {
        Long t = DEFLECTS.get(p.getUuid());
        if (t == null) return false;
        if (System.currentTimeMillis() >= t) { DEFLECTS.remove(p.getUuid()); return false; }
        return true;
    }
    private static SlashState get(AbstractClientPlayerEntity p) {
        SlashState s = SLASHES.get(p.getUuid());
        if (s != null && s.isFinished()) { SLASHES.remove(p.getUuid()); return null; }
        return s;
    }
    public static boolean isAttacking(AbstractClientPlayerEntity p) { return get(p) != null; }
    private static float curve(float p) {
        if (p < 0.3f) return (float) Math.sin(p / 0.3f * Math.PI / 2);
        if (p < 0.5f) return 1.0f + 0.15f * (float) Math.sin((p - 0.3f) / 0.2f * Math.PI);
        return 1.0f - (float) Math.sin((p - 0.5f) / 0.5f * Math.PI / 2);
    }
    public static void applySlash(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head) {
        SlashState s = get(p); if (s == null) return;
        float c = curve(s.getProgress());
        switch (s.step) {
            case 0 -> { rArm.yaw = -1.9f + c * 3.2f; rArm.pitch = -0.85f; rArm.roll = 0.2f; body.yaw += c * 0.6f - 0.3f; body.pitch += c * 0.12f; lArm.yaw = 0.4f; lArm.pitch = -0.6f; }
            case 1 -> { rArm.yaw = 1.9f - c * 3.2f; rArm.pitch = -0.85f; rArm.roll = -0.2f; body.yaw -= c * 0.6f - 0.3f; body.pitch += c * 0.12f; lArm.yaw = -0.4f; lArm.pitch = -0.6f; }
            case 2 -> { rArm.pitch = 2.3f - c * 4.0f; rArm.yaw = -0.2f; body.pitch += c * 0.35f; body.roll += c * 0.05f; lArm.pitch = -0.9f; lArm.yaw = 0.5f; }
            default -> { body.yaw += (float) Math.sin(s.getProgress() * Math.PI) * 1.2f; rArm.pitch = -1.5f; rArm.roll = 0.6f; lArm.pitch = -1.5f; lArm.yaw = -0.6f; head.pitch -= 0.1f; }
        }
    }
    public static void applyDeflect(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm) {
        rArm.pitch = -1.4f; rArm.yaw = -0.3f; lArm.pitch = -1.0f; lArm.yaw = 0.4f;
    }

    public static void cleanup(UUID id) {
        SLASHES.remove(id);
        DEFLECTS.remove(id);
    }

    public static int size() {
        return SLASHES.size() + DEFLECTS.size();
    }

    public static void cleanupAll() {
        SLASHES.clear();
        DEFLECTS.clear();
    }
}