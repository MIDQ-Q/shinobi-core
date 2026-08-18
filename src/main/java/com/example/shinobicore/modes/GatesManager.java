package com.example.shinobicore.modes;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import java.util.UUID;

public class GatesManager {
    private static final float[][] GATE_DATA = {
        {0.20f, 0.20f, 0.20f, 0.5f, 3},
        {0.50f, 0.50f, 0.25f, 0.5f, 5},
        {0.80f, 0.80f, 0.30f, 1.0f, 7},
        {1.10f, 1.10f, 0.35f, 1.0f, 9},
        {1.40f, 1.40f, 0.40f, 1.5f, 11},
        {1.70f, 1.70f, 0.45f, 1.5f, 13},
        {2.00f, 2.00f, 0.50f, 2.0f, 15},
        {5.00f, 5.00f, 0.65f, 0.0f, 20},
    };

    private static final UUID ATK_UUID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567801");
    private static final UUID DMG_UUID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567802");
    private static final UUID SPD_UUID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567803");

    public static final int GATE8_DURATION = 3 * 60 * 20;
    public static final int GATE8_COOLDOWN = 15 * 60 * 20;

    public static boolean activateNextGate(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int current = data.getActiveGate();
        int next = current + 1;
        if (next > 8) return false;
        if (next == 8 && data.getGateCooldownTicks() > 0) {
            player.sendMessage(Text.literal("\u00a7cGate 8 on cooldown."), false);
            return false;
        }
        String node = gateNode(next);
        if (!data.getUnlockedNodes().contains(node)) {
            player.sendMessage(Text.literal("\u00a7cGate " + next + " not unlocked."), false);
            return false;
        }
        if (current > 0) removeModifiers(player);
        data.setActiveGate(next);
        applyModifiers(player, next);
        if (next == 8) data.setGate8RemainingTicks(GATE8_DURATION);
        player.sendMessage(Text.literal("\u00a7a\u26a1 Gate " + next + " opened!"), false);
        return true;
    }

    public static boolean deactivateGate(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int gate = data.getActiveGate();
        if (gate == 0) return false;
        if (gate == 8) {
            player.sendMessage(Text.literal("\u00a7cGate 8 cannot be closed!"), false);
            return false;
        }
        removeModifiers(player);
        data.setActiveGate(0);
        player.sendMessage(Text.literal("\u00a77Gates closed."), false);
        return true;
    }

    public static void tick(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int gate = data.getActiveGate();
        if (gate == 0) {
            if (data.getGateCooldownTicks() > 0) data.setGateCooldownTicks(data.getGateCooldownTicks() - 1);
            return;
        }
        float[] gd = GATE_DATA[gate - 1];
        if (gd[3] > 0 && player.age % 40 == 0) {
            player.damage(player.getDamageSources().magic(), gd[3]);
        }
        if (gate == 8) {
            int rem = data.getGate8RemainingTicks();
            if (rem > 0) {
                data.setGate8RemainingTicks(rem - 1);
            } else {
                removeModifiers(player);
                data.setActiveGate(0);
                data.setGateCooldownTicks(GATE8_COOLDOWN);
                player.sendMessage(Text.literal("\u00a7aGate 8 expired. You survived!"), false);
                return;
            }
        }
        if (player.getWorld() instanceof ServerWorld sw && player.age % 4 == 0) {
            int count = Math.min((int) gd[4], 5);
            for (int i = 0; i < count; i++) {
                double a = sw.getRandom().nextDouble() * Math.PI * 2;
                double d = 0.3 + sw.getRandom().nextDouble() * 0.4;
                sw.spawnParticles(ParticleTypes.DAMAGE_INDICATOR,
                    player.getX() + Math.cos(a) * d,
                    player.getY() + 0.5 + sw.getRandom().nextDouble() * 1.5,
                    player.getZ() + Math.sin(a) * d, 1, 0, 0, 0, 0);
            }
        }
    }

    private static void applyModifiers(ServerPlayerEntity p, int gate) {
        float[] gd = GATE_DATA[gate - 1];
        var as = p.getAttributeInstance(EntityAttributes.GENERIC_ATTACK_SPEED);
        var dm = p.getAttributeInstance(EntityAttributes.GENERIC_ATTACK_DAMAGE);
        var sp = p.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (as != null) as.addTemporaryModifier(new EntityAttributeModifier(ATK_UUID, "gate_as", gd[0], EntityAttributeModifier.Operation.MULTIPLY_TOTAL));
        if (dm != null) dm.addTemporaryModifier(new EntityAttributeModifier(DMG_UUID, "gate_dm", gd[1], EntityAttributeModifier.Operation.MULTIPLY_TOTAL));
        if (sp != null) sp.addTemporaryModifier(new EntityAttributeModifier(SPD_UUID, "gate_sp", gd[2], EntityAttributeModifier.Operation.MULTIPLY_TOTAL));
    }

    private static void removeModifiers(ServerPlayerEntity p) {
        var as = p.getAttributeInstance(EntityAttributes.GENERIC_ATTACK_SPEED);
        var dm = p.getAttributeInstance(EntityAttributes.GENERIC_ATTACK_DAMAGE);
        var sp = p.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (as != null) as.removeModifier(ATK_UUID);
        if (dm != null) dm.removeModifier(DMG_UUID);
        if (sp != null) sp.removeModifier(SPD_UUID);
    }

    private static String gateNode(int g) {
        switch (g) {
            case 1: return "gate_one"; case 2: return "gate_two";
            case 3: return "gate_three"; case 4: return "gate_four";
            case 5: return "gate_five"; case 6: return "gate_six";
            case 7: return "gate_seven"; case 8: return "gate_eight";
            default: return "";
        }
    }
}