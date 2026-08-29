package com.example.shinobicore.util;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;

import java.util.Comparator;
import java.util.PriorityQueue;

/**
 * Lightweight server tick scheduler for delayed effects
 * (wall removal, delayed explosions, DoT zones).
 * HLD: Section 6.3
 */
public final class TickScheduler {

    private static final PriorityQueue<ScheduledTask> QUEUE =
        new PriorityQueue<>(Comparator.comparingLong(t -> t.runTick));

    private static long currentTick = 0;
    private static boolean registered = false;

    private TickScheduler() {}

    public static void init() {
        if (registered) {
            return;
        }
        registered = true;
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            currentTick++;
            while (!QUEUE.isEmpty() && QUEUE.peek().runTick <= currentTick) {
                ScheduledTask task = QUEUE.poll();
                try {
                    task.runnable.run();
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("TickScheduler task failed: {}", e.getMessage());
                }
            }
        });
        ShinobiCore.LOGGER.info("TickScheduler initialized");
    }

    public static void schedule(int delayTicks, Runnable runnable) {
        QUEUE.add(new ScheduledTask(currentTick + delayTicks, runnable));
    }

    private record ScheduledTask(long runTick, Runnable runnable) {}
}