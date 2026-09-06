package com.example.shinobicore.modules.jutsu.requirement;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.core.RequirementsDefinition;
import com.example.shinobicore.jutsu.executor.CooldownSystem;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.ElementType;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.Map;

/**
 * Validates all requirements before a jutsu cast is allowed.
 * Returns a result with a human-readable fail reason.
 */
public final class JutsuRequirementService {
    private JutsuRequirementService() {}

    public static void init() {
        ShinobiCore.LOGGER.info("[JutsuRequirement] Ready.");
    }

    public static CheckResult check(ServerPlayerEntity player, JutsuDefinition def) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        String id = def.getId();

        // 1. Learned
        if (!data.getLearnedJutsus().contains(id) && !player.hasPermissionLevel(2)) {
            return CheckResult.fail("not_learned", "You haven't learned " + def.getName());
        }

        // 2. Cooldown
        if (CooldownSystem.isOnCooldown(player.getUuid(), id)) {
            int rem = CooldownSystem.getRemaining(player.getUuid(), id);
            return CheckResult.fail("cooldown", String.format("Cooldown: %.1fs", rem / 20.0));
        }

        // 3. Chakra
        int chakraCost = def.getCost().getOrDefault(
            com.example.shinobicore.jutsu.enums.ResourceType.CHAKRA, 0);
        if (data.getCurrentChakra() < chakraCost) {
            return CheckResult.fail("chakra", "Not enough chakra! Need " + chakraCost);
        }

        // 4. Stat requirements
        RequirementsDefinition req = def.getRequirements();
        if (req != null && req.getStats() != null) {
            for (Map.Entry<String, Integer> e : req.getStats().entrySet()) {
                StatType st = statById(e.getKey());
                if (st != null && data.getStatLevel(st) < e.getValue()) {
                    return CheckResult.fail("stat",
                        "Need " + e.getKey() + " " + e.getValue() +
                        " (have " + data.getStatLevel(st) + ")");
                }
            }
        }

        // 5. Element requirements
        if (req != null && req.getElements() != null) {
            for (Map.Entry<String, Integer> e : req.getElements().entrySet()) {
                ElementType el = elementById(e.getKey());
                if (el != null && data.getNatureLevel(el) < e.getValue()) {
                    return CheckResult.fail("element",
                        "Need " + e.getKey() + " level " + e.getValue());
                }
            }
        }

        // 6. Exhaustion
        if (data.isExhausted()) {
            return CheckResult.fail("exhausted", "You are exhausted!");
        }

        return CheckResult.ok();
    }

    public static void sendFailMessage(ServerPlayerEntity player, CheckResult result) {
        if (!result.ok) {
            player.sendMessage(Text.literal("\u00a7c" + result.message), true);
        }
    }

    private static StatType statById(String id) {
        for (StatType s : StatType.values()) if (s.getId().equals(id)) return s;
        return null;
    }

    private static ElementType elementById(String id) {
        for (ElementType e : ElementType.values()) if (e.getId().equals(id)) return e;
        return null;
    }

    public static class CheckResult {
        public final boolean ok;
        public final String reason;
        public final String message;

        private CheckResult(boolean ok, String reason, String message) {
            this.ok = ok; this.reason = reason; this.message = message;
        }
        public static CheckResult ok() { return new CheckResult(true, "", ""); }
        public static CheckResult fail(String reason, String message) {
            return new CheckResult(false, reason, message);
        }
    }
}