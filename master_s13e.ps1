# ============================================================
# SPRINT 13 FINAL: Test Command + Balance + Reputation
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$resBase = Join-Path $root "src\main\resources"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 13 FINAL: Test + Balance + Reputation" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("  [OK] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host ("  [MISS] " + $p) -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host ("  [SKIP] already: " + (Split-Path $p -Leaf)) -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host ("  [FAIL] pattern: " + (Split-Path $p -Leaf)) -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host ("  [PATCH] " + (Split-Path $p -Leaf)) -ForegroundColor Green
    return $true
}

# ============================================================
# SECTION 1: ClanBalance.json
# ============================================================
Write-Host "[1/4] Creating clan_balance.json..." -ForegroundColor Yellow

$balanceJson = @'
{
    "description": "S12-01: Clan balance configuration. All multipliers are applied to base values.",
    "clans": {
        "uchiha": {
            "fire_damage_mult": 1.10,
            "genjutsu_resist": 1.15,
            "chakra_cost_mult": 0.95
        },
        "hyuga": {
            "melee_damage_mult": 1.15,
            "accuracy_mult": 1.10,
            "byakugan_range_mult": 1.20
        },
        "uzumaki": {
            "max_chakra_mult": 1.20,
            "regen_mult": 1.10,
            "seal_duration_mult": 1.30
        },
        "senju": {
            "regen_mult": 1.10,
            "max_health_mult": 1.15,
            "wood_release_mult": 1.25
        },
        "nara": {
            "control_mult": 1.15,
            "cast_speed_mult": 1.10,
            "shadow_duration_mult": 1.40
        },
        "aburame": {
            "dot_damage_mult": 1.10,
            "poison_resist": 1.15,
            "insect_swarm_mult": 1.20
        },
        "inuzuka": {
            "move_speed_mult": 1.15,
            "dodge_mult": 1.10,
            "beast_sense_range_mult": 1.30
        },
        "akimichi": {
            "max_health_mult": 1.20,
            "melee_damage_mult": 1.10,
            "expansion_duration_mult": 1.25
        },
        "hatake": {
            "attack_speed_mult": 1.10,
            "lightning_damage_mult": 1.15,
            "copy_chance_mult": 1.20
        }
    },
    "global_balance": {
        "max_clan_bonus_stack": 3,
        "clan_technique_cost_reduction": 0.15,
        "universal_technique_cost_mult": 1.0
    }
}
'@
Write-File (Join-Path $resBase "data\shinobicore\config\clan_balance.json") $balanceJson

# ============================================================
# SECTION 2: ClanReputation.java
# ============================================================
Write-Host "[2/4] Creating ClanReputation..." -ForegroundColor Yellow

$reputationJava = @'
package com.example.shinobicore.clan;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.HashMap;
import java.util.Map;

/**
 * S12-06: Clan reputation system.
 * Tracks player reputation with each clan (-100 to +100).
 * Stored in NinjaPlayerData for persistence.
 */
public class ClanReputation {
    public static final int MIN_REP = -100;
    public static final int MAX_REP = 100;
    public static final int NEUTRAL = 0;
    public static final int FRIENDLY_THRESHOLD = 50;
    public static final int HOSTILE_THRESHOLD = -50;

    private static final String[] CLAN_IDS = {
        "uchiha", "hyuga", "uzumaki", "senju", "nara",
        "aburame", "inuzuka", "akimichi", "hatake"
    };

    /**
     * Get player's reputation with a specific clan.
     */
    public static int getReputation(ServerPlayerEntity player, String clanId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        Map<String, Integer> repMap = data.getClanReputation();
        return repMap.getOrDefault(clanId, NEUTRAL);
    }

    /**
     * Modify player's reputation with a clan.
     * @return New reputation value
     */
    public static int modifyReputation(ServerPlayerEntity player, String clanId, int amount) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        Map<String, Integer> repMap = data.getClanReputation();
        int current = repMap.getOrDefault(clanId, NEUTRAL);
        int newRep = Math.max(MIN_REP, Math.min(MAX_REP, current + amount));
        repMap.put(clanId, newRep);
        data.setClanReputation(repMap);

        // Notify player of significant changes
        if (Math.abs(amount) >= 10) {
            String clanName = clanId.substring(0, 1).toUpperCase() + clanId.substring(1);
            String change = amount > 0 ? "+" + amount : String.valueOf(amount);
            player.sendMessage(Text.literal("\u00a7e" + clanName + " reputation: " + change + " (now " + newRep + ")"), false);
        }

