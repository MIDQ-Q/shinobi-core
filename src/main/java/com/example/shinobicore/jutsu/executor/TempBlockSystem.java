package com.example.shinobicore.jutsu.executor;

import net.minecraft.block.BlockState;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class TempBlockSystem {

    private static class Entry {
        final ServerWorld world;
        final BlockPos pos;
        final BlockState original;
        int ticksLeft;
        Entry(ServerWorld w, BlockPos p, BlockState o, int t) { world=w; pos=p; original=o; ticksLeft=t; }
    }

    private static final List<Entry> ACTIVE = new ArrayList<>();

    public static void scheduleRemoval(ServerWorld world, BlockPos pos, BlockState original, int ticks) {
        ACTIVE.add(new Entry(world, pos, original, ticks));
    }

    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Entry> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Entry e = it.next();
            e.ticksLeft--;
            if (e.ticksLeft <= 0) {
                if (e.world.getBlockState(e.pos) != e.original) {
                    e.world.setBlockState(e.pos, e.original, 3);
                }
                it.remove();
            }
        }
    }
}