package com.example.shinobicore.util;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.world.ServerWorld;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

public class TickScheduler {
    private static final List<Task> TASKS = new ArrayList<>();
    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;
        ServerTickEvents.START_WORLD_TICK.register(world -> {
            List<Task> currentTasks;
            synchronized (TASKS) {
                currentTasks = new ArrayList<>(TASKS);
                TASKS.clear();
            }
            
            List<Task> toKeep = new ArrayList<>();
            for (Task t : currentTasks) {
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
            synchronized (TASKS) {
                TASKS.addAll(toKeep);
            }
        });
    }

    public static void schedule(ServerWorld world, int delay, int interval, int count, Consumer<ServerWorld> action) {
        register();
        synchronized (TASKS) { 
            TASKS.add(new Task(world, delay, interval, count, action)); 
        }
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