package com.example.shinobicore.command;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.stat.ClanType;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.suggestion.SuggestionProvider;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import java.util.Random;

public class NinjaCommand {
    private static final Random RANDOM = new Random();
    private static final SuggestionProvider<ServerCommandSource> STAT_SUGGESTIONS =
        (ctx, builder) -> {
            for (StatType s : StatType.values()) builder.suggest(s.getId());
            return builder.buildFuture();
        };

    private static final SuggestionProvider<ServerCommandSource> NATURE_SUGGESTIONS =
        (ctx, builder) -> {
            for (ElementType e : ElementType.values()) builder.suggest(e.getId());
            return builder.buildFuture();
        };

    private static final SuggestionProvider<ServerCommandSource> CLAN_SUGGESTIONS =
        (ctx, builder) -> {
            for (ClanType c : ClanType.values()) builder.suggest(c.getId());
            return builder.buildFuture();
        };

    private static final SuggestionProvider<ServerCommandSource> JUTSU_SUGGESTIONS =
        (ctx, builder) -> {
            for (JutsuDefinition def : JutsuRegistry.getAll()) builder.suggest(def.id());
            return builder.buildFuture();
        };

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("ninja")
            // /ninja info
            .then(CommandManager.literal("info").executes(ctx -> {
                ServerPlayerEntity player = ctx.getSource().getPlayer();
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                ctx.getSource().sendFeedback(() -> Text.literal(
                    "=== NINJA STATS ===\n" +
                    "Chakra: " + (int)data.getCurrentChakra() + "/" + (int)NinjaFormula.maxChakra(data) + "\n" +
                    "Reserve: Lv " + data.getReserveLevel() + "\n" +
                    "Fatigue: " + (int)data.getFatigue() + (data.isExhausted() ? " [EXHAUSTED]" : "") + "\n" +
                    "Clan: " + data.getClan().getId() + "\n" +
                    "Affinity: " + (data.getAffinity() != null ? data.getAffinity().getId() : "none") + "\n" +
                    "Learned Jutsu: " + data.getLearnedJutsus().size()
                ), false);
                return 1;
            }))

            // /ninja set ...
            .then(CommandManager.literal("set")
                .then(CommandManager.literal("chakra")
                    .then(CommandManager.argument("value", IntegerArgumentType.integer(0, 10000))
                        .executes(ctx -> {
                            ServerPlayerEntity player = ctx.getSource().getPlayer();
                            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                            data.setCurrentChakra(IntegerArgumentType.getInteger(ctx, "value"));
                            ctx.getSource().sendFeedback(() -> Text.literal("Chakra set"), false);
                            return 1;
                        })))

                .then(CommandManager.literal("fatigue")
                    .then(CommandManager.argument("value", IntegerArgumentType.integer(0, 100))
                        .executes(ctx -> {
                            ServerPlayerEntity player = ctx.getSource().getPlayer();
                            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                            data.setFatigue(IntegerArgumentType.getInteger(ctx, "value"));
                            ctx.getSource().sendFeedback(() -> Text.literal("Fatigue set"), false);
                            return 1;
                        })))

                .then(CommandManager.literal("stat")
                    .then(CommandManager.argument("stat", StringArgumentType.word()).suggests(STAT_SUGGESTIONS)
                        .then(CommandManager.argument("value", IntegerArgumentType.integer(0, 100))
                            .executes(ctx -> {
                                ServerPlayerEntity player = ctx.getSource().getPlayer();
                                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                                String statId = StringArgumentType.getString(ctx, "stat");
                                int value = IntegerArgumentType.getInteger(ctx, "value");
                                for (StatType s : StatType.values()) {
                                    if (s.getId().equals(statId)) {
                                        data.setStatLevel(s, value);
                                        ctx.getSource().sendFeedback(() -> Text.literal("Set " + statId + " to " + value), false);
                                        return 1;
                                    }
                                }
                                ctx.getSource().sendFeedback(() -> Text.literal("Unknown stat"), false);
                                return 0;
                            }))))

                .then(CommandManager.literal("nature")
                    .then(CommandManager.argument("element", StringArgumentType.word()).suggests(NATURE_SUGGESTIONS)
                        .then(CommandManager.argument("value", IntegerArgumentType.integer(0, 100))
                            .executes(ctx -> {
                                ServerPlayerEntity player = ctx.getSource().getPlayer();
                                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                                String elId = StringArgumentType.getString(ctx, "element");
                                int value = IntegerArgumentType.getInteger(ctx, "value");
                                for (ElementType e : ElementType.values()) {
                                    if (e.getId().equals(elId)) {
                                        data.setNatureLevel(e, value);
                                        data.setNatureUnlocked(e, value > 0);
                                        ctx.getSource().sendFeedback(() -> Text.literal("Set " + elId + " to " + value), false);
                                        return 1;
                                    }
                                }
                                ctx.getSource().sendFeedback(() -> Text.literal("Unknown nature"), false);
                                return 0;
                            }))))

                .then(CommandManager.literal("clan")
                    .then(CommandManager.argument("clan", StringArgumentType.word()).suggests(CLAN_SUGGESTIONS)
                        .executes(ctx -> {
                            ServerPlayerEntity player = ctx.getSource().getPlayer();
                            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                            String clanId = StringArgumentType.getString(ctx, "clan");
                            for (ClanType c : ClanType.values()) {
                                if (c.getId().equals(clanId)) {
                                    data.setClan(c);
                                    ctx.getSource().sendFeedback(() -> Text.literal("Clan set to " + clanId), false);
                                    return 1;
                                }
                            }
                            return 0;
                        })))

                .then(CommandManager.literal("affinity")
                    .then(CommandManager.argument("element", StringArgumentType.word()).suggests(NATURE_SUGGESTIONS)
                        .executes(ctx -> {
                            ServerPlayerEntity player = ctx.getSource().getPlayer();
                            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                            String elId = StringArgumentType.getString(ctx, "element");
                            for (ElementType e : ElementType.values()) {
                                if (e.getId().equals(elId)) {
                                    data.setAffinity(e);
                                    ctx.getSource().sendFeedback(() -> Text.literal("Affinity set to " + elId), false);
                                    return 1;
                                }
                            }
                            return 0;
                        }))))

