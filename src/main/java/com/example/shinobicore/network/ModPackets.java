package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;
import com.example.shinobicore.pose.LowPoseTracker;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
public class ModPackets {
    public static final Identifier CHAKRA_SYNC_ID = new Identifier("shinobicore", "chakra_sync");
    public static final Identifier MEDITATE_ID = new Identifier("shinobicore", "meditate");
    public static final Identifier SELECT_SLOT_ID = new Identifier("shinobicore", "select_slot");
    public static final Identifier CAST_SLOT_ID = new Identifier("shinobicore", "cast_slot");
    public static final Identifier SET_SLOT_ID = new Identifier("shinobicore", "set_slot");
    public static final Identifier LOADOUT_SYNC_ID = new Identifier("shinobicore", "loadout_sync");
    public static final Identifier CATALOG_SYNC_ID = new Identifier("shinobicore", "catalog_sync");
    public static final Identifier STATS_SYNC_ID = new Identifier("shinobicore", "stats_sync");
    public static final Identifier SPEND_SP_ID = new Identifier("shinobicore", "spend_sp");
    public static final Identifier BODY_SYNC_ID = new Identifier("shinobicore", "body_sync");
    public static final Identifier CHAKRA_MODE_ID = new Identifier("shinobicore", "chakra_mode");
    public static final Identifier PARKOUR_ACTION_ID = new Identifier("shinobicore", "parkour_action");
    public static final Identifier DODGE_ID = new Identifier("shinobicore", "dodge");
    public static final Identifier POSE_SYNC_ID = new Identifier("shinobicore", "pose_sync");
    public static void register() {
        ServerPlayNetworking.registerGlobalReceiver(MEDITATE_ID, (server, player, handler, buf, responseSender) -> {
            boolean start = buf.readBoolean();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setMeditating(start));
        });

        ServerPlayNetworking.registerGlobalReceiver(SELECT_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int set = buf.readInt(); int slot = buf.readInt();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setActiveSlot(set, slot));
        });

        ServerPlayNetworking.registerGlobalReceiver(CAST_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int set = buf.readInt(); int slot = buf.readInt();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                int s = Math.max(0, Math.min(4, slot));
                String id = data.getLoadoutSlot(set == 0 ? 0 : 1, s);
                if (id != null) JutsuCaster.cast(player, id);
                else player.sendMessage(Text.literal("§cSlot " + (s + 1) + " is empty!"), false);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(DODGE_ID, (server, player, handler, buf, responseSender) -> {
            int direction = buf.readInt(); // -1 = влево, 1 = вправо
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.getCurrentChakra() <= 0 || data.isExhausted()) return;
                
                // Усталость за dodge
                data.setFatigue(data.getFatigue() + ModConfig.instance.parkour.dodgeFatigue);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(POSE_SYNC_ID, (server, player, handler, buf, responseSender) -> {
            boolean low = buf.readBoolean();
            server.execute(() -> LowPoseTracker.set(player.getUuid(), low));
        });

        ServerPlayConnectionEvents.DISCONNECT.register((handler, server) ->
            LowPoseTracker.set(handler.player.getUuid(), false));

        ServerPlayNetworking.registerGlobalReceiver(SET_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int set = buf.readInt(); int slot = buf.readInt(); String id = buf.readString();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                String clean = id.isEmpty() ? null : id;
                if (clean != null && !data.getLearnedJutsus().contains(clean)) {
                    player.sendMessage(Text.literal("§cLearn it first!"), false);
                    return;
                }
                data.setLoadoutSlot(set, Math.max(0, Math.min(4, slot)), clean);
                ShinobiCore.sendLoadoutSync(player);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(SPEND_SP_ID, (server, player, handler, buf, responseSender) -> {
            String type = buf.readString(); String id = buf.readString();
            server.execute(() -> ShinobiCore.handleSpendSp(player, type, id));
        });

        ServerPlayNetworking.registerGlobalReceiver(CHAKRA_MODE_ID, (server, player, handler, buf, responseSender) -> {
            boolean enable = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setChakraMode(enable);
                ShinobiCore.sendBodySync(player);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(PARKOUR_ACTION_ID, (server, player, handler, buf, responseSender) -> {
            String actionId = buf.readString();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.getCurrentChakra() <= 0 || data.isExhausted()) return;
                
                float f = 0;
                
                // Специальный случай для charged_jump (с параметром fatigue)
                if (actionId.equals("charged_jump")) {
                    f = buf.readFloat();
                } else {
                    switch (actionId) {
                        case "slide": f = ModConfig.instance.parkour.slideFatigue; break;
                        case "double_jump": f = ModConfig.instance.parkour.doubleJumpFatigue; break;
                        case "wall_jump": f = ModConfig.instance.parkour.wallJumpFatigue; break;
                        case "vault": f = ModConfig.instance.parkour.vaultFatigue; break;
                        case "wall_run": f = ModConfig.instance.parkour.wallRunFatiguePerTick; break;
                        case "edge_grab": f = ModConfig.instance.parkour.edgeGrabFatigue; break;
                        case "roll": f = ModConfig.instance.parkour.rollFatigue; break;
                    }
                }
                if (f > 0) data.setFatigue(data.getFatigue() + f);
            });
        });
    }
}