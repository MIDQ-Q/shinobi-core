package com.example.shinobicore.client;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public final class ClientNinjaStateHolder {
    private static final ClientNinjaStateHolder INSTANCE = new ClientNinjaStateHolder();

    private final String[] loadoutA = new String[5];
    private final String[] loadoutB = new String[5];
    private int activeA = 0;
    private int activeB = 0;
    private final Map<String, String> catalog = new HashMap<>();
    private final Set<String> learned = new HashSet<>();
    private int skillPoints = 0;
    private int reserveLevel = 1;
    private int reserveXp = 0;
    private final Map<String, Integer> statLevels = new HashMap<>();
    private final Map<String, Integer> statXp = new HashMap<>();
    private final Map<String, Integer> natureLevels = new HashMap<>();
    private final Map<String, Integer> natureXp = new HashMap<>();
    private final Map<String, Boolean> natureUnlocked = new HashMap<>();
    private int hpLevel = 0;
    private int speedLevel = 0;
    private int jumpLevel = 0;
    private boolean chakraMode = false;
    private boolean dangerSense = false;
    private boolean sensoryEnabled = true;
    private boolean meditating = false;
    private String kenjutsuStance = "aggressive";
    private boolean deflectHeld = false;
    private String clanId = "none";
    private String affinityId = null;
    private final Set<String> unlockedNodes = new HashSet<>();

    public static ClientNinjaStateHolder get() { return INSTANCE; }

    // Loadout
    public String[] getLoadoutA() { return loadoutA; }
    public String[] getLoadoutB() { return loadoutB; }
    public int getActiveA() { return activeA; }
    public void setActiveA(int v) { activeA = v; }
    public int getActiveB() { return activeB; }
    public void setActiveB(int v) { activeB = v; }

    // Catalog & Learned
    public Map<String, String> getCatalog() { return catalog; }
    public Set<String> getLearned() { return learned; }

    // Progression
    public int getSkillPoints() { return skillPoints; }
    public void setSkillPoints(int v) { skillPoints = v; }
    public int getReserveLevel() { return reserveLevel; }
    public void setReserveLevel(int v) { reserveLevel = v; }
    public int getReserveXp() { return reserveXp; }
    public void setReserveXp(int v) { reserveXp = v; }

    // Stats
    public Map<String, Integer> getStatLevels() { return statLevels; }
    public Map<String, Integer> getStatXp() { return statXp; }
    public Map<String, Integer> getNatureLevels() { return natureLevels; }
    public Map<String, Integer> getNatureXp() { return natureXp; }
    public Map<String, Boolean> getNatureUnlocked() { return natureUnlocked; }

    // Body
    public int getHpLevel() { return hpLevel; }
    public void setHpLevel(int v) { hpLevel = v; }
    public int getSpeedLevel() { return speedLevel; }
    public void setSpeedLevel(int v) { speedLevel = v; }
    public int getJumpLevel() { return jumpLevel; }
    public void setJumpLevel(int v) { jumpLevel = v; }

    // Mode flags
    public boolean isChakraMode() { return chakraMode; }
    public void setChakraMode(boolean v) { chakraMode = v; }
    public boolean isDangerSense() { return dangerSense; }
    public void setDangerSense(boolean v) { dangerSense = v; }
    public boolean isSensoryEnabled() { return sensoryEnabled; }
    public void setSensoryEnabled(boolean v) { sensoryEnabled = v; }
    public boolean isMeditating() { return meditating; }
    public void setMeditating(boolean v) { meditating = v; }

    // Combat
    public String getKenjutsuStance() { return kenjutsuStance; }
    public void setKenjutsuStance(String v) { kenjutsuStance = v; }
    public boolean isDeflectHeld() { return deflectHeld; }
    public void setDeflectHeld(boolean v) { deflectHeld = v; }

    // Clan
    public String getClanId() { return clanId; }
    public void setClanId(String v) { clanId = v; }
    public String getAffinityId() { return affinityId; }
    public void setAffinityId(String v) { affinityId = v; }

    // Tree
    public Set<String> getUnlockedNodes() { return unlockedNodes; }

    // Reset
    public String[] getLoadout(int set) { return set == 0 ? loadoutA : loadoutB; }
    public int getActive(int set) { return set == 0 ? activeA : activeB; }
    public String getActiveJutsuId(int set) { return getLoadout(set)[getActive(set)]; }

    public String getName(String id) {
        if (id == null) return "";
        return catalog.getOrDefault(id, id);
    }

    public void cycleLoadout(int set) {
        if (set == 0) {
            int start = activeA;
            do { activeA = (activeA + 1) % 5; if (loadoutA[activeA] != null) break; } while (activeA != start);
        } else {
            int start = activeB;
            do { activeB = (activeB + 1) % 5; if (loadoutB[activeB] != null) break; } while (activeB != start);
        }
    }

    private long lastCastMsA = 0;
    private long lastCastMsB = 0;

    public void castActiveJutsu(int set) {
        long nowMs = System.currentTimeMillis();
        if (set == 0) { if (nowMs - lastCastMsA < 400) return; lastCastMsA = nowMs; }
        else { if (nowMs - lastCastMsB < 400) return; lastCastMsB = nowMs; }
        String jutsuId = getActiveJutsuId(set);
        if (jutsuId == null) return;
        net.minecraft.client.MinecraftClient client = net.minecraft.client.MinecraftClient.getInstance();
        if (client.player == null || client.getNetworkHandler() == null) return;
        net.minecraft.network.PacketByteBuf buf = new net.minecraft.network.PacketByteBuf(io.netty.buffer.Unpooled.buffer());
        buf.writeInt(set);
        buf.writeInt(getActive(set));
        client.getNetworkHandler().sendPacket(
            new net.minecraft.network.packet.c2s.play.CustomPayloadC2SPacket(
                new net.minecraft.util.Identifier("shinobicore", "cast_slot"), buf));
    }

    public void reset() {
        activeA = 0; activeB = 0;
        for (int i = 0; i < 5; i++) { loadoutA[i] = null; loadoutB[i] = null; }
        catalog.clear(); learned.clear();
        skillPoints = 0; reserveLevel = 1; reserveXp = 0;
        statLevels.clear(); statXp.clear();
        natureLevels.clear(); natureXp.clear(); natureUnlocked.clear();
        hpLevel = 0; speedLevel = 0; jumpLevel = 0;
        chakraMode = false; dangerSense = false;
        sensoryEnabled = true; meditating = false;
        kenjutsuStance = "aggressive"; deflectHeld = false;
        clanId = "none"; affinityId = null;
        unlockedNodes.clear();
    }
}