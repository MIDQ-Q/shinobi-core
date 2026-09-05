package com.example.shinobicore.network;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.executor.JutsuCaster;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class JutsuCastBridge {

    public static final Identifier ID = new Identifier("shinobicore", "jutsu_cast_v2");
    private static final Map<UUID, Long> LAST_CAST = new HashMap<>();
    private static final long MIN_INTERVAL_MS = 250;

    public static void register() {
        ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, responseSender) -> {
            int set = buf.readInt();
            server.execute(() -> castFromLoadout(player, set));
        });
    }

    private static void castFromLoadout(ServerPlayerEntity player, int set) {
        if (set < 0 || set > 1) return;

        // Anti-flood: max 1 cast per 250ms per player
        long now = System.currentTimeMillis();
        Long last = LAST_CAST.get(player.getUuid());
        if (last != null && now - last < MIN_INTERVAL_MS) return;
        LAST_CAST.put(player.getUuid(), now);

        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int slot = data.getActiveSlot(set);
        String id = data.getLoadoutSlot(set, slot);
        if (id == null || id.isEmpty()) {
            player.sendMessage(Text.literal("\u00a7cNo jutsu bound! Use /shinobicore jutsu bind"), true);
            return;
        }
        JutsuDefinition def = JutsuRegistry.get(id);
        if (def == null) {
            player.sendMessage(Text.literal("\u00a7cUnknown jutsu: " + id), true);
            return;
        }
        if (!data.getLearnedJutsus().contains(id) && !player.hasPermissionLevel(2)) {
            player.sendMessage(Text.literal("\u00a7cYou haven't learned " + def.getName()), true);
            return;
        }
        JutsuCaster.cast(player, def);
    }
}