$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p"
}

# ============ 1. TickScheduler (no more Thread.sleep!) ============
Write-File "$base\java\com\example\shinobicore\util\TickScheduler.java" @'
package com.example.shinobicore.util;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.world.ServerWorld;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.function.Consumer;

public class TickScheduler {
    private static final List<Task> TASKS = new ArrayList<>();
    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;
        ServerTickEvents.START_WORLD_TICK.register(world -> {
            synchronized (TASKS) {
                Iterator<Task> it = TASKS.iterator();
                while (it.hasNext()) {
                    Task t = it.next();
                    if (t.world != world) continue;
                    t.delay--;
                    if (t.delay > 0) continue;
                    t.delay = t.interval;
                    try { t.action.accept(world); } catch (Exception ignored) {}
                    t.count--;
                    if (t.count <= 0) it.remove();
                }
            }
        });
    }

    public static void schedule(ServerWorld world, int delay, int interval, int count, Consumer<ServerWorld> action) {
        register();
        synchronized (TASKS) { TASKS.add(new Task(world, delay, interval, count, action)); }
    }

    private static class Task {
        final ServerWorld world; int delay; final int interval; int count; final Consumer<ServerWorld> action;
        Task(ServerWorld w, int d, int i, int c, Consumer<ServerWorld> a) { world = w; delay = d; interval = i; count = c; action = a; }
    }
}
'@

# ============ 2. ZoneBehavior rewrite (no lag + more particles) ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\ZoneBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class ZoneBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 10f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 5f;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 160;
        float tickDamage = params.has("tickDamage") ? params.get("tickDamage").getAsFloat() : 2f;
        int tickInterval = params.has("tickInterval") ? params.get("tickInterval").getAsInt() : 20;
        boolean burn = params.has("burn") && params.get("burn").getAsBoolean();
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        Box box = new Box(center, center).expand(radius);
        int ticks = Math.max(1, duration / tickInterval);
        TickScheduler.schedule(world, 1, tickInterval, ticks, w -> {
            for (Entity e : w.getOtherEntities(player, box)) {
                if (e instanceof LivingEntity liv && !liv.equals(player)) {
                    liv.damage(player.getDamageSources().magic(), tickDamage);
                    if (burn) liv.setOnFireFor(3);
                }
            }
            for (int i = 0; i < 40; i++) {
                double a = Math.random() * Math.PI * 2;
                double r = Math.random() * radius;
                w.spawnParticles(ParticleTypes.FLAME,
                    center.x + Math.cos(a) * r, center.y + 0.1 + Math.random() * 0.8, center.z + Math.sin(a) * r,
                    1, 0, 0.06, 0, 0.03);
            }
            for (int i = 0; i < 15; i++) {
                double a = Math.random() * Math.PI * 2;
                double r = Math.random() * radius;
                w.spawnParticles(ParticleTypes.LARGE_SMOKE,
                    center.x + Math.cos(a) * r, center.y + 0.3, center.z + Math.sin(a) * r,
                    1, 0, 0.04, 0, 0.01);
            }
        });
        JutsuLogger.logBehavior("zone", "radius=" + radius + " ticks=" + ticks);
    }
}
'@

# ============ 3. PullBehavior rewrite (real pull, no lag) ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\PullBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class PullBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 12f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 6f;
        float pullStrength = params.has("pullStrength") ? params.get("pullStrength").getAsFloat() : 0.35f;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 60;
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        Box box = new Box(center, center).expand(radius);
        int ticks = Math.max(1, duration / 5);
        TickScheduler.schedule(world, 1, 5, ticks, w -> {
            for (Entity e : w.getOtherEntities(player, box)) {
                if (e instanceof LivingEntity liv && !liv.equals(player)) {
                    Vec3d to = center.subtract(liv.getPos());
                    double dist = to.length();
                    if (dist > 0.5) {
                        Vec3d pull = to.normalize().multiply(pullStrength);
                        liv.setVelocity(pull.x, liv.getVelocity().y * 0.5, pull.z);
                        liv.velocityModified = true;
                    }
                    liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 20, 1, false, false));
                    if (damage > 0) liv.damage(player.getDamageSources().magic(), damage * 0.2f);
                }
            }
            for (int i = 0; i < 20; i++) {
                double a = (i / 20.0) * Math.PI * 2;
                w.spawnParticles(ParticleTypes.PORTAL,
                    center.x + Math.cos(a) * radius, center.y + 0.5, center.z + Math.sin(a) * radius,
                    1, -Math.cos(a) * 0.15, 0.05, -Math.sin(a) * 0.15, 0.03);
            }
        });
        JutsuLogger.logBehavior("pull", "radius=" + radius + " ticks=" + ticks);
    }
}
'@