        return newRep;
    }

    /**
     * Get standing with a clan based on reputation.
     */
    public static Standing getStanding(ServerPlayerEntity player, String clanId) {
        int rep = getReputation(player, clanId);
        if (rep >= FRIENDLY_THRESHOLD) return Standing.FRIENDLY;
        if (rep <= HOSTILE_THRESHOLD) return Standing.HOSTILE;
        return Standing.NEUTRAL;
    }

    /**
     * Check if player is friendly with a clan.
     */
    public static boolean isFriendly(ServerPlayerEntity player, String clanId) {
        return getStanding(player, clanId) == Standing.FRIENDLY;
    }

    /**
     * Check if player is hostile with a clan.
     */
    public static boolean isHostile(ServerPlayerEntity player, String clanId) {
        return getStanding(player, clanId) == Standing.HOSTILE;
    }

    /**
     * Get reputation multiplier for clan-specific effects.
     * Friendly: 1.2x, Neutral: 1.0x, Hostile: 0.8x
     */
    public static float getReputationMultiplier(ServerPlayerEntity player, String clanId) {
        Standing standing = getStanding(player, clanId);
        switch (standing) {
            case FRIENDLY: return 1.2f;
            case HOSTILE: return 0.8f;
            default: return 1.0f;
        }
    }

    /**
     * Reset all clan reputations to neutral.
     */
    public static void resetAll(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        Map<String, Integer> repMap = new HashMap<>();
        for (String clanId : CLAN_IDS) {
            repMap.put(clanId, NEUTRAL);
        }
        data.setClanReputation(repMap);
        player.sendMessage(Text.literal("\u00a77All clan reputations reset to neutral."), false);
    }

    /**
     * Get all clan reputations for display.
     */
    public static Map<String, Integer> getAllReputations(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        return new HashMap<>(data.getClanReputation());
    }

    public enum Standing {
        FRIENDLY("\u00a7aFriendly"),
        NEUTRAL("\u00a77Neutral"),
        HOSTILE("\u00a7cHostile");

        private final String displayName;

        Standing(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() {
            return displayName;
        }
    }
}
'@
Write-File (Join-Path $srcBase "clan\ClanReputation.java") $reputationJava

# ============================================================
# SECTION 3: ShinobicoreTestCommand
# ============================================================
Write-Host "[3/4] Creating test command..." -ForegroundColor Yellow

$testCommand = @'
package com.example.shinobicore.command;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.clan.ClanReputation;
import com.example.shinobicore.dojutsu.DojutsuDefinition;
import com.example.shinobicore.dojutsu.DojutsuRegistry;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.entity.enemy.NinjaEnemyEntity;
import com.example.shinobicore.entity.enemy.NinjaRank;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.tree.SkillTreeNode;
import com.example.shinobicore.tree.SkillTreeRegistry;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.command.argument.EntityArgumentType;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import java.util.Collection;
import java.util.Map;

/**
 * S13-FINAL: Comprehensive test command for all systems.
 * Usage: /shinobicore_test [subcommand]
 */
