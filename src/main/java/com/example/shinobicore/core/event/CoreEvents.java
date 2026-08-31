package com.example.shinobicore.core.event;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

/**
 * Global event bus. Static singleton - modules call CoreEvents.publish(...) directly.
 */
public final class CoreEvents {

    private static final Map<Class<?>, CopyOnWriteArrayList<Consumer<?>>> LISTENERS =
            new ConcurrentHashMap<>();

    public CoreEvents() {}

    public static <T> void subscribe(Class<T> type, Consumer<T> listener) {
        LISTENERS
                .computeIfAbsent(type, k -> new CopyOnWriteArrayList<>())
                .add(listener);
    }

    @SuppressWarnings("unchecked")
    public static <T> void publish(T event) {
        CopyOnWriteArrayList<Consumer<?>> list = LISTENERS.get(event.getClass());
        if (list == null || list.isEmpty()) {
            return;
        }

        for (Consumer<?> raw : list) {
            try {
                ((Consumer<T>) raw).accept(event);
            } catch (Throwable t) {
                ShinobiLogger.error(
                        "core",
                        "Event listener failed for event: " + event.getClass().getSimpleName(),
                        t
                );
            }
        }
    }
}