package com.example.shinobicore.command;

import com.example.shinobicore.jutsu.core.VisualDefinition;
import com.example.shinobicore.jutsu.enums.ElementType;
import com.example.shinobicore.jutsu.executor.Fx;
import com.mojang.brigadier.arguments.DoubleArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import static net.minecraft.server.command.CommandManager.argument;
import static net.minecraft.server.command.CommandManager.literal;

/**
 * ToolsPack 2 (1.1.3): предпросмотр визуального языка техник в игре.
 *
 *   /shinobicore fx                          — справка
 *   /shinobicore fx fire                     — все базовые эффекты стихии (2 ряда, 20 сек)
 *   /shinobicore fx fire beam                — один эффект
 *   /shinobicore fx fire beam 2.0            — с масштабом
 *   /shinobicore fx fire beam spiral         — со стилем (для trail/impact/circle/zone/beam)
 *   /shinobicore fx fire trail helix 1.5     — стиль + масштаб
 *   /shinobicore fx none all2                — только новые эмиттеры (ToolsPack 2)
 *   /shinobicore fx none stop                — остановить
 *
 * Стили: trail: default/ribbon/helix/smoke/sparks/lightning
 *        impact: default/nova/shockwave/implosion
 *        circle(cast): default/runes/pillars/spiral
 *        zone: default/dome/rune_circle/vortex/wall
 *        beam: default/lightning/spiral/pulse
 */
public class FxPreviewCommand {

    private static final String[] KINDS = {
        "burst", "trail", "circle", "gather", "beam", "zone", "impact",
        "sphere", "ghost", "fuse",
        "helix", "vortex", "shockwave", "runes", "pillar", "dome", "chain",
        "all", "all2", "stop"
    };

    /** Эффекты, которым можно передать стиль. */
    private static final String[] STYLED = { "trail", "impact", "circle", "zone", "beam" };

    private static final String[] BASE_SET = {
        "circle", "gather", "trail", "beam", "zone", "sphere", "ghost", "impact", "burst", "fuse"
    };
    private static final String[] NEW_SET = {
        "pillar", "vortex", "helix", "shockwave", "runes", "dome", "chain"
    };

    private static final int DURATION_TICKS = 400;

    private static final class Task {
        final ServerWorld world;
        final Vec3d pos;
        final Vec3d dir;
        final ElementType el;
        final VisualDefinition vis;
        final String kind;
        int age;

        Task(ServerWorld world, Vec3d pos, Vec3d dir, ElementType el, VisualDefinition vis, String kind) {
            this.world = world; this.pos = pos; this.dir = dir;
            this.el = el; this.vis = vis; this.kind = kind; this.age = 0;
        }
    }

    private static final List<Task> TASKS = new ArrayList<>();
    private static boolean tickerRegistered = false;

    public static LiteralArgumentBuilder<ServerCommandSource> branch() {
        ensureTicker();
        return literal("fx")
            .executes(ctx -> {
                ctx.getSource().sendFeedback(() -> Text.literal(
                    "\u00A7e/shinobicore fx <element> [kind] [scale] [style]\n" +
                    "\u00A77elements: fire water wind earth lightning yin yang none\n" +
                    "\u00A77kinds:    burst trail circle gather beam zone impact sphere ghost fuse\n" +
                    "\u00A77          helix vortex shockwave runes pillar dome chain | all all2 stop\n" +
                    "\u00A77styles:   trail=ribbon/helix/smoke/sparks/lightning impact=nova/shockwave/implosion\n" +
                    "\u00A77          circle=runes/pillars/spiral zone=dome/rune_circle/vortex/wall\n" +
                    "\u00A77          beam=lightning/spiral/pulse"), false);
                return 1;
            })
            .then(argument("element", StringArgumentType.word())
                .suggests((c, b) -> {
                    for (ElementType e : ElementType.values()) b.suggest(e.getId());
                    return b.buildFuture();
                })
                .executes(ctx -> run(ctx, "all", 1.0, ""))
                .then(argument("kind", StringArgumentType.word())
                    .suggests((c, b) -> {
                        for (String k : KINDS) b.suggest(k);
                        return b.buildFuture();
                    })
                    .executes(ctx -> run(ctx, StringArgumentType.getString(ctx, "kind"), 1.0, ""))
                    .then(argument("scale", DoubleArgumentType.doubleArg(0.25, 4.0))
                        .executes(ctx -> run(ctx, StringArgumentType.getString(ctx, "kind"),
                                             DoubleArgumentType.getDouble(ctx, "scale"), ""))
                        .then(argument("style", StringArgumentType.word())
                            .suggests((c, b) -> {
                                for (String st : new String[]{ "default", "ribbon", "helix", "smoke", "sparks",
                                        "lightning", "nova", "shockwave", "implosion", "runes", "pillars",
                                        "spiral", "dome", "rune_circle", "vortex", "wall", "pulse" }) {
                                    b.suggest(st);
                                }
                                return b.buildFuture();
                            })
                            .executes(ctx -> run(ctx, StringArgumentType.getString(ctx, "kind"),
                                                 DoubleArgumentType.getDouble(ctx, "scale"),
                                                 StringArgumentType.getString(ctx, "style")))))));
    }

