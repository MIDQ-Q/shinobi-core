package com.example.shinobicore.core.event;

import com.example.shinobicore.ShinobiCore;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

/**
 * Simple typed event bus for decoupling modules.
 * Synchronous dispatch on the publishing thread.
 * Server-side bus. Client has its own instance via ClientEventBus.
 */
public final class ShinobiEventBus {
    private static final Map<Class<?>, List<Consumer<?>>> LISTENERS = new ConcurrentHashMap<>();
    private static boolean enabled = true;

    private ShinobiEventBus() {}

    public static <T> void subscribe(Class<T> eventType, Consumer<T> handler) {
        LISTENERS.computeIfAbsent(eventType, k -> new CopyOnWriteArrayList<>()).add(handler);
        ShinobiCore.LOGGER.info("[EventBus] Subscribed to {}", eventType.getSimpleName());
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
                ShinobiCore.LOGGER.error("[EventBus] Error in handler for {}: {}",
                    event.getClass().getSimpleName(), e.getMessage());
            }
        }
    }

    public static void setEnabled(boolean value) { enabled = value; }
    public static boolean isEnabled() { return enabled; }

    public static void clearAll() {
        LISTENERS.clear();
        ShinobiCore.LOGGER.info("[EventBus] All listeners cleared");
    }

    public static int listenerCount(Class<?> eventType) {
        List<Consumer<?>> handlers = LISTENERS.get(eventType);
        return handlers == null ? 0 : handlers.size();
    }
}