# ============ 4. SummonBehavior rewrite (allies + 120s lifetime + max 2) ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\SummonBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.ai.goal.ActiveTargetGoal;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.entity.mob.Monster;
import net.minecraft.entity.passive.WolfEntity;
import net.minecraft.registry.Registries;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;

public class SummonBehavior implements JutsuBehavior {
    private static final Map<UUID, java.util.List<Long>> SUMMON_TIMES = new HashMap<>();
    private static final long LIFETIME_MS = 120000;

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        String entityId = params.has("entity") ? params.get("entity").getAsString() : "minecraft:wolf";
        int count = params.has("count") ? params.get("count").getAsInt() : 1;

        long now = System.currentTimeMillis();
        java.util.List<Long> times = SUMMON_TIMES.computeIfAbsent(player.getUuid(), k -> new java.util.ArrayList<>());
        times.removeIf(t -> now - t > LIFETIME_MS);
        if (times.size() >= 2) {
            player.sendMessage(Text.literal("\u00a7cMax 2 summons active! Wait for them to dissipate."), false);
            return;
        }

        EntityType<?> type = Registries.ENTITY_TYPE.getOrEmpty(new Identifier(entityId)).orElse(null);
        if (type == null) {
            player.sendMessage(Text.literal("\u00a7cUnknown summon: " + entityId), false);
            return;
        }
        Vec3d basePos = player.getPos();
        for (int i = 0; i < count; i++) {
            Entity entity = type.create(world);
            if (entity == null) continue;
            double angle = Math.random() * Math.PI * 2;
            double r = 1.5 + Math.random();
            entity.setPosition(basePos.x + Math.cos(angle) * r, basePos.y, basePos.z + Math.sin(angle) * r);
            world.spawnEntity(entity);
            if (entity instanceof WolfEntity wolf) {
                wolf.setOwner(player);
                wolf.setTamed(true);
            }
            if (entity instanceof MobEntity mob) {
                // Make hostile mobs into allies: attack monsters, never the player
                mob.targetSelector.clear();
                mob.targetSelector.add(1, new ActiveTargetGoal<>(mob, Monster.class, 10, true, true,
                    t -> !t.equals(player) && !(t instanceof WolfEntity)));
            }
            times.add(now);
            // Dissipate after 120s
            final Entity summon = entity;
            TickScheduler.schedule(world, 2400, 2400, 1, w -> {
                if (!summon.isRemoved()) {
                    for (int p = 0; p < 15; p++) {
                        w.spawnParticles(net.minecraft.particle.ParticleTypes.POOF,
                            summon.getX(), summon.getY() + Math.random(), summon.getZ(), 1, 0.3, 0.3, 0.3, 0.02);
                    }
                    summon.discard();
                }
            });
        }
        JutsuLogger.logBehavior("summon", "entity=" + entityId + " count=" + count);
    }
}
'@

