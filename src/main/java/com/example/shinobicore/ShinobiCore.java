package com.example.shinobicore;

import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.command.NinjaCommand;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.item.ModItems;
import com.example.shinobicore.event.NinjaTickHandler;
import com.example.shinobicore.jutsu.AoeBehavior;
import com.example.shinobicore.jutsu.BehaviorRegistry;
import com.example.shinobicore.jutsu.DashBehavior;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.jutsu.MeleeBehavior;
import com.example.shinobicore.jutsu.ProjectileBehavior;
import com.example.shinobicore.jutsu.UtilityBehavior;
import com.example.shinobicore.jutsu.WallBehavior;
import com.example.shinobicore.jutsu.GenjutsuBehavior; // PHASE_E_GENJUTSU_BEHAVIOR_REGISTERED
import com.example.shinobicore.jutsu.GenjutsuBehavior;
import com.example.shinobicore.network.ChakraSyncPacket;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.tree.SkillTreeNode;
import com.example.shinobicore.tree.SkillTreeRegistry;
import com.example.shinobicore.stat.StatType;
import io.netty.buffer.Unpooled;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Random;

public class ShinobiCore implements ModInitializer {
    public static final String MOD_ID = "shinobicore";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);
    private static final Random RANDOM = new Random();

    @Override
    public void onInitialize() {
        LOGGER.info("Shinobi Core загружается...");
        ModConfig.load();
        JutsuLogger.init();
        ModEntities.register();
        ModItems.register();

        BehaviorRegistry.register("projectile", new ProjectileBehavior());
        BehaviorRegistry.register("aoe", new AoeBehavior());
        BehaviorRegistry.register("dash", new DashBehavior());
        BehaviorRegistry.register("melee", new MeleeBehavior());
        BehaviorRegistry.register("wall", new WallBehavior());
        BehaviorRegistry.register("utility", new UtilityBehavior());
        BehaviorRegistry.register("genjutsu", new GenjutsuBehavior());

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> NinjaCommand.register(dispatcher));
        ServerTickEvents.END_SERVER_TICK.register(NinjaTickHandler::onServerTick);
        // === PHASE5_CAST_TICK ===
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
                com.example.shinobicore.combat.CastingServerState.tickPlayer(p);
            }
        });
        ModPackets.register();

        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            ServerPlayerEntity player = handler.getPlayer();
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

            if (!data.isClanChosen()) {
                ClanDefinition randomClan = ClanRegistry.getRandom();
                if (randomClan != null) {
                    // === ИЗМЕНЕНО: сохраняем строку ===
                    data.setClanId(randomClan.id());
                    data.setAffinity(randomClan.affinity());
                // === AFFINITY DEDUP FIX ===
                    // === Р¤РРљРЎ: СЂР°Р·Р±Р»РѕРєРёСЂРѕРІР°С‚СЊ affinity РєР°Рє nature ===
                    if (randomClan.affinity() != null) {
                        data.setNatureUnlocked(randomClan.affinity(), true);
                        if (data.getNatureLevel(randomClan.affinity()) < 5) {
                            data.setNatureLevel(randomClan.affinity(), 5);
                        }
                    }
                    // === ФИКС: разблокировать affinity как nature ===
                    
                    data.setClanChosen(true);

                    if (randomClan.extraAffinityCount() > 0) {
                        ElementType[] elements = ElementType.values();
                        ElementType second = elements[RANDOM.nextInt(elements.length)];
                        if (second != randomClan.affinity()) {
                            data.setNatureLevel(second, 10);
                            data.setNatureUnlocked(second, true);
                        }
                    }

                    LOGGER.info("Auto-assigned clan {} to {}", randomClan.id(), player.getName().getString());
                }
            }

            sendChakraSync(player);
            sendCatalogSync(player);
            sendLoadoutSync(player);
            sendStatsSync(player);
            sendBodySync(player);
                sendTreeSync(player);
        });

        ServerLifecycleEvents.SERVER_STARTED.register(server -> {
            JutsuRegistry.reload(server.getResourceManager());
            ClanRegistry.reload(server.getResourceManager());
            SkillTreeRegistry.reload(server.getResourceManager());
        });

        ServerLifecycleEvents.END_DATA_PACK_RELOAD.register((server, resourceManager, success) -> {
            if (success) {
                JutsuRegistry.reload(server.getResourceManager());
                ClanRegistry.reload(server.getResourceManager());
            SkillTreeRegistry.reload(server.getResourceManager());
                for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) sendCatalogSync(p);
            }
        });

        LOGGER.info("Shinobi Core загружен!");
    }

    public static void sendChakraSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        ChakraSyncPacket.fromData(data).write(buf);
        ServerPlayNetworking.send(player, ModPackets.CHAKRA_SYNC_ID, buf);
    }

    public static void sendCatalogSync(ServerPlayerEntity player) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        var all = JutsuRegistry.getAll();
        buf.writeInt(all.size());
        for (var def : all) {
            buf.writeString(def.id());
            buf.writeString(def.name());
        }
        ServerPlayNetworking.send(player, ModPackets.CATALOG_SYNC_ID, buf);
    }

    public static void sendLoadoutSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getActiveSlot(0));
        buf.writeInt(data.getActiveSlot(1));
        for (int i = 0; i < 5; i++) buf.writeString(data.getLoadoutSlot(0, i) == null ? "" : data.getLoadoutSlot(0, i));
        for (int i = 0; i < 5; i++) buf.writeString(data.getLoadoutSlot(1, i) == null ? "" : data.getLoadoutSlot(1, i));
        buf.writeInt(data.getLearnedJutsus().size());
        for (String id : data.getLearnedJutsus()) buf.writeString(id);
        ServerPlayNetworking.send(player, ModPackets.LOADOUT_SYNC_ID, buf);
    }

    public static void sendStatsSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getSkillPoints());
        buf.writeInt(data.getReserveLevel());
        buf.writeInt(data.getReserveXp());
        for (StatType s : StatType.values()) { buf.writeInt(data.getStatLevel(s)); buf.writeInt(data.getStatXp(s)); }
        for (ElementType e : ElementType.values()) { buf.writeInt(data.getNatureLevel(e)); buf.writeInt(data.getNatureXp(e)); }
        for (ElementType e : ElementType.values()) buf.writeBoolean(data.isNatureUnlocked(e));
        buf.writeBoolean(data.isSensoryEnabled());
        ServerPlayNetworking.send(player, ModPackets.STATS_SYNC_ID, buf);
    }

    public static void sendBodySync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getHpLevel());
        buf.writeInt(data.getSpeedLevel());
        buf.writeInt(data.getJumpLevel());
        buf.writeBoolean(data.isChakraMode());
        
        // === ИЗМЕНЕНО: отправляем строку ===
        buf.writeString(data.getClanId());
        buf.writeString(data.getAffinity() != null ? data.getAffinity().getId() : "");
        
        ServerPlayNetworking.send(player, ModPackets.BODY_SYNC_ID, buf);
    }

        public static void broadcastCastFx(ServerPlayerEntity player, String natureId) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(player.getId());
        buf.writeString(natureId);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(player)) {
            ServerPlayNetworking.send(p, ModPackets.CAST_FX_ID, buf);
        }
        ServerPlayNetworking.send(player, ModPackets.CAST_FX_ID, buf);
    }

    public static void sendRasenganSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(data.isRasenganCharging());
        buf.writeFloat(data.getRasenganChargeProgress());
        buf.writeBoolean(data.isRasenganReady());
        ServerPlayNetworking.send(player, ModPackets.RASENGAN_SYNC_ID, buf);
    }

    public static void handleRasenganStrike(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (!data.isRasenganReady()) return;

        data.setRasenganReady(false);
        data.setRasenganCharging(false);

        // Параметры из JSON
        float dashDistance = 6.0f;
        float hitRadius = 2.5f;
        float knockback = 3.5f;
        float damage = 16.0f;

        // Читаем из JutsuDefinition если есть
        var def = com.example.shinobicore.jutsu.JutsuRegistry.get("shinobicore:rasengan");
        if (def != null) {
            damage = def.baseDamage() * com.example.shinobicore.stat.NinjaFormula.damageMultiplier(data, def);
            if (def.params().has("dashDistance")) dashDistance = def.params().get("dashDistance").getAsFloat();
            if (def.params().has("hitRadius")) hitRadius = def.params().get("hitRadius").getAsFloat();
            if (def.params().has("knockback")) knockback = def.params().get("knockback").getAsFloat();
        }

        net.minecraft.util.math.Vec3d look = player.getRotationVector();
        net.minecraft.util.math.Vec3d startPos = player.getPos();
        net.minecraft.util.math.Vec3d endPos = startPos.add(look.multiply(dashDistance));

        // Рывок вперёд
        player.addVelocity(look.x * dashDistance * 0.6, 0.15, look.z * dashDistance * 0.6);
        player.velocityModified = true;

        // Урон по пути
        if (player.getWorld() instanceof net.minecraft.server.world.ServerWorld serverWorld) {
            java.util.List<net.minecraft.entity.LivingEntity> targets =
                    findRasenganTargets(serverWorld, player, startPos, endPos, hitRadius);

            for (net.minecraft.entity.LivingEntity target : targets) {
                target.damage(player.getDamageSources().magic(), damage);

                // Мощный отброс (Расенган подбрасывает)
                net.minecraft.util.math.Vec3d kb = target.getPos().subtract(player.getPos()).normalize();
                target.addVelocity(kb.x * knockback, knockback * 0.4, kb.z * knockback);
                target.velocityModified = true;
            }

            // Визуал: взрыв частиц при ударе
            if (!targets.isEmpty()) {
                net.minecraft.util.math.Vec3d hitPos = targets.get(0).getPos();
                spawnRasenganImpact(serverWorld, hitPos);
            }

            // Визуал: след вдоль пути
            spawnRasenganTrail(serverWorld, startPos, endPos, 80);
        }

        sendRasenganSync(player);
        com.example.shinobicore.jutsu.JutsuLogger.logBehavior("rasengan",
                String.format("STRIKE: player=%s, damage=%.2f, knockback=%.2f",
                        player.getName().getString(), damage, knockback));
    }

    private static java.util.List<net.minecraft.entity.LivingEntity> findRasenganTargets(
            net.minecraft.server.world.ServerWorld world, ServerPlayerEntity attacker,
            net.minecraft.util.math.Vec3d start, net.minecraft.util.math.Vec3d end, float radius) {
        java.util.List<net.minecraft.entity.LivingEntity> targets = new java.util.ArrayList<>();
        net.minecraft.util.math.Vec3d dir = end.subtract(start).normalize();
        float length = (float) start.distanceTo(end);

        for (float d = 0; d <= length; d += 0.5f) {
            net.minecraft.util.math.Vec3d checkPos = start.add(dir.multiply(d));
            for (net.minecraft.entity.Entity entity : world.getOtherEntities(attacker,
                    attacker.getBoundingBox().expand(radius + 1.0).offset(checkPos.subtract(attacker.getPos())))) {
                if (entity instanceof net.minecraft.entity.LivingEntity living
                        && !living.equals(attacker) && living.isAlive()) {
                    if (living.getPos().distanceTo(checkPos) <= radius + 0.5) {
                        if (!targets.contains(living)) {
                            targets.add(living);
                        }
                    }
                }
            }
        }
        return targets;
    }

    private static void spawnRasenganTrail(net.minecraft.server.world.ServerWorld world,
                                            net.minecraft.util.math.Vec3d start,
                                            net.minecraft.util.math.Vec3d end, int count) {
        net.minecraft.util.math.Vec3d dir = end.subtract(start).normalize();
        float length = (float) start.distanceTo(end);

        for (int i = 0; i < count; i++) {
            float progress = (float) i / count;
            net.minecraft.util.math.Vec3d center = start.add(dir.multiply(progress * length));

            // Вращающиеся спирали
            float angle = progress * (float)(Math.PI * 6);
            float spiralRadius = 0.4f + (float)Math.sin(progress * Math.PI) * 0.4f;

            double x = center.x + Math.cos(angle) * spiralRadius;
            double y = center.y + 1.0 + Math.sin(angle * 2) * spiralRadius * 0.3;
            double z = center.z + Math.sin(angle) * spiralRadius;

            world.spawnParticles(net.minecraft.particle.ParticleTypes.ENCHANT, x, y, z,
                    2, 0.08, 0.08, 0.08, 0.08);

            if (i % 3 == 0) {
                world.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT, x, y, z,
                        1, 0.15, 0.15, 0.15, 0.12);
            }
        }
    }

    private static void spawnRasenganImpact(net.minecraft.server.world.ServerWorld world,
                                             net.minecraft.util.math.Vec3d pos) {
        // Кольцо частиц
        for (int i = 0; i < 40; i++) {
            double angle = (i / 40.0) * Math.PI * 2;
            double r = 1.0 + Math.random() * 2.0;

            world.spawnParticles(net.minecraft.particle.ParticleTypes.ENCHANT,
                    pos.x + Math.cos(angle) * r,
                    pos.y + 0.5 + Math.random() * 1.5,
                    pos.z + Math.sin(angle) * r,
                    3, 0.2, 0.3, 0.2, 0.1);
        }

        // Взрывная волна
        for (int i = 0; i < 30; i++) {
            world.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT,
                    pos.x + (Math.random() - 0.5) * 4.0,
                    pos.y + Math.random() * 2.5,
                    pos.z + (Math.random() - 0.5) * 4.0,
                    2, 0.3, 0.3, 0.3, 0.2);
        }

        // Облако
        for (int i = 0; i < 15; i++) {
            world.spawnParticles(net.minecraft.particle.ParticleTypes.CLOUD,
                    pos.x + (Math.random() - 0.5) * 2.0,
                    pos.y + 1.0,
                    pos.z + (Math.random() - 0.5) * 2.0,
                    3, 0.3, 0.2, 0.3, 0.01);
        }
    }
    
    public static void handleSpendSp(ServerPlayerEntity player, String type, String id) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int currentLevel;
        boolean isBody = type.equals("body");
        if (type.equals("stat")) {
            StatType s = statById(id); if (s == null) return;
            currentLevel = data.getStatLevel(s);
        } else if (type.equals("nature")) {
            ElementType e = elementById(id); if (e == null) return;
            if (!data.isNatureUnlocked(e)) { player.sendMessage(Text.literal("§cUnlock this nature first!"), false); return; }
            currentLevel = data.getNatureLevel(e);
        } else if (type.equals("reserve")) {
            currentLevel = data.getReserveLevel();
        } else if (isBody) {
            if (id.equals("hp")) currentLevel = data.getHpLevel();
            else if (id.equals("speed")) currentLevel = data.getSpeedLevel();
            else if (id.equals("jump")) currentLevel = data.getJumpLevel();
            else return;
        } else return;

        int maxLevel = isBody ? 7 : NinjaPlayerData.MAX_LEVEL;
        if (currentLevel >= maxLevel) { player.sendMessage(Text.literal("§cMax level reached!"), false); return; }

        int cost = isBody ? NinjaFormula.bodySpCost() : NinjaFormula.spCostForLevel(currentLevel);
        if (data.getSkillPoints() < cost) { player.sendMessage(Text.literal("§cNot enough SP! Need " + cost), false); return; }

        data.addSkillPoints(-cost);
        if (type.equals("stat")) data.setStatLevel(statById(id), currentLevel + 1);
        else if (type.equals("nature")) { ElementType e = elementById(id); data.setNatureLevel(e, currentLevel + 1); data.setNatureUnlocked(e, true); }
        else if (type.equals("reserve")) data.setReserveLevel(currentLevel + 1);
        else if (isBody) {
            if (id.equals("hp")) data.setHpLevel(currentLevel + 1);
            else if (id.equals("speed")) data.setSpeedLevel(currentLevel + 1);
            else if (id.equals("jump")) data.setJumpLevel(currentLevel + 1);
            if (id.equals("hp")) {
                var hpAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH);
                if (hpAttr != null) hpAttr.setBaseValue(NinjaFormula.maxHealth(data.getHpLevel()));
            }
        }

        sendStatsSync(player);
        sendBodySync(player);
                sendTreeSync(player);
        sendChakraSync(player);
        player.sendMessage(Text.literal("§aLevel up!"), false);
    }

    public static void sendTreeSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getUnlockedNodes().size());
        for (String nodeId : data.getUnlockedNodes()) buf.writeString(nodeId);
        ServerPlayNetworking.send(player, ModPackets.TREE_SYNC_ID, buf);
    }

    public static void handleUnlockNode(ServerPlayerEntity player, String nodeId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        SkillTreeNode node = SkillTreeRegistry.get(nodeId);
        if (node == null) {
            player.sendMessage(Text.literal("В§cUnknown node: " + nodeId), false);
            return;
        }
        if (data.isNodeUnlocked(nodeId)) {
            player.sendMessage(Text.literal("В§cAlready unlocked!"), false);
            return;
        }
        if (!SkillTreeRegistry.isVisibleServer(node, data)) {
            player.sendMessage(Text.literal("В§cThis node is not available to you!"), false);
            return;
        }
        for (String req : node.requires()) {
            if (!data.isNodeUnlocked(req)) {
                player.sendMessage(Text.literal("В§cRequires: " + req), false);
                return;
            }
        }
        if (data.getSkillPoints() < node.spCost()) {
            player.sendMessage(Text.literal("В§cNot enough SP! Need " + node.spCost()), false);
            return;
        }
        if (!node.branch().equals("general") && !node.branch().equals("taijutsu")
            && !node.branch().equals("medical")) {
            ElementType nature = null;
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(node.branch())) { nature = e; break; }
            }
            if (nature != null && !data.isNatureUnlocked(nature)) {
                player.sendMessage(Text.literal("В§cUnlock this nature first!"), false);
                return;
            }
        }

        data.addSkillPoints(-node.spCost());
        data.unlockNode(nodeId);

        if ("jutsu".equals(node.type()) && node.jutsuId() != null) {
            if (!data.getLearnedJutsus().contains(node.jutsuId())) {
                data.learnJutsu(node.jutsuId());
            }
        }

        sendStatsSync(player);
        sendLoadoutSync(player);
        sendTreeSync(player);
        player.sendMessage(Text.literal("В§aUnlocked: " + nodeId), false);
    }

    private static StatType statById(String id) {
        for (StatType s : StatType.values()) if (s.getId().equals(id)) return s;
        return null;
    }

    private static ElementType elementById(String id) {
        for (ElementType e : ElementType.values()) if (e.getId().equals(id)) return e;
        return null;
    }

    public static void broadcastHitStop(ServerPlayerEntity attacker, net.minecraft.entity.LivingEntity target,
                                         int attackerMs, int targetMs) {
        // Send to attacker
        PacketByteBuf atkBuf = new PacketByteBuf(Unpooled.buffer());
        atkBuf.writeInt(attacker.getId());
        atkBuf.writeInt(attackerMs);
        ServerPlayNetworking.send(attacker, ModPackets.HIT_STOP_ID, atkBuf);
        // Send target freeze to attacker (so attacker sees target freeze)
        if (target != null) {
            PacketByteBuf tgtBuf = new PacketByteBuf(Unpooled.buffer());
            tgtBuf.writeInt(target.getId());
            tgtBuf.writeInt(targetMs);
            ServerPlayNetworking.send(attacker, ModPackets.HIT_STOP_ID, tgtBuf);
        }
        // Send to target (if player)
        if (target instanceof ServerPlayerEntity targetPlayer) {
            PacketByteBuf selfBuf = new PacketByteBuf(Unpooled.buffer());
            selfBuf.writeInt(targetPlayer.getId());
            selfBuf.writeInt(targetMs);
            ServerPlayNetworking.send(targetPlayer, ModPackets.HIT_STOP_ID, selfBuf);
        }
    }

    // === PHASE5 CAST BROADCAST ===
    public static void broadcastCastStart(ServerPlayerEntity player, String jutsuId, int durationTicks) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(player.getId());
        buf.writeString(jutsuId);
        buf.writeInt(durationTicks);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(player)) {
            ServerPlayNetworking.send(p, ModPackets.CAST_START_ID, buf);
        }
        ServerPlayNetworking.send(player, ModPackets.CAST_START_ID, buf);
    }

    public static void broadcastCastInterrupt(ServerPlayerEntity player) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(player.getId());
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(player)) {
            ServerPlayNetworking.send(p, ModPackets.CAST_INTERRUPT_ID, buf);
        }
        ServerPlayNetworking.send(player, ModPackets.CAST_INTERRUPT_ID, buf);
    }
}