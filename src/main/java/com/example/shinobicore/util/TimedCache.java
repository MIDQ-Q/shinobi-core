package com.example.shinobicore.util;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.BiConsumer;
import java.util.function.Function;

/**
 * Thread-safe cache with automatic TTL-based expiration.
 * Replaces raw HashMap/ConcurrentHashMap in animation and state tracking
 * to prevent unbounded memory growth.
 */
public class TimedCache<K, V> {
    private final ConcurrentHashMap<K, TimedEntry<V>> map = new ConcurrentHashMap<>();
    private final long ttlMs;

    public TimedCache(long ttlMs) {
        this.ttlMs = ttlMs;
    }

    public void put(K key, V value) {
        map.put(key, new TimedEntry<>(value, System.currentTimeMillis() + ttlMs));
    }

    public V get(K key) {
        TimedEntry<V> entry = map.get(key);
        if (entry == null) return null;
        if (System.currentTimeMillis() >= entry.expiresAt) {
            map.remove(key);
            return null;
        }
        return entry.value;
    }

    /**
     * Returns value for key, or defaultValue if absent/expired.
     */
    public V getOrDefault(K key, V defaultValue) {
        V v = get(key);
        return v != null ? v : defaultValue;
    }

    /**
     * Compute-if-absent with TTL. If key is absent or expired,
     * computes value via mappingFunction and stores it.
     */
    public V computeIfAbsent(K key, Function<? super K, ? extends V> mappingFunction) {
        V existing = get(key);
        if (existing != null) return existing;
        V computed = mappingFunction.apply(key);
        put(key, computed);
        return computed;
    }

    public boolean containsKey(K key) {
        return get(key) != null;
    }

    public void remove(K key) {
        map.remove(key);
    }

    public void cleanup() {
        long now = System.currentTimeMillis();
        map.entrySet().removeIf(e -> now >= e.getValue().expiresAt);
    }

    public void clear() {
        map.clear();
    }

    public int size() {
        cleanup();
        return map.size();
    }

    public void forEach(BiConsumer<K, V> consumer) {
        cleanup();
        map.forEach((k, e) -> consumer.accept(k, e.value));
    }

    private static class TimedEntry<V> {
        final V value;
        final long expiresAt;

        TimedEntry(V value, long expiresAt) {
            this.value = value;
            this.expiresAt = expiresAt;
        }
    }
}