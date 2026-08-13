package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import io.netty.buffer.Unpooled;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.network.packet.c2s.play.CustomPayloadC2SPacket;
import net.minecraft.util.Identifier;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class ClientNinjaState {
    public static final String[] loadoutA = new String[5];
    public static final String[] loadoutB = new String[5];
    public static int activeA = 0;
    public static int activeB = 0;

    public static final Map<String, String> catalog = new HashMap<>();
    public static final Set<String> learned = new HashSet<>();

    public static int skillPoints = 0;
    public static int reserveLevel = 1;
    public static int reserveXp = 0;
    public static final Map<String, Integer> statLevels = new HashMap<>();
    public static final Map<String, Integer> statXp = new HashMap<>();
    public static final Map<String, Integer> natureLevels = new HashMap<>();
    public static final Map<String, Integer> natureXp = new HashMap<>();
    public static final Map<String, Boolean> natureUnlocked = new HashMap<>();

    public static int hpLevel = 0;
    public static int speedLevel = 0;
    public static int jumpLevel = 0;
    public static boolean chakraMode = false;
    public static boolean dangerSense = false;
    public static boolean sensoryEnabled = true;
    public static boolean meditating = false;
    public static String kenjutsuStance = "aggressive";
    public static boolean deflectHeld = false;
    public static String clanId = "none";
    public static String affinityId = null;
    public static final Set<String> unlockedNodes = new HashSet<>();

    public static String[] loadout(int set) { return set == 0 ? loadoutA : loadoutB; }
    public static int active(int set) { return set == 0 ? activeA : activeB; }
    public static String activeJutsuId(int set) { return loadout(set)[active(set)]; }

    public static String name(String id) {
        if (id == null) return "";
        return catalog.getOrDefault(id, id);
    }

    public static void cycleLoadout(int set) {
        if (set == 0) {
            int start = activeA;
            do {
                activeA = (activeA + 1) % 5;
                if (loadoutA[activeA] != null) break;
            } while (activeA != start);
            ShinobiCore.LOGGER.debug("[JUTSU] Cycled slot A to: {} ({})", activeA, activeJutsuId(0));
        } else {
            int start = activeB;
            do {
                activeB = (activeB + 1) % 5;
                if (loadoutB[activeB] != null) break;
            } while (activeB != start);
            ShinobiCore.LOGGER.debug("[JUTSU] Cycled slot B to: {} ({})", activeB, activeJutsuId(1));
        }
    }

    public static void castActiveJutsu(int set) {
        String jutsuId = activeJutsuId(set);
        int slotIndex = active(set);
        
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] === CAST JUTSU ===");
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] Set: {} ({}), Slot index: {}", 
            set, set == 0 ? "A" : "B", slotIndex);
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] Jutsu ID: {}", jutsuId);
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] Loadout A: [{}, {}, {}, {}, {}]", 
            loadoutA[0], loadoutA[1], loadoutA[2], loadoutA[3], loadoutA[4]);
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] Loadout B: [{}, {}, {}, {}, {}]", 
            loadoutB[0], loadoutB[1], loadoutB[2], loadoutB[3], loadoutB[4]);
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] Active A: {}, Active B: {}", activeA, activeB);
        
        if (jutsuId == null) {
            ShinobiCore.LOGGER.debug("[CAST-CLIENT] ✗ No jutsu in slot, aborting");
            return;
        }
        
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) {
            ShinobiCore.LOGGER.debug("[CAST-CLIENT] ✗ Player is null, aborting");
            return;
        }
        if (client.getNetworkHandler() == null) {
            ShinobiCore.LOGGER.debug("[CAST-CLIENT] ✗ NetworkHandler is null, aborting");
            return;
        }
        
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] ✓ Sending packet: cast_slot");
        ShinobiCore.LOGGER.debug("[CAST-CLIENT]   Packet data: set={}, slot={}", set, slotIndex);
        
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(set);
        buf.writeInt(slotIndex);
        
        client.getNetworkHandler().sendPacket(new CustomPayloadC2SPacket(
            new Identifier("shinobicore", "cast_slot"), buf));
        
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] ✓ Packet sent successfully");
    }
}