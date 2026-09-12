package com.example.shinobicore.client.combat;
import com.example.shinobicore.client.CinematicCamera;
import com.example.shinobicore.item.KatanaItem;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.Hand;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.client.ClientNinjaStateHolder;
public class KenjutsuClientHandler {

    /**
     * P1-5: приёмник подтверждения шага комбо катаны.
     * Вызывается из ShinobiCoreClient.onInitializeClient().
     */
    public static void register() {
        net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking.registerGlobalReceiver(
                ModPackets.KATANA_COMBO_SYNC_ID, (client, handler, buf, responseSender) -> {
            int serverStep = buf.readInt();
            int nextStep = buf.readInt();
            boolean success = buf.readBoolean();
            byte reasonCode = buf.readByte();

            client.execute(() -> {
                awaitingComboSync = false;
                comboStep = success ? nextStep : serverStep;
                lastAttack = System.currentTimeMillis();
                if (!success) {
                    com.example.shinobicore.combat.ComboMachine.RejectReason reason =
                            com.example.shinobicore.combat.ComboMachine.RejectReason.fromCode(reasonCode);
                    com.example.shinobicore.ShinobiCore.LOGGER.debug(
                            "[KATANA-COMBO-SYNC] step={} reason={}", comboStep, reason);
                }
            });
        });
    }

    private static int comboStep = 0;
    private static long lastAttack = 0;
    private static long cooldownEnd = 0;
    // P1-5: ждём подтверждения сервера. Снаружи — таймаут, чтобы потерянный
    // пакет не блокировал катану навсегда.
    private static boolean awaitingComboSync = false;
    private static long syncWaitStartMs = 0L;
    private static final long SYNC_WAIT_TIMEOUT_MS = 500L;
    private static final String[] ORDER = {"aggressive", "defensive"};
    public static boolean tryAttack(ClientPlayerEntity player) {
        if (!(player.getMainHandStack().getItem() instanceof KatanaItem)) return false;
        long now = System.currentTimeMillis();
        if (now < cooldownEnd) return false;
        // P1-5: не отправляем второй пакет, пока не пришло подтверждение.
        // Иначе клиент убегает вперёд сервера — это и был рассинхрон.
        if (awaitingComboSync) {
            if (now - syncWaitStartMs < SYNC_WAIT_TIMEOUT_MS) return false;
            awaitingComboSync = false;   // пакет потерялся — разблокируемся
        }
        if (now - lastAttack > 1500) comboStep = 0;
        String stance = ClientNinjaStateHolder.get().getKenjutsuStance();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(comboStep);
        buf.writeString(stance);
        ClientPlayNetworking.send(ModPackets.KATANA_ATTACK_ID, buf);
        String slashAnim = com.example.shinobicore.client.render.WeaponVisualRegistry.getSlashAnim(player.getMainHandStack(), comboStep);
        if (slashAnim != null) {
            com.example.shinobicore.client.anim.json.PlayerJsonAnimState.play(slashAnim, true); // my Blockbench slash anims
        } else {
            KenjutsuAnimations.playSlash(player, comboStep);
        }
        playSlashParticles(player, comboStep);
        SwordTrailRenderer.playSlashTrail(player, comboStep); // PHASE_K1_TRAIL_HOOKED
        TaijutsuSounds.playWhoosh();
        if (comboStep == 3) {
            TaijutsuSounds.playKickSound();
            CinematicCamera.addShake(0.12f);
        }
        player.swingHand(Hand.MAIN_HAND);
        // D4: кулдаун из единого источника. Было 350/450/500 мс на клиенте при
        // серверном пороге 341/400/450 мс — запас 9 мс, любой лаг ломал удар.
        long cd = com.example.shinobicore.combat.KenjutsuBalance.clientCooldownMs(
                com.example.shinobicore.combat.KenjutsuStance.fromId(stance));
        cooldownEnd = now + cd;
        lastAttack = now;
        // P1-5: шаг НЕ инкрементируем локально — ждём KATANA_COMBO_SYNC.
        awaitingComboSync = true;
        syncWaitStartMs = now;
        return true;
    }
    public static void setDeflectHeld(ClientPlayerEntity player, boolean held) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(held);
        ClientPlayNetworking.send(ModPackets.KATANA_DEFLECT_ID, buf);
        ClientNinjaStateHolder.get().setDeflectHeld(held);
        if (held) {
            KenjutsuAnimations.playDeflect(player);
            player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 0.4f, 1.5f);
        }
    }
    public static void cycleStance(ClientPlayerEntity player) {
        String cur = ClientNinjaStateHolder.get().getKenjutsuStance();
        String next = ORDER[(java.util.Arrays.asList(ORDER).indexOf(cur) + 1) % ORDER.length];
        ClientNinjaStateHolder.get().setKenjutsuStance(next);
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(next);
        ClientPlayNetworking.send(ModPackets.KATANA_STANCE_ID, buf);
        player.sendMessage(Text.translatable("stance.shinobicore." + next), false);
    }
    private static void playSlashParticles(ClientPlayerEntity player, int step) {
        MinecraftClient client = MinecraftClient.getInstance();
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        Vec3d pos = player.getPos().add(0, 1.2, 0);
        int count = step == 3 ? 24 : 12;
        for (int i = 0; i < count; i++) {
            float t = (i / (float) count) * 2f - 1f;
            Vec3d dir = look.add(right.multiply(step % 2 == 0 ? t : -t)).normalize();
            client.world.addParticle(step == 3 ? ParticleTypes.ENCHANT : ParticleTypes.SWEEP_ATTACK,
                    pos.x + dir.x * 1.5, pos.y + dir.y * 1.5 + t * 0.3, pos.z + dir.z * 1.5,
                    dir.x * 0.1, dir.y * 0.1, dir.z * 0.1);
        }
        if (step == 3) {
            for (int i = 0; i < 12; i++) {
                double a = (i / 12.0) * Math.PI * 2;
                client.world.addParticle(ParticleTypes.CRIT,
                        pos.x + Math.cos(a) * 1.8, pos.y, pos.z + Math.sin(a) * 1.8, 0, 0.1, 0);
            }
        }
    }
}