package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.core.ActivationDefinition;
import com.example.shinobicore.jutsu.core.EffectDefinition;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.core.LevelingDefinition;
import com.example.shinobicore.jutsu.core.PropertyDefinition;
import com.example.shinobicore.jutsu.enums.ResourceType;
import com.example.shinobicore.jutsu.progression.JutsuProgressionState;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class JutsuCaster {

    public static boolean cast(ServerPlayerEntity player, JutsuDefinition jutsu) {
        UUID uid = player.getUuid();
        String id = jutsu.getId();

        if (CooldownSystem.isOnCooldown(uid, id)) {
            double sec = CooldownSystem.getRemaining(uid, id) / 20.0;
            player.sendMessage(Text.literal(String.format("В§cCooldown: %.1fs", sec)), true);
            return false;
        }

        JutsuProgressionState prog = JutsuProgressionState.get(player.getServer());
        int level = Math.min(prog.getLevel(uid, id), jutsu.getLeveling().getMaxLevel());

        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (!player.hasPermissionLevel(2) && !NinjaFormula.checkRequirements(jutsu, data)) {
            player.sendMessage(Text.literal("В§cRequirements not met for " + jutsu.getName()), false);
            return false;
        }

        Map<String, Double> nums = jutsu.getLeveling().numericAt(level);
        int chakra = nums.containsKey("cost") ? nums.get("cost").intValue()
                : jutsu.getCost().getOrDefault(ResourceType.CHAKRA, 0);
        if (data.getCurrentChakra() < chakra) {
            player.sendMessage(Text.literal("В§cNot enough chakra!"), false);
            return false;
        }
        data.setCurrentChakra(data.getCurrentChakra() - chakra);
        int fatigue = jutsu.getCost().getOrDefault(ResourceType.FATIGUE, 0);
        if (fatigue > 0) data.setFatigue(data.getFatigue() + fatigue);
        ShinobiCore.sendChakraSync(player);

        double scale = 1.0;
        if (nums.containsKey("damage")) {
            double d1 = jutsu.getLeveling().firstTableDamage();
            double dL = nums.get("damage");
            if (d1 > 0) scale = dL / d1;
        }

        List<PropertyDefinition> props = new ArrayList<>(jutsu.getProperties());
        for (String pid : jutsu.getLeveling().unlockedPropertiesAt(level)) {
            props.add(new PropertyDefinition(pid, new java.util.HashMap<>()));
        }
        List<EffectDefinition> effects = new ArrayList<>(jutsu.getEffects());
        effects.addAll(jutsu.getLeveling().unlockedEffectsAt(level));

        int multiCap = 0;
        for (PropertyDefinition p : props) {
            if (p.getId().equals("multi_target")) multiCap = p.getInt("count", 3);
        }

        CastContext ctx = new CastContext(player, jutsu, level, scale, props, effects, multiCap);

        // ===== ACTIVATION ROUTING =====
        ActivationDefinition act = jutsu.getActivation();
        switch (act.getType()) {
            case INSTANT, CONDITIONAL -> {
                VerificationLogger.logCast(player, id, jutsu.getActivation().getType().getId());
                FormExecutor.executeForm(ctx);
            }
            case HANDSEALS -> {
                int seals = act.getInt("sealCount", 3);
                double spd = act.getDouble("sealSpeed", 1.0);
                VerificationLogger.logActivation(id, "HANDSEALS", String.format("STARTED duration=%d seals=%d", (int) (seals * 10 / spd), seals));
                ActivationSystem.start(ctx, ActivationSystem.Mode.HANDSEALS, (int) (seals * 10 / spd), 0, 0);
                player.sendMessage(Text.literal("В§bWeaving " + seals + " seals..."), true);
            }
            case CHARGE -> {
                int min = act.getInt("minCharge", 20);
                int max = act.getInt("maxCharge", 60);
                VerificationLogger.logActivation(id, "CHARGE", String.format("STARTED duration=%d min=%d", max, min));
                ActivationSystem.start(ctx, ActivationSystem.Mode.CHARGE, max, min, 0);
                player.sendMessage(Text.literal("В§eCharging... В§7(/shinobicore jutsu release)"), true);
            }
            case HOLD -> {
                double drain = act.getDouble("chakraPerTick", 0.5);
                VerificationLogger.logCast(player, id, jutsu.getActivation().getType().getId());
                FormExecutor.executeForm(ctx);
                VerificationLogger.logActivation(id, "HOLD", "STARTED drain=" + drain);
                ActivationSystem.start(ctx, ActivationSystem.Mode.HOLD, Integer.MAX_VALUE, 0, drain);
                player.sendMessage(Text.literal("В§bChanneling... В§7(release to stop)"), true);
            }
            case COUNTER -> {
                int window = (int) (act.getDouble("windowMs", 400) / 50.0) + 1;
                double threshold = act.getDouble("damageThreshold", 1.0);
                VerificationLogger.logActivation(id, "COUNTER", String.format("STARTED window=%d threshold=%.1f", window * 4, threshold));
                ActivationSystem.start(ctx, ActivationSystem.Mode.COUNTER, window * 4, 0, threshold);
                player.sendMessage(Text.literal("В§eCounter stance!"), false);
            }
            case ON_DEATH -> {
                VerificationLogger.logActivation(id, "ON_DEATH", "STARTED (Izanagi armed)");
                ActivationSystem.start(ctx, ActivationSystem.Mode.ON_DEATH, Integer.MAX_VALUE, 0, 0);
                player.sendMessage(Text.literal("В§dIzanagi armed..."), false);
            }
            case PASSIVE -> {
                VerificationLogger.logActivation(id, "PASSIVE", "STARTED (aura active)");
                EffectExecutor.applyEffects(ctx, player);
                ActivationSystem.start(ctx, ActivationSystem.Mode.PASSIVE, Integer.MAX_VALUE, 0, 0);
                player.sendMessage(Text.literal("В§aPassive active В§7(release to disable)"), false);
            }
        }

        com.example.shinobicore.ai.AiSystem.notifyPlayerCast(player);
        double cd = jutsu.getCooldown();
        if (cd > 0) {
            CooldownSystem.start(uid, id, (int) (cd * 20));
            net.minecraft.network.PacketByteBuf cbuf = new net.minecraft.network.PacketByteBuf(io.netty.buffer.Unpooled.buffer());
            cbuf.writeString(id);
            cbuf.writeInt((int) (cd * 20));
            net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.send(player, com.example.shinobicore.network.ModPackets.COOLDOWN_SYNC_ID, cbuf);
        }
        prog.addUse(uid, id);
        VerificationLogger.logProgression(player, id, level, prog.getUses(uid, id));
        return true;
    }

    public static boolean beginCast(ServerPlayerEntity player, String jutsuId) {
        JutsuDefinition def = JutsuRegistry.get(jutsuId);
        if (def == null) return false;
        return cast(player, def);
    }
}