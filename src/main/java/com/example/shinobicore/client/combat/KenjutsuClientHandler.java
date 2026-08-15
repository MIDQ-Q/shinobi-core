package com.example.shinobicore.client.combat;
import com.example.shinobicore.client.CinematicCamera;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.combat.KenjutsuFormulas;
import com.example.shinobicore.combat.KenjutsuStance;
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
public class KenjutsuClientHandler {
    private static int comboStep = 0;
    private static long lastAttack = 0;
    private static long cooldownEnd = 0;
    private static final String[] ORDER = {"aggressive", "seigan", "iai"};
    public static boolean tryAttack(ClientPlayerEntity player) {
        if (!(player.getMainHandStack().getItem() instanceof KatanaItem)) return false;
        long now = System.currentTimeMillis();
        if (now < cooldownEnd) return false;
        if (now - lastAttack > 1500) comboStep = 0;
        String stance = ClientNinjaState.kenjutsuStance;
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(comboStep);
        buf.writeString(stance);
        ClientPlayNetworking.send(ModPackets.KATANA_ATTACK_ID, buf);
        if (stance.equals("iai")) KenjutsuAnimations.playIaiSlash(player); else KenjutsuAnimations.playSlash(player, comboStep); // PHASE_A_IAI_HOOK
        playSlashParticles(player, comboStep);
        SwordTrailRenderer.playSlashTrail(player, comboStep); // PHASE_K1_TRAIL_HOOKED
        TaijutsuSounds.playKatanaSlash(comboStep);
        if (comboStep == 3) {
            TaijutsuSounds.playKickSound();
            CinematicCamera.addShake(0.12f);
        }
        player.swingHand(Hand.MAIN_HAND);
        long cd = stance.equals("aggressive") ? 350 : stance.equals("seigan") ? 450 : 500;
        cooldownEnd = now + cd;
        lastAttack = now;
        comboStep = (comboStep + 1) % 4;
        return true;
    }
    public static void setDeflectHeld(ClientPlayerEntity player, boolean held) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(held);
        ClientPlayNetworking.send(ModPackets.KATANA_DEFLECT_ID, buf);
        ClientNinjaState.deflectHeld = held;
        if (held) {
            KenjutsuAnimations.playDeflect(player);
            TaijutsuSounds.playKatanaDeflectSound();
        }
    }
    public static void cycleStance(ClientPlayerEntity player) {
        String cur = ClientNinjaState.kenjutsuStance;
        String next = ORDER[(java.util.Arrays.asList(ORDER).indexOf(cur) + 1) % ORDER.length];
        ClientNinjaState.kenjutsuStance = next;
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(next);
        ClientPlayNetworking.send(ModPackets.KATANA_STANCE_ID, buf);
        player.sendMessage(Text.literal("В§aStance: " + next), false);
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