$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$java = "$base\java\com\example\shinobicore"
$res = "$base\resources"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace('E:\Games\mod\src\main\', ''))" -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[!] Not found: $p" -ForegroundColor Red; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    if ($c.Contains($new)) { Write-Host "[~] Already patched: $($p.Replace('E:\Games\mod\src\main\', ''))" -ForegroundColor Yellow; return }
    if (-not $c.Contains($old)) { Write-Host "[!] Pattern not found in: $($p.Replace('E:\Games\mod\src\main\', ''))" -ForegroundColor Red; return }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] Patched: $($p.Replace('E:\Games\mod\src\main\', ''))" -ForegroundColor Green
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  PHASE 1: UNIQUE MECHANICS, DOJUTSU & ELEMENT INTERACTIONS" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. DojutsuDefinition.java
# ================================================================
Write-Host "[1/16] DojutsuDefinition.java..." -ForegroundColor White
Write-File "$java\dojutsu\DojutsuDefinition.java" @'
package com.example.shinobicore.dojutsu;

import java.util.List;

/**
 * Definition of a Dojutsu (eye technique).
 * Loaded from data/shinobicore/dojutsu/*.json
 */
public record DojutsuDefinition(
    String id,
    String name,
    String clanId,
    List<String> grantedJutsu,
    float damageMultiplier,
    float costReduction,
    String description
) {
    public boolean grantsJutsu(String jutsuId) {
        return grantedJutsu != null && grantedJutsu.contains(jutsuId);
    }
}
'@

# ================================================================
# 2. DojutsuRegistry.java
# ================================================================
Write-Host "[2/16] DojutsuRegistry.java..." -ForegroundColor White
Write-File "$java\dojutsu\DojutsuRegistry.java" @'
package com.example.shinobicore.dojutsu;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class DojutsuRegistry {
    private static final Map<String, DojutsuDefinition> DOJUTSU = new HashMap<>();

    public static void reload(ResourceManager manager) {
        DOJUTSU.clear();
        Map<Identifier, List<Resource>> resources = manager.findAllResources("dojutsu",
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json"));
        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            for (Resource resource : entry.getValue()) {
                try (InputStream stream = resource.getInputStream()) {
                    JsonObject json = JsonParser.parseReader(
                        new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                    DojutsuDefinition def = parse(json);
                    DOJUTSU.put(def.id(), def);
                    ShinobiCore.LOGGER.info("Loaded dojutsu: {}", def.id());
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("Failed to load dojutsu from {}: {}", entry.getKey(), e.getMessage());
                }
            }
        }
        ShinobiCore.LOGGER.info("Loaded {} dojutsu", DOJUTSU.size());
    }

    public static DojutsuDefinition get(String id) {
        return DOJUTSU.get(id);
    }

    public static Collection<DojutsuDefinition> getAll() {
        return DOJUTSU.values();
    }

    public static boolean exists(String id) {
        return DOJUTSU.containsKey(id);
    }

    private static DojutsuDefinition parse(JsonObject json) {
        String id = json.get("id").getAsString();
        String name = json.has("name") ? json.get("name").getAsString() : id;
        String clanId = json.has("clanId") ? json.get("clanId").getAsString() : null;
        List<String> grantedJutsu = new ArrayList<>();
        if (json.has("grantedJutsu")) {
            JsonArray arr = json.getAsJsonArray("grantedJutsu");
            for (int i = 0; i < arr.size(); i++) {
                grantedJutsu.add(arr.get(i).getAsString());
            }
        }
        float damageMult = json.has("damageMultiplier") ? json.get("damageMultiplier").getAsFloat() : 1.0f;
        float costRed = json.has("costReduction") ? json.get("costReduction").getAsFloat() : 0f;
        String desc = json.has("description") ? json.get("description").getAsString() : "";
        return new DojutsuDefinition(id, name, clanId, grantedJutsu, damageMult, costRed, desc);
    }
}
'@

# ================================================================
# 3. ElementInteractionManager.java
# ================================================================
Write-Host "[3/16] ElementInteractionManager.java..." -ForegroundColor White
Write-File "$java\jutsu\ElementInteractionManager.java" @'
package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.block.Blocks;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.fluid.FluidState;
import net.minecraft.item.ItemStack;
import net.minecraft.item.Items;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

/**
 * Manages interactions between elements and the environment.
 * Called from behaviors and projectile entities.
 *
 * Interactions:
 * 1. Fire + Water -> Steam (blindness cloud)
 * 2. Lightning + Water -> Electrocute (bonus damage in water)
 * 3. Wind + Fire -> Fire amplification (+25% damage)
 * 4. Earth + Water -> Mud (slowness zone)
 * 5. Water + Fire -> Extinguish (removes fire)
 * 6. Lightning + Metal Armor -> Conductivity (+50% damage)
 * 7. Fire + Flammable Block -> Spread fire
 * 8. Water + Lava -> Obsidian/Cobblestone
 */
public class ElementInteractionManager {

    // ============================================================
    // 1. FIRE + WATER -> STEAM
    // ============================================================
    public static void fireMeetsWater(ServerWorld world, Vec3d pos, float radius) {
        // Spawn steam particles
        for (int i = 0; i < 30; i++) {
            double angle = Math.random() * Math.PI * 2;
            double r = Math.random() * radius;
            world.spawnParticles(ParticleTypes.CLOUD,
                pos.x + Math.cos(angle) * r,
                pos.y + 0.5 + Math.random() * 2.0,
                pos.z + Math.sin(angle) * r,
                3, 0.2, 0.5, 0.2, 0.01);
        }
        world.spawnParticles(ParticleTypes.LARGE_SMOKE,
            pos.x, pos.y + 1, pos.z, 10, 1.0, 1.5, 1.0, 0.01);

        // Blindness to entities in steam
        for (Entity e : world.getOtherEntities(null, new Box(pos, pos).expand(radius))) {
            if (e instanceof LivingEntity liv) {
                liv.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.BLINDNESS, 60, 0, false, false));
            }
        }

        world.playSound(null, BlockPos.ofFloored(pos),
            SoundEvents.BLOCK_FIRE_EXTINGUISH, SoundCategory.BLOCKS, 1.5f, 0.8f);

        ShinobiCore.LOGGER.debug("[ELEMENT] Fire + Water -> Steam at {}", pos);
    }

    // ============================================================
    // 2. LIGHTNING + WATER -> ELECTROCUTE
    // ============================================================
    public static void lightningMeetsWater(ServerWorld world, Vec3d pos, float radius,
                                             float bonusDamage, ServerPlayerEntity caster) {
        // Check if there's water nearby
        BlockPos center = BlockPos.ofFloored(pos);
        boolean hasWater = false;
        for (int dx = -2; dx <= 2; dx++) {
            for (int dz = -2; dz <= 2; dz++) {
                FluidState fs = world.getFluidState(center.add(dx, 0, dz));
                if (!fs.isEmpty()) { hasWater = true; break; }
            }
            if (hasWater) break;
        }

        if (!hasWater) return;

        // Electric particles on water surface
        for (int i = 0; i < 40; i++) {
            double angle = Math.random() * Math.PI * 2;
            double r = Math.random() * radius;
            world.spawnParticles(ParticleTypes.ELECTRIC_SPARK,
                pos.x + Math.cos(angle) * r,
                pos.y + 0.1,
                pos.z + Math.sin(angle) * r,
                2, 0.1, 0.05, 0.1, 0.05);
        }

        // Bonus damage to entities in water
        for (Entity e : world.getOtherEntities(caster, new Box(pos, pos).expand(radius))) {
            if (e instanceof LivingEntity liv && liv.isTouchingWater()) {
                liv.damage(caster != null ? caster.getDamageSources().magic()
                    : world.getDamageSources().magic(), bonusDamage);
                liv.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.SLOWNESS, 40, 1, false, false));
            }
        }

        world.playSound(null, center,
            SoundEvents.ENTITY_LIGHTNING_BOLT_IMPACT, SoundCategory.BLOCKS, 1.0f, 1.5f);

        ShinobiCore.LOGGER.debug("[ELEMENT] Lightning + Water -> Electrocute at {}", pos);
    }

    // ============================================================
    // 3. WIND + FIRE -> AMPLIFICATION (checked in JutsuCaster)
    // ============================================================
    public static float getWindFireAmplification(ServerPlayerEntity caster) {
        // This is handled via TreePassives.fireWindSynergy
        // Here we add elemental interaction bonus
        var data = ((com.example.shinobicore.stat.NinjaDataHolder) caster).shinobicore_getData();
        if (data.isNatureUnlocked(com.example.shinobicore.stat.ElementType.WIND)
            && data.getNatureLevel(com.example.shinobicore.stat.ElementType.WIND) >= 20) {
            return 0.15f; // +15% fire damage if wind level >= 20
        }
        return 0f;
    }

    // ============================================================
    // 4. EARTH + WATER -> MUD
    // ============================================================
    public static void earthMeetsWater(ServerWorld world, Vec3d pos, float radius) {
        // Spawn mud particles
        for (int i = 0; i < 25; i++) {
            double angle = Math.random() * Math.PI * 2;
            double r = Math.random() * radius;
            world.spawnParticles(ParticleTypes.POOF,
                pos.x + Math.cos(angle) * r,
                pos.y + 0.2,
                pos.z + Math.sin(angle) * r,
                2, 0.15, 0.1, 0.15, 0.02);
        }

        // Slowness + Mining Fatigue to entities in area
        for (Entity e : world.getOtherEntities(null, new Box(pos, pos).expand(radius))) {
            if (e instanceof LivingEntity liv) {
                liv.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.SLOWNESS, 100, 2, false, false));
                liv.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.MINING_FATIGUE, 100, 1, false, false));
            }
        }

        ShinobiCore.LOGGER.debug("[ELEMENT] Earth + Water -> Mud at {}", pos);
    }

    // ============================================================
    // 5. WATER + FIRE -> EXTINGUISH
    // ============================================================
    public static void waterExtinguishes(ServerWorld world, Vec3d pos, float radius) {
        BlockPos center = BlockPos.ofFloored(pos);
        int extinguished = 0;
        int r = (int) radius;
        for (int dx = -r; dx <= r; dx++) {
            for (int dy = -1; dy <= 2; dy++) {
                for (int dz = -r; dz <= r; dz++) {
                    BlockPos bp = center.add(dx, dy, dz);
                    if (world.getBlockState(bp).isOf(Blocks.FIRE)) {
                        world.removeBlock(bp, false);
                        extinguished++;
                    }
                }
            }
        }
        if (extinguished > 0) {
            world.playSound(null, center,
                SoundEvents.BLOCK_FIRE_EXTINGUISH, SoundCategory.BLOCKS, 1.0f, 1.0f);
            ShinobiCore.LOGGER.debug("[ELEMENT] Water extinguished {} fire blocks", extinguished);
        }
    }

    // ============================================================
    // 6. LIGHTNING + METAL ARMOR -> CONDUCTIVITY
    // ============================================================
    public static float getLightningMetalBonus(LivingEntity target) {
        int metalCount = 0;
        for (ItemStack armor : target.getArmorItems()) {
            if (armor.getItem() == Items.IRON_HELMET
                || armor.getItem() == Items.IRON_CHESTPLATE
                || armor.getItem() == Items.IRON_LEGGINGS
                || armor.getItem() == Items.IRON_BOOTS
                || armor.getItem() == Items.CHAINMAIL_HELMET
                || armor.getItem() == Items.CHAINMAIL_CHESTPLATE
                || armor.getItem() == Items.CHAINMAIL_LEGGINGS
                || armor.getItem() == Items.CHAINMAIL_BOOTS) {
                metalCount++;
            }
        }
        return metalCount * 0.125f; // +12.5% per metal armor piece (max +50%)
    }

    // ============================================================
    // 7. FIRE + FLAMMABLE -> SPREAD
    // ============================================================
    public static void fireSpreads(ServerWorld world, Vec3d pos, float radius) {
        BlockPos center = BlockPos.ofFloored(pos);
        int spread = 0;
        int r = (int) radius;
        for (int dx = -r; dx <= r; dx++) {
            for (int dz = -r; dz <= r; dz++) {
                for (int dy = 0; dy <= 2; dy++) {
                    BlockPos bp = center.add(dx, dy, dz);
                    if (world.getBlockState(bp).isAir()) {
                        // Check if adjacent block is flammable
                        BlockPos below = bp.down();
                        if (world.getBlockState(below).isOf(Blocks.OAK_LOG)
                            || world.getBlockState(below).isOf(Blocks.BIRCH_LOG)
                            || world.getBlockState(below).isOf(Blocks.SPRUCE_LOG)
                            || world.getBlockState(below).isOf(Blocks.JUNGLE_LOG)
                            || world.getBlockState(below).isOf(Blocks.ACACIA_LOG)
                            || world.getBlockState(below).isOf(Blocks.DARK_OAK_LOG)
                            || world.getBlockState(below).isOf(Blocks.OAK_PLANKS)
                            || world.getBlockState(below).isOf(Blocks.OAK_LEAVES)
                            || world.getBlockState(below).isOf(Blocks.GRASS)
                            || world.getBlockState(below).isOf(Blocks.TALL_GRASS)) {
                            if (Math.random() < 0.3) {
                                world.setBlockState(bp, Blocks.FIRE.getDefaultState(), 3);
                                spread++;
                            }
                        }
                    }
                }
            }
        }
        if (spread > 0) {
            ShinobiCore.LOGGER.debug("[ELEMENT] Fire spread to {} blocks", spread);
        }
    }

    // ============================================================
    // 8. WATER + LAVA -> OBSIDIAN
    // ============================================================
    public static void waterMeetsLava(ServerWorld world, Vec3d pos, float radius) {
        BlockPos center = BlockPos.ofFloored(pos);
        int converted = 0;
        int r = (int) radius;
        for (int dx = -r; dx <= r; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                for (int dz = -r; dz <= r; dz++) {
                    BlockPos bp = center.add(dx, dy, dz);
                    if (world.getBlockState(bp).isOf(Blocks.LAVA)) {
                        world.setBlockState(bp, Blocks.OBSIDIAN.getDefaultState(), 3);
                        converted++;
                    } else if (world.getBlockState(bp).isOf(Blocks.FLOWING_LAVA)) {
                        world.setBlockState(bp, Blocks.COBBLESTONE.getDefaultState(), 3);
                        converted++;
                    }
                }
            }
        }
        if (converted > 0) {
            world.playSound(null, center,
                SoundEvents.BLOCK_FIRE_EXTINGUISH, SoundCategory.BLOCKS, 1.5f, 0.6f);
            world.spawnParticles(ParticleTypes.LARGE_SMOKE,
                pos.x, pos.y, pos.z, 15, 1.0, 1.0, 1.0, 0.01);
            ShinobiCore.LOGGER.debug("[ELEMENT] Water + Lava -> {} blocks converted", converted);
        }
    }

    // ============================================================
    // DISPATCHER: called from behaviors
    // ============================================================
    public static void onElementalImpact(ServerWorld world, String elementType,
                                          Vec3d pos, float radius, ServerPlayerEntity caster) {
        if (world == null || pos == null) return;
        switch (elementType) {
            case "fire" -> {
                fireSpreads(world, pos, radius * 0.5f);
                // Check if water nearby -> steam
                BlockPos center = BlockPos.ofFloored(pos);
                for (int dx = -1; dx <= 1; dx++) {
                    for (int dz = -1; dz <= 1; dz++) {
                        FluidState fs = world.getFluidState(center.add(dx, 0, dz));
                        if (!fs.isEmpty()) {
                            fireMeetsWater(world, pos, radius);
                            return;
                        }
                    }
                }
            }
            case "water" -> {
                waterExtinguishes(world, pos, radius);
                waterMeetsLava(world, pos, radius);
            }
            case "lightning" -> {
                lightningMeetsWater(world, pos, radius, 4.0f, caster);
            }
            case "earth" -> {
                // Check if water nearby -> mud
                BlockPos center = BlockPos.ofFloored(pos);
                for (int dx = -1; dx <= 1; dx++) {
                    for (int dz = -1; dz <= 1; dz++) {
                        FluidState fs = world.getFluidState(center.add(dx, 0, dz));
                        if (!fs.isEmpty()) {
                            earthMeetsWater(world, pos, radius);
                            return;
                        }
                    }
                }
            }
            case "wind" -> {
                // Wind + Fire synergy is handled in JutsuCaster
            }
        }
    }
}
'@