# ============ 5. HeavenlyStrike: jump FORWARD + no lag ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\HeavenlyStrikeBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class HeavenlyStrikeBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float radius = params.has("radius") ? params.has("radius") ? params.get("radius").getAsFloat() : 4f : 4f;
        float knockdown = params.has("knockdown") ? params.get("knockdown").getAsFloat() : 1.2f;
        // Jump FORWARD + UP
        Vec3d look = player.getRotationVector();
        player.addVelocity(look.x * 0.6, 0.9, look.z * 0.6);
        player.velocityModified = true;
        TickScheduler.schedule(world, 14, 14, 1, w -> {
            Vec3d center = player.getPos();
            for (Entity e : w.getOtherEntities(player, new Box(center, center).expand(radius))) {
                if (e instanceof LivingEntity liv && !liv.equals(player)) {
                    liv.damage(player.getDamageSources().magic(), damage);
                    Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(knockdown);
                    liv.addVelocity(kb.x, -0.3, kb.z);
                    liv.velocityModified = true;
                }
            }
            for (int i = 0; i < 50; i++) {
                double a = (i / 50.0) * Math.PI * 2;
                w.spawnParticles(ParticleTypes.CRIT,
                    center.x + Math.cos(a) * radius, center.y, center.z + Math.sin(a) * radius,
                    2, 0, 0.15, 0, 0.05);
            }
            w.spawnParticles(ParticleTypes.EXPLOSION, center.x, center.y, center.z, 3, 0.5, 0.2, 0.5, 0.02);
        });
        JutsuLogger.logBehavior("heavenly_strike", "radius=" + radius);
    }
}
'@

# ============ 6. CounterStance: no lag ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\CounterStanceBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class CounterStanceBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 3.5f;
        float multiplier = params.has("multiplier") ? params.get("multiplier").getAsFloat() : 2.5f;
        int ticks = 30; // 1.5s window
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.RESISTANCE, ticks, 2, false, false));
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 0.8f, 1.2f);
        TickScheduler.schedule(world, 1, 2, ticks / 2, w -> {
            if (player.hurtTime <= 0) return;
            for (Entity e : w.getOtherEntities(player, new Box(player.getPos(), player.getPos()).expand(radius))) {
                if (e instanceof LivingEntity liv && !liv.equals(player)) {
                    liv.damage(player.getDamageSources().magic(), damage * multiplier);
                    Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(1.2);
                    liv.addVelocity(kb.x, 0.4, kb.z);
                    liv.velocityModified = true;
                    w.spawnParticles(ParticleTypes.ENCHANT, liv.getX(), liv.getY() + 1, liv.getZ(), 10, 0.3, 0.3, 0.3, 0.05);
                }
            }
        });
        JutsuLogger.logBehavior("counter_stance", "mult=" + multiplier);
    }
}
'@

# ============ 7. ClientNinjaState: cast cooldown 400ms (fix held-button drain) ============
$cns = "$base\java\com\example\shinobicore\client\ClientNinjaState.java"
$c = [System.IO.File]::ReadAllText($cns, $utf8)
if (-not $c.Contains("lastCastMsA")) {
    $c = $c.Replace(
        "public static void castActiveJutsu(int set) {",
        "private static long lastCastMsA = 0;`n    private static long lastCastMsB = 0;`n`n    public static void castActiveJutsu(int set) {`n        long nowMs = System.currentTimeMillis();`n        if (set == 0) { if (nowMs - lastCastMsA < 400) return; lastCastMsA = nowMs; }`n        else { if (nowMs - lastCastMsB < 400) return; lastCastMsB = nowMs; }"
    )
    [System.IO.File]::WriteAllText($cns, $c, $utf8)
    Write-Host "[OK] ClientNinjaState: cast cooldown 400ms"
}

# ============ 8. JutsuAssignmentScreen: fix categories + 2-row tabs ============
Write-File "$base\java\com\example\shinobicore\client\JutsuAssignmentScreen.java" @'
package com.example.shinobicore.client;

import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.client.gui.widget.TextFieldWidget;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;

import java.util.*;

public class JutsuAssignmentScreen extends Screen {
    private final int loadoutSet;
    private final int slotIndex;
    private final Screen parent;

