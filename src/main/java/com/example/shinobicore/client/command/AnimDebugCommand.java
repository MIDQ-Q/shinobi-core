package com.example.shinobicore.client.command;

import com.example.shinobicore.client.anim.json.AnimDiagnostics;
import com.example.shinobicore.client.anim.json.PlayerJsonAnimState;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandManager;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;
import net.fabricmc.fabric.api.client.command.v2.FabricClientCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * Клиентская команда диагностики анимаций.
 * Использование: /shinobianim <подкоманда>
 */
public class AnimDebugCommand {

    public static void register() {
        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> {
            dispatcher.register(
                ClientCommandManager.literal("shinobianim")

                // ── /shinobianim info ──────────────────────────
                .then(ClientCommandManager.literal("info")
                    .executes(ctx -> {
                        FabricClientCommandSource src = ctx.getSource();
                        src.sendFeedback(Text.literal("=== FILE CHECK ===").formatted(Formatting.GOLD));
                        for (AnimDiagnostics.DiagResult r : AnimDiagnostics.checkFiles()) {
                            sendResult(src, r);
                        }
                        src.sendFeedback(Text.literal("=== PARSE ===").formatted(Formatting.GOLD));
                        for (AnimDiagnostics.DiagResult r : AnimDiagnostics.parseAnimations()) {
                            sendResult(src, r);
                        }
                        return 1;
                    })
                )

                // ── /shinobianim bones ─────────────────────────
                .then(ClientCommandManager.literal("bones")
                    .executes(ctx -> {
                        FabricClientCommandSource src = ctx.getSource();
                        src.sendFeedback(Text.literal("=== BONE MAPPING ===").formatted(Formatting.GOLD));
                        for (AnimDiagnostics.DiagResult r : AnimDiagnostics.checkBoneMapping()) {
                            sendResult(src, r);
                        }
                        return 1;
                    })
                )

                // ── /shinobianim loaded ────────────────────────
                .then(ClientCommandManager.literal("loaded")
                    .executes(ctx -> {
                        FabricClientCommandSource src = ctx.getSource();
                        src.sendFeedback(Text.literal("=== LOADED ANIMATIONS ===").formatted(Formatting.GOLD));
                        for (AnimDiagnostics.DiagResult r : AnimDiagnostics.checkLoaded()) {
                            sendResult(src, r);
                        }
                        return 1;
                    })
                )

                // ── /shinobianim conflicts ─────────────────────
                .then(ClientCommandManager.literal("conflicts")
                    .executes(ctx -> {
                        FabricClientCommandSource src = ctx.getSource();
                        src.sendFeedback(Text.literal("=== CONFLICTS & ORDER ===").formatted(Formatting.GOLD));
                        for (AnimDiagnostics.DiagResult r : AnimDiagnostics.checkConflicts()) {
                            sendResult(src, r);
                        }
                        return 1;
                    })
                )

                // ── /shinobianim runtime ───────────────────────
                .then(ClientCommandManager.literal("runtime")
                    .executes(ctx -> {
                        FabricClientCommandSource src = ctx.getSource();
                        src.sendFeedback(Text.literal("=== RUNTIME STATE ===").formatted(Formatting.GOLD));
                        for (AnimDiagnostics.DiagResult r : AnimDiagnostics.getRuntimeState()) {
                            sendResult(src, r);
                        }
                        return 1;
                    })
                )

                // ── /shinobianim test <name> ───────────────────
                .then(ClientCommandManager.literal("test")
                    .then(ClientCommandManager.argument("name", com.mojang.brigadier.arguments.StringArgumentType.word())
                        .executes(ctx -> {
                            FabricClientCommandSource src = ctx.getSource();
                            String name = com.mojang.brigadier.arguments.StringArgumentType.getString(ctx, "name");
                            src.sendFeedback(Text.literal("=== TEST: " + name + " ===").formatted(Formatting.GOLD));
                            for (AnimDiagnostics.DiagResult r : AnimDiagnostics.testAnimation(name)) {
                                sendResult(src, r);
                            }
                            return 1;
                        })
                    )
                )

                // ── /shinobianim stop ──────────────────────────
                .then(ClientCommandManager.literal("stop")
                    .executes(ctx -> {
                        PlayerJsonAnimState.stop();
                        ctx.getSource().sendFeedback(
                            Text.literal("Animation stopped, returning to idle")
                                .formatted(Formatting.YELLOW));
                        return 1;
                    })
                )

                // ── /shinobianim log <on|off> ──────────────────
                .then(ClientCommandManager.literal("log")
                    .then(ClientCommandManager.literal("on")
                        .executes(ctx -> {
                            AnimDiagnostics.setRuntimeLog(true);
                            AnimDiagnostics.clearRuntimeLog();
                            ctx.getSource().sendFeedback(
                                Text.literal("Runtime logging ON").formatted(Formatting.GREEN));
                            return 1;
                        })
                    )
                    .then(ClientCommandManager.literal("off")
                        .executes(ctx -> {
                            AnimDiagnostics.setRuntimeLog(false);
                            ctx.getSource().sendFeedback(
                                Text.literal("Runtime logging OFF").formatted(Formatting.YELLOW));
                            return 1;
                        })
                    )
                )

                // ── /shinobianim log view ──────────────────────
                .then(ClientCommandManager.literal("logview")
                    .executes(ctx -> {
                        FabricClientCommandSource src = ctx.getSource();
                        java.util.List<String> log = AnimDiagnostics.getRuntimeLog();
                        src.sendFeedback(Text.literal("=== RUNTIME LOG (" + log.size() + " lines) ===")
                            .formatted(Formatting.GOLD));
                        int max = Math.min(log.size(), 30);
                        for (int i = log.size() - max; i < log.size(); i++) {
                            src.sendFeedback(Text.literal(log.get(i)).formatted(Formatting.GRAY));
                        }
                        return 1;
                    })
                )

                // ── /shinobianim full ──────────────────────────
                .then(ClientCommandManager.literal("full")
                    .executes(ctx -> {
                        FabricClientCommandSource src = ctx.getSource();
                        String report = AnimDiagnostics.runFullDiagnostics();
                        for (String line : report.split("\n")) {
                            Formatting fmt = line.startsWith("[OK]") ? Formatting.GREEN
                                : line.startsWith("[FAIL]") ? Formatting.RED
                                : line.startsWith("---") ? Formatting.GOLD
                                : Formatting.GRAY;
                            src.sendFeedback(Text.literal(line).formatted(fmt));
                        }
                        return 1;
                    })
                )
            );
        });
    }

    private static void sendResult(FabricClientCommandSource src, AnimDiagnostics.DiagResult r) {
        Formatting fmt = r.ok ? Formatting.GREEN : Formatting.RED;
        src.sendFeedback(Text.literal(r.toString()).formatted(fmt));
    }
}