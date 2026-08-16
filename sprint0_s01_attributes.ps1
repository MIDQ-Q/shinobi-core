# ============================================================
#  SPRINT 0 / S0-01: ATTRIBUTE REGISTRY
#  Server-side attribute system with delta-sync
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint0_s01_attributes.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace($root, ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) {
        Write-Host "[MISS] $p" -ForegroundColor Red
        $script:err++
        return
    }
    $c = [System.IO.File]::ReadAllText($p, $utf8)

    # FIX 2: Normalize CRLF before comparison
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")

    # Idempotency check
    if ($cNorm.Contains($newNorm)) {
        Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow
        $script:skip++
        return
    }
    if (-not $cNorm.Contains($oldNorm)) {
        Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red
        $script:err++
        return
    }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 0 / S0-01: SERVER ATTRIBUTE REGISTRY" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. AttributeType.java - enum of all player attributes
# ================================================================
Write-Host "[1/7] AttributeType.java..." -ForegroundColor White
$content1 = @'
package com.example.shinobicore.stat;

/**
 * S0-01: Server-side attribute registry.
 * All attributes stored on server. Client receives only display values via delta-sync.
 */
public enum AttributeType {
    MAX_CHAKRA("max_chakra", 100f, 99999f, false),
    CHAKRA("chakra", 100f, 99999f, true),
    MAX_STAMINA("max_stamina", 100f, 99999f, false),
    STAMINA("stamina", 100f, 99999f, true),
    CHAKRA_REGEN("chakra_regen", 1.0f, 100f, false),
    STAMINA_REGEN("stamina_regen", 2.0f, 100f, false),
    CONTROL("control", 0f, 100f, false),
    MASTERY("mastery", 0f, 100f, false),
    CAST_SPEED("cast_speed", 1.0f, 10f, false),
    SENSOR_TIER("sensor_tier", 0f, 5f, false),
    DOJUTSU_STATE("dojutsu_state", 0f, 10f, true);

    private final String id;
    private final float defaultValue;
    private final float maxValue;
    private final boolean volatileAttr;

    AttributeType(String id, float defaultValue, float maxValue, boolean volatileAttr) {
        this.id = id;
        this.defaultValue = defaultValue;
        this.maxValue = maxValue;
        this.volatileAttr = volatileAttr;
    }

    public String getId() { return id; }
    public float getDefaultValue() { return defaultValue; }
    public float getMaxValue() { return maxValue; }
    public boolean isVolatile() { return volatileAttr; }

    public static AttributeType fromId(String id) {
        for (AttributeType a : values()) {
            if (a.id.equals(id)) return a;
        }
        return null;
    }
}
'@
Write-File "$java\stat\AttributeType.java" $content1

# ================================================================
# 2. AttributeStore.java - per-player attribute storage
# ================================================================
Write-Host "[2/7] AttributeStore.java..." -ForegroundColor White
$content2 = @'
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
'@
Write-File "$java\stat\AttributeStore.java" $content2

# ================================================================
# 3. AttributeSyncPacket.java - FIX 1: fixed broken path
# ================================================================
Write-Host "[3/7] AttributeSyncPacket.java..." -ForegroundColor White
$content3 = @'
package com.example.shinobicore.network;

import com.example.shinobicore.stat.AttributeType;
import net.minecraft.network.PacketByteBuf;
import java.util.EnumMap;
import java.util.Map;

/**
 * S0-01 / S0-06: Delta-sync packet for attributes.
 * Server -> Client. Sends only changed attributes.
 * RULE: READ ALL DATA BEFORE server.execute()!
 */
public record AttributeSyncPacket(Map<AttributeType, Float> changedAttributes) {

    public static final net.minecraft.util.Identifier ID =
        new net.minecraft.util.Identifier("shinobicore", "attribute_sync");

    public void write(PacketByteBuf buf) {
        buf.writeInt(changedAttributes.size());
        for (Map.Entry<AttributeType, Float> e : changedAttributes.entrySet()) {
            buf.writeString(e.getKey().getId());
            buf.writeFloat(e.getValue());
        }
    }

    public static AttributeSyncPacket read(PacketByteBuf buf) {
        int count = buf.readInt();
        Map<AttributeType, Float> attrs = new EnumMap<>(AttributeType.class);
        for (int i = 0; i < count; i++) {
            String id = buf.readString();
            float value = buf.readFloat();
            AttributeType attr = AttributeType.fromId(id);
            if (attr != null) {
                attrs.put(attr, value);
            }
        }
        return new AttributeSyncPacket(attrs);
    }
}
'@
# FIX 1: Path on single line - no newline inside quotes!
$packetPath = Join-Path $java "network\AttributeSyncPacket.java"
Write-File $packetPath $content3

# ================================================================
# 4. Patch NinjaDataHolder - expose AttributeStore
# ================================================================
Write-Host "[4/7] Patching NinjaDataHolder.java..." -ForegroundColor White
Patch-File "$java\stat\NinjaDataHolder.java" `
    "public interface NinjaDataHolder {`n    NinjaPlayerData shinobicore_getData();`n}" `
    "public interface NinjaDataHolder {`n    NinjaPlayerData shinobicore_getData();`n    com.example.shinobicore.stat.AttributeStore shinobicore_getAttributes();`n}"

