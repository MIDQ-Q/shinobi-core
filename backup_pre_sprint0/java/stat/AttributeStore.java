package com.example.shinobicore.stat;

import net.minecraft.nbt.NbtCompound;
import java.util.EnumMap;
import java.util.Map;

/**
 * S0-01: Per-player attribute storage.
 * Lives on server. Client gets delta-synced display values only.
 */
public class AttributeStore {

    private final EnumMap<AttributeType, Float> values = new EnumMap<>(AttributeType.class);
    private final EnumMap<AttributeType, Float> lastSynced = new EnumMap<>(AttributeType.class);
    private boolean dirty = false;

    public AttributeStore() {
        for (AttributeType attr : AttributeType.values()) {
            values.put(attr, attr.getDefaultValue());
            lastSynced.put(attr, attr.getDefaultValue());
        }
    }

    public float get(AttributeType attr) {
        Float v = values.get(attr);
        return v != null ? v : attr.getDefaultValue();
    }

    public void set(AttributeType attr, float value) {
        float clamped = Math.max(0f, Math.min(value, attr.getMaxValue()));
        Float old = values.get(attr);
        if (old == null || Math.abs(old - clamped) > 0.001f) {
            values.put(attr, clamped);
            dirty = true;
        }
    }

    public void add(AttributeType attr, float delta) {
        set(attr, get(attr) + delta);
    }

    public float getRatio(AttributeType attr) {
        float max = get(AttributeType.MAX_CHAKRA);
        if (attr == AttributeType.CHAKRA && max > 0) return get(attr) / max;
        max = get(AttributeType.MAX_STAMINA);
        if (attr == AttributeType.STAMINA && max > 0) return get(attr) / max;
        return 0f;
    }

    public Map<AttributeType, Float> collectDelta() {
        Map<AttributeType, Float> delta = new EnumMap<>(AttributeType.class);
        for (AttributeType attr : AttributeType.values()) {
            float current = get(attr);
            float last = lastSynced.getOrDefault(attr, current);
            if (Math.abs(current - last) > 0.001f) {
                delta.put(attr, current);
                lastSynced.put(attr, current);
            }
        }
        dirty = false;
        return delta;
    }

    public boolean isDirty() { return dirty; }
    public void markClean() { dirty = false; }

    public void applyMultipliers(Map<AttributeType, Float> multipliers) {
        for (Map.Entry<AttributeType, Float> e : multipliers.entrySet()) {
            set(e.getKey(), get(e.getKey()) * e.getValue());
        }
    }

    public void resetToDefaults() {
        for (AttributeType attr : AttributeType.values()) {
            values.put(attr, attr.getDefaultValue());
        }
        dirty = true;
    }

    public NbtCompound writeNbt() {
        NbtCompound nbt = new NbtCompound();
        for (AttributeType attr : AttributeType.values()) {
            nbt.putFloat(attr.getId(), get(attr));
        }
        return nbt;
    }

    public void readNbt(NbtCompound nbt) {
        if (nbt == null) return;
        for (AttributeType attr : AttributeType.values()) {
            if (nbt.contains(attr.getId())) {
                values.put(attr, nbt.getFloat(attr.getId()));
            }
        }
        for (AttributeType attr : AttributeType.values()) {
            lastSynced.put(attr, get(attr));
        }
        dirty = false;
    }

    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder("AttributeStore{");
        for (AttributeType attr : AttributeType.values()) {
            sb.append(attr.getId()).append("=").append(String.format("%.1f", get(attr))).append(", ");
        }
        sb.append("}");
        return sb.toString();
    }
}