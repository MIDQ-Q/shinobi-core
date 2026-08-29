package com.example.shinobicore.command;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.component.IClanComponent;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.IDojutsuComponent;
import com.example.shinobicore.stat.component.IJutsuComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

/**
 * Test command for CCA components.
 * Usage: /test_components
 * HLD: Section 1.1
 */
public class TestComponentsCommand {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(
            CommandManager.literal("test_components")
                .requires(source -> source.hasPermissionLevel(2))
                .executes(TestComponentsCommand::execute)
        );
    }

    private static int execute(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }

        int passed = 0;
        int failed = 0;

        msg(player, "=== ShinobiCore Component Tests ===", "6");

        if (testChakra(player)) { passed++; msg(player, "[PASS] Chakra", "a"); }
        else { failed++; msg(player, "[FAIL] Chakra", "c"); }

        if (testStats(player)) { passed++; msg(player, "[PASS] Stats", "a"); }
        else { failed++; msg(player, "[FAIL] Stats", "c"); }

        if (testClan(player)) { passed++; msg(player, "[PASS] Clan", "a"); }
        else { failed++; msg(player, "[FAIL] Clan", "c"); }

        if (testJutsu(player)) { passed++; msg(player, "[PASS] Jutsu", "a"); }
        else { failed++; msg(player, "[FAIL] Jutsu", "c"); }

        if (testDojutsu(player)) { passed++; msg(player, "[PASS] Dojutsu", "a"); }
        else { failed++; msg(player, "[FAIL] Dojutsu", "c"); }

        String color = "a";
        if (failed > 0) color = "c";
        msg(player, "Results: " + passed + " passed, " + failed + " failed", color);

        return failed == 0 ? 1 : 0;
    }

    private static boolean testChakra(ServerPlayerEntity player) {
        IChakraComponent c = NinjaComponents.getChakra(player);
        if (c == null) return false;

        c.setCurrentChakra(500.0f);
        if (Math.abs(c.getCurrentChakra() - 500.0f) > 0.01f) return false;

        c.setFatigue(0.0f);
        c.addFatigue(50.0f);
        if (Math.abs(c.getFatigue() - 50.0f) > 0.01f) return false;

        c.addFatigue(60.0f);
        if (!c.isExhausted()) return false;

        c.setCurrentChakra(100.0f);
        if (!c.spendChakra(50.0f)) return false;
        if (Math.abs(c.getCurrentChakra() - 50.0f) > 0.01f) return false;

        if (c.spendChakra(200.0f)) return false;

        c.resetToDefaults();
        return true;
    }

    private static boolean testStats(ServerPlayerEntity player) {
        IStatsComponent s = NinjaComponents.getStats(player);
        if (s == null) return false;

        s.setStatLevel(StatType.NINJUTSU, 10);
        if (s.getStatLevel(StatType.NINJUTSU) != 10) return false;

        s.setStatXp(StatType.NINJUTSU, 0);
        s.setSkillPoints(10);
        s.addSkillPoints(5);
        if (s.getSkillPoints() != 15) return false;

        if (!s.spendSkillPoints(5)) return false;
        if (s.getSkillPoints() != 10) return false;

        if (s.spendSkillPoints(999)) return false;

        s.unlockPassive("test_passive");
        if (!s.hasPassive("test_passive")) return false;

        s.resetToDefaults();
        return true;
    }

    private static boolean testClan(ServerPlayerEntity player) {
        IClanComponent c = NinjaComponents.getClan(player);
        if (c == null) return false;

        c.setClanId("uchiha");
        if (!"uchiha".equals(c.getClanId())) return false;

        c.setReputation("senju", 0);
        c.modifyReputation("senju", 60);
        if (c.getReputation("senju") != 60) return false;
        if (!c.isAlly("senju")) return false;

        c.setReputation("akatsuki", -60);
        if (!c.isEnemy("akatsuki")) return false;

        c.setReputation("test", 0);
        c.modifyReputation("test", 200);
        if (c.getReputation("test") != 100) return false;

        c.setClanId(null);
        c.resetReputations();
        return true;
    }

    private static boolean testJutsu(ServerPlayerEntity player) {
        IJutsuComponent j = NinjaComponents.getJutsu(player);
        if (j == null) return false;

        if (!j.learnJutsu("fireball")) return false;
        if (!j.hasLearned("fireball")) return false;

        j.setLoadoutSlot(0, 0, "fireball");
        if (!"fireball".equals(j.getLoadoutSlot(0, 0))) return false;

        j.setActiveLoadout(0);
        j.toggleLoadout();
        if (j.getActiveLoadout() != 1) return false;

        j.forgetJutsu("fireball");
        if (j.hasLearned("fireball")) return false;

        j.resetAll();
        return true;
    }

    private static boolean testDojutsu(ServerPlayerEntity player) {
        IDojutsuComponent d = NinjaComponents.getDojutsu(player);
        if (d == null) return false;

        if (!d.activateDojutsu("sharingan")) return false;
        if (!"sharingan".equals(d.getActiveDojutsu())) return false;

        d.addUsage("sharingan", 10);
        if (d.getUsage("sharingan") != 10) return false;

        d.addStress("sharingan", 110.0f);
        if (!d.isBlinded()) return false;

        d.deactivateDojutsu();
        if (d.getActiveDojutsu() != null) return false;

        d.resetAll();
        return true;
    }

    private static void msg(ServerPlayerEntity player, String message, String colorCode) {
        player.sendMessage(Text.literal("\u00a7" + colorCode + message), false);
        ShinobiCore.LOGGER.info("[TestComponents] " + message);
    }
}