# ================================================================
# 5. Patch ServerPlayerEntityMixin - add AttributeStore field
# ================================================================
Write-Host "[5/7] Patching ServerPlayerEntityMixin.java..." -ForegroundColor White
$mixinPath = "$java\mixin\ServerPlayerEntityMixin.java"

Patch-File $mixinPath `
    "@Unique`n    private final NinjaPlayerData shinobicore_data = new NinjaPlayerData();" `
    "@Unique`n    private final NinjaPlayerData shinobicore_data = new NinjaPlayerData();`n`n    @Unique`n    private final com.example.shinobicore.stat.AttributeStore shinobicore_attributes =`n        new com.example.shinobicore.stat.AttributeStore();"

Patch-File $mixinPath `
    "@Override`n    public NinjaPlayerData shinobicore_getData() {`n        return shinobicore_data;`n    }" `
    "@Override`n    public NinjaPlayerData shinobicore_getData() {`n        return shinobicore_data;`n    }`n`n    @Override`n    public com.example.shinobicore.stat.AttributeStore shinobicore_getAttributes() {`n        return shinobicore_attributes;`n    }"

# NBT save
Patch-File $mixinPath `
    "nbt.put(""ShinobiCoreData"", shinobicore_data.writeNbt());" `
    "nbt.put(""ShinobiCoreData"", shinobicore_data.writeNbt());`n        nbt.put(""ShinobiCoreAttributes"", shinobicore_attributes.writeNbt());"

# NBT load
Patch-File $mixinPath `
    "if (nbt.contains(""ShinobiCoreData"")) {`n            shinobicore_data.readNbt(nbt.getCompound(""ShinobiCoreData""));`n        }" `
    "if (nbt.contains(""ShinobiCoreData"")) {`n            shinobicore_data.readNbt(nbt.getCompound(""ShinobiCoreData""));`n        }`n        if (nbt.contains(""ShinobiCoreAttributes"")) {`n            shinobicore_attributes.readNbt(nbt.getCompound(""ShinobiCoreAttributes""));`n        }"

# ================================================================
# 6. FIX 5: Register packet in ModPackets.java
# ================================================================
Write-Host "[6/7] Registering packet in ModPackets.java..." -ForegroundColor White
$modPacketsPath = "$java\network\ModPackets.java"

# Add ID constant
Patch-File $modPacketsPath `
    "public static final Identifier HIT_STOP_ID = new Identifier(""shinobicore"", ""hit_stop"");" `
    "public static final Identifier HIT_STOP_ID = new Identifier(""shinobicore"", ""hit_stop"");`n    public static final Identifier ATTRIBUTE_SYNC_ID = new Identifier(""shinobicore"", ""attribute_sync"");"

# ================================================================
# 7. FIX 5: Register receiver in ShinobiCoreClient.java
# ================================================================
Write-Host "[7/7] Registering receiver in ShinobiCoreClient.java..." -ForegroundColor White
$clientPath = "$java\client\ShinobiCoreClient.java"

$receiverBlock = @'

        // === S0-01: Attribute delta sync receiver ===
        ClientPlayNetworking.registerGlobalReceiver(AttributeSyncPacket.ID, (client, handler, buf, responseSender) -> {
            // RULE: Read ALL data from buf BEFORE client.execute()!
            final AttributeSyncPacket packet = AttributeSyncPacket.read(buf);
            client.execute(() -> {
                // Client-side attribute display update will go here in S0-07
                // For now, just log for debugging
                if (client.player != null) {
                    ShinobiCore.LOGGER.debug("[ATTR-SYNC] Received {} attribute changes", packet.changedAttributes().size());
                }
            });
        });
'@

Patch-File $clientPath `
    "HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);" `
    "HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);$receiverBlock"

# Add import if missing
Patch-File $clientPath `
    "import com.example.shinobicore.ShinobiCore;" `
    "import com.example.shinobicore.ShinobiCore;`nimport com.example.shinobicore.network.AttributeSyncPacket;"

# ================================================================
# SUMMARY & EXIT CODE (FIX 3)
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S0-01 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Created:" -ForegroundColor White
Write-Host "    stat/AttributeType.java          - 11 attributes enum" -ForegroundColor White
Write-Host "    stat/AttributeStore.java         - per-player storage + delta" -ForegroundColor White
Write-Host "    network/AttributeSyncPacket.java - S2C delta packet" -ForegroundColor White
Write-Host ""
Write-Host "  Patched:" -ForegroundColor White
Write-Host "    NinjaDataHolder.java             - +getAttributes()" -ForegroundColor White
Write-Host "    ServerPlayerEntityMixin.java     - +AttributeStore + NBT" -ForegroundColor White
Write-Host "    ModPackets.java                  - +ATTRIBUTE_SYNC_ID" -ForegroundColor White
Write-Host "    ShinobiCoreClient.java           - +global receiver" -ForegroundColor White
Write-Host ""

# FIX 3: Exit with error code if any patches failed
if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected - stopping sprint chain!" -ForegroundColor Red
    Write-Host "  Fix errors before running sprint0_s02_clan_overrides.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  Then: .\scripts\sprint0_s02_clan_overrides.ps1" -ForegroundColor Yellow
exit 0