# ================================================================
# 4. ScrollItem.java
# ================================================================
Write-Host "[4/16] ScrollItem.java..." -ForegroundColor White
Write-File "$java\item\ScrollItem.java" @'
package com.example.shinobicore.item;

import net.minecraft.client.item.TooltipContext;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
import net.minecraft.world.World;

import java.util.List;

/**
 * A scroll that grants access to a specific jutsu.
 * NBT tag "JutsuId" stores the jutsu identifier.
 */
public class ScrollItem extends Item {
    public ScrollItem(Settings settings) {
        super(settings);
    }

    public static String getJutsuId(ItemStack stack) {
        NbtCompound nbt = stack.getNbt();
        if (nbt != null && nbt.contains("JutsuId")) {
            return nbt.getString("JutsuId");
        }
        return null;
    }

    public static void setJutsuId(ItemStack stack, String jutsuId) {
        stack.getOrCreateNbt().putString("JutsuId", jutsuId);
    }

    @Override
    public Text getName(ItemStack stack) {
        String jutsuId = getJutsuId(stack);
        if (jutsuId != null) {
            return Text.literal("Scroll: " + jutsuId.replace("shinobicore:", "")).formatted(Formatting.GOLD);
        }
        return Text.literal("Empty Scroll").formatted(Formatting.GRAY);
    }

