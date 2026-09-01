package com.example.shinobicore.core.event;

import com.example.shinobicore.ShinobiCore;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

/**
 * Client-side event bus. Separate from server bus.
 * Used for client-only events (render, input, HUD).
 */
public final class ClientEventBus {
    private static final Map<Class<?>, List<Consumer<?>>> LISTENERS = new ConcurrentHashMap<>();
    private static boolean enabled = true;

    private ClientEventBus() {}

    public static <T> void subscribe(Class<T> eventType, Consumer<T> handler) {
        LISTENERS.computeIfAbsent(eventType, k -> new CopyOnWriteArrayList<>()).add(handler);
    }

    @SuppressWarnings("unchecked")
    public static <T> void publish(T event) {
        if (!enabled) return;
        List<Consumer<?>> handlers = LISTENERS.get(event.getClass());
        if (handlers == null) return;
        for (Consumer<?> h : handlers) {
            try {
                ((Consumer<T>) h).accept(event);
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("[ClientEventBus] Error in handler for {}: {}",
                    event.getClass().getSimpleName(), e.getMessage());
            }
        }
    }

    public static void clearAll() { LISTENERS.clear(); }
    public static void setEnabled(boolean v) { enabled = v; }
}