    private static int run(com.mojang.brigadier.context.CommandContext<ServerCommandSource> ctx,
                           String kind, double scale, String style) {
        ServerPlayerEntity p = ctx.getSource().getPlayer();
        if (p == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }
        String elId = StringArgumentType.getString(ctx, "element");
        if ("stop".equals(kind) || "stop".equals(elId)) {
            TASKS.clear();
            ctx.getSource().sendFeedback(() -> Text.literal("\u00A77FX preview stopped"), true);
            return 1;
        }
        ElementType el = ElementType.fromId(elId);
        ServerWorld world = p.getServerWorld();
        Vec3d look = p.getRotationVector().normalize();
        Vec3d right = Math.abs(look.y) < 0.9
                ? look.crossProduct(new Vec3d(0, 1, 0)).normalize()
                : new Vec3d(1, 0, 0);
        Vec3d base = p.getPos().add(look.multiply(3.5));

        TASKS.removeIf(t -> t.age > DURATION_TICKS);

        if ("all".equals(kind) || "all2".equals(kind)) {
            String[] show = "all".equals(kind) ? BASE_SET : NEW_SET;
            for (int i = 0; i < show.length; i++) {
                int col = i / 2;
                int row = i % 2;
                double side = (col - show.length / 4.0) * 2.6;
                Vec3d pos = base.add(right.multiply(side)).add(look.multiply(row * 3.0 + (i % 3) * 0.6));
                TASKS.add(new Task(world, pos, look, el, visFor(show[i], scale, style), show[i]));
            }
        } else {
            boolean known = false;
            for (String k : KINDS) if (k.equals(kind)) { known = true; break; }
            if (!known) {
                ctx.getSource().sendError(Text.literal("Unknown kind: " + kind));
                return 0;
            }
            TASKS.add(new Task(world, base, look, el, visFor(kind, scale, style), kind));
        }
        final String fk = kind;
        final String fs = style;
        ctx.getSource().sendFeedback(() -> Text.literal(
            "\u00A7aFX preview: \u00A7f" + el.getId() + "/" + fk +
            (fs.isEmpty() ? "" : "/" + fs) + "\u00A7a scale=" + scale +
            " \u00A77(20s, \u00A7f/shinobicore fx none stop\u00A77)"), true);
        return 1;
    }

    /** Стиль применяется только к «своим» kind; остальным — обычный visual. */
    private static VisualDefinition visFor(String kind, double scale, String style) {
        String st = (style == null || style.isEmpty()) ? null : style;
        String trail = null, impact = null, cast = null, zone = null, beam = null;
        if (st != null) {
            switch (kind) {
                case "trail" -> trail = st;
                case "impact", "burst" -> impact = st;
                case "circle", "gather" -> cast = st;
                case "zone" -> zone = st;
                case "beam" -> beam = st;
                default -> { /* новые эмиттеры стилей не имеют */ }
            }
        }
        return new VisualDefinition(null, null, null, null, scale, true, trail, impact, cast, zone, beam);
    }

