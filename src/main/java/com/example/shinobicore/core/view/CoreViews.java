package com.example.shinobicore.core.view;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Global view registry. Static singleton - modules call CoreViews.get(player, Type) directly.
 */
public final class CoreViews {

    @FunctionalInterface
    public interface ViewFactory<T> {
        Optional<T> create(PlayerEntity player);
    }

    private static final Map<Class<?>, ViewFactory<?>> FACTORIES = new ConcurrentHashMap<>();

    public CoreViews() {}

    public static <T> void register(Class<T> type, ViewFactory<T> factory) {
        FACTORIES.put(type, factory);
    }

    @SuppressWarnings("unchecked")
    public static <T> Optional<T> get(PlayerEntity player, Class<T> type) {
        ViewFactory<?> raw = FACTORIES.get(type);
        if (raw == null) {
            return Optional.empty();
        }

        try {
            return ((ViewFactory<T>) raw).create(player);
        } catch (Throwable t) {
            ShinobiLogger.error("core", "View factory failed: " + type.getSimpleName(), t);
            return Optional.empty();
        }
    }
}