    private static final String[] CATEGORIES = {"All","Fire","Water","Wind","Light","Earth","Tai","Ken","Shur","Med","Sum","Seal","Gen"};
    private static final String[] CAT_KEYS = {"all","fire","water","wind","lightning","earth","taijutsu","kenjutsu","shuriken","medical","summon","sealing","general"};

    private String currentCategory = "all";
    private String searchQuery = "";
    private TextFieldWidget searchBox;
    private List<String> filteredJutsus = new ArrayList<>();
    private int scrollOffset = 0;
    private static final int VISIBLE_COUNT = 10;
    private static final int ROW_HEIGHT = 18;

    public JutsuAssignmentScreen(Screen parent, int loadoutSet, int slotIndex) {
        super(Text.literal("Assign Jutsu"));
        this.parent = parent;
        this.loadoutSet = loadoutSet;
        this.slotIndex = slotIndex;
    }

    @Override
    protected void init() {
        searchBox = new TextFieldWidget(textRenderer, width/2 - 100, 16, 200, 16, Text.literal("Search"));
        searchBox.setChangedListener(s -> { searchQuery = s.toLowerCase(); updateFilteredList(); });
        addDrawableChild(searchBox);

        // 2 rows of tabs
        int tabW = 48, tabH = 16, gap = 2;
        int perRow = 7;
        int totalW = perRow * (tabW + gap);
        int startX = width/2 - totalW/2;
        for (int i = 0; i < CATEGORIES.length; i++) {
            int row = i / perRow;
            int col = i % perRow;
            final String cat = CAT_KEYS[i];
            addDrawableChild(ButtonWidget.builder(
                Text.literal(CATEGORIES[i]),
                b -> { currentCategory = cat; updateFilteredList(); }
            ).dimensions(startX + col * (tabW + gap), 38 + row * (tabH + 2), tabW, tabH).build());
        }

        addDrawableChild(ButtonWidget.builder(Text.literal("Cancel"), b -> close()).dimensions(width/2 - 40, height - 28, 80, 20).build());
        updateFilteredList();
    }

    private void updateFilteredList() {
        filteredJutsus.clear();
        for (String id : ClientNinjaState.learned) {
            String name = ClientNinjaState.name(id).toLowerCase();
            if (!searchQuery.isEmpty() && !name.contains(searchQuery) && !id.toLowerCase().contains(searchQuery)) continue;
            if (!currentCategory.equals("all") && !matchesCategory(id, currentCategory)) continue;
            filteredJutsus.add(id);
        }
        filteredJutsus.sort(String.CASE_INSENSITIVE_ORDER);
        scrollOffset = 0;
    }

    private boolean matchesCategory(String id, String cat) {
        String lower = id.toLowerCase();
        return switch (cat) {
            case "fire" -> lower.contains("fire") || lower.contains("flame") || lower.contains("ash") || lower.contains("amaterasu") || lower.contains("blaze");
            case "water" -> lower.contains("water") || lower.contains("shark") || lower.contains("maelstrom");
            case "wind" -> lower.contains("wind") || lower.contains("vacuum") || lower.contains("gale") || lower.contains("rasenshuriken") || lower.contains("sickle");
            case "lightning" -> lower.contains("light") || lower.contains("thunder") || lower.contains("chidori") || lower.contains("kirin");
            case "earth" -> lower.contains("earth") || lower.contains("rock") || lower.contains("stone") || lower.contains("golem");
            case "taijutsu" -> lower.contains("taijutsu") || lower.contains("lotus") || lower.contains("peacock") || lower.contains("elephant") || lower.contains("gates") || lower.contains("rotation") || lower.contains("whirlwind") || lower.contains("swallow");
            case "kenjutsu" -> lower.contains("kenjutsu") || lower.contains("katana") || lower.contains("iai") || lower.contains("slash") || lower.contains("counter") || lower.contains("heavenly");
            case "shuriken" -> lower.contains("shuriken") || lower.contains("kunai") || lower.contains("senbon") || lower.contains("tracking") || lower.contains("flash") || lower.contains("smoke");
            case "medical" -> lower.contains("medical") || lower.contains("heal") || lower.contains("resus") || lower.contains("hundred") || lower.contains("palm") || lower.contains("poison_extract");
            case "summon" -> lower.contains("summon") || lower.contains("contract") || lower.contains("edo");
            case "sealing" -> lower.contains("seal") || lower.contains("reaper");
            case "general" -> lower.contains("substitution") || lower.contains("shunshin") || lower.contains("clone") || lower.contains("hide") || lower.contains("flicker") || lower.contains("genjutsu") || lower.contains("rope") || lower.contains("camouflage") || lower.contains("paper");
            default -> true;
        };
    }

