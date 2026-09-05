package com.example.shinobicore.command;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.core.LevelingDefinition;
import com.example.shinobicore.jutsu.executor.HandheldSystem;
import com.example.shinobicore.jutsu.executor.JutsuCaster;
import com.example.shinobicore.jutsu.executor.ZoneSystem;
import com.example.shinobicore.jutsu.progression.JutsuProgressionState;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

import java.util.Map;

import static net.minecraft.server.command.CommandManager.argument;
import static net.minecraft.server.command.CommandManager.literal;

public class JutsuTestCommand {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        LiteralArgumentBuilder<ServerCommandSource> jutsu = literal("jutsu");
        jutsu.then(castBranch());
        jutsu.then(listBranch());
        jutsu.then(progBranch());
        jutsu.then(addUsesBranch());
        jutsu.then(setLevelBranch());
        jutsu.then(levelUpBranch());
        jutsu.then(giveSpBranch());
        jutsu.then(releaseBranch());
        jutsu.then(throwBranch());
        jutsu.then(bindBranch());
        dispatcher.register(literal("shinobicore").then(jutsu).then(aiBranch()));
    }

    private static String norm(String raw) {
        String t = raw.trim();
        return t.contains(":") ? t : "shinobicore:" + t;
    }

    private static LiteralArgumentBuilder<ServerCommandSource> castBranch() {
        return literal("cast")
            .then(argument("id", StringArgumentType.greedyString())
                .suggests((ctx, b) -> {
                    for (JutsuDefinition def : JutsuRegistry.getAll()) b.suggest(def.getId());
                    return b.buildFuture();
                })
                .executes(ctx -> {
                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                    final String id = norm(StringArgumentType.getString(ctx, "id"));
                    JutsuDefinition def = JutsuRegistry.get(id);
                    if (def == null) {
                        ctx.getSource().sendFeedback(() -> Text.literal("§cUnknown jutsu: " + id), false);
                        return 0;
                    }
                    boolean ok = JutsuCaster.cast(p, def);
                    if (!ok) ctx.getSource().sendFeedback(() -> Text.literal("§cCast failed"), false);
                    return ok ? 1 : 0;
                }));
    }

    private static LiteralArgumentBuilder<ServerCommandSource> listBranch() {
        return literal("list").executes(ctx -> {
            StringBuilder sb = new StringBuilder("§e=== Jutsu v2 loaded: " + JutsuRegistry.size() + " ===\n");
            for (JutsuDefinition def : JutsuRegistry.getAll()) {
                sb.append("§7- §f").append(def.getId())
                  .append(" §8[").append(def.getForm().getType().getId()).append("]\n");
            }
            ctx.getSource().sendFeedback(() -> Text.literal(sb.toString()), false);
            return 1;
        });
    }

    private static LiteralArgumentBuilder<ServerCommandSource> progBranch() {
        return literal("prog")
            .then(argument("id", StringArgumentType.greedyString()).executes(ctx -> {
                ServerPlayerEntity p = ctx.getSource().getPlayer();
                final String id = norm(StringArgumentType.getString(ctx, "id"));
                JutsuProgressionState prog = JutsuProgressionState.get(p.getServer());
                final int lvl = prog.getLevel(p.getUuid(), id);
                final int uses = prog.getUses(p.getUuid(), id);
                ctx.getSource().sendFeedback(() -> Text.literal(
                    "§b" + id + " §7lvl=§f" + lvl + " §7uses=§f" + uses), false);
                return 1;
            }));
    }

    private static LiteralArgumentBuilder<ServerCommandSource> addUsesBranch() {
        return literal("adduses")
            .then(argument("id", StringArgumentType.greedyString())
                .then(argument("amount", IntegerArgumentType.integer(1, 100000)).executes(ctx -> {
                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                    final String id = norm(StringArgumentType.getString(ctx, "id"));
                    final int amount = IntegerArgumentType.getInteger(ctx, "amount");
                    JutsuProgressionState prog = JutsuProgressionState.get(p.getServer());
                    for (int i = 0; i < amount; i++) prog.addUse(p.getUuid(), id);
                    final int total = prog.getUses(p.getUuid(), id);
                    ctx.getSource().sendFeedback(() -> Text.literal(
                        "§a+" + amount + " uses to " + id + " (total: " + total + ")"), false);
                    return 1;
                })));
    }

    private static LiteralArgumentBuilder<ServerCommandSource> setLevelBranch() {
        return literal("setlevel")
            .then(argument("id", StringArgumentType.greedyString())
                .then(argument("level", IntegerArgumentType.integer(1, 99)).executes(ctx -> {
                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                    final String id = norm(StringArgumentType.getString(ctx, "id"));
                    final int level = IntegerArgumentType.getInteger(ctx, "level");
                    JutsuProgressionState prog = JutsuProgressionState.get(p.getServer());
                    prog.setLevel(p.getUuid(), id, level);
                    ctx.getSource().sendFeedback(() -> Text.literal(
                        "§a" + id + " set to level " + level), false);
                    return 1;
                })));
    }

    private static LiteralArgumentBuilder<ServerCommandSource> levelUpBranch() {
        return literal("levelup")
            .then(argument("id", StringArgumentType.greedyString()).executes(ctx -> {
                ServerPlayerEntity p = ctx.getSource().getPlayer();
                final String id = norm(StringArgumentType.getString(ctx, "id"));
                JutsuDefinition def = JutsuRegistry.get(id);
                if (def == null) {
                    ctx.getSource().sendFeedback(() -> Text.literal("§cUnknown jutsu"), false);
                    return 0;
                }
                JutsuProgressionState prog = JutsuProgressionState.get(p.getServer());
                NinjaPlayerData data = ((NinjaDataHolder) p).shinobicore_getData();
                int lvl = prog.getLevel(p.getUuid(), id);
                Integer nextKey = def.getLeveling().nextRowLevel(lvl);
                if (nextKey == null) {
                    ctx.getSource().sendFeedback(() -> Text.literal("§cMax level reached"), false);
                    return 0;
                }
                LevelingDefinition.LevelData row = def.getLeveling().rowAt(nextKey);
                Map<String, Integer> req = row.getRequirements();
                int uses = prog.getUses(p.getUuid(), id);
                if (req.getOrDefault("uses", 0) > uses) {
                    ctx.getSource().sendFeedback(() -> Text.literal(
                        "§cNeed " + req.get("uses") + " uses (have " + uses + ")"), false);
                    return 0;
                }
                int spCost = req.getOrDefault("sp", 0);
                if (data.getSkillPoints() < spCost) {
                    ctx.getSource().sendFeedback(() -> Text.literal("§cNeed " + spCost + " SP"), false);
                    return 0;
                }
                for (Map.Entry<String, Integer> e : req.entrySet()) {
                    try {
                        StatType st = StatType.valueOf(e.getKey().toUpperCase());
                        if (data.getStatLevel(st) < e.getValue()) {
                            ctx.getSource().sendFeedback(() -> Text.literal(
                                "§cNeed " + e.getKey() + " " + e.getValue()), false);
                            return 0;
                        }
                    } catch (Exception ignored) {}
                }
                if (spCost > 0) data.addSkillPoints(-spCost);
                prog.setLevel(p.getUuid(), id, nextKey);
                final int nl = nextKey;
                ctx.getSource().sendFeedback(() -> Text.literal(
                    "§a" + id + " upgraded to level " + nl + "!"), false);
                return 1;
            }));
    }

    private static LiteralArgumentBuilder<ServerCommandSource> giveSpBranch() {
        return literal("givesp")
            .then(argument("amount", IntegerArgumentType.integer(1, 100000)).executes(ctx -> {
                ServerPlayerEntity p = ctx.getSource().getPlayer();
                final int amount = IntegerArgumentType.getInteger(ctx, "amount");
                NinjaPlayerData data = ((NinjaDataHolder) p).shinobicore_getData();
                data.addSkillPoints(amount);
                final int total = data.getSkillPoints();
                ctx.getSource().sendFeedback(() -> Text.literal(
                    "§a+" + amount + " SP (total: " + total + ")"), false);
                return 1;
            }));
    }

    private static LiteralArgumentBuilder<ServerCommandSource> releaseBranch() {
        return literal("release").executes(ctx -> {
            ServerPlayerEntity p = ctx.getSource().getPlayer();
            com.example.shinobicore.jutsu.executor.ActivationSystem.release(p.getUuid());
            ZoneSystem.toggleOff(p.getUuid());
            return 1;
        });
    }

    private static LiteralArgumentBuilder<ServerCommandSource> throwBranch() {
        return literal("throw").executes(ctx -> {
            ServerPlayerEntity p = ctx.getSource().getPlayer();
            HandheldSystem.throwHeld(p);
            return 1;
        });
    }

    private static LiteralArgumentBuilder<ServerCommandSource> bindBranch() {
        return literal("bind")
            .then(argument("set", IntegerArgumentType.integer(0, 1))
            .then(argument("slot", IntegerArgumentType.integer(1, 5))
            .then(argument("id", StringArgumentType.greedyString()).executes(ctx -> {
                ServerPlayerEntity p = ctx.getSource().getPlayer();
                int set = IntegerArgumentType.getInteger(ctx, "set");
                int slot = IntegerArgumentType.getInteger(ctx, "slot") - 1;
                final String id = norm(StringArgumentType.getString(ctx, "id"));
                NinjaPlayerData d = ((NinjaDataHolder) p).shinobicore_getData();
                d.setLoadoutSlot(set, slot, id);
                ShinobiCore.sendLoadoutSync(p);
                ctx.getSource().sendFeedback(() -> Text.literal(
                    "\u00a7aBound " + id + " to set " + set + " slot " + (slot + 1)), false);
                return 1;
            }))));
    }

    private static LiteralArgumentBuilder<ServerCommandSource> aiBranch() {
        return literal("ai").then(literal("spawn")
            .then(argument("level", IntegerArgumentType.integer(1, 20)).executes(ctx -> {
                ServerPlayerEntity p = ctx.getSource().getPlayer();
                final int lvl = IntegerArgumentType.getInteger(ctx, "level");
                net.minecraft.entity.mob.MobEntity mob =
                        com.example.shinobicore.ai.AiEntities.ROGUE_NINJA.create(p.getServerWorld());
                if (mob != null) {
                    net.minecraft.util.math.Vec3d pos = p.getPos().add(p.getRotationVector().multiply(4));
                    mob.setPosition(pos.x, pos.y, pos.z);
                    p.getServerWorld().spawnEntity(mob);
                    com.example.shinobicore.ai.EnemySystem.register(mob, lvl);
                    ctx.getSource().sendFeedback(() -> Text.literal(
                        "\u00a7aSpawned rogue ninja lvl " + lvl + " (dodge " + Math.min(50, 8 + lvl * 3) + "%)"), false);
                }
                return 1;
            })));
    }
}