public class ShinobicoreTestCommand {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore_test")
            .requires(source -> source.hasPermissionLevel(2))
            .then(CommandManager.literal("systems")
                .executes(ShinobicoreTestCommand::testAllSystems))
            .then(CommandManager.literal("balance")
                .executes(ShinobicoreTestCommand::testBalance))
            .then(CommandManager.literal("spawn")
                .then(CommandManager.argument("rank", StringArgumentType.word())
                    .suggests((ctx, builder) -> {
                        for (NinjaRank rank : NinjaRank.values()) {
                            builder.suggest(rank.getId());
                        }
                        return builder.buildFuture();
                    })
                    .executes(ShinobicoreTestCommand::spawnEnemy)))
            .then(CommandManager.literal("reputation")
                .then(CommandManager.argument("target", EntityArgumentType.players())
                    .executes(ShinobicoreTestCommand::showReputation)))
            .then(CommandManager.literal("reset_reputation")
                .executes(ShinobicoreTestCommand::resetReputation))
        );
    }

    private static int testAllSystems(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource source = ctx.getSource();
        ServerPlayerEntity player = source.getPlayer();

        sendTestHeader(player, "SHINOBICORE SYSTEM TEST");

        // Test 1: Jutsu Registry
        int jutsuCount = 0;
        try {
            for (JutsuDefinition def : JutsuRegistry.getAll()) {
                jutsuCount++;
            }
            sendTestResult(player, "Jutsu Registry", jutsuCount + " jutsu loaded", true);
        } catch (Exception e) {
            sendTestResult(player, "Jutsu Registry", "FAILED: " + e.getMessage(), false);
        }

        // Test 2: Clan Registry
        int clanCount = 0;
        try {
            for (ClanDefinition def : ClanRegistry.getAll()) {
                clanCount++;
            }
            sendTestResult(player, "Clan Registry", clanCount + " clans loaded", true);
        } catch (Exception e) {
            sendTestResult(player, "Clan Registry", "FAILED: " + e.getMessage(), false);
        }

        // Test 3: Skill Tree
        int nodeCount = 0;
        try {
            for (SkillTreeNode node : SkillTreeRegistry.getAllNodes()) {
                nodeCount++;
            }
            sendTestResult(player, "Skill Tree", nodeCount + " nodes loaded", true);
        } catch (Exception e) {
            sendTestResult(player, "Skill Tree", "FAILED: " + e.getMessage(), false);
        }

        // Test 4: Dojutsu Registry
        int dojutsuCount = 0;
        try {
            for (DojutsuDefinition def : DojutsuRegistry.getAll()) {
                dojutsuCount++;
            }
            sendTestResult(player, "Dojutsu Registry", dojutsuCount + " dojutsu loaded", true);
        } catch (Exception e) {
            sendTestResult(player, "Dojutsu Registry", "FAILED: " + e.getMessage(), false);
        }

        // Test 5: Entity Registration
        try {
            sendTestResult(player, "Entity Registration", "NinjaEnemy: " + (ModEntities.NINJA_ENEMY != null), true);
        } catch (Exception e) {
            sendTestResult(player, "Entity Registration", "FAILED: " + e.getMessage(), false);
        }

        // Test 6: Player Data
        if (player != null) {
            try {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                String clanId = data.getClanId();
                int gate = data.getActiveGate();
                sendTestResult(player, "Player Data", "Clan: " + clanId + ", Gate: " + gate, true);
            } catch (Exception e) {
                sendTestResult(player, "Player Data", "FAILED: " + e.getMessage(), false);
            }
        }

        sendTestFooter(player);
        return 1;
    }

    private static int testBalance(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource source = ctx.getSource();
        ServerPlayerEntity player = source.getPlayer();

        sendTestHeader(player, "CLAN BALANCE TEST");

        for (ClanDefinition clan : ClanRegistry.getAll()) {
            String clanId = clan.id();
            Map<String, Float> bonuses = clan.bonuses();
            if (bonuses != null && !bonuses.isEmpty()) {
                StringBuilder sb = new StringBuilder();
                for (Map.Entry<String, Float> entry : bonuses.entrySet()) {
                    sb.append(entry.getKey()).append("=").append(String.format("%.2f", entry.getValue())).append(", ");
                }
                String bonusStr = sb.length() > 2 ? sb.substring(0, sb.length() - 2) : "none";
                sendTestResult(player, clanId, bonusStr, true);
            } else {
                sendTestResult(player, clanId, "NO BONUSES", false);
            }
        }

        sendTestFooter(player);
        return 1;
    }

    private static int spawnEnemy(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource source = ctx.getSource();
        ServerPlayerEntity player = source.getPlayer();
        String rankId = StringArgumentType.getString(ctx, "rank");

        if (player == null) {
            source.sendError(Text.literal("Player required"));
            return 0;
        }

        NinjaRank rank = null;
        for (NinjaRank r : NinjaRank.values()) {
            if (r.getId().equals(rankId)) {
                rank = r;
                break;
            }
        }

        if (rank == null) {
            source.sendError(Text.literal("Unknown rank: " + rankId));
            return 0;
        }

        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos().add(3, 0, 3);

        NinjaEnemyEntity enemy = new NinjaEnemyEntity(ModEntities.NINJA_ENEMY, world);
        enemy.setRank(rank);
        enemy.setPosition(pos.getX() + 0.5, pos.getY(), pos.getZ() + 0.5);
        enemy.setTarget(player);
        world.spawnEntity(enemy);

        player.sendMessage(Text.literal("\u00a7aSpawned " + rank.getId() + " enemy at " + pos.toShortString()), false);
        return 1;
    }

    private static int showReputation(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource source = ctx.getSource();
        Collection<ServerPlayerEntity> targets = EntityArgumentType.getPlayers(ctx, "target");

        for (ServerPlayerEntity target : targets) {
            sendTestHeader(source.getPlayer(), "REPUTATION: " + target.getName().getString());
            Map<String, Integer> reps = ClanReputation.getAllReputations(target);
            for (Map.Entry<String, Integer> entry : reps.entrySet()) {
                String clanId = entry.getKey();
                int rep = entry.getValue();
                ClanReputation.Standing standing = ClanReputation.getStanding(target, clanId);
                String repStr = String.format("%d (%s)", rep, standing.getDisplayName());
                sendTestResult(source.getPlayer(), clanId, repStr, rep >= 0);
            }
            sendTestFooter(source.getPlayer());
        }

        return 1;
    }

    private static int resetReputation(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource source = ctx.getSource();
        ServerPlayerEntity player = source.getPlayer();

        if (player == null) {
            source.sendError(Text.literal("Player required"));
            return 0;
        }

        ClanReputation.resetAll(player);
        return 1;
    }

    private static void sendTestHeader(ServerPlayerEntity player, String title) {
        if (player == null) return;
        player.sendMessage(Text.literal(""), false);
        player.sendMessage(Text.literal("\u00a76\u2550".repeat(40)), false);
        player.sendMessage(Text.literal("\u00a7e\u2551 " + title + " \u00a7e\u2551"), false);
        player.sendMessage(Text.literal("\u00a76\u2550".repeat(40)), false);
    }

    private static void sendTestResult(ServerPlayerEntity player, String system, String result, boolean success) {
        if (player == null) return;
        String icon = success ? "\u00a7a\u2713" : "\u00a7c\u2717";
        player.sendMessage(Text.literal(icon + " \u00a77" + system + ": \u00a7f" + result), false);
    }

    private static void sendTestFooter(ServerPlayerEntity player) {
        if (player == null) return;
        player.sendMessage(Text.literal("\u00a76\u2550".repeat(40)), false);
        player.sendMessage(Text.literal(""), false);
    }
}
'@
Write-File (Join-Path $srcBase "command\ShinobicoreTestCommand.java") $testCommand