    @Override
    public void render(DrawContext ctx, int mouseX, int mouseY, float delta) {
        renderBackground(ctx);
        super.render(ctx, mouseX, mouseY, delta);

        String title = "Slot " + (slotIndex + 1) + " (Loadout " + (loadoutSet == 0 ? "A" : "B") + ")";
        ctx.drawText(textRenderer, Text.literal(title), width/2 - textRenderer.getWidth(title)/2, 6, 0xFFFFFF, true);

        int listX = width/2 - 150, listY = 78;
        int listW = 300, listH = VISIBLE_COUNT * ROW_HEIGHT + 4;
        ctx.fill(listX - 2, listY - 2, listX + listW + 2, listY + listH + 2, 0xFF333333);
        ctx.fill(listX, listY, listX + listW, listY + listH, 0xAA111111);

        int shown = 0;
        for (int i = scrollOffset; i < filteredJutsus.size() && shown < VISIBLE_COUNT; i++, shown++) {
            String id = filteredJutsus.get(i);
            String name = ClientNinjaState.name(id);
            int rowY = listY + 2 + shown * ROW_HEIGHT;
            boolean hover = mouseX >= listX && mouseX < listX + listW && mouseY >= rowY && mouseY < rowY + ROW_HEIGHT;
            if (hover) ctx.fill(listX, rowY, listX + listW, rowY + ROW_HEIGHT, 0x44FFFFFF);
            ctx.drawText(textRenderer, Text.literal(name), listX + 4, rowY + 4, hover ? 0xFFFFFF : 0xDDDDDD, false);
        }

        if (filteredJutsus.size() > VISIBLE_COUNT) {
            int maxScroll = filteredJutsus.size() - VISIBLE_COUNT;
            int scrollBarY = listY + (int)((float)scrollOffset / maxScroll * (listH - 20));
            ctx.fill(listX + listW - 4, listY, listX + listW, listY + listH, 0x44444444);
            ctx.fill(listX + listW - 4, scrollBarY, listX + listW, scrollBarY + 20, 0xFF888888);
        }

        String count = filteredJutsus.size() + " jutsus";
        ctx.drawText(textRenderer, Text.literal(count), listX + listW - textRenderer.getWidth(count) - 4, listY + listH + 4, 0xAAAAAA, false);

        int clearY = listY + listH + 16;
        boolean clearHover = mouseX >= listX && mouseX < listX + listW && mouseY >= clearY && mouseY < clearY + 14;
        ctx.fill(listX, clearY, listX + listW, clearY + 14, clearHover ? 0xFFCC3322 : 0xAA442211);
        ctx.drawText(textRenderer, Text.literal("[ Clear this slot ]"), listX + listW/2 - textRenderer.getWidth("[ Clear this slot ]")/2, clearY + 3, 0xFFFFFF, false);
    }

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        int listX = width/2 - 150, listY = 78;
        int listW = 300;
        int listH = VISIBLE_COUNT * ROW_HEIGHT + 4;

        if (mx >= listX && mx < listX + listW && my >= listY && my < listY + listH) {
            int idx = scrollOffset + (int)((my - listY - 2) / ROW_HEIGHT);
            if (idx >= 0 && idx < filteredJutsus.size()) {
                sendSetSlot(filteredJutsus.get(idx));
                return true;
            }
        }