    @Override
    public void appendTooltip(ItemStack stack, World world, List<Text> tooltip, TooltipContext context) {
        String jutsuId = getJutsuId(stack);
        if (jutsuId != null) {
            tooltip.add(Text.literal("Grants access to: " + jutsuId).formatted(Formatting.YELLOW));
            tooltip.add(Text.literal("Consume to learn the jutsu").formatted(Formatting.GRAY));
        } else {
            tooltip.add(Text.literal("An empty scroll").formatted(Formatting.GRAY));
        }
    }

    @Override
    public boolean hasGlint(ItemStack stack) {
        return getJutsuId(stack) != null;
    }
}
'@

# ================================================================
# 5. Patch JutsuDefinition.java — add requiresDojutsu/requiresScroll
# ================================================================
Write-Host "[5/16] Patching JutsuDefinition.java..." -ForegroundColor White
Patch-File "$java\jutsu\JutsuDefinition.java" `
    'int requiredUsesForFullProficiency,
    Map<String, Integer> requirements
) {' `
    'int requiredUsesForFullProficiency,
    Map<String, Integer> requirements,
    String requiresDojutsu,
    String requiresScroll
) {'

# ================================================================
# 6. Patch JutsuRegistry.java — parse new fields
# ================================================================
Write-Host "[6/16] Patching JutsuRegistry.java..." -ForegroundColor White
Patch-File "$java\jutsu\JutsuRegistry.java" `
    'return new JutsuDefinition(
            id, name, category, nature, type, behaviorClass, params,
            baseCost, baseDamage, strain,
            requiredUses, requirements
        );' `
    'String requiresDojutsu = json.has("requiresDojutsu") && !json.get("requiresDojutsu").isJsonNull()
            ? json.get("requiresDojutsu").getAsString() : null;
        String requiresScroll = json.has("requiresScroll") && !json.get("requiresScroll").isJsonNull()
            ? json.get("requiresScroll").getAsString() : null;
        return new JutsuDefinition(
            id, name, category, nature, type, behaviorClass, params,
            baseCost, baseDamage, strain,
            requiredUses, requirements, requiresDojutsu, requiresScroll
        );'

# ================================================================
# 7. Patch JutsuCaster.java — dojutsu/scroll checks
# ================================================================
Write-Host "[7/16] Patching JutsuCaster.java..." -ForegroundColor White
Patch-File "$java\jutsu\JutsuCaster.java" `
    'if (!NinjaFormula.checkRequirements(def, data)) {' `
    '// === DOJUTSU CHECK ===
        if (def.requiresDojutsu() != null) {
            String activeDojutsu = data.getActiveDojutsu();
            if (activeDojutsu == null || !activeDojutsu.equals(def.requiresDojutsu())) {
                // Check if player has a scroll for this jutsu
                boolean hasScroll = false;
                if (def.requiresScroll() != null) {
                    for (int i = 0; i < player.getInventory().size(); i++) {
                        ItemStack stack = player.getInventory().getStack(i);
                        if (stack.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                            String scrollJutsu = com.example.shinobicore.item.ScrollItem.getJutsuId(stack);
                            if (def.id().equals(scrollJutsu)) {
                                hasScroll = true;
                                break;
                            }
                        }
                    }
                }
                if (!hasScroll) {
                    player.sendMessage(Text.literal("\u00a7cThis jutsu requires " + def.requiresDojutsu()
                        + "! (Or a scroll)"), false);
                    JutsuLogger.logBehavior("caster",
                        String.format("REJECTED dojutsu: player=%s, jutsu=%s, required=%s, active=%s",
                            player.getName().getString(), def.id(), def.requiresDojutsu(), activeDojutsu));
                    return false;
                }
            }
        }

        // === SCROLL CHECK (for jutsu that only need scroll, no dojutsu) ===
        if (def.requiresScroll() != null && def.requiresDojutsu() == null) {
            boolean hasScroll = false;
            for (int i = 0; i < player.getInventory().size(); i++) {
                ItemStack stack = player.getInventory().getStack(i);
                if (stack.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                    String scrollJutsu = com.example.shinobicore.item.ScrollItem.getJutsuId(stack);
                    if (def.id().equals(scrollJutsu)) {
                        hasScroll = true;
                        break;
                    }
                }
            }
            if (!hasScroll) {
                player.sendMessage(Text.literal("\u00a7cThis jutsu requires a scroll: "
                    + def.requiresScroll()), false);
                return false;
            }
        }

        if (!NinjaFormula.checkRequirements(def, data)) {'

# Add ItemStack import to JutsuCaster
Patch-File "$java\jutsu\JutsuCaster.java" `
    'import net.minecraft.text.Text;' `
    'import net.minecraft.item.ItemStack;
import net.minecraft.text.Text;'

# ================================================================
# 8. Patch NinjaPlayerData.java — activeDojutsu field
# ================================================================
Write-Host "[8/16] Patching NinjaPlayerData.java..." -ForegroundColor White
Patch-File "$java\stat\NinjaPlayerData.java" `
    'private boolean chakraMode = false;' `
    'private boolean chakraMode = false;
    private String activeDojutsu = null;'

Patch-File "$java\stat\NinjaPlayerData.java" `
    'public boolean isChakraMode() { return chakraMode; }' `
    'public boolean isChakraMode() { return chakraMode; }
    public String getActiveDojutsu() { return activeDojutsu; }
    public void setActiveDojutsu(String dojutsuId) { this.activeDojutsu = dojutsuId; statsDirty = true; }'

# NBT save
Patch-File "$java\stat\NinjaPlayerData.java" `
    'nbt.putBoolean("ChakraMode", chakraMode);' `
    'nbt.putBoolean("ChakraMode", chakraMode);
        if (activeDojutsu != null) nbt.putString("ActiveDojutsu", activeDojutsu);'

# NBT load
Patch-File "$java\stat\NinjaPlayerData.java" `
    'chakraMode = nbt.getBoolean("ChakraMode");' `
    'chakraMode = nbt.getBoolean("ChakraMode");
        if (nbt.contains("ActiveDojutsu")) activeDojutsu = nbt.getString("ActiveDojutsu");'

# ================================================================
# 9. Patch ShinobiCore.java — load DojutsuRegistry + set dojutsu on clan join
# ================================================================
Write-Host "[9/16] Patching ShinobiCore.java..." -ForegroundColor White
Patch-File "$java\ShinobiCore.java" `
    'import com.example.shinobicore.jutsu.BehaviorRegistry;' `
    'import com.example.shinobicore.dojutsu.DojutsuRegistry;
import com.example.shinobicore.jutsu.BehaviorRegistry;'

Patch-File "$java\ShinobiCore.java" `
    'JutsuRegistry.reload(server.getResourceManager());
                ClanRegistry.reload(server.getResourceManager());
                SkillTreeRegistry.reload(server.getResourceManager());' `
    'JutsuRegistry.reload(server.getResourceManager());
                ClanRegistry.reload(server.getResourceManager());
                SkillTreeRegistry.reload(server.getResourceManager());
                DojutsuRegistry.reload(server.getResourceManager());'

# Set dojutsu on clan join
Patch-File "$java\ShinobiCore.java" `
    'data.setClanChosen(true);' `
    'data.setClanChosen(true);
                    // === AUTO-SET DOJUTSU FROM CLAN ===
                    if (randomClan.hasDojutsu() && randomClan.dojutsuHook() != null) {
                        data.setActiveDojutsu(randomClan.dojutsuHook());
                        LOGGER.info("Auto-assigned dojutsu {} to {}", randomClan.dojutsuHook(), player.getName().getString());
                    }'

# ================================================================
# 10. Patch ClientNinjaState.java — activeDojutsu
# ================================================================
Write-Host "[10/16] Patching ClientNinjaState.java..." -ForegroundColor White
Patch-File "$java\client\ClientNinjaState.java" `
    'public static String affinityId = null;' `
    'public static String affinityId = null;
    public static String activeDojutsu = null;'

# ================================================================
# 11. Patch ShinobiCoreClient.java — sync dojutsu
# ================================================================
Write-Host "[11/16] Patching ShinobiCoreClient.java..." -ForegroundColor White
Patch-File "$java\client\ShinobiCoreClient.java" `
    'ClientNinjaState.affinityId = affinity.isEmpty() ? null : affinity;' `
    'ClientNinjaState.affinityId = affinity.isEmpty() ? null : affinity;
                if (buf.readableBytes() > 0) {
                    String dojutsu = buf.readString();
                    ClientNinjaState.activeDojutsu = dojutsu.isEmpty() ? null : dojutsu;
                }'

# ================================================================
# 12. Patch sendBodySync — send dojutsu
# ================================================================
Write-Host "[12/16] Patching sendBodySync..." -ForegroundColor White
Patch-File "$java\ShinobiCore.java" `
    'buf.writeString(data.getAffinity() != null ? data.getAffinity().getId() : "");
        ServerPlayNetworking.send(player, ModPackets.BODY_SYNC_ID, buf);' `
    'buf.writeString(data.getAffinity() != null ? data.getAffinity().getId() : "");
        buf.writeString(data.getActiveDojutsu() != null ? data.getActiveDojutsu() : "");
        ServerPlayNetworking.send(player, ModPackets.BODY_SYNC_ID, buf);'

# ================================================================
# 13. Patch ModItems.java — register ScrollItem
# ================================================================
Write-Host "[13/16] Patching ModItems.java..." -ForegroundColor White
Patch-File "$java\item\ModItems.java" `
    'public static void register() {' `
    'public static final Item SCROLL = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "scroll"),
        new ScrollItem(new Item.Settings().maxCount(1)));

    public static void register() {'

# ================================================================
# 14. JSON: Dojutsu definitions
# ================================================================
Write-Host "[14/16] Creating dojutsu JSON files..." -ForegroundColor White
Write-File "$res\data\shinobicore\dojutsu\sharingan.json" @'
{
    "id": "sharingan",
    "name": "Sharingan",
    "clanId": "uchiha",
    "grantedJutsu": ["shinobicore:amaterasu", "shinobicore:uchiha_amaterasu"],
    "damageMultiplier": 1.15,
    "costReduction": 0.10,
    "description": "The copy wheel eye of the Uchiha clan. Grants access to Amaterasu and enhances genjutsu."
}
'@

Write-File "$res\data\shinobicore\dojutsu\byakugan.json" @'
{
    "id": "byakugan",
    "name": "Byakugan",
    "clanId": "hyuga",
    "grantedJutsu": ["shinobicore:hyu_64", "shinobicore:hyu_128"],
    "damageMultiplier": 1.10,
    "costReduction": 0.05,
    "description": "The all-seeing white eye of the Hyuga clan. Enhances Gentle Fist techniques."
}
'@

# ================================================================
# 15. JSON: Update jutsu files with dojutsu/scroll requirements
# ================================================================
Write-Host "[15/16] Updating jutsu JSON files..." -ForegroundColor White

# Amaterasu requires Sharingan
Patch-File "$res\data\shinobicore\jutsu\amaterasu.json" `
    '"requirements":{"control":40,"nature_fire":45,"genjutsu":25}}' `
    '"requirements":{"control":40,"nature_fire":45,"genjutsu":25},"requiresDojutsu":"sharingan"}'

# Uchiha Amaterasu requires Sharingan
Patch-File "$res\data\shinobicore\jutsu\uchiha_amaterasu.json" `
    '"requirements": {"control": 40, "nature_fire": 45, "genjutsu": 25}
}' `
    '"requirements": {"control": 40, "nature_fire": 45, "genjutsu": 25},
    "requiresDojutsu": "sharingan"
}'

# Forbidden: Eight Gates requires scroll
Patch-File "$res\data\shinobicore\jutsu\forbidden_eight_gates.json" `
    '"requirements": {"taijutsu": 50, "control": 40}
}' `
    '"requirements": {"taijutsu": 50, "control": 40},
    "requiresScroll": "scroll_of_eight_gates"
}'