            // /ninja give xp ...
            .then(CommandManager.literal("give")
                .then(CommandManager.literal("xp")
                .then(CommandManager.literal("sp")
                    .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                        .executes(ctx -> {
                            ServerPlayerEntity player = ctx.getSource().getPlayer();
                            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                            int amount = IntegerArgumentType.getInteger(ctx, "amount");
                            data.addSkillPoints(amount);
                            ShinobiCore.sendStatsSync(player);
                            ctx.getSource().sendFeedback(() -> Text.literal("§aAdded " + amount + " SP"), false);
                            return 1;
                        })))
                    .then(CommandManager.literal("stat")
                        .then(CommandManager.argument("stat", StringArgumentType.word()).suggests(STAT_SUGGESTIONS)
                            .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                                .executes(ctx -> {
                                    ServerPlayerEntity player = ctx.getSource().getPlayer();
                                    NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                                    String statId = StringArgumentType.getString(ctx, "stat");
                                    int amount = IntegerArgumentType.getInteger(ctx, "amount");
                                    for (StatType s : StatType.values()) {
                                        if (s.getId().equals(statId)) {
                                            boolean leveled = NinjaFormula.addStatXp(data, s, amount);
                                            ctx.getSource().sendFeedback(() -> Text.literal(
                                                "Added " + amount + " XP to " + statId +
                                                (leveled ? " (LEVEL UP!)" : "")
                                            ), false);
                                            return 1;
                                        }
                                    }
                                    return 0;
                                }))))
                    .then(CommandManager.literal("nature")
                        .then(CommandManager.argument("element", StringArgumentType.word()).suggests(NATURE_SUGGESTIONS)
                            .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                                .executes(ctx -> {
                                    ServerPlayerEntity player = ctx.getSource().getPlayer();
                                    NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                                    String elId = StringArgumentType.getString(ctx, "element");
                                    int amount = IntegerArgumentType.getInteger(ctx, "amount");
                                    for (ElementType e : ElementType.values()) {
                                        if (e.getId().equals(elId)) {
                                            boolean leveled = NinjaFormula.addNatureXp(data, e, amount);
                                            ctx.getSource().sendFeedback(() -> Text.literal(
                                                "Added " + amount + " nature XP to " + elId +
                                                (leveled ? " (LEVEL UP!)" : "")
                                            ), false);
                                            return 1;
                                        }
                                    }
                                    return 0;
                                }))))
                    .then(CommandManager.literal("reserve")
                        .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                            .executes(ctx -> {
                                ServerPlayerEntity player = ctx.getSource().getPlayer();
                                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                                int amount = IntegerArgumentType.getInteger(ctx, "amount");
                                boolean leveled = NinjaFormula.addReserveXp(data, amount);
                                ctx.getSource().sendFeedback(() -> Text.literal(
                                    "Added " + amount + " reserve XP" +
                                    (leveled ? " (LEVEL UP!)" : "")
                                ), false);
                                return 1;
                            })))))

            // /ninja jutsu ...
            .then(CommandManager.literal("jutsu")
                .then(CommandManager.literal("list").executes(ctx -> {
                    var all = JutsuRegistry.getAll();
                    if (all.isEmpty()) {
                        ctx.getSource().sendFeedback(() -> Text.literal("No jutsu loaded"), false);
                        return 1;
                    }
                    StringBuilder sb = new StringBuilder("=== Loaded Jutsu (" + all.size() + ") ===\n");
                    for (var def : all) {
                        sb.append("- ").append(def.name())
                          .append(" [").append(def.id()).append("]\n")
                          .append("  cost=").append(def.baseCost())
                          .append(", damage=").append(def.baseDamage())
                          .append(", strain=").append(def.strain())
                          .append(", nature=").append(def.nature() != null ? def.nature().getId() : "none")
                          .append("\n");
                    }
                    ctx.getSource().sendFeedback(() -> Text.literal(sb.toString()), false);
                    return 1;
                }))
                .then(CommandManager.literal("info")
                    .then(CommandManager.argument("id", StringArgumentType.greedyString()).suggests(JUTSU_SUGGESTIONS)
                        .executes(ctx -> {
                            ServerPlayerEntity player = ctx.getSource().getPlayer();
                            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                            String raw = StringArgumentType.getString(ctx, "id").trim();
                            String id = raw.split("\\s+")[0];
                            JutsuDefinition def = JutsuRegistry.get(id);
                            if (def == null) {
                                ctx.getSource().sendFeedback(() -> Text.literal("§cJutsu not found: " + id), false);
                                return 0;
                            }
                            float usage = NinjaFormula.usageScore(def, data);
                            float cs = NinjaFormula.characterScore(def, data);
                            float m = NinjaFormula.mastery(def, data);
                            float cost = NinjaFormula.calculateCost(def, data);
                            float dmg = NinjaFormula.damageMultiplier(data, def);
                            ctx.getSource().sendFeedback(() -> Text.literal(
                                "=== " + def.name() + " ===\n" +
                                "Usage: " + data.getJutsuUsage(def.id()) + "/" + def.requiredUsesForFullProficiency() + " (" + (int) usage + "%)\n" +
                                "Character Score: " + String.format("%.1f", cs) + "\n" +
                                "Mastery: " + String.format("%.1f", m) + "\n" +
                                "Cost: " + String.format("%.1f", cost) + " chakra\n" +
                                "Damage mult: x" + String.format("%.2f", dmg)
                            ), false);
                            return 1;
                        }))))

            // /ninja learn <id>
            .then(CommandManager.literal("learn")
                .then(CommandManager.argument("id", StringArgumentType.greedyString()).suggests(JUTSU_SUGGESTIONS)
                    .executes(ctx -> {
                        ServerPlayerEntity player = ctx.getSource().getPlayer();
                        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                        String raw = StringArgumentType.getString(ctx, "id").trim();
                        String id = raw.split("\\s+")[0];
                        if (JutsuRegistry.get(id) == null) {
                            ctx.getSource().sendFeedback(() -> Text.literal("§cJutsu not found: " + id), false);
                            return 0;
                        }
                        data.getLearnedJutsus().add(id);

                        // Авто-назначение в первый пустой слот
                        for (int i = 0; i < 5; i++) {
                            if (data.getLoadoutSlot(i) == null) {
                                data.setLoadoutSlot(i, id);
                                final int slotNum = i + 1;
                                ctx.getSource().sendFeedback(() -> Text.literal("§7Auto-assigned to slot " + slotNum), false);
                                break;
                            }
                        }

                        ShinobiCore.sendLoadoutSync(player);
                        ctx.getSource().sendFeedback(() -> Text.literal("§aLearned " + id), false);
                        return 1;
                    })))

            // /ninja cast <id>
            .then(CommandManager.literal("cast")
                .then(CommandManager.argument("id", StringArgumentType.greedyString()).suggests(JUTSU_SUGGESTIONS)
                    .executes(ctx -> {
                        ServerPlayerEntity player = ctx.getSource().getPlayer();
                        String raw = StringArgumentType.getString(ctx, "id").trim();
                        String id = raw.split("\\s+")[0];
                        JutsuCaster.cast(player, id);
                        return 1;
                    })))

            // /ninja slot <1-5> <id>
            .then(CommandManager.literal("slot")
                .then(CommandManager.argument("num", IntegerArgumentType.integer(1, 5))
                    .then(CommandManager.argument("id", StringArgumentType.greedyString()).suggests(JUTSU_SUGGESTIONS)
                        .executes(ctx -> {
                            ServerPlayerEntity player = ctx.getSource().getPlayer();
                            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                            int num = IntegerArgumentType.getInteger(ctx, "num");
                            String raw = StringArgumentType.getString(ctx, "id").trim();
                            String id = raw.split("\\s+")[0];
                            if (JutsuRegistry.get(id) == null) {
                                ctx.getSource().sendFeedback(() -> Text.literal("§cJutsu not found: " + id), false);
                                return 0;
                            }
                            if (!data.getLearnedJutsus().contains(id)) {
                                ctx.getSource().sendFeedback(() -> Text.literal("§cLearn it first!"), false);
                                return 0;
                            }
                            data.setLoadoutSlot(num - 1, id);
                            ShinobiCore.sendLoadoutSync(player);
                            ctx.getSource().sendFeedback(() -> Text.literal("§aSlot " + num + " = " + id), false);
                            return 1;
                        }))))

            // /ninja clan choose <id>
            .then(CommandManager.literal("clan")
                .then(CommandManager.literal("choose")
                    .then(CommandManager.argument("id", StringArgumentType.word()).suggests((ctx, builder) -> {
                        for (var clan : ClanRegistry.getAll()) builder.suggest(clan.id());
                        return builder.buildFuture();
                    })
                        .executes(ctx -> {
                            ServerPlayerEntity player = ctx.getSource().getPlayer();
                            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                            String clanId = StringArgumentType.getString(ctx, "id");

                            if (data.isClanChosen()) {
                                ctx.getSource().sendFeedback(() -> Text.literal("§cClan already chosen!"), false);
                                return 0;
                            }

                            ClanDefinition def = ClanRegistry.get(clanId);
                            if (def == null) {
                                ctx.getSource().sendFeedback(() -> Text.literal("§cClan not found: " + clanId), false);
                                return 0;
                            }

                            data.setClan(ClanType.valueOf(clanId.toUpperCase()));
                            data.setAffinity(def.affinity());
                            data.setClanChosen(true);

                            // Sarutobi: выбор второй стихии
                            if (def.extraAffinityCount() > 0) {
                                ElementType[] elements = ElementType.values();
                                ElementType second = elements[RANDOM.nextInt(elements.length)];
                                if (second != def.affinity()) {
                                    data.setNatureLevel(second, 10);
                                    data.setNatureUnlocked(second, true);
                                    ctx.getSource().sendFeedback(() -> Text.literal("§aExtra affinity: " + second.getId()), false);
                                }
                            }

                            ShinobiCore.sendChakraSync(player);
                            ctx.getSource().sendFeedback(() -> Text.literal("§aClan chosen: " + def.name()), false);
                            return 1;
                        })))
                .then(CommandManager.literal("list").executes(ctx -> {
                    StringBuilder sb = new StringBuilder("=== Available Clans ===\n");
                    for (var clan : ClanRegistry.getAll()) {
                        sb.append("- ").append(clan.name())
                          .append(" [").append(clan.id()).append("]\n")
                          .append("  affinity=").append(clan.affinity() != null ? clan.affinity().getId() : "none")
                          .append(", reserve=").append(clan.reserveBonus())
                          .append(", dojutsu=").append(clan.dojutsuHook() != null ? clan.dojutsuHook() : "none")
                          .append("\n");
                    }
                    ctx.getSource().sendFeedback(() -> Text.literal(sb.toString()), false);
                    return 1;
                })))

            // /ninja reloadconfig
            .then(CommandManager.literal("reloadconfig").executes(ctx -> {
                ModConfig.load();
                ctx.getSource().sendFeedback(() -> Text.literal("§aConfig reloaded"), false);
                return 1;
            }))
        );
    }
}