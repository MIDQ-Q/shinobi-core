package com.example.shinobicore.network.handlers;

import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.network.PacketValidator;
import com.example.shinobicore.network.PacketRateLimiter;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.StatType;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public final class ProgressionPacketHandlers {
    private ProgressionPacketHandlers() {}

    public static void register() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.SPEND_SP_ID, (server, player, handler, buf, responseSender) -> {
            final String type = PacketValidator.safeReadString(buf);
            final String id = PacketValidator.safeReadString(buf);
            if (type == null || type.isEmpty() || id == null || id.isEmpty()) return;
            if (!PacketRateLimiter.allow(player.getUuid(), "SPEND_SP", 200)) return;
            server.execute(() -> ShinobiCore.handleSpendSp(player, type, id));
        });

        ServerPlayNetworking.registerGlobalReceiver(ModPackets.UNLOCK_NODE_ID, (server, player, handler, buf, responseSender) -> {
            final String nodeId = PacketValidator.safeReadString(buf);
            server.execute(() -> ShinobiCore.handleUnlockNode(player, nodeId));
        });

        ServerPlayNetworking.registerGlobalReceiver(ModPackets.ATTUNEMENT_ID, (server, player, handler, buf, responseSender) -> {
            final String elementId = PacketValidator.safeReadString(buf);
            final boolean success = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                ElementType element = null;
                for (ElementType e : ElementType.values()) {
                    if (e.getId().equals(elementId)) { element = e; break; }
                }
                if (element == null) return;
                if (success) {
                    int unlockedCount = 0;
                    for (ElementType e2 : ElementType.values()) {
                        if (data.isNatureUnlocked(e2)) unlockedCount++;
                    }
                    int cost = 10 + unlockedCount * 5;
                    if (data.getSkillPoints() < cost) {
                        player.sendMessage(Text.literal("\u00a7cNot enough SP! Need " + cost), false);
                        return;
                    }
                    data.addSkillPoints(-cost);
                    data.setNatureUnlocked(element, true);
                    if (data.getNatureLevel(element) < 1) data.setNatureLevel(element, 1);
                    ShinobiCore.sendStatsSync(player);
                    player.sendMessage(Text.literal("\u00a7aAttuned to " + elementId + "! (-" + cost + " SP)"), false);
                } else {
                    player.sendMessage(Text.literal("\u00a7cAttunement failed."), false);
                }
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(ModPackets.CONTROL_TRAIN_ID, (server, player, handler, buf, responseSender) -> {
            final boolean success = buf.readBoolean();
            final float accuracy = buf.readFloat();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                int xp = success ? Math.round(15 + accuracy * 25) : 3;
                NinjaFormula.grantStatXp(data, StatType.CONTROL, xp);
                ShinobiCore.sendStatsSync(player);
                player.sendMessage(Text.literal(success
                    ? String.format("\u00a7aControl training: +%d XP (%.0f%%)", xp, accuracy * 100)
                    : "\u00a77Training: +" + xp + " XP"), false);
            });
        });
    }
}