    private static void ensureTicker() {
        if (tickerRegistered) return;
        tickerRegistered = true;
        ServerTickEvents.END_SERVER_TICK.register(FxPreviewCommand::tickAll);
    }

    private static void tickAll(MinecraftServer server) {
        if (TASKS.isEmpty()) return;
        Iterator<Task> it = TASKS.iterator();
        while (it.hasNext()) {
            Task t = it.next();
            t.age++;
            if (t.age > DURATION_TICKS) { it.remove(); continue; }
            try {
                tickTask(t);
            } catch (Exception ex) {
                it.remove();
            }
        }
    }

    private static void tickTask(Task t) {
        double sc = scaleOf(t.vis);
        switch (t.kind) {
            case "burst"  -> { if (t.age % 25 == 0) Fx.burst(t.world, t.pos.add(0, 1, 0), t.el, t.vis, 20); }
            case "trail"  -> {
                double prog = (t.age % 60) / 60.0 * 8.0;
                Fx.trailRich(t.world, t.pos.add(0, 1.2, 0).add(t.dir.multiply(prog)), t.dir,
                        t.el, t.vis, 0.5, t.age);
            }
            case "circle" -> Fx.castCircle(t.world, t.pos, t.el, t.vis, 1.25 * sc, t.age);
            case "gather" -> Fx.chargeGather(t.world, t.pos.add(0, 1.3, 0), t.el, t.vis, t.age);
            case "beam"   -> Fx.beamCore(t.world, t.pos.add(0, 1.3, 0), t.dir, 12, 0.5, t.el, t.vis, t.age);
            case "zone"   -> Fx.zoneVisual(t.world, t.pos.add(0, 0.6, 0), 4.0 * sc, t.el, t.vis, t.age);
            case "impact" -> { if (t.age % 30 == 0) Fx.impactFlash(t.world, t.pos.add(0, 0.6, 0), t.el, t.vis, 2.0 * sc); }
            case "sphere" -> Fx.spinningSphere(t.world, t.pos.add(0, 1.3, 0), t.el, t.vis, 0.5, t.age);
            case "ghost"  -> Fx.dashGhost(t.world, t.pos.add(0, 1.0, 0), t.el, t.vis, t.age);
            case "fuse"   -> { if (t.age % 4 == 0) Fx.fuseSpark(t.world, t.pos.add(0, 0.2, 0), t.el, t.vis, 60 - (t.age % 60)); }
            case "helix"  -> Fx.helixColumn(t.world, t.pos, t.el, t.vis, 3.0 * sc, 0.8 * sc, t.age);
            case "vortex" -> Fx.vortex(t.world, t.pos, t.el, t.vis, 1.4 * sc, 3.2 * sc, t.age);
            case "shockwave" -> {
                int cycle = t.age % 50;
                if (cycle < 25) Fx.shockwaveRing(t.world, t.pos.add(0, 0.2, 0), t.el, t.vis, 4.0 * sc, cycle, 24);
            }
            case "runes"  -> Fx.groundRunes(t.world, t.pos, t.el, t.vis, 2.2 * sc, t.age);
            case "pillar" -> Fx.lightPillar(t.world, t.pos, t.el, t.vis, 4.0 * sc, t.age);
            case "dome"   -> Fx.domeShell(t.world, t.pos, t.el, t.vis, 2.6 * sc, t.age);
            case "chain"  -> {
                Vec3d from = t.pos.add(0, 1.0, 0);
                Vec3d to = t.pos.add(t.dir.multiply(4.5)).add(0, 2.2, 0);
                Fx.chainArc(t.world, from, to, t.el, t.vis, t.age);
            }
            default -> { }
        }
    }

    private static double scaleOf(VisualDefinition vis) {
        return vis != null && vis.getScale() > 0 ? vis.getScale() : 1.0;
    }
}