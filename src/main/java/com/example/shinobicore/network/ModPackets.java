package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;

public class ModPackets {
    public static final Identifier CHAKRA_SYNC_ID = new Identifier("shinobicore", "chakra_sync");
    public static final Identifier MEDITATE_ID = new Identifier("shinobicore", "meditate");
    public static final Identifier SELECT_SLOT_ID = new Identifier("shinobicore", "select_slot");
    public static final Identifier CAST_SLOT_ID = new Identifier("shinobicore", "cast_slot");
    public static final Identifier LOADOUT_SYNC_ID = new Identifier("shinobicore", "loadout_sync");
    public static final Identifier STATS_SYNC_ID = new Identifier("shinobicore", "stats_sync");
    public static final Identifier SPEND_SP_ID = new Identifier("shinobicore", "spend_sp");
    public static final Identifier BODY_SYNC_ID = new Identifier("shinobicore", "body_sync");
    public static final Identifier CHAKRA_MODE_ID = new Identifier("shinobicore", "chakra_mode");

    public static void register() {
        ServerPlayNetworking.registerGlobalReceiver(MEDITATE_ID, (server, player, handler, buf, responseSender) -> {
            boolean start = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setMeditating(start);
                ShinobiCore.LOGGER.info("Player {} meditation: {}", player.getName().getString(), start);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(SELECT_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int slot = buf.readInt();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setActiveSlot(slot);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(CAST_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int slot = buf.readInt();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                int s = Math.max(0, Math.min(4, slot));
                String id = data.getLoadoutSlot(s);
                if (id != null) {
                    JutsuCaster.cast(player, id);
                } else {
                    player.sendMessage(Text.literal("§cSlot " + (s + 1) + " is empty!"), false);
                }
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(SPEND_SP_ID, (server, player, handler, buf, responseSender) -> {
            String type = buf.readString();
            String id = buf.readString();
            server.execute(() -> handleSpendSp(player, type, id));
        });

        ServerPlayNetworking.registerGlobalReceiver(CHAKRA_MODE_ID, (server, player, handler, buf, responseSender) -> {
            boolean enable = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setChakraMode(enable);
                ShinobiCore.LOGGER.info("Player {} chakra mode: {}", player.getName().getString(), enable);
            });
        });
    }

    private static void handleSpendSp(ServerPlayerEntity player, String type, String id) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

        int currentLevel;
        boolean isBody = type.equals("body");

        if (type.equals("stat")) {
            StatType s = statById(id);
            if (s == null) return;
            currentLevel = data.getStatLevel(s);
        } else if (type.equals("nature")) {
            ElementType e = elementById(id);
            if (e == null) return;
            if (!data.isNatureUnlocked(e)) {
                player.sendMessage(Text.literal("§cUnlock this nature first!"), false);
                return;
            }
            currentLevel = data.getNatureLevel(e);
        } else if (type.equals("reserve")) {
            currentLevel = data.getReserveLevel();
        } else if (isBody) {
            if (id.equals("hp")) currentLevel = data.getHpLevel();
            else if (id.equals("speed")) currentLevel = data.getSpeedLevel();
            else if (id.equals("jump")) currentLevel = data.getJumpLevel();
            else return;
        } else {
            return;
        }

        int maxLevel = isBody ? 7 : NinjaPlayerData.MAX_LEVEL;
        if (currentLevel >= maxLevel) {
            player.sendMessage(Text.literal("§cMax level reached!"), false);
            return;
        }

        int cost = isBody ? NinjaFormula.bodySpCost() : NinjaFormula.spCostForLevel(currentLevel);
        if (data.getSkillPoints() < cost) {
            player.sendMessage(Text.literal("§cNot enough SP! Need " + cost), false);
            return;
        }

        data.addSkillPoints(-cost);

        if (type.equals("stat")) {
            data.setStatLevel(statById(id), currentLevel + 1);
        } else if (type.equals("nature")) {
            ElementType e = elementById(id);
            data.setNatureLevel(e, currentLevel + 1);
            data.setNatureUnlocked(e, true);
        } else if (type.equals("reserve")) {
            data.setReserveLevel(currentLevel + 1);
        } else if (isBody) {
            if (id.equals("hp")) data.setHpLevel(currentLevel + 1);
            else if (id.equals("speed")) data.setSpeedLevel(currentLevel + 1);
            else if (id.equals("jump")) data.setJumpLevel(currentLevel + 1);
        }

        ShinobiCore.sendStatsSync(player);
        ShinobiCore.sendChakraSync(player);
        ShinobiCore.sendBodySync(player);
        player.sendMessage(Text.literal("§aLevel up!"), false);
    }

    private static StatType statById(String id) {
        for (StatType s : StatType.values()) {
            if (s.getId().equals(id)) return s;
        }
        return null;
    }

    private static ElementType elementById(String id) {
        for (ElementType e : ElementType.values()) {
            if (e.getId().equals(id)) return e;
        }
        return null;
    }
}