package com.example.shinobicore.command;

import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.stat.component.StatType;
import com.example.shinobicore.chakra.server.ServerChakraMirror;
import com.example.shinobicore.data.DataValidator;
import com.example.shinobicore.jutsu.data.JutsuRegistry;
import com.example.shinobicore.tree.SkillTreeRegistry;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.FloatArgumentType;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.loader.api.FabricLoader;
import net.fabricmc.loader.api.ModContainer;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

import java.util.Optional;

public final class ShinobiCommands {
    private static boolean registered = false;

    private ShinobiCommands() {}

    public static void register() {
        if (registered) return;
        registered = true;
        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            dispatcher.register(CommandManager.literal("shinobicore")
                .requires(source -> source.hasPermissionLevel(2))
                .then(CommandManager.literal("version").executes(ShinobiCommands::cmdVersion))
                .then(CommandManager.literal("systems").executes(ShinobiCommands::cmdSystems))
                .then(CommandManager.literal("components").executes(ShinobiCommands::cmdComponents))
                .then(CommandManager.literal("packets").executes(ShinobiCommands::cmdPackets))
                .then(CommandManager.literal("config")
                    .then(CommandManager.literal("reload").executes(ShinobiCommands::cmdConfigReload)))
                .then(CommandManager.literal("movement")
                    .then(CommandManager.literal("waterwalk")
                        .then(CommandManager.literal("test").executes(ShinobiCommands::cmdWaterWalkTest)))
                    .then(CommandManager.literal("meditation")
                        .then(CommandManager.literal("test").executes(ShinobiCommands::cmdMeditationTest))))
                .then(CommandManager.literal("chakra")
                    .then(CommandManager.literal("info").executes(ShinobiCommands::cmdChakraInfo))
                    .then(CommandManager.literal("set")
                        .then(CommandManager.argument("value", FloatArgumentType.floatArg(0, 99999))
                            .executes(ShinobiCommands::cmdChakraSet)))
                    .then(CommandManager.literal("add")
                        .then(CommandManager.argument("value", FloatArgumentType.floatArg(-99999, 99999))
                            .executes(ShinobiCommands::cmdChakraAdd)))
                    .then(CommandManager.literal("mode")
                        .then(CommandManager.literal("on").executes(ctx -> cmdChakraMode(ctx, true)))
                        .then(CommandManager.literal("off").executes(ctx -> cmdChakraMode(ctx, false))))
                    .then(CommandManager.literal("reset").executes(ShinobiCommands::cmdChakraReset)))
                .then(CommandManager.literal("stats")
                    .then(CommandManager.literal("info").executes(ShinobiCommands::cmdStatsInfo))
                    .then(CommandManager.literal("set")
                        .then(CommandManager.argument("stat", StringArgumentType.word())
                            .then(CommandManager.argument("level", IntegerArgumentType.integer(1, 100))
                                .executes(ShinobiCommands::cmdStatsSet))))
                    .then(CommandManager.literal("addxp")
                        .then(CommandManager.argument("stat", StringArgumentType.word())
                            .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 10000))
                                .executes(ShinobiCommands::cmdStatsAddXp))))
                    .then(CommandManager.literal("addsp")
                        .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 1000))
                            .executes(ShinobiCommands::cmdStatsAddSp))))
                .then(CommandManager.literal("data")
                    .then(CommandManager.literal("validate").executes(ShinobiCommands::cmdDataValidate)))
            );
        });
    }

    private static int cmdVersion(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> text("=== ShinobiCore Version ===", Formatting.GOLD), false);
        Optional<ModContainer> mod = FabricLoader.getInstance().getModContainer("shinobicore");
        String version = mod.map(m -> m.getMetadata().getVersion().getFriendlyString()).orElse("UNKNOWN");
        src.sendFeedback(() -> text("Mod version: " + version, Formatting.WHITE), false);
        String mcVersion = FabricLoader.getInstance().getModContainer("minecraft")
                .map(m -> m.getMetadata().getVersion().getFriendlyString()).orElse("?");
        src.sendFeedback(() -> text("Minecraft: " + mcVersion, Formatting.WHITE), false);
        String loaderVersion = FabricLoader.getInstance().getModContainer("fabricloader")
                .map(m -> m.getMetadata().getVersion().getFriendlyString()).orElse("?");
        src.sendFeedback(() -> text("Fabric Loader: " + loaderVersion, Formatting.WHITE), false);
        src.sendFeedback(() -> text("--- Optional Mods ---", Formatting.GRAY), false);
        printModStatus(src, "bettercombat", "Better Combat");
        printModStatus(src, "geckolib", "GeckoLib");
        printModStatus(src, "cloth-config", "Cloth Config");
        printModStatus(src, "player-animator", "Player Animator");
        printModStatus(src, "irons_spells", "Iron's Spells");
        return 1;
    }

    private static int cmdSystems(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> text("=== ShinobiCore Systems ===", Formatting.GOLD), false);
        printSystem(src, "Logger", true);
        printSystem(src, "Commands", true);
        printSystem(src, "VFX Manager", true);
        printSystem(src, "Packets", true);
        printSystem(src, "Components", checkComponents());
        printSystem(src, "Data Loaders", checkDataLoaders());
        printSystem(src, "Worldgen", true);
        printSystem(src, "Legacy Taijutsu", false);
        printSystem(src, "Legacy Parkour", false);
        printSystem(src, "Wall Walk", false);
        return 1;
    }

    private static int cmdComponents(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        if (!(src.getEntity() instanceof ServerPlayerEntity player)) {
            src.sendError(Text.literal("Must be run by a player"));
            return 0;
        }
        src.sendFeedback(() -> text("=== Components for " + player.getName().getString() + " ===", Formatting.GOLD), false);
        
        try {
            var chakraOpt = NinjaComponents.CHAKRA.maybeGet(player);
            if (chakraOpt.isPresent()) {
                var chakra = chakraOpt.get();
                src.sendFeedback(() -> text("[CHAKRA] current=" + chakra.getCurrentChakra()
                        + " max=" + chakra.getMaxChakra(), Formatting.AQUA), false);
            } else {
                src.sendFeedback(() -> text("[CHAKRA] NOT FOUND", Formatting.RED), false);
            }
        } catch (Exception e) {
            src.sendFeedback(() -> text("[CHAKRA] ERROR: " + e.getMessage(), Formatting.RED), false);
        }

        try {
            var statsOpt = NinjaComponents.STATS.maybeGet(player);
            if (statsOpt.isPresent()) {
                var stats = statsOpt.get();
                src.sendFeedback(() -> text("[STATS] Found (ninjutsu=" + stats.getStatLevel(StatType.NINJUTSU)
                        + " taijutsu=" + stats.getStatLevel(StatType.TAIJUTSU)
                        + " control=" + stats.getStatLevel(StatType.CONTROL) + ")", Formatting.AQUA), false);
            } else {
                src.sendFeedback(() -> text("[STATS] NOT FOUND", Formatting.RED), false);
            }
        } catch (Exception e) {
            src.sendFeedback(() -> text("[STATS] ERROR: " + e.getMessage(), Formatting.RED), false);
        }

        try {
            var clanOpt = NinjaComponents.CLAN.maybeGet(player);
            if (clanOpt.isPresent()) {
                var clan = clanOpt.get();
                src.sendFeedback(() -> text("[CLAN] id=" + clan.getClanId(), Formatting.AQUA), false);
            } else {
                src.sendFeedback(() -> text("[CLAN] NOT FOUND", Formatting.RED), false);
            }
        } catch (Exception e) {
            src.sendFeedback(() -> text("[CLAN] ERROR: " + e.getMessage(), Formatting.RED), false);
        }

        try {
            var jutsuOpt = NinjaComponents.JUTSU.maybeGet(player);
            if (jutsuOpt.isPresent()) {
                src.sendFeedback(() -> text("[JUTSU] Found", Formatting.AQUA), false);
            } else {
                src.sendFeedback(() -> text("[JUTSU] NOT FOUND", Formatting.RED), false);
            }
        } catch (Exception e) {
            src.sendFeedback(() -> text("[JUTSU] ERROR: " + e.getMessage(), Formatting.RED), false);
        }

        try {
            var dojutsuOpt = NinjaComponents.DOJUTSU.maybeGet(player);
            if (dojutsuOpt.isPresent()) {
                src.sendFeedback(() -> text("[DOJUTSU] Found", Formatting.AQUA), false);
            } else {
                src.sendFeedback(() -> text("[DOJUTSU] NOT FOUND", Formatting.RED), false);
            }
        } catch (Exception e) {
            src.sendFeedback(() -> text("[DOJUTSU] ERROR: " + e.getMessage(), Formatting.RED), false);
        }
        return 1;
    }

    private static int cmdPackets(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> text("=== Registered Packets ===", Formatting.GOLD), false);
        String[] packets = {
                "shinobicore:vfx_spawn_v3",
                "shinobicore:chakra_client_state",
                "shinobicore:movement_action",
                "shinobicore:component_sync"
        };
        for (String p : packets) {
            src.sendFeedback(() -> text("  " + p, Formatting.WHITE), false);
        }
        return 1;
    }

    private static int cmdDataValidate(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> text("=== Data Validation ===", Formatting.GOLD), false);
        DataValidator.ValidationResult result = DataValidator.validate();
        src.sendFeedback(() -> text("Jutsu loaded: " + JutsuRegistry.getAll().size(), Formatting.WHITE), false);
        src.sendFeedback(() -> text("Clans loaded: " + ClanRegistry.getAll().size(), Formatting.WHITE), false);
        src.sendFeedback(() -> text("Skill tree nodes: " + SkillTreeRegistry.getAll().size(), Formatting.WHITE), false);
        if (result.hasErrors()) {
            src.sendFeedback(() -> text("Errors: " + result.errorCount(), Formatting.RED), false);
            result.errors().stream().limit(5).forEach(err ->
                    src.sendFeedback(() -> text("  - " + err, Formatting.RED), false)
            );
            if (result.errorCount() > 5) {
                src.sendFeedback(() -> text("  ... and " + (result.errorCount() - 5) + " more errors", Formatting.GRAY), false);
            }
        } else {
            src.sendFeedback(() -> text("Errors: 0", Formatting.GREEN), false);
        }
        return 1;
    }

    private static void printModStatus(ServerCommandSource src, String modId, String displayName) {
        boolean loaded = FabricLoader.getInstance().isModLoaded(modId);
        Formatting color = loaded ? Formatting.GREEN : Formatting.GRAY;
        String status = loaded ? "LOADED" : "not found";
        src.sendFeedback(() -> text("  " + displayName + ": " + status, color), false);
    }

    private static void printSystem(ServerCommandSource src, String name, boolean active) {
        Formatting color = active ? Formatting.GREEN : Formatting.RED;
        String status = active ? "OK" : "DISABLED";
        src.sendFeedback(() -> text("  " + name + ": " + status, color), false);
    }

    private static boolean checkComponents() {
        try {
            Class.forName("com.example.shinobicore.stat.component.NinjaComponents");
            return true;
        } catch (ClassNotFoundException e) {
            return false;
        }
    }

    private static boolean checkDataLoaders() {
        try {
            Class.forName("com.example.shinobicore.data.DataValidator");
            return true;
        } catch (ClassNotFoundException e) {
            return false;
        }
    }

    private static int cmdConfigReload(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        ShinobiCoreConfig.reload();
        src.sendFeedback(() -> text("Config reloaded successfully.", Formatting.GREEN), false);
        return 1;
    }

    private static ServerPlayerEntity getExecutingPlayer(CommandContext<ServerCommandSource> ctx) {
        try {
            return ctx.getSource().getPlayerOrThrow();
        } catch (Exception e) {
            return null;
        }
    }

    private static int cmdChakraInfo(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        ServerPlayerEntity player = getExecutingPlayer(ctx);
        if (player == null) { src.sendError(Text.literal("Must be run by a player")); return 0; }
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (chakra == null) { src.sendError(Text.literal("Chakra component not found")); return 0; }
        
        src.sendFeedback(() -> text("=== Chakra Info ===", Formatting.GOLD), false);
        src.sendFeedback(() -> text(String.format("Current: %.1f / %.1f", chakra.getCurrentChakra(), chakra.getMaxChakra()), Formatting.WHITE), false);
        src.sendFeedback(() -> text(String.format("Fatigue: %.1f", chakra.getFatigue()), Formatting.WHITE), false);
        src.sendFeedback(() -> text("Mode: " + (chakra.isChakraMode() ? "ON" : "OFF"), chakra.isChakraMode() ? Formatting.GREEN : Formatting.RED), false);
        src.sendFeedback(() -> text("Exhausted: " + chakra.isExhausted(), chakra.isExhausted() ? Formatting.RED : Formatting.GREEN), false);
        src.sendFeedback(() -> text("Meditating: " + chakra.isMeditating(), chakra.isMeditating() ? Formatting.GREEN : Formatting.GRAY), false);
        return 1;
    }

    private static int cmdChakraSet(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        ServerPlayerEntity player = getExecutingPlayer(ctx);
        if (player == null) { src.sendError(Text.literal("Must be a player")); return 0; }
        float value = FloatArgumentType.getFloat(ctx, "value");
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (chakra == null) return 0;
        
        ServerChakraMirror.applyAdminSet(player, value, chakra.getMaxChakra(), chakra.getFatigue(), chakra.isChakraMode(), chakra.isExhausted());
        ModPackets.sendAdminSet(player, value, chakra.getMaxChakra(), chakra.getFatigue(), chakra.isChakraMode(), chakra.isExhausted());
        src.sendFeedback(() -> text("Chakra set to " + value, Formatting.GREEN), false);
        return 1;
    }

    private static int cmdChakraAdd(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        ServerPlayerEntity player = getExecutingPlayer(ctx);
        if (player == null) { src.sendError(Text.literal("Must be a player")); return 0; }
        float value = FloatArgumentType.getFloat(ctx, "value");
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (chakra == null) return 0;
        
        float newCurrent = Math.max(0, chakra.getCurrentChakra() + value);
        ServerChakraMirror.applyAdminSet(player, newCurrent, chakra.getMaxChakra(), chakra.getFatigue(), chakra.isChakraMode(), chakra.isExhausted());
        ModPackets.sendAdminSet(player, newCurrent, chakra.getMaxChakra(), chakra.getFatigue(), chakra.isChakraMode(), chakra.isExhausted());
        src.sendFeedback(() -> text("Chakra added: " + value, Formatting.GREEN), false);
        return 1;
    }

    private static int cmdChakraMode(CommandContext<ServerCommandSource> ctx, boolean mode) {
        ServerCommandSource src = ctx.getSource();
        ServerPlayerEntity player = getExecutingPlayer(ctx);
        if (player == null) { src.sendError(Text.literal("Must be a player")); return 0; }
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (chakra == null) return 0;
        
        ServerChakraMirror.applyAdminSet(player, chakra.getCurrentChakra(), chakra.getMaxChakra(), chakra.getFatigue(), mode, chakra.isExhausted());
        ModPackets.sendAdminSet(player, chakra.getCurrentChakra(), chakra.getMaxChakra(), chakra.getFatigue(), mode, chakra.isExhausted());
        src.sendFeedback(() -> text("Chakra mode set to " + (mode ? "ON" : "OFF"), Formatting.GREEN), false);
        return 1;
    }

    private static int cmdChakraReset(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        ServerPlayerEntity player = getExecutingPlayer(ctx);
        if (player == null) { src.sendError(Text.literal("Must be a player")); return 0; }
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (chakra == null) return 0;
        
        chakra.resetToDefaults();
        ModPackets.sendAdminSet(player, chakra.getCurrentChakra(), chakra.getMaxChakra(), 0.0f, false, false);
        src.sendFeedback(() -> text("Chakra reset to defaults", Formatting.GREEN), false);
        return 1;
    }

    private static int cmdWaterWalkTest(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        ServerPlayerEntity player = getExecutingPlayer(ctx);
        if (player == null) { src.sendError(Text.literal("Must be a player")); return 0; }
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (chakra == null) return 0;
        
        chakra.setChakraMode(true);
        ModPackets.sendAdminSet(player, chakra.getCurrentChakra(), chakra.getMaxChakra(), chakra.getFatigue(), true, chakra.isExhausted());
        src.sendFeedback(() -> text("Chakra mode enabled. Walk onto water to test.", Formatting.GREEN), false);
        return 1;
    }

    private static int cmdMeditationTest(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> text("Meditation test: Press M on ground.", Formatting.GREEN), false);
        return 1;
    }

    // === SPRINT A: STATS COMMANDS ===
    private static int cmdStatsInfo(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        ServerPlayerEntity player = getExecutingPlayer(ctx);
        if (player == null) { src.sendError(Text.literal("Must be a player")); return 0; }
        IStatsComponent stats = NinjaComponents.getStats(player);
        if (stats == null) { src.sendError(Text.literal("Stats component not found")); return 0; }
        
        src.sendFeedback(() -> text("=== Stats Info ===", Formatting.GOLD), false);
        for (StatType type : StatType.values()) {
            int level = stats.getStatLevel(type);
            int xp = stats.getStatXp(type);
            int required = stats.getXpForNextLevel(type);
            src.sendFeedback(() -> text(String.format("%s: Lv %d | XP %d/%d", type.getDisplayName(), level, xp, required), Formatting.WHITE), false);
        }
        src.sendFeedback(() -> text("SP: " + stats.getSkillPoints(), Formatting.AQUA), false);
        return 1;
    }

    private static int cmdStatsSet(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        ServerPlayerEntity player = getExecutingPlayer(ctx);
        if (player == null) return 0;
        String statId = StringArgumentType.getString(ctx, "stat");
        int level = IntegerArgumentType.getInteger(ctx, "level");
        StatType type = StatType.fromId(statId);
        if (type == null) { src.sendError(Text.literal("Unknown stat: " + statId)); return 0; }
        
        IStatsComponent stats = NinjaComponents.getStats(player);
        if (stats == null) return 0;
        stats.setStatLevel(type, level);
        src.sendFeedback(() -> text("Set " + statId + " to level " + level, Formatting.GREEN), false);
        return 1;
    }

    private static int cmdStatsAddXp(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        ServerPlayerEntity player = getExecutingPlayer(ctx);
        if (player == null) return 0;
        String statId = StringArgumentType.getString(ctx, "stat");
        int amount = IntegerArgumentType.getInteger(ctx, "amount");
        StatType type = StatType.fromId(statId);
        if (type == null) { src.sendError(Text.literal("Unknown stat: " + statId)); return 0; }
        
        IStatsComponent stats = NinjaComponents.getStats(player);
        if (stats == null) return 0;
        stats.addXp(type, amount);
        src.sendFeedback(() -> text("Added " + amount + " XP to " + statId, Formatting.GREEN), false);
        return 1;
    }

    private static int cmdStatsAddSp(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        ServerPlayerEntity player = getExecutingPlayer(ctx);
        if (player == null) return 0;
        int amount = IntegerArgumentType.getInteger(ctx, "amount");
        IStatsComponent stats = NinjaComponents.getStats(player);
        if (stats == null) return 0;
        stats.addSkillPoints(amount);
        src.sendFeedback(() -> text("Added " + amount + " SP", Formatting.GREEN), false);
        return 1;
    }

    private static Text text(String msg, Formatting color) {
        return Text.literal(msg).formatted(color);
    }
}