package com.example.shinobicore.core.service;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
public final class CoreServices {
    private static final Map<Class<?>, Object> SERVICES = new ConcurrentHashMap<>();
    private CoreServices() {}
    public static <T> void register(Class<T> type, T service) { SERVICES.put(type, service); }
    public static <T> Optional<T> get(Class<T> type) {
        Object value = SERVICES.get(type);
        if (value == null) return Optional.empty();
        return Optional.ofNullable(type.cast(value));
    }
    public static <T> T require(Class<T> type) {
        return get(type).orElseThrow(() -> new IllegalStateException("Core service not registered: " + type.getSimpleName()));
    }
}