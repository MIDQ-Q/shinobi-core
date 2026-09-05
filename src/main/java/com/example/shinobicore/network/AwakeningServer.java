package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

public final class AwakeningServer {
    public static final Identifier CHOOSE_ID = new Identifier("shinobicore", "awakening_choose");
    public static final Identifier ELEMENT_ID = new Identifier("shinobicore", "awakening_element");
    public static final Identifier OPEN_ID = new Identifier("shinobicore", "open_awakening");

    public static void init() {
        ServerPlayNetworking.registerGlobalReceiver(CHOOSE_ID, (server, player, handler, buf, rs) -> {
            String clanId = buf.readString();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.getClanId() != null && !data.getClanId().equals("none")) return;
                
                data.setClanId(clanId);
                data.setClanChosen(true);
                
                ElementType[] elements = ElementType.values();
                ElementType innate = elements[player.getRandom().nextInt(elements.length)];
                while (innate.getId().equals("yin") || innate.getId().equals("yang") || innate.getId().equals("none")) {
                    innate = elements[player.getRandom().nextInt(elements.length)];
                }
                data.setNatureUnlocked(innate, true);
                data.setNatureLevel(innate, 1);
                
                data.addSkillPoints(5);
                data.learnJutsu("shinobicore:chakra_push");
                
                ShinobiCore.sendBodySync(player);
                ShinobiCore.sendStatsSync(player);
                
                PacketByteBuf out = new PacketByteBuf(Unpooled.buffer());
                out.writeString(innate.getId());
                ServerPlayNetworking.send(player, ELEMENT_ID, out);
            });
        });

        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            ServerPlayerEntity p = handler.player;
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) p).shinobicore_getData();
                if (data.getClanId() == null || data.getClanId().equals("none")) {
                    PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                    ServerPlayNetworking.send(p, OPEN_ID, buf);
                }
            });
        });
    }
}