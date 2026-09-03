package com.example.shinobicore.network.handlers;

import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.network.PacketValidator;
import com.example.shinobicore.network.PacketRateLimiter;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.executor.JutsuCaster;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public final class LoadoutPacketHandlers {
    private LoadoutPacketHandlers() {}

    public static void register() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.SELECT_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            final int set = buf.readInt();
            final int slot = buf.readInt();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setActiveSlot(set, slot));
        });

        ServerPlayNetworking.registerGlobalReceiver(ModPackets.CAST_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            final int set = buf.readInt();
            final int slot = buf.readInt();
            if (!PacketValidator.validLoadoutSet(set) || !PacketValidator.validSlotIndex(slot)) return;
            if (!PacketRateLimiter.allow(player.getUuid(), "CAST_SLOT", 400)) return;
            if (!PacketValidator.validPlayerState(player)) return;
            ShinobiCore.LOGGER.info("[CAST-SERVER] === RECEIVED PACKET ===");
            ShinobiCore.LOGGER.info("[CAST-SERVER] Player: {}", player.getName().getString());
            ShinobiCore.LOGGER.info("[CAST-SERVER] Set: {}, Slot: {}", set, slot);
            server.execute(() -> {
                ShinobiCore.LOGGER.info("[CAST-SERVER] Processing on server thread...");
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data == null) { ShinobiCore.LOGGER.info("[CAST-SERVER] data is null"); return; }
                int s = Math.max(0, Math.min(4, slot));
                String id = data.getLoadoutSlot(set == 0 ? 0 : 1, s);
                ShinobiCore.LOGGER.info("[CAST-SERVER] Loadout slot lookup: set={}, slot={} -> id={}",
                    set == 0 ? 0 : 1, s, id);
                if (id != null) {
                    ShinobiCore.LOGGER.info("[CAST-SERVER] Calling false /* TODO: implement */", id);
                    boolean success = false /* TODO: implement */;
                    ShinobiCore.LOGGER.info("[CAST-SERVER] JutsuCaster.beginCast returned: {}", success);
                } else {
                    ShinobiCore.LOGGER.info("[CAST-SERVER] Slot {} is empty!", s + 1);
                    player.sendMessage(Text.literal("\u00a7cSlot " + (s + 1) + " is empty!"), false);
                }
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(ModPackets.SET_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            final int set = buf.readInt();
            final int slot = buf.readInt();
            final String id = PacketValidator.safeReadString(buf);
            if (!PacketValidator.validLoadoutSet(set) || !PacketValidator.validSlotIndex(slot)) return;
            if (!PacketValidator.validJutsuId(id)) return;
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                String clean = id.isEmpty() ? null : id;
                if (clean != null && !data.getLearnedJutsus().contains(clean)) {
                    player.sendMessage(Text.literal("\u00a7cLearn it first!"), false);
                    return;
                }
                data.setLoadoutSlot(set, Math.max(0, Math.min(4, slot)), clean);
                ShinobiCore.sendLoadoutSync(player);
            });
        });
    }
}