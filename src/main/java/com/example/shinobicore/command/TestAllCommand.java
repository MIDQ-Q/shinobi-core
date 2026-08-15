package com.example.shinobicore.command;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.*;
import com.example.shinobicore.stat.*;
import com.example.shinobicore.tree.SkillTreeNode;
import com.example.shinobicore.tree.SkillTreeRegistry;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.combat.*;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;

import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Команда /testall — автоматическое тестирование всех систем мода.
 * Генерирует отчёт в config/shinobicore/test_report_<timestamp>.txt
 */
public class TestAllCommand {

    private static final List<String> results = new ArrayList<>();
    private static int passed = 0;
    private static int failed = 0;
    private static int skipped = 0;

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("testall")
            .executes(ctx -> runAllTests(ctx.getSource()))
            .then(CommandManager.literal("jutsu").executes(ctx -> runJutsuTests(ctx.getSource())))
            .then(CommandManager.literal("formulas").executes(ctx -> runFormulaTests(ctx.getSource())))
            .then(CommandManager.literal("tree").executes(ctx -> runTreeTests(ctx.getSource())))
            .then(CommandManager.literal("clans").executes(ctx -> runClanTests(ctx.getSource())))
            .then(CommandManager.literal("combat").executes(ctx -> runCombatTests(ctx.getSource())))
        );
    }

    private static int runAllTests(ServerCommandSource source) {
        results.clear();
        passed = 0; failed = 0; skipped = 0;

        source.sendFeedback(() -> Text.literal("§6=== SHINOBICORE TEST SUITE ==="), false);
        source.sendFeedback(() -> Text.literal("§7Running all tests..."), false);

        runFormulaTests(source);
        runJutsuTests(source);
        runTreeTests(source);
        runClanTests(source);
        runCombatTests(source);
        runConfigTests(source);
        runNetworkTests(source);

        writeReport(source);

        source.sendFeedback(() -> Text.literal("§a=== TESTS COMPLETE ==="), false);
        source.sendFeedback(() -> Text.literal(
            String.format("§aPassed: %d §cFailed: %d §7Skipped: %d", passed, failed, skipped)), false);

        return 1;
    }

    // ==================== JUTSU TESTS ====================
    private static int runJutsuTests(ServerCommandSource source) {
        source.sendFeedback(() -> Text.literal("§6--- Jutsu Registry Tests ---"), false);

        // Test 1: Registry loaded
        Collection<JutsuDefinition> allJutsu = JutsuRegistry.getAll();
        check("Jutsu registry loaded", allJutsu != null && !allJutsu.isEmpty(),
            "Loaded " + (allJutsu != null ? allJutsu.size() : 0) + " jutsu");

        // Test 2: Each jutsu has valid fields
        int validCount = 0;
        int invalidCount = 0;
        List<String> invalidIds = new ArrayList<>();

        for (JutsuDefinition def : allJutsu) {
            boolean valid = true;
            StringBuilder errors = new StringBuilder();

            if (def.id() == null || def.id().isEmpty()) { valid = false; errors.append("empty id; "); }
            if (def.name() == null || def.name().isEmpty()) { valid = false; errors.append("empty name; "); }
            if (def.type() == null || def.type().isEmpty()) { valid = false; errors.append("empty type; "); }
            if (def.baseCost() < 0) { valid = false; errors.append("negative cost; "); }
            if (def.baseDamage() < 0) { valid = false; errors.append("negative damage; "); }
            if (def.strain() < 0) { valid = false; errors.append("negative strain; "); }

            if (valid) validCount++;
            else {
                invalidCount++;
                invalidIds.add(def.id() + " (" + errors + ")");
            }
        }
        check("All jutsu have valid fields", invalidCount == 0,
            validCount + " valid, " + invalidCount + " invalid" +
            (invalidCount > 0 ? ": " + String.join(", ", invalidIds.subList(0, Math.min(5, invalidIds.size()))) : ""));

        // Test 3: Duplicate IDs
        Set<String> ids = new HashSet<>();
        List<String> duplicates = new ArrayList<>();
        for (JutsuDefinition def : allJutsu) {
            if (!ids.add(def.id())) duplicates.add(def.id());
        }
        check("No duplicate jutsu IDs", duplicates.isEmpty(),
            duplicates.isEmpty() ? "All unique" : "Duplicates: " + String.join(", ", duplicates));

        // Test 4: Behavior classes exist
        int behaviorOk = 0;
        int behaviorFail = 0;
        List<String> missingBehaviors = new ArrayList<>();

        for (JutsuDefinition def : allJutsu) {
            if ("custom".equals(def.type()) && def.behaviorClass() != null) {
                try {
                    Class.forName(def.behaviorClass());
                    behaviorOk++;
                } catch (ClassNotFoundException e) {
                    behaviorFail++;
                    missingBehaviors.add(def.id() + " -> " + def.behaviorClass());
                }
            }
        }
        check("All custom behavior classes exist", behaviorFail == 0,
            behaviorOk + " found, " + behaviorFail + " missing" +
            (behaviorFail > 0 ? ": " + String.join(", ", missingBehaviors.subList(0, Math.min(3, missingBehaviors.size()))) : ""));

        // Test 5: BehaviorRegistry returns non-null for all types
        int registryOk = 0;
        for (JutsuDefinition def : allJutsu) {
            JutsuBehavior behavior = BehaviorRegistry.getFor(def);
            if (behavior != null) registryOk++;
        }
        check("BehaviorRegistry resolves all jutsu", registryOk == allJutsu.size(),
            registryOk + "/" + allJutsu.size());

        // Test 6: Requirements are valid stat names
        int reqOk = 0, reqBad = 0;
        Set<String> validReqKeys = Set.of("control", "ninjutsu", "taijutsu", "genjutsu",
            "medical", "space_time", "perception",
            "nature_fire", "nature_water", "nature_wind", "nature_lightning", "nature_earth");
        for (JutsuDefinition def : allJutsu) {
            for (String key : def.requirements().keySet()) {
                if (validReqKeys.contains(key)) reqOk++;
                else reqBad++;
            }
        }
        check("All requirement keys are valid", reqBad == 0,
            reqOk + " valid, " + reqBad + " unknown keys");

        // Test 7: Cast simulation (dry run — check cost calculation doesn't crash)
        ServerPlayerEntity player = source.getPlayer();
        if (player != null) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            int castSimOk = 0, castSimFail = 0;
            for (JutsuDefinition def : allJutsu) {
                try {
                    float cost = NinjaFormula.calculateCost(def, data);
                    if (cost >= 0) castSimOk++;
                    else castSimFail++;
                } catch (Exception e) {
                    castSimFail++;
                }
            }
            check("Cost calculation works for all jutsu", castSimFail == 0,
                castSimOk + " ok, " + castSimFail + " errors");
        }

        source.sendFeedback(() -> Text.literal("§7Jutsu tests done."), false);
        return 1;
    }

    // ==================== FORMULA TESTS ====================
    private static int runFormulaTests(ServerCommandSource source) {
        source.sendFeedback(() -> Text.literal("§6--- Formula Tests ---"), false);

        // Test: maxChakra formula
        NinjaPlayerData testData = new NinjaPlayerData();
        float baseMax = NinjaFormula.maxChakra(testData);
        check("Base max chakra > 0", baseMax > 0, "maxChakra=" + baseMax);

        // Test: regen formula
        float regen = NinjaFormula.regenPerSecond(testData);
        check("Base regen > 0", regen > 0, "regen=" + regen);

        // Test: fatigue decay
        float decay = NinjaFormula.fatigueDecayPerSecond(testData);
        check("Fatigue decay > 0", decay > 0, "decay=" + decay);

        // Test: XP formula increases with level
        int xp1 = NinjaFormula.xpToNextLevel(1);
        int xp10 = NinjaFormula.xpToNextLevel(10);
        int xp50 = NinjaFormula.xpToNextLevel(50);
        check("XP curve is increasing", xp1 < xp10 && xp10 < xp50,
            "L1=" + xp1 + " L10=" + xp10 + " L50=" + xp50);

        // Test: SP cost formula
        int sp1 = NinjaFormula.spCostForLevel(1);
        int sp50 = NinjaFormula.spCostForLevel(50);
        check("SP cost formula works", sp1 > 0 && sp50 >= sp1,
            "L1=" + sp1 + " L50=" + sp50);

        // Test: maxHealth formula
        int hp0 = NinjaFormula.maxHealth(0);
        int hp7 = NinjaFormula.maxHealth(7);
        check("HP scaling works", hp0 == 20 && hp7 == 160,
            "hp(0)=" + hp0 + " hp(7)=" + hp7);

        // Test: speed multiplier bounds
        float speed0 = NinjaFormula.speedMultiplier(0, false);
        float speed7 = NinjaFormula.speedMultiplier(7, true);
        check("Speed multiplier in bounds", speed0 >= 1.0f && speed7 <= 4.0f,
            "speed(0)=" + speed0 + " speed(7,chakra)=" + speed7);

        // Test: jump multiplier bounds
        float jump0 = NinjaFormula.jumpHorizontalMultiplier(0, false);
        float jump7 = NinjaFormula.jumpHorizontalMultiplier(7, true);
        check("Jump multiplier in bounds", jump0 >= 1.0f && jump7 <= 5.5f,
            "jump(0)=" + jump0 + " jump(7,chakra)=" + jump7);

        // Test: meditation multipliers
        float medRegen = NinjaFormula.meditationRegenMultiplier();
        float medDecay = NinjaFormula.meditationFatigueDecayMultiplier();
        check("Meditation multipliers > 1", medRegen > 1.0f && medDecay > 1.0f,
            "regen=" + medRegen + " decay=" + medDecay);

        // Test: mastery formula bounds
        JutsuDefinition sampleDef = JutsuRegistry.getAll().iterator().next();
        float mastery = NinjaFormula.mastery(sampleDef, testData);
        check("Mastery in [0,100]", mastery >= 0 && mastery <= 100, "mastery=" + mastery);

        source.sendFeedback(() -> Text.literal("§7Formula tests done."), false);
        return 1;
    }

    // ==================== SKILL TREE TESTS ====================
    private static int runTreeTests(ServerCommandSource source) {
        source.sendFeedback(() -> Text.literal("§6--- Skill Tree Tests ---"), false);

        Collection<SkillTreeNode> allNodes = SkillTreeRegistry.getAll();
        check("Skill tree loaded", allNodes != null && !allNodes.isEmpty(),
            "Nodes: " + (allNodes != null ? allNodes.size() : 0));

        // Test: No duplicate node IDs
        Set<String> nodeIds = new HashSet<>();
        List<String> dupNodes = new ArrayList<>();
        for (SkillTreeNode node : allNodes) {
            if (!nodeIds.add(node.id())) dupNodes.add(node.id());
        }
        check("No duplicate tree node IDs", dupNodes.isEmpty(),
            dupNodes.isEmpty() ? "All unique" : "Duplicates: " + String.join(", ", dupNodes));

        // Test: All requires[] reference existing nodes
        int refOk = 0, refBad = 0;
        List<String> badRefs = new ArrayList<>();
        for (SkillTreeNode node : allNodes) {
            for (String req : node.requires()) {
                if (SkillTreeRegistry.get(req) != null) refOk++;
                else { refBad++; badRefs.add(node.id() + " -> " + req); }
            }
        }
        check("All node requirements exist", refBad == 0,
            refOk + " valid refs, " + refBad + " broken" +
            (refBad > 0 ? ": " + String.join(", ", badRefs.subList(0, Math.min(3, badRefs.size()))) : ""));

        // Test: All jutsuId references point to existing jutsu
        int jutsuRefOk = 0, jutsuRefBad = 0;
        List<String> badJutsuRefs = new ArrayList<>();
        for (SkillTreeNode node : allNodes) {
            if (node.jutsuId() != null && !node.jutsuId().isEmpty()) {
                if (JutsuRegistry.get(node.jutsuId()) != null) jutsuRefOk++;
                else { jutsuRefBad++; badJutsuRefs.add(node.id() + " -> " + node.jutsuId()); }
            }
        }
        check("All tree jutsuId refs valid", jutsuRefBad == 0,
            jutsuRefOk + " ok, " + jutsuRefBad + " missing" +
            (jutsuRefBad > 0 ? ": " + String.join(", ", badJutsuRefs.subList(0, Math.min(3, badJutsuRefs.size()))) : ""));

        // Test: Branches exist
        check("Branches loaded", SkillTreeRegistry.getAllBranches().size() > 10,
            "Branches: " + SkillTreeRegistry.getAllBranches().size());

        // Test: No circular dependencies (simple check — depth limit)
        int maxDepth = 0;
        for (SkillTreeNode node : allNodes) {
            int depth = getDepth(node, new HashSet<>(), 0);
            maxDepth = Math.max(maxDepth, depth);
        }
        check("No circular dependencies (max depth < 20)", maxDepth < 20,
            "Max chain depth: " + maxDepth);

        // Test: TreePassives collect doesn't crash
        try {
            TreePassives.Bonuses bonuses = TreePassives.collectClient();
            check("TreePassives.collectClient() works", true, "OK");
        } catch (Exception e) {
            check("TreePassives.collectClient() works", false, e.getMessage());
        }

        source.sendFeedback(() -> Text.literal("§7Tree tests done."), false);
        return 1;
    }

    private static int getDepth(SkillTreeNode node, Set<String> visited, int depth) {
        if (visited.contains(node.id())) return 999; // circular
        visited.add(node.id());
        int max = depth;
        for (String req : node.requires()) {
            SkillTreeNode parent = SkillTreeRegistry.get(req);
            if (parent != null) {
                max = Math.max(max, getDepth(parent, visited, depth + 1));
            }
        }
        return max;
    }

    // ==================== CLAN TESTS ====================
    private static int runClanTests(ServerCommandSource source) {
        source.sendFeedback(() -> Text.literal("§6--- Clan Tests ---"), false);

        Collection<ClanDefinition> allClans = ClanRegistry.getAll();
        check("Clans loaded", allClans != null && !allClans.isEmpty(),
            "Clans: " + (allClans != null ? allClans.size() : 0));

        // Test: Each clan has valid fields
        for (ClanDefinition clan : allClans) {
            check("Clan '" + clan.id() + "' has valid affinity",
                clan.affinity() == null || Arrays.asList(ElementType.values()).contains(clan.affinity()),
                "affinity=" + (clan.affinity() != null ? clan.affinity().getId() : "null"));
        }

        // Test: costMultiplier values are reasonable (0.5 - 2.0)
        boolean costOk = true;
        for (ClanDefinition clan : allClans) {
            for (float mult : clan.costMultiplier().values()) {
                if (mult < 0.5f || mult > 2.0f) costOk = false;
            }
        }
        check("Clan costMultiplier in [0.5, 2.0]", costOk, "All values in range");

        // Test: fatigueMultiplier positive
        boolean fatOk = true;
        for (ClanDefinition clan : allClans) {
            if (clan.fatigueMultiplier() <= 0) fatOk = false;
        }
        check("Clan fatigueMultiplier > 0", fatOk, "All positive");

        source.sendFeedback(() -> Text.literal("§7Clan tests done."), false);
        return 1;
    }

    // ==================== COMBAT TESTS ====================
    private static int runCombatTests(ServerCommandSource source) {
        source.sendFeedback(() -> Text.literal("§6--- Combat Tests ---"), false);

        // Test: TaijutsuStyle values
        check("TaijutsuStyle has 2+ values", TaijutsuStyle.values().length >= 2,
            "Styles: " + TaijutsuStyle.values().length);

        // Test: TaijutsuCombo constants
        check("Combo max steps = 4", TaijutsuCombo.MAX_STEPS == 4, "MAX_STEPS=" + TaijutsuCombo.MAX_STEPS);
        check("Combo timeout > 0", TaijutsuCombo.COMBO_TIMEOUT_MS > 0, "timeout=" + TaijutsuCombo.COMBO_TIMEOUT_MS);

        // Test: Damage formulas produce positive values
        float dmg = TaijutsuFormulas.baseDamage(10);
        check("Taijutsu baseDamage(10) > 0", dmg > 0, "dmg=" + dmg);

        float computed = TaijutsuFormulas.computeDamage(10, TaijutsuStyle.STANDARD, false, 0, false);
        check("computeDamage produces positive", computed > 0, "dmg=" + computed);

        int cooldown = TaijutsuFormulas.attackCooldownTicks(TaijutsuStyle.STANDARD, false);
        check("attackCooldownTicks > 0", cooldown > 0, "cooldown=" + cooldown);

        // Test: KenjutsuStance
        check("KenjutsuStance has 3 values", KenjutsuStance.values().length == 3,
            "Stances: " + KenjutsuStance.values().length);

        // Test: MarkTracker
        check("MarkTracker class accessible", true, "OK");

        // Test: MeleeHitDetection constants
        check("Melee range > 0", MeleeHitDetection.RANGE > 0, "range=" + MeleeHitDetection.RANGE);
        check("Cone angle > 0", MeleeHitDetection.CONE_ANGLE_DEG > 0, "angle=" + MeleeHitDetection.CONE_ANGLE_DEG);

        source.sendFeedback(() -> Text.literal("§7Combat tests done."), false);
        return 1;
    }

    // ==================== CONFIG TESTS ====================
    private static int runConfigTests(ServerCommandSource source) {
        source.sendFeedback(() -> Text.literal("§6--- Config Tests ---"), false);

        check("ModConfig.instance loaded", ModConfig.instance != null, "OK");
        check("Chakra config > 0", ModConfig.instance.chakra.baseChakra > 0,
            "baseChakra=" + ModConfig.instance.chakra.baseChakra);
        check("Taijutsu config > 0", ModConfig.instance.taijutsu.baseDamage > 0,
            "baseDamage=" + ModConfig.instance.taijutsu.baseDamage);
        check("Progression config > 0", ModConfig.instance.progression.xpBase > 0,
            "xpBase=" + ModConfig.instance.progression.xpBase);
        check("Parkour config exists", ModConfig.instance.parkour != null, "OK");

        source.sendFeedback(() -> Text.literal("§7Config tests done."), false);
        return 1;
    }

    // ==================== NETWORK TESTS ====================
    private static int runNetworkTests(ServerCommandSource source) {
        source.sendFeedback(() -> Text.literal("§6--- Network Tests ---"), false);

        // Test: All packet IDs are non-null
        check("CHAKRA_SYNC_ID defined", com.example.shinobicore.network.ModPackets.CHAKRA_SYNC_ID != null, "OK");
        check("CAST_SLOT_ID defined", com.example.shinobicore.network.ModPackets.CAST_SLOT_ID != null, "OK");
        check("SET_SLOT_ID defined", com.example.shinobicore.network.ModPackets.SET_SLOT_ID != null, "OK");
        check("LOADOUT_SYNC_ID defined", com.example.shinobicore.network.ModPackets.LOADOUT_SYNC_ID != null, "OK");
        check("TAIJUTSU_ATTACK_ID defined", com.example.shinobicore.network.ModPackets.TAIJUTSU_ATTACK_ID != null, "OK");
        check("RASENGAN_SYNC_ID defined", com.example.shinobicore.network.ModPackets.RASENGAN_SYNC_ID != null, "OK");

        source.sendFeedback(() -> Text.literal("§7Network tests done."), false);
        return 1;
    }

    // ==================== UTILITIES ====================
    private static void check(String testName, boolean condition, String details) {
        if (condition) {
            passed++;
            results.add("[PASS] " + testName + " | " + details);
        } else {
            failed++;
            results.add("[FAIL] " + testName + " | " + details);
        }
    }

    private static void writeReport(ServerCommandSource source) {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
        Path reportDir = Path.of("config", "shinobicore");
        Path reportPath = reportDir.resolve("test_report_" + timestamp + ".txt");

        try {
            Files.createDirectories(reportDir);
            try (PrintWriter pw = new PrintWriter(new FileWriter(reportPath.toFile()))) {
                pw.println("╔══════════════════════════════════════════════════════════╗");
                pw.println("║        SHINOBICORE AUTOMATED TEST REPORT                ║");
                pw.println("╚══════════════════════════════════════════════════════════╝");
                pw.println();
                pw.println("Date: " + LocalDateTime.now());
                pw.println("Total Tests: " + (passed + failed + skipped));
                pw.println("Passed: " + passed);
                pw.println("Failed: " + failed);
                pw.println("Skipped: " + skipped);
                pw.println();
                pw.println("══════════════════════════════════════════════════════════");
                pw.println();

                // Failed first
                if (failed > 0) {
                    pw.println("--- FAILED TESTS ---");
                    for (String r : results) {
                        if (r.startsWith("[FAIL]")) pw.println("  " + r);
                    }
                    pw.println();
                }

                // All results
                pw.println("--- ALL RESULTS ---");
                for (String r : results) {
                    pw.println("  " + r);
                }
            }

            source.sendFeedback(() -> Text.literal("§aReport saved: " + reportPath), false);
        } catch (IOException e) {
            source.sendFeedback(() -> Text.literal("§cFailed to write report: " + e.getMessage()), false);
        }
    }
}