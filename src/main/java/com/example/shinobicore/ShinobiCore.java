package com.example.shinobicore;

import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.command.NinjaCommand;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.event.NinjaTickHandler;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.network.ChakraSyncPacket;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ClanType;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import io.netty.buffer.Unpooled;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.example.shinobicore.entity.ModEntities;
import java.util.Random;
import com.example.shinobicore.enchantment.ModEnchantments;
import com.example.shinobicore.jutsu.*;


public class ShinobiCore implements ModInitializer {
    public static final String MOD_ID = "shinobicore";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);
    private static final Random RANDOM = new Random();

    @Override
    public void onInitialize() {
        LOGGER.info("Shinobi Core загружается...");
        ModEnchantments.register();
        ModConfig.load();
        ModEntities.register();
        // Регистрация behaviors
        BehaviorRegistry.register("projectile", new ProjectileBehavior());
        BehaviorRegistry.register("aoe", new AoeBehavior());
        BehaviorRegistry.register("dash", new DashBehavior());
        BehaviorRegistry.register("melee", new MeleeBehavior());
        BehaviorRegistry.register("wall", new WallBehavior());
        BehaviorRegistry.register("utility", new UtilityBehavior());
        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            NinjaCommand.register(dispatcher);
        });

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
                            LOGGER.info("Sarutobi {} gained extra affinity: {}", player.getName().getString(), second.getId());
                        }
                    }

                    LOGGER.info("Auto-assigned clan {} to {}", randomClan.id(), player.getName().getString());
                }
            }

            sendChakraSync(player);
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
            }
        });

        LOGGER.info("Shinobi Core загружен!");
    }

    public static void sendChakraSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        ChakraSyncPacket packet = ChakraSyncPacket.fromData(data);

        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        packet.write(buf);

        ServerPlayNetworking.send(player, ModPackets.CHAKRA_SYNC_ID, buf);
    }

    public static void sendLoadoutSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getActiveSlot());
        for (int i = 0; i < 5; i++) {
            buf.writeString(data.getLoadoutSlot(i) == null ? "" : data.getLoadoutSlot(i));
        }
        ServerPlayNetworking.send(player, ModPackets.LOADOUT_SYNC_ID, buf);
    }

    public static void sendStatsSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getSkillPoints());
        buf.writeInt(data.getReserveLevel());
        buf.writeInt(data.getReserveXp());
        for (StatType s : StatType.values()) {
            buf.writeInt(data.getStatLevel(s));
            buf.writeInt(data.getStatXp(s));
        }
        for (ElementType e : ElementType.values()) {
            buf.writeInt(data.getNatureLevel(e));
            buf.writeInt(data.getNatureXp(e));
        }
        for (ElementType e : ElementType.values()) {
            buf.writeBoolean(data.isNatureUnlocked(e));
        }
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
}