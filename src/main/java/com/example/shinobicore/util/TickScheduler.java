package com.example.shinobicore.util;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.world.ServerWorld;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.function.Consumer;

public class TickScheduler {
    private static final List<Task> TASKS = new ArrayList<>();
    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;
        ServerTickEvents.START_WORLD_TICK.register(world -> {
            synchronized (TASKS) {
                Iterator<Task> it = TASKS.iterator();
                while (it.hasNext()) {
                    Task t = it.next();
                    if (t.world != world) continue;
                    t.delay--;
                    if (t.delay > 0) continue;
                    t.delay = t.interval;
                    try { t.action.accept(world); } catch (Exception ignored) {}
                    t.count--;
                    if (t.count <= 0) it.remove();
                }
            }
        });
    }

    public static void schedule(ServerWorld world, int delay, int interval, int count, Consumer<ServerWorld> action) {
        register();
        synchronized (TASKS) { TASKS.add(new Task(world, delay, interval, count, action)); }
    }

    private static class Task {
        final ServerWorld world; int delay; final int interval; int count; final Consumer<ServerWorld> action;
        Task(ServerWorld w, int d, int i, int c, Consumer<ServerWorld> a) { world = w; delay = d; interval = i; count = c; action = a; }
    }
}