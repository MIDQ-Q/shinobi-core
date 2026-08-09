package com.example.shinobicore.client;

import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.entity.NinjaProjectileRenderer;
import com.example.shinobicore.network.ChakraSyncPacket;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.StatType;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import com.example.shinobicore.client.parkour.ParkourManager;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class ShinobiCoreClient implements ClientModInitializer {

    @Override
    public void onInitializeClient() {
        KeyBindings.register();
        ClientInputHandler.register();
        ChakraPhysicsClient.register();
        ParkourManager.register();

        // === РЕГИСТРАЦИЯ РЕНДЕРЕРОВ (было потеряно!) ===
        EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CHAKRA_SYNC_ID, (client, handler, buf, responseSender) -> {
            ChakraSyncPacket packet = ChakraSyncPacket.read(buf);
            client.execute(() -> {
                ChakraHudRenderer.currentChakra = packet.currentChakra();
                ChakraHudRenderer.maxChakra = packet.maxChakra();
                ChakraHudRenderer.fatigue = packet.fatigue();
                ChakraHudRenderer.exhausted = packet.exhausted();
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CATALOG_SYNC_ID, (client, handler, buf, responseSender) -> {
            Map<String, String> cat = new HashMap<>();
            int n = buf.readInt();
            for (int i = 0; i < n; i++) cat.put(buf.readString(), buf.readString());
            client.execute(() -> {
                ClientNinjaState.catalog.clear();
                ClientNinjaState.catalog.putAll(cat);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.LOADOUT_SYNC_ID, (client, handler, buf, responseSender) -> {
            int aA = buf.readInt(); int aB = buf.readInt();
            String[] la = new String[5]; String[] lb = new String[5];
            for (int i = 0; i < 5; i++) { String s = buf.readString(); la[i] = s.isEmpty() ? null : s; }
            for (int i = 0; i < 5; i++) { String s = buf.readString(); lb[i] = s.isEmpty() ? null : s; }
            Set<String> learned = new HashSet<>();
            int lc = buf.readInt();
            for (int i = 0; i < lc; i++) learned.add(buf.readString());
            client.execute(() -> {
                ClientNinjaState.activeA = aA; ClientNinjaState.activeB = aB;
                for (int i = 0; i < 5; i++) { ClientNinjaState.loadoutA[i] = la[i]; ClientNinjaState.loadoutB[i] = lb[i]; }
                ClientNinjaState.learned.clear();
                ClientNinjaState.learned.addAll(learned);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.STATS_SYNC_ID, (client, handler, buf, responseSender) -> {
            int sp = buf.readInt(); int resLvl = buf.readInt(); int resXp = buf.readInt();
            Map<String, Integer> sl = new HashMap<>(); Map<String, Integer> sx = new HashMap<>();
            for (StatType s : StatType.values()) { sl.put(s.getId(), buf.readInt()); sx.put(s.getId(), buf.readInt()); }
            Map<String, Integer> nl = new HashMap<>(); Map<String, Integer> nx = new HashMap<>(); Map<String, Boolean> nu = new HashMap<>();
            for (ElementType e : ElementType.values()) { nl.put(e.getId(), buf.readInt()); nx.put(e.getId(), buf.readInt()); }
            for (ElementType e : ElementType.values()) nu.put(e.getId(), buf.readBoolean());
            client.execute(() -> {
                ClientNinjaState.skillPoints = sp;
                ClientNinjaState.reserveLevel = resLvl;
                ClientNinjaState.reserveXp = resXp;
                ClientNinjaState.statLevels.clear(); ClientNinjaState.statLevels.putAll(sl);
                ClientNinjaState.statXp.clear(); ClientNinjaState.statXp.putAll(sx);
                ClientNinjaState.natureLevels.clear(); ClientNinjaState.natureLevels.putAll(nl);
                ClientNinjaState.natureXp.clear(); ClientNinjaState.natureXp.putAll(nx);
                ClientNinjaState.natureUnlocked.clear(); ClientNinjaState.natureUnlocked.putAll(nu);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.BODY_SYNC_ID, (client, handler, buf, responseSender) -> {
            int hp = buf.readInt(); int speed = buf.readInt(); int jump = buf.readInt();
            boolean chakra = buf.readBoolean(); String clan = buf.readString(); String affinity = buf.readString();
            client.execute(() -> {
                ClientNinjaState.hpLevel = hp;
                ClientNinjaState.speedLevel = speed;
                ClientNinjaState.jumpLevel = jump;
                ClientNinjaState.chakraMode = chakra;
                ClientNinjaState.clanId = clan.isEmpty() ? "none" : clan;
                ClientNinjaState.affinityId = affinity.isEmpty() ? null : affinity;
            });
        });

        HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
    }
}