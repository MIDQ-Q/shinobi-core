package com.example.shinobicore.util;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.world.ServerWorld;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

public class TickScheduler {
    // S13-03: Use separate lists for pending and active tasks to avoid synchronization
    private static final List<Task> pendingTasks = new ArrayList<>();
    private static final List<Task> activeTasks = new ArrayList<>();
    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;
        ServerTickEvents.START_WORLD_TICK.register(world -> {
            // Move pending tasks to active (no synchronization needed - single-threaded tick)
            if (!pendingTasks.isEmpty()) {
                activeTasks.addAll(pendingTasks);
                pendingTasks.clear();
            }

            // Process active tasks
            List<Task> toKeep = new ArrayList<>();
            for (Task t : activeTasks) {
                if (t.world != world) {
                    toKeep.add(t);
                    continue;
                }
                t.delay--;
                if (t.delay > 0) {
                    toKeep.add(t);
                    continue;
                }
                t.delay = t.interval;
                try {
                    t.action.accept(world);
                } catch (Exception ignored) {}
                t.count--;
                if (t.count > 0) {
                    toKeep.add(t);
                }
            }
            activeTasks.clear();
            activeTasks.addAll(toKeep);
        });
    }

    public static void schedule(ServerWorld world, int delay, int interval, int count, Consumer<ServerWorld> action) {
        register();
        pendingTasks.add(new Task(world, delay, interval, count, action));
    }

    private static class Task {
        final ServerWorld world;
        int delay;
        final int interval;
        int count;
        final Consumer<ServerWorld> action;

        Task(ServerWorld w, int d, int i, int c, Consumer<ServerWorld> a) {
            world = w; delay = d; interval = i; count = c; action = a;
        }
    }
}