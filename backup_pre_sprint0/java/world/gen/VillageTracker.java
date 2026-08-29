package com.example.shinobicore.world.gen;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerChunkEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.nbt.NbtList;
import net.minecraft.registry.Registry;
import net.minecraft.registry.RegistryKeys;
import net.minecraft.registry.entry.RegistryEntry;
import net.minecraft.server.MinecraftServer;
import net.minecraft.structure.StructureStart;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.PersistentState;
import net.minecraft.world.PersistentStateManager;
import net.minecraft.world.gen.structure.Structure;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Thread-safe registry of village positions discovered during chunk
 * loading. Persists to NBT for future use (e.g., manual road commands).
 *
 * Uses ServerChunkEvents.CHUNK_LOAD + chunk.getStructureStarts()
 * (READ-ONLY, safe, no recursion, no mixin).
 *
 * HLD Section 9 (World).
 */
public final class VillageTracker extends PersistentState {

    private static final String KEY = "shinobicore_villages";

    /** Runtime set (thread-safe, populated by CHUNK_LOAD listener). */
    private static final Set<Long> VILLAGES = Collections.newSetFromMap(new ConcurrentHashMap<>());

    private VillageTracker() {}

    public static VillageTracker get(MinecraftServer server) {
        PersistentStateManager mgr = server.getOverworld().getPersistentStateManager();
        return mgr.getOrCreate(VillageTracker::createFromNbt, VillageTracker::new, KEY);
    }

    public static VillageTracker createFromNbt(NbtCompound nbt) {
        VillageTracker t = new VillageTracker();
        t.readNbt(nbt);
        return t;
    }

    // ---------------- Event registration ----------------

    public static void init() {
        ServerChunkEvents.CHUNK_LOAD.register((world, chunk) -> {
            try {
                Map<Structure, StructureStart> starts = chunk.getStructureStarts();
                if (starts == null || starts.isEmpty()) return;

                Registry<Structure> reg = world.getRegistryManager().get(RegistryKeys.STRUCTURE);
                for (Map.Entry<Structure, StructureStart> e : starts.entrySet()) {
                    Structure structure = e.getKey();
                    StructureStart start = e.getValue();
                    if (start == null || !start.hasChildren()) continue;

                    RegistryEntry<Structure> entry = reg.getEntry(structure);
                    if (entry.getKey().isPresent()) {
                        String id = entry.getKey().get().getValue().toString();
                        if (id.contains("village")) {
                            onVillageChunkGenerated(start.getPos().getStartPos());
                        }
                    }
                }
            } catch (Exception ignored) {
                // never break chunk loading
            }
        });

        ServerLifecycleEvents.SERVER_STARTED.register(server -> {
            get(server); // load from NBT
        });
        ServerLifecycleEvents.SERVER_STOPPING.register(server -> {
            get(server).markDirty(); // save
        });

        ShinobiCore.LOGGER.info("VillageTracker initialized (CHUNK_LOAD listener)");
    }

    // ---------------- Discovery ----------------

    public static void onVillageChunkGenerated(BlockPos villagePos) {
        long key = toKey(villagePos);
        if (VILLAGES.add(key)) {
            ShinobiCore.LOGGER.info("VillageTracker: village discovered at {}, {}",
                villagePos.getX(), villagePos.getZ());
        }
    }

    // ---------------- Queries ----------------

    public static List<BlockPos> snapshot() {
        List<BlockPos> list = new ArrayList<>();
        for (long k : VILLAGES) {
            int x = (int) (k >> 32);
            int z = (int) k;
            list.add(new BlockPos(x, 0, z));
        }
        return list;
    }

    public static int count() {
        return VILLAGES.size();
    }

    private static long toKey(BlockPos p) {
        return ((long) p.getX() << 32) | (p.getZ() & 0xFFFFFFFFL);
    }

    // ---------------- Persistence ----------------

    @Override
    public NbtCompound writeNbt(NbtCompound nbt) {
        NbtList list = new NbtList();
        for (long k : VILLAGES) {
            NbtCompound c = new NbtCompound();
            c.putInt("X", (int) (k >> 32));
            c.putInt("Z", (int) k);
            list.add(c);
        }
        nbt.put("Villages", list);
        return nbt;
    }

    public void readNbt(NbtCompound nbt) {
        if (nbt.contains("Villages")) {
            NbtList list = nbt.getList("Villages", 10);
            for (int i = 0; i < list.size(); i++) {
                NbtCompound c = list.getCompound(i);
                VILLAGES.add(((long) c.getInt("X") << 32) | (c.getInt("Z") & 0xFFFFFFFFL));
            }
        }
    }
}