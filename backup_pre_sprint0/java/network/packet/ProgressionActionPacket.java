package com.example.shinobicore.network.packet;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.progression.SkillNodes;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.component.IJutsuComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

/**
 * Client -> server progression mutations.
 * Actions: 1=stat+, 2=body+, 3=unlock passive, 4=set loadout slot.
 * CRITICAL: read buf BEFORE server.execute().
 */
public class ProgressionActionPacket {
    public static final Identifier ID = new Identifier("shinobicore", "progression_action");

    public static void send(int action, String payload) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(action);
        buf.writeString(payload != null ? payload : "");
        ClientPlayNetworking.send(ID, buf);
    }

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
            final int action = buf.readInt();
            final String payload = buf.readString();
            server.execute(() -> handle(player, action, payload));
        });
    }

    private static void handle(net.minecraft.server.network.ServerPlayerEntity player, int action, String payload) {
        IStatsComponent stats = NinjaComponents.getStats(player);
        IJutsuComponent jutsu = NinjaComponents.getJutsu(player);
        if (stats == null) return;

        if (action == 1) {
            StatType type = StatType.fromString(payload);
            if (type != null && stats.spendSkillPoints(1)) {
                stats.addStatLevel(type, 1);
            }
        } else if (action == 2) {
            if (!stats.spendSkillPoints(1)) return;
            switch (payload) {
                case "speed": stats.setBodyLevelSpeed(stats.getBodyLevelSpeed() + 1); break;
                case "jump": stats.setBodyLevelJump(stats.getBodyLevelJump() + 1); break;
                case "vitality": stats.setBodyLevelVitality(stats.getBodyLevelVitality() + 1); break;
                case "reserve": stats.setBodyLevelReserve(stats.getBodyLevelReserve() + 1); break;
                case "endurance": stats.setBodyLevelEndurance(stats.getBodyLevelEndurance() + 1); break;
                default: stats.addSkillPoints(1); break;
            }
        } else if (action == 3) {
            SkillNodes.Node node = SkillNodes.byId(payload);
            if (node == null) return;
            if (node.parent != null && !stats.hasPassive(node.parent)) return;
            if (stats.hasPassive(node.id)) return;
            if (stats.spendSkillPoints(node.cost)) {
                stats.unlockPassive(node.id);
            }
        } else if (action == 4) {
            if (jutsu == null) return;
            int i1 = payload.indexOf(':');
            int i2 = payload.indexOf(':', i1 + 1);
            if (i1 < 0 || i2 < 0) return;
            try {
                int loadout = Integer.parseInt(payload.substring(0, i1));
                int slot = Integer.parseInt(payload.substring(i1 + 1, i2));
                String jid = payload.substring(i2 + 1);
                if (jid.isEmpty()) {
                    jutsu.setLoadoutSlot(loadout, slot, null);
                } else if (jutsu.hasLearned(jid)) {
                    jutsu.setLoadoutSlot(loadout, slot, jid);
                }
            } catch (Exception e) {
                ShinobiCore.LOGGER.warn("Bad loadout payload: {}", payload);
            }
        }

        NinjaComponents.STATS.sync(player, stats);
        if (jutsu != null) NinjaComponents.JUTSU.sync(player, jutsu);
    }
}