        int clearY = listY + listH + 16;
        if (mx >= listX && mx < listX + listW && my >= clearY && my < clearY + 14) {
            sendSetSlot("");
            return true;
        }

        return super.mouseClicked(mx, my, button);
    }

    @Override
    public boolean mouseScrolled(double mx, double my, double amount) {
        int maxScroll = Math.max(0, filteredJutsus.size() - VISIBLE_COUNT);
        scrollOffset = Math.max(0, Math.min(maxScroll, scrollOffset - (int)amount));
        return true;
    }

    private void sendSetSlot(String id) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(loadoutSet);
        buf.writeInt(slotIndex);
        buf.writeString(id);
        ClientPlayNetworking.send(ModPackets.SET_SLOT_ID, buf);
        close();
    }

    @Override
    public void close() {
        if (client != null) client.setScreen(parent);
    }
}
'@

# ============ 9. Remove duplicate jutsus + their tree nodes ============
$dupes = @("water_five_sharks", "water_tearing", "earth_dragon_bullet")
foreach ($d in $dupes) {
    $jf = "$base\resources\data\shinobicore\jutsu\$d.json"
    if (Test-Path $jf) { Remove-Item $jf -Force; Write-Host "[OK] Removed duplicate $d.json" }
}
$tree = "$base\resources\data\shinobicore\skill_tree\tree.json"
$tc = [System.IO.File]::ReadAllText($tree, $utf8)
$tc = $tc -replace ',?\{"id":"water_five_n"[^}]*\}', ''
$tc = $tc -replace ',?\{"id":"water_tearing_n"[^}]*\}', ''
$tc = $tc -replace ',?\{"id":"earth_dragon_n"[^}]*\}', ''
[System.IO.File]::WriteAllText($tree, $tc, $utf8)
Write-Host "[OK] Removed duplicate tree nodes"

# ============ 10. Buff cloud particles in JSONs ============
$cloudFix = @{
    "fire_ash_pile" = '{"id":"shinobicore:fire_ash_pile","name":"Fire Release: Ash Pile Burn","category":"elemental_ninjutsu","nature":"fire","type":"aoe","params":{"radius":6,"particle":"smoke","particleCount":250,"statusEffect":"blindness","statusDuration":100,"statusAmplifier":1},"baseCost":34,"baseDamage":4,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":22,"nature_fire":28,"ninjutsu":20}}'
    "fire_ash_hide" = '{"id":"shinobicore:fire_ash_hide","name":"Fire Release: Hiding in Ash","category":"elemental_ninjutsu","nature":"fire","type":"aoe","params":{"radius":5,"particle":"smoke","particleCount":250,"statusEffect":"blindness","statusDuration":80},"baseCost":26,"baseDamage":2,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"control":18,"nature_fire":24,"ninjutsu":16}}'
    "wind_dust_cloud" = '{"id":"shinobicore:wind_dust_cloud","name":"Wind Release: Dust Cloud","category":"elemental_ninjutsu","nature":"wind","type":"aoe","params":{"radius":6,"particle":"smoke","particleCount":250,"statusEffect":"blindness","statusDuration":100,"statusAmplifier":1},"baseCost":30,"baseDamage":3,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":20,"nature_wind":26,"ninjutsu":18}}'
    "smoke_bomb" = '{"id":"shinobicore:smoke_bomb","name":"Tool: Smoke Bomb","category":"shape_ninjutsu","type":"aoe","params":{"radius":4,"particle":"smoke","particleCount":250,"statusEffect":"blindness","statusDuration":60},"baseCost":15,"baseDamage":0,"strain":4,"requiredUsesForFullProficiency":25,"requirements":{"control":12,"perception":10}}'
}
foreach ($k in $cloudFix.Keys) {
    Write-File "$base\resources\data\shinobicore\jutsu\$k.json" $cloudFix[$k]
}
Write-Host "[OK] Cloud particles buffed to 250"

Write-Host "=== BATCH CRITICAL DONE ==="