# Forbidden: Edo Tensei requires scroll
Patch-File "$res\data\shinobicore\jutsu\forbidden_edo_tensei.json" `
    '"requirements":{"taijutsu":45,"control":35,"ninjutsu":35}}' `
    '"requirements":{"taijutsu":45,"control":35,"ninjutsu":35},"requiresScroll":"scroll_of_edo_tensei"}'

# ================================================================
# 16. Patch NinjaProjectileEntity — elemental interactions
# ================================================================
Write-Host "[16/16] Patching NinjaProjectileEntity.java..." -ForegroundColor White
Patch-File "$java\entity\NinjaProjectileEntity.java" `
    'this.discard();
        return;
    }
    this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);' `
    '// === ELEMENTAL INTERACTIONS ON IMPACT ===
        if (this.getWorld() instanceof ServerWorld sw) {
            String particle = this.dataTracker.get(PARTICLE_TYPE);
            Vec3d impactPos = this.getPos();
            float impactRadius = this.dataTracker.get(RADIUS);
            com.example.shinobicore.jutsu.ElementInteractionManager.onElementalImpact(
                sw, particle, impactPos, impactRadius,
                this.getOwner() instanceof ServerPlayerEntity sp ? sp : null);
        }
        this.discard();
        return;
    }
    this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);'

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  PHASE 1 COMPLETE!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor Cyan
Write-Host "  [Java] dojutsu/DojutsuDefinition.java" -ForegroundColor White
Write-Host "  [Java] dojutsu/DojutsuRegistry.java" -ForegroundColor White
Write-Host "  [Java] jutsu/ElementInteractionManager.java (8 interactions)" -ForegroundColor White
Write-Host "  [Java] item/ScrollItem.java" -ForegroundColor White
Write-Host "  [JSON] dojutsu/sharingan.json" -ForegroundColor White
Write-Host "  [JSON] dojutsu/byakugan.json" -ForegroundColor White
Write-Host ""
Write-Host "Patched files:" -ForegroundColor Cyan
Write-Host "  [Patch] JutsuDefinition.java (+requiresDojutsu, +requiresScroll)" -ForegroundColor White
Write-Host "  [Patch] JutsuRegistry.java (parse new fields)" -ForegroundColor White
Write-Host "  [Patch] JutsuCaster.java (dojutsu/scroll checks)" -ForegroundColor White
Write-Host "  [Patch] NinjaPlayerData.java (+activeDojutsu + NBT)" -ForegroundColor White
Write-Host "  [Patch] ShinobiCore.java (DojutsuRegistry + auto-set)" -ForegroundColor White
Write-Host "  [Patch] ClientNinjaState.java (+activeDojutsu)" -ForegroundColor White
Write-Host "  [Patch] ShinobiCoreClient.java (sync dojutsu)" -ForegroundColor White
Write-Host "  [Patch] ModItems.java (+ScrollItem)" -ForegroundColor White
Write-Host "  [Patch] NinjaProjectileEntity.java (elemental interactions)" -ForegroundColor White
Write-Host "  [JSON] amaterasu.json (+requiresDojutsu)" -ForegroundColor White
Write-Host "  [JSON] forbidden_eight_gates.json (+requiresScroll)" -ForegroundColor White
Write-Host "  [JSON] forbidden_edo_tensei.json (+requiresScroll)" -ForegroundColor White
Write-Host ""
Write-Host "Elemental Interactions:" -ForegroundColor Cyan
Write-Host "  1. Fire + Water -> Steam (blindness cloud)" -ForegroundColor White
Write-Host "  2. Lightning + Water -> Electrocute (+4 dmg in water)" -ForegroundColor White
Write-Host "  3. Wind + Fire -> Amplification (+15% if wind lvl >= 20)" -ForegroundColor White
Write-Host "  4. Earth + Water -> Mud (slowness + mining fatigue)" -ForegroundColor White
Write-Host "  5. Water + Fire -> Extinguish (removes fire blocks)" -ForegroundColor White
Write-Host "  6. Lightning + Metal Armor -> Conductivity (+12.5%/piece)" -ForegroundColor White
Write-Host "  7. Fire + Flammable -> Spread fire to wood/leaves" -ForegroundColor White
Write-Host "  8. Water + Lava -> Obsidian/Cobblestone" -ForegroundColor White
Write-Host ""
Write-Host "Dojutsu Restrictions:" -ForegroundColor Cyan
Write-Host "  Amaterasu -> requires Sharingan (Uchiha clan) or scroll" -ForegroundColor White
Write-Host "  Eight Gates -> requires scroll" -ForegroundColor White
Write-Host "  Edo Tensei -> requires scroll" -ForegroundColor White
Write-Host ""
Write-Host "Next step: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "Then: .\gradlew.bat runClient" -ForegroundColor Yellow
Write-Host "Test: /unlockall -> try Amaterasu (should be blocked without Uchiha)" -ForegroundColor Yellow
Write-Host "Test: /ninja set clan uchiha -> try Amaterasu (should work)" -ForegroundColor Yellow