package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;

public class ActivationSystem {

    public enum Mode { HANDSEALS, CHARGE, HOLD, COUNTER, ON_DEATH, PASSIVE }

    private static class Active {
        final CastContext ctx;
        final Mode mode;
        int elapsed;
        final int duration;
        final int min;
        final double extra; // drain per tick (HOLD) or damage threshold (COUNTER)
        Active(CastContext ctx, Mode mode, int duration, int min, double extra) {
            this.ctx = ctx; this.mode = mode; this.duration = duration; this.min = min; this.extra = extra;
        }
    }

    private static final Map<UUID, Active> ACTIVE = new HashMap<>();

    public static void start(CastContext ctx, Mode mode, int duration, int min, double extra) {
        VerificationLogger.logActivation(ctx.jutsu.getId(), mode.name(), String.format("STARTED duration=%d min=%d", duration, min));
        ACTIVE.put(ctx.caster.getUuid(), new Active(ctx, mode, duration, min, extra));
    }

    public static boolean hasActive(UUID uid) { return ACTIVE.containsKey(uid); }

    /** Called on damage taken. Returns true if damage should apply. */
    public static boolean onDamageTaken(ServerPlayerEntity victim, float amount) {
        Active a = ACTIVE.get(victim.getUuid());
        if (a == null) return true;
        switch (a.mode) {
            case HANDSEALS, CHARGE, HOLD -> {
                ACTIVE.remove(victim.getUuid());
                victim.sendMessage(Text.literal("§c§lINTERRUPTED! §7Cast lost"), false);
                return true;
            }
            case COUNTER -> {
                if (amount >= a.extra) {
                    ACTIVE.remove(victim.getUuid());
                    victim.sendMessage(Text.literal("§e§lCOUNTER!"), false);
                    FormExecutor.executeForm(a.ctx);
                }
                return true;
            }
            case ON_DEATH -> {
                if (victim.getHealth() - amount <= 0) {
                    ACTIVE.remove(victim.getUuid());
                    victim.setHealth(victim.getMaxHealth() * 0.5f);
                    victim.sendMessage(Text.literal("§d§lIZANAGI! §7Death rewritten"), false);
                    FormExecutor.executeForm(a.ctx);
                    return false; // cancel lethal hit
                }
                return true;
            }
            default -> { return true; }
        }
    }

    /** Release command: fire charge / stop hold / toggle passive off. */
    public static void release(UUID uid) {
        Active a = ACTIVE.get(uid);
        if (a == null) return;
        if (!(a.ctx.caster instanceof ServerPlayerEntity p)) return;
        switch (a.mode) {
            case CHARGE -> {
                if (a.elapsed < a.min) {
                    p.sendMessage(Text.literal("§cNot charged yet! (" + a.elapsed + "/" + a.min + ")"), true);
                    return;
                }
                double power = Math.min(1.0, (double) a.elapsed / Math.max(1, a.duration));
                ACTIVE.remove(uid);
                CastContext scaled = new CastContext(a.ctx.caster, a.ctx.jutsu, a.ctx.level,
                        a.ctx.damageScale * (0.5 + 0.5 * power), a.ctx.props, a.ctx.effects, a.ctx.multiCap);
                p.sendMessage(Text.literal("§aRELEASE! §7power=" + (int) (power * 100) + "%"), false);
                FormExecutor.executeForm(scaled);
            }
            case HOLD -> {
                ACTIVE.remove(uid);
                p.sendMessage(Text.literal("§7Channel ended"), false);
            }
            case PASSIVE -> {
                ACTIVE.remove(uid);
                p.sendMessage(Text.literal("§7Passive disabled"), false);
            }
            default -> ACTIVE.remove(uid);
        }
    }

    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Map.Entry<UUID, Active>> it = ACTIVE.entrySet().iterator();
        while (it.hasNext()) {
            Active a = it.next().getValue();
            if (!(a.ctx.caster instanceof ServerPlayerEntity p)) { it.remove(); continue; }
            if (!p.isAlive()) { it.remove(); continue; }
            a.elapsed++;
            switch (a.mode) {
                case HANDSEALS -> {
                    p.sendMessage(Text.literal("§bWeaving seals... §f" + a.elapsed + "/" + a.duration), true);
                    if (a.elapsed >= a.duration) {
                        it.remove();
                        p.sendMessage(Text.literal("§a§lJUTSU READY!"), false);
                        FormExecutor.executeForm(a.ctx);
                    }
                }
                case CHARGE -> {
                    double power = Math.min(1.0, (double) a.elapsed / Math.max(1, a.duration));
                    p.sendMessage(Text.literal("§eCharging... §f" + (int) (power * 100) + "% §7(release!)"), true);
                    if (a.elapsed >= a.duration) {
                        it.remove();
                        CastContext scaled = new CastContext(a.ctx.caster, a.ctx.jutsu, a.ctx.level,
                                a.ctx.damageScale, a.ctx.props, a.ctx.effects, a.ctx.multiCap);
                        p.sendMessage(Text.literal("§a§lFULL POWER RELEASE!"), false);
                        FormExecutor.executeForm(scaled);
                    }
                }
                case HOLD -> {
                    NinjaPlayerData data = ((NinjaDataHolder) p).shinobicore_getData();
                    if (data.getCurrentChakra() < a.extra) {
                        it.remove();
                        p.sendMessage(Text.literal("§cChakra depleted! Channel ended"), false);
                    } else {
                        data.setCurrentChakra((float) (data.getCurrentChakra() - a.extra));
                        if (a.elapsed % 20 == 0) ShinobiCore.sendChakraSync(p);
                    }
                }
                case COUNTER -> {
                    if (a.elapsed >= a.duration) {
                        it.remove();
                        p.sendMessage(Text.literal("§7Counter window expired"), true);
                    }
                }
                case PASSIVE -> {
                    if (a.elapsed % 100 == 0) {
                        EffectExecutor.applyEffects(a.ctx, p);
                    }
                }
                default -> {}
            }
        }
    }
}