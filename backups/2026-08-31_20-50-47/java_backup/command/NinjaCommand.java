package com.example.shinobicore.command;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.FloatArgumentType;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.builder.ArgumentBuilder;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.suggestion.Suggestions;
import com.mojang.brigadier.suggestion.SuggestionsBuilder;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

import java.util.concurrent.CompletableFuture;

public class NinjaCommand {
    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("ninja")
                .then(CommandManager.literal("info").executes(ctx -> info(ctx.getSource())))
                .then(setBranch())
                .then(giveBranch())
                .then(jutsuBranch())
                .then(CommandManager.literal("learn")
                        .then(CommandManager.argument("id", StringArgumentType.greedyString())
                                .suggests(NinjaCommand::suggestJutsu)
                                .executes(ctx -> learn(ctx.getSource(), StringArgumentType.getString(ctx, "id")))))
                .then(CommandManager.literal("cast")
                        .then(CommandManager.argument("id", StringArgumentType.greedyString())
                                .executes(ctx -> {
                                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                                    return JutsuCaster.cast(p, normalizeId(StringArgumentType.getString(ctx, "id"))) ? 1 : 0;
                                })))
                .then(slotBranch())
                .then(clanBranch())
                .then(CommandManager.literal("reloadconfig").executes(ctx -> {
                    ModConfig.load();
                    ctx.getSource().sendFeedback(() -> Text.literal("§aConfig reloaded"), false);
                    return 1;
                }))
        );
    }

    private static ArgumentBuilder<ServerCommandSource, ?> setBranch() {
        return CommandManager.literal("set")
                .then(CommandManager.literal("chakra").then(CommandManager.argument("value", FloatArgumentType.floatArg(0, 100000))
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            data(p).setCurrentChakra(FloatArgumentType.getFloat(ctx, "value"));
                            ShinobiCore.sendChakraSync(p);
                            return feedback(ctx.getSource(), "Chakra set");
                        })))
                .then(CommandManager.literal("fatigue").then(CommandManager.argument("value", FloatArgumentType.floatArg(0, 100))
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            data(p).setFatigue(FloatArgumentType.getFloat(ctx, "value"));
                            ShinobiCore.sendChakraSync(p);
                            return feedback(ctx.getSource(), "Fatigue set");
                        })))
                .then(CommandManager.literal("stat").then(CommandManager.argument("id", StringArgumentType.word())
                        .suggests(NinjaCommand::suggestStats)
                        .then(CommandManager.argument("value", IntegerArgumentType.integer(0, 100))
                                .executes(ctx -> {
                                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                                    StatType s = statById(StringArgumentType.getString(ctx, "id"));
                                    if (s == null) return feedback(ctx.getSource(), "§cUnknown stat");
                                    data(p).setStatLevel(s, IntegerArgumentType.getInteger(ctx, "value"));
                                    ShinobiCore.sendStatsSync(p);
                                    return feedback(ctx.getSource(), "Set " + s.getId());
                                }))))
                .then(CommandManager.literal("nature").then(CommandManager.argument("id", StringArgumentType.word())
                        .suggests(NinjaCommand::suggestElements)
                        .then(CommandManager.argument("value", IntegerArgumentType.integer(0, 100))
                                .executes(ctx -> {
                                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                                    ElementType e = elementById(StringArgumentType.getString(ctx, "id"));
                                    if (e == null) return feedback(ctx.getSource(), "§cUnknown nature");
                                    int v = IntegerArgumentType.getInteger(ctx, "value");
                                    data(p).setNatureLevel(e, v);
                                    if (v > 0) data(p).setNatureUnlocked(e, true);
                                    ShinobiCore.sendStatsSync(p);
                                    return feedback(ctx.getSource(), "Set " + e.getId());
                                }))))
                // === ИЗМЕНЕНО: принимаем строку, проверяем существование в ClanRegistry ===
                .then(CommandManager.literal("clan").then(CommandManager.argument("id", StringArgumentType.word())
                        .suggests(NinjaCommand::suggestClans)
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            String id = StringArgumentType.getString(ctx, "id");
                            ClanDefinition clan = ClanRegistry.get(id);
                            if (clan == null) return feedback(ctx.getSource(), "§cUnknown clan: " + id);
                            data(p).setClanId(id);
                            ShinobiCore.sendBodySync(p);
                            return feedback(ctx.getSource(), "Clan set to " + id);
                        })))
                .then(CommandManager.literal("affinity").then(CommandManager.argument("id", StringArgumentType.word())
                        .suggests(NinjaCommand::suggestElements)
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            data(p).setAffinity(elementById(StringArgumentType.getString(ctx, "id")));
                            ShinobiCore.sendBodySync(p);
                            return feedback(ctx.getSource(), "Affinity set");
                        })));
    }

    private static ArgumentBuilder<ServerCommandSource, ?> giveBranch() {
        return CommandManager.literal("give")
                .then(CommandManager.literal("xp")
                        .then(CommandManager.literal("stat").then(CommandManager.argument("id", StringArgumentType.word())
                                .suggests(NinjaCommand::suggestStats)
                                .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                                        .executes(ctx -> {
                                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                                            StatType s = statById(StringArgumentType.getString(ctx, "id"));
                                            if (s == null) return feedback(ctx.getSource(), "§cUnknown stat");
                                            NinjaFormula.addStatXp(data(p), s, IntegerArgumentType.getInteger(ctx, "amount"));
                                            ShinobiCore.sendStatsSync(p);
                                            return feedback(ctx.getSource(), "XP given");
                                        }))))
                        .then(CommandManager.literal("nature").then(CommandManager.argument("id", StringArgumentType.word())
                                .suggests(NinjaCommand::suggestElements)
                                .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                                        .executes(ctx -> {
                                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                                            ElementType e = elementById(StringArgumentType.getString(ctx, "id"));
                                            if (e == null) return feedback(ctx.getSource(), "§cUnknown nature");
                                            NinjaFormula.addNatureXp(data(p), e, IntegerArgumentType.getInteger(ctx, "amount"));
                                            ShinobiCore.sendStatsSync(p);
                                            return feedback(ctx.getSource(), "XP given");
                                        }))))
                        .then(CommandManager.literal("reserve").then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                                .executes(ctx -> {
                                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                                    NinjaFormula.addReserveXp(data(p), IntegerArgumentType.getInteger(ctx, "amount"));
                                    ShinobiCore.sendStatsSync(p);
                                    ShinobiCore.sendChakraSync(p);
                                    return feedback(ctx.getSource(), "XP given");
                                }))))
                .then(CommandManager.literal("sp").then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            data(p).addSkillPoints(IntegerArgumentType.getInteger(ctx, "amount"));
                            ShinobiCore.sendStatsSync(p);
                            return feedback(ctx.getSource(), "SP added");
                        })));
    }

    private static ArgumentBuilder<ServerCommandSource, ?> jutsuBranch() {
        return CommandManager.literal("jutsu")
                .then(CommandManager.literal("list").executes(ctx -> {
                    StringBuilder sb = new StringBuilder("=== Jutsu ===\n");
                    for (JutsuDefinition def : JutsuRegistry.getAll()) {
                        sb.append("- ").append(def.id()).append(" [").append(def.type()).append("]\n");
                    }
                    ctx.getSource().sendFeedback(() -> Text.literal(sb.toString()), false);
                    return 1;
                }))
                .then(CommandManager.literal("info").then(CommandManager.argument("id", StringArgumentType.greedyString())
                        .executes(ctx -> {
                            JutsuDefinition def = JutsuRegistry.get(normalizeId(StringArgumentType.getString(ctx, "id")));
                            if (def == null) return feedback(ctx.getSource(), "§cNot found");
                            ctx.getSource().sendFeedback(() -> Text.literal(
                                    def.name() + "\n" +
                                            "§7type=" + def.type() +
                                            " nature=" + (def.hasNature() ? def.nature().getId() : "none") +
                                            " cost=" + def.baseCost() + " dmg=" + def.baseDamage()), false);
                            return 1;
                        })));
    }

    private static ArgumentBuilder<ServerCommandSource, ?> slotBranch() {
        return CommandManager.literal("slot")
                .then(CommandManager.literal("a").then(slotSet(0)))
                .then(CommandManager.literal("b").then(slotSet(1)));
    }

    private static ArgumentBuilder<ServerCommandSource, ?> slotSet(int set) {
        return CommandManager.argument("num", IntegerArgumentType.integer(1, 5))
                .then(CommandManager.argument("id", StringArgumentType.greedyString())
                        .suggests((ctx, b) -> {
                            b.suggest("none");
                            for (JutsuDefinition def : JutsuRegistry.getAll()) b.suggest(def.id());
                            return b.buildFuture();
                        })
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            String id = StringArgumentType.getString(ctx, "id");
                            String clean = id.equals("none") ? null : normalizeId(id);
                            if (clean != null && !data(p).getLearnedJutsus().contains(clean)) {
                                return feedback(ctx.getSource(), "§cLearn it first!");
                            }
                            data(p).setLoadoutSlot(set, IntegerArgumentType.getInteger(ctx, "num") - 1, clean);
                            ShinobiCore.sendLoadoutSync(p);
                            return feedback(ctx.getSource(), "Slot set");
                        }));
    }

    private static ArgumentBuilder<ServerCommandSource, ?> clanBranch() {
        return CommandManager.literal("clan")
                .then(CommandManager.literal("list").executes(ctx -> {
                    StringBuilder sb = new StringBuilder("=== Clans ===\n");
                    for (ClanDefinition c : ClanRegistry.getAll()) {
                        sb.append("- ").append(c.id()).append(" (").append(c.name()).append(")\n");
                    }
                    ctx.getSource().sendFeedback(() -> Text.literal(sb.toString()), false);
                    return 1;
                }))
                // === ИЗМЕНЕНО: принимаем строку, проверяем существование ===
                .then(CommandManager.literal("choose").then(CommandManager.argument("id", StringArgumentType.word())
                        .suggests(NinjaCommand::suggestClans)
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            String id = StringArgumentType.getString(ctx, "id");
                            ClanDefinition clan = ClanRegistry.get(id);
                            if (clan == null) return feedback(ctx.getSource(), "§cUnknown clan: " + id);
                            data(p).setClanId(id);
                            data(p).setClanChosen(true);
                            ShinobiCore.sendBodySync(p);
                            return feedback(ctx.getSource(), "Clan chosen: " + id);
                        })));
    }

    private static int learn(ServerCommandSource source, String id) {
        ServerPlayerEntity p = source.getPlayer();
        NinjaPlayerData d = data(p);
        id = normalizeId(id);
        if (JutsuRegistry.get(id) == null) return feedback(source, "§cJutsu not found: " + id);
        if (d.getLearnedJutsus().contains(id)) return feedback(source, "§cAlready learned");
        d.learnJutsu(id);
        String placed = null;
        for (int set = 0; set < 2 && placed == null; set++) {
            for (int i = 0; i < 5; i++) {
                if (d.getLoadoutSlot(set, i) == null) {
                    d.setLoadoutSlot(set, i, id);
                    placed = (set == 0 ? "A" : "B") + (i + 1);
                    break;
                }
            }
        }
        ShinobiCore.sendLoadoutSync(p);
        ShinobiCore.sendStatsSync(p);
        String msg = "§aLearned " + id + (placed != null ? " §7-> slot " + placed : "");
        source.sendFeedback(() -> Text.literal(msg), false);
        return 1;
    }

    private static int info(ServerCommandSource source) {
        ServerPlayerEntity p = source.getPlayer();
        NinjaPlayerData d = data(p);
        source.sendFeedback(() -> Text.literal(
                "=== NINJA STATS ===\n" +
                        "Chakra: " + (int) d.getCurrentChakra() + "/" + (int) NinjaFormula.maxChakra(d) + "\n" +
                        "Reserve: Lv " + d.getReserveLevel() + "\n" +
                        "Fatigue: " + (int) d.getFatigue() + "\n" +
                        "SP: " + d.getSkillPoints() + "\n" +
                        "Clan: " + d.getClanId() + "\n" +
                        "Affinity: " + (d.getAffinity() != null ? d.getAffinity().getId() : "none") + "\n" +
                        "Learned Jutsu: " + d.getLearnedJutsus().size()), false);
        return 1;
    }

    private static NinjaPlayerData data(ServerPlayerEntity p) {
        return ((NinjaDataHolder) p).shinobicore_getData();
    }

    private static String normalizeId(String raw) {
        String id = raw.trim();
        if (!id.contains(":")) id = "shinobicore:" + id;
        return id;
    }

    private static int feedback(ServerCommandSource source, String msg) {
        source.sendFeedback(() -> Text.literal(msg), false);
        return msg.startsWith("§c") ? 0 : 1;
    }

    private static StatType statById(String id) {
        for (StatType s : StatType.values()) if (s.getId().equals(id)) return s;
        return null;
    }

    private static ElementType elementById(String id) {
        for (ElementType e : ElementType.values()) if (e.getId().equals(id)) return e;
        return null;
    }

    private static CompletableFuture<Suggestions> suggestStats(CommandContext<ServerCommandSource> ctx, SuggestionsBuilder b) {
        for (StatType s : StatType.values()) b.suggest(s.getId());
        return b.buildFuture();
    }

    private static CompletableFuture<Suggestions> suggestElements(CommandContext<ServerCommandSource> ctx, SuggestionsBuilder b) {
        for (ElementType e : ElementType.values()) b.suggest(e.getId());
        return b.buildFuture();
    }

    // === ДОБАВЛЕНО: подсказки кланов из ClanRegistry ===
    private static CompletableFuture<Suggestions> suggestClans(CommandContext<ServerCommandSource> ctx, SuggestionsBuilder b) {
        for (ClanDefinition c : ClanRegistry.getAll()) b.suggest(c.id());
        return b.buildFuture();
    }

    private static CompletableFuture<Suggestions> suggestJutsu(CommandContext<ServerCommandSource> ctx, SuggestionsBuilder b) {
        for (JutsuDefinition def : JutsuRegistry.getAll()) b.suggest(def.id());
        return b.buildFuture();
    }
}