# ============================================================
# SECTION 4: Patches for integration
# ============================================================
Write-Host "[4/4] Patching integration points..." -ForegroundColor Yellow

# Add reputation field to NinjaPlayerData
$ninjaDataFile = Join-Path $srcBase "stat\NinjaPlayerData.java"
Patch-File $ninjaDataFile `
    "    private int gateCooldownTicks = 0;" `
    "    private int gateCooldownTicks = 0;`n    private java.util.Map<String, Integer> clanReputation = new java.util.HashMap<>();"

Patch-File $ninjaDataFile `
    "    public void setGateCooldownTicks(int v) { this.gateCooldownTicks = v; }" `
    "    public void setGateCooldownTicks(int v) { this.gateCooldownTicks = v; }`n    public java.util.Map<String, Integer> getClanReputation() { return clanReputation; }`n    public void setClanReputation(java.util.Map<String, Integer> rep) { this.clanReputation = rep; }"

# Register test command
$commandFile = Join-Path $srcBase "command\ModCommands.java"
if (Test-Path $commandFile) {
    Patch-File $commandFile `
        "import com.example.shinobicore.command.TestAllCommand;" `
        "import com.example.shinobicore.command.TestAllCommand;`nimport com.example.shinobicore.command.ShinobicoreTestCommand;"

    Patch-File $commandFile `
        "TestAllCommand.register(dispatcher);" `
        "TestAllCommand.register(dispatcher);`n        ShinobicoreTestCommand.register(dispatcher);"
} else {
    # Try alternative registration point
    $scFile = Join-Path $srcBase "ShinobiCore.java"
    Patch-File $scFile `
        "TestAllCommand.register(" `
        "com.example.shinobicore.command.ShinobicoreTestCommand.register(`n            dispatcher);`n        TestAllCommand.register("
}

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 20 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    }
} finally { Pop-Location }

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 13 FINAL PART 1 COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created:" -ForegroundColor White
Write-Host "  - clan_balance.json (configurable clan multipliers)" -ForegroundColor Cyan
Write-Host "  - ClanReputation.java (S12-06 reputation system)" -ForegroundColor Cyan
Write-Host "  - ShinobicoreTestCommand.java (comprehensive testing)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test commands:" -ForegroundColor Yellow
Write-Host "  /shinobicore_test systems    - Test all registries" -ForegroundColor White
Write-Host "  /shinobicore_test balance    - Show clan bonuses" -ForegroundColor White
Write-Host "  /shinobicore_test spawn <rank> - Spawn enemy" -ForegroundColor White
Write-Host "  /shinobicore_test reputation <player> - Show rep" -ForegroundColor White
Write-Host "  /shinobicore_test reset_reputation - Reset all" -ForegroundColor White
Write-Host ""