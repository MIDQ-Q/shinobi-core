package com.example.shinobicore;

import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.command.NinjaCommand;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.event.NinjaTickHandler;
import com.example.shinobicore.jutsu.AoeBehavior;
import com.example.shinobicore.jutsu.BehaviorRegistry;
import com.example.shinobicore.jutsu.DashBehavior;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.jutsu.MeleeBehavior;
import com.example.shinobicore.jutsu.ProjectileBehavior;
import com.example.shinobicore.jutsu.UtilityBehavior;
import com.example.shinobicore.jutsu.WallBehavior;
import com.example.shinobicore.network.ChakraSyncPacket;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ClanType;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
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
        ModEntities.register();

        BehaviorRegistry.register("projectile", new ProjectileBehavior());
        BehaviorRegistry.register("aoe", new AoeBehavior());
        BehaviorRegistry.register("dash", new DashBehavior());
        BehaviorRegistry.register("melee", new MeleeBehavior());
        BehaviorRegistry.register("wall", new WallBehavior());
        BehaviorRegistry.register("utility", new UtilityBehavior());

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> NinjaCommand.register(dispatcher));
        ServerTickEvents.END_SERVER_TICK.register(NinjaTickHandler::onServerTick);
        ModPackets.register();

        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            ServerPlayerEntity player = handler.getPlayer();
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

            if (!data.isClanChosen()) {
                ClanDefinition randomClan = ClanRegistry.getRandom();
                if (randomClan != null) {
                    data.setClan(ClanType.valueOf(randomClan.id().toUpperCase()));
                    data.setAffinity(randomClan.affinity());
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
        });

        ServerLifecycleEvents.SERVER_STARTED.register(server -> {
            JutsuRegistry.reload(server.getResourceManager());
            ClanRegistry.reload(server.getResourceManager());
        });

        ServerLifecycleEvents.END_DATA_PACK_RELOAD.register((server, resourceManager, success) -> {
            if (success) {
                JutsuRegistry.reload(server.getResourceManager());
                ClanRegistry.reload(server.getResourceManager());
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
        ServerPlayNetworking.send(player, ModPackets.STATS_SYNC_ID, buf);
    }

    public static void sendBodySync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getHpLevel());
        buf.writeInt(data.getSpeedLevel());
        buf.writeInt(data.getJumpLevel());
        buf.writeBoolean(data.isChakraMode());
        buf.writeString(data.getClan().getId());
        buf.writeString(data.getAffinity() != null ? data.getAffinity().getId() : "");
        ServerPlayNetworking.send(player, ModPackets.BODY_SYNC_ID, buf);
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
        sendChakraSync(player);
        player.sendMessage(Text.literal("§aLevel up!"), false);
    }

    private static StatType statById(String id) {
        for (StatType s : StatType.values()) if (s.getId().equals(id)) return s;
        return null;
    }

    private static ElementType elementById(String id) {
        for (ElementType e : ElementType.values()) if (e.getId().equals(id)) return e;
        return null;
    }
}