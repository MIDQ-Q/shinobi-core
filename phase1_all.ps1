$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"
$res  = "E:\Games\mod\src\main\resources\data\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace('E:\Games\mod\src\main\', ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    if ($c.Contains($new)) { Write-Host "[SKIP] already applied: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $c.Contains($old)) { Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  PHASE 1: UNIQUE MECHANICS + DOJUTSU + SCROLLS + ELEMENTS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. ElementInteractionManager.java
# ================================================================
Write-Host "[1/14] ElementInteractionManager..." -ForegroundColor White
$content = @'
package com.example.shinobicore.jutsu;

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

public class ElementInteractionManager {

    public static void fireMeetsWater(ServerWorld world, Vec3d pos, float radius) {
        for (int i = 0; i < 30; i++) {
            double angle = Math.random() * Math.PI * 2;
            double r = Math.random() * radius;
            world.spawnParticles(ParticleTypes.CLOUD,
                pos.x + Math.cos(angle) * r, pos.y + 0.5 + Math.random() * 2.0,
                pos.z + Math.sin(angle) * r, 3, 0.2, 0.5, 0.2, 0.01);
        }
        world.spawnParticles(ParticleTypes.LARGE_SMOKE, pos.x, pos.y + 1, pos.z, 10, 1.0, 1.5, 1.0, 0.01);
        for (Entity e : world.getOtherEntities(null, new Box(pos, pos).expand(radius))) {
            if (e instanceof LivingEntity liv) {
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, 60, 0, false, false));
            }
        }
        world.playSound(null, BlockPos.ofFloored(pos), SoundEvents.BLOCK_FIRE_EXTINGUISH, SoundCategory.BLOCKS, 1.5f, 0.8f);
    }

    public static void lightningMeetsWater(ServerWorld world, Vec3d pos, float radius, float bonusDmg, ServerPlayerEntity caster) {
        BlockPos center = BlockPos.ofFloored(pos);
        boolean hasWater = false;
        for (int dx = -2; dx <= 2 && !hasWater; dx++)
            for (int dz = -2; dz <= 2 && !hasWater; dz++) {
                FluidState fs = world.getFluidState(center.add(dx, 0, dz));
                if (!fs.isEmpty()) hasWater = true;
            }
        if (!hasWater) return;
        for (int i = 0; i < 40; i++) {
            double a = Math.random() * Math.PI * 2;
            double r = Math.random() * radius;
            world.spawnParticles(ParticleTypes.ELECTRIC_SPARK,
                pos.x + Math.cos(a) * r, pos.y + 0.1, pos.z + Math.sin(a) * r, 2, 0.1, 0.05, 0.1, 0.05);
        }
        for (Entity e : world.getOtherEntities(caster, new Box(pos, pos).expand(radius))) {
            if (e instanceof LivingEntity liv && liv.isTouchingWater()) {
                liv.damage(caster != null ? caster.getDamageSources().magic() : world.getDamageSources().magic(), bonusDmg);
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, 1, false, false));
            }
        }
        world.playSound(null, center, SoundEvents.ENTITY_LIGHTNING_BOLT_IMPACT, SoundCategory.BLOCKS, 1.0f, 1.5f);
    }

    public static void earthMeetsWater(ServerWorld world, Vec3d pos, float radius) {
        for (int i = 0; i < 25; i++) {
            double a = Math.random() * Math.PI * 2;
            double r = Math.random() * radius;
            world.spawnParticles(ParticleTypes.POOF,
                pos.x + Math.cos(a) * r, pos.y + 0.2, pos.z + Math.sin(a) * r, 2, 0.15, 0.1, 0.15, 0.02);
        }
        for (Entity e : world.getOtherEntities(null, new Box(pos, pos).expand(radius))) {
            if (e instanceof LivingEntity liv) {
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 100, 2, false, false));
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, 100, 1, false, false));
            }
        }
    }

    public static void waterExtinguishes(ServerWorld world, Vec3d pos, float radius) {
        BlockPos center = BlockPos.ofFloored(pos);
        int r = (int) radius;
        int count = 0;
        for (int dx = -r; dx <= r; dx++)
            for (int dy = -1; dy <= 2; dy++)
                for (int dz = -r; dz <= r; dz++) {
                    BlockPos bp = center.add(dx, dy, dz);
                    if (world.getBlockState(bp).isOf(Blocks.FIRE)) {
                        world.removeBlock(bp, false);
                        count++;
                    }
                }
        if (count > 0)
            world.playSound(null, center, SoundEvents.BLOCK_FIRE_EXTINGUISH, SoundCategory.BLOCKS, 1.0f, 1.0f);
    }

    public static float getLightningMetalBonus(LivingEntity target) {
        int metal = 0;
        for (ItemStack armor : target.getArmorItems()) {
            if (armor.getItem() == Items.IRON_HELMET || armor.getItem() == Items.IRON_CHESTPLATE
                || armor.getItem() == Items.IRON_LEGGINGS || armor.getItem() == Items.IRON_BOOTS
                || armor.getItem() == Items.CHAINMAIL_HELMET || armor.getItem() == Items.CHAINMAIL_CHESTPLATE
                || armor.getItem() == Items.CHAINMAIL_LEGGINGS || armor.getItem() == Items.CHAINMAIL_BOOTS)
                metal++;
        }
        return metal * 0.125f;
    }

    public static void fireSpreads(ServerWorld world, Vec3d pos, float radius) {
        BlockPos center = BlockPos.ofFloored(pos);
        int r = (int) radius;
        for (int dx = -r; dx <= r; dx++)
            for (int dz = -r; dz <= r; dz++)
                for (int dy = 0; dy <= 2; dy++) {
                    BlockPos bp = center.add(dx, dy, dz);
                    if (world.getBlockState(bp).isAir()) {
                        BlockPos below = bp.down();
                        if (world.getBlockState(below).isOf(Blocks.OAK_LOG)
                            || world.getBlockState(below).isOf(Blocks.SPRUCE_LOG)
                            || world.getBlockState(below).isOf(Blocks.BIRCH_LOG)
                            || world.getBlockState(below).isOf(Blocks.JUNGLE_LOG)
                            || world.getBlockState(below).isOf(Blocks.ACACIA_LOG)
                            || world.getBlockState(below).isOf(Blocks.DARK_OAK_LOG)
                            || world.getBlockState(below).isOf(Blocks.OAK_PLANKS)
                            || world.getBlockState(below).isOf(Blocks.OAK_LEAVES)) {
                            if (Math.random() < 0.3) {
                                world.setBlockState(bp, Blocks.FIRE.getDefaultState(), 3);
                            }
                        }
                    }
                }
    }

    public static void waterMeetsLava(ServerWorld world, Vec3d pos, float radius) {
        BlockPos center = BlockPos.ofFloored(pos);
        int r = (int) radius;
        int converted = 0;
        for (int dx = -r; dx <= r; dx++)
            for (int dy = -1; dy <= 1; dy++)
                for (int dz = -r; dz <= r; dz++) {
                    BlockPos bp = center.add(dx, dy, dz);
                    if (world.getBlockState(bp).isOf(Blocks.LAVA)) {
                        world.setBlockState(bp, Blocks.OBSIDIAN.getDefaultState(), 3);
                        converted++;
                    }
                }
        if (converted > 0) {
            world.playSound(null, center, SoundEvents.BLOCK_FIRE_EXTINGUISH, SoundCategory.BLOCKS, 1.5f, 0.6f);
            world.spawnParticles(ParticleTypes.LARGE_SMOKE, pos.x, pos.y, pos.z, 15, 1.0, 1.0, 1.0, 0.01);
        }
    }

    public static void onElementalImpact(ServerWorld world, String elementType, Vec3d pos, float radius, ServerPlayerEntity caster) {
        if (world == null || pos == null) return;
        BlockPos center = BlockPos.ofFloored(pos);
        switch (elementType) {
            case "fire" -> {
                fireSpreads(world, pos, radius * 0.5f);
                for (int dx = -1; dx <= 1; dx++)
                    for (int dz = -1; dz <= 1; dz++) {
                        FluidState fs = world.getFluidState(center.add(dx, 0, dz));
                        if (!fs.isEmpty()) { fireMeetsWater(world, pos, radius); return; }
                    }
            }
            case "water" -> {
                waterExtinguishes(world, pos, radius);
                waterMeetsLava(world, pos, radius);
            }
            case "lightning" -> lightningMeetsWater(world, pos, radius, 4.0f, caster);
            case "earth" -> {
                for (int dx = -1; dx <= 1; dx++)
                    for (int dz = -1; dz <= 1; dz++) {
                        FluidState fs = world.getFluidState(center.add(dx, 0, dz));
                        if (!fs.isEmpty()) { earthMeetsWater(world, pos, radius); return; }
                    }
            }
        }
    }
}
'@
Write-File "$base\jutsu\ElementInteractionManager.java" $content

# ================================================================
# 2. DojutsuDefinition.java
# ================================================================
Write-Host "[2/14] DojutsuDefinition..." -ForegroundColor White
$content = @'
package com.example.shinobicore.dojutsu;

import java.util.List;

public record DojutsuDefinition(
    String id, String name, String clanId,
    List<String> grantedJutsu, float damageMultiplier, float costReduction, String description
) {
    public boolean grantsJutsu(String jutsuId) {
        return grantedJutsu != null && grantedJutsu.contains(jutsuId);
    }
}
'@
Write-File "$base\dojutsu\DojutsuDefinition.java" $content

# ================================================================
# 3. DojutsuRegistry.java
# ================================================================
Write-Host "[3/14] DojutsuRegistry..." -ForegroundColor White
$content = @'
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
import java.util.*;

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
                    ShinobiCore.LOGGER.error("Failed to load dojutsu: {}", e.getMessage());
                }
            }
        }
        ShinobiCore.LOGGER.info("Loaded {} dojutsu", DOJUTSU.size());
    }

    public static DojutsuDefinition get(String id) { return DOJUTSU.get(id); }
    public static Collection<DojutsuDefinition> getAll() { return DOJUTSU.values(); }
    public static boolean exists(String id) { return DOJUTSU.containsKey(id); }

    private static DojutsuDefinition parse(JsonObject json) {
        String id = json.get("id").getAsString();
        String name = json.has("name") ? json.get("name").getAsString() : id;
        String clanId = json.has("clanId") ? json.get("clanId").getAsString() : null;
        List<String> granted = new ArrayList<>();
        if (json.has("grantedJutsu")) {
            JsonArray arr = json.getAsJsonArray("grantedJutsu");
            for (int i = 0; i < arr.size(); i++) granted.add(arr.get(i).getAsString());
        }
        float dmgMult = json.has("damageMultiplier") ? json.get("damageMultiplier").getAsFloat() : 1.0f;
        float costRed = json.has("costReduction") ? json.get("costReduction").getAsFloat() : 0f;
        String desc = json.has("description") ? json.get("description").getAsString() : "";
        return new DojutsuDefinition(id, name, clanId, granted, dmgMult, costRed, desc);
    }
}
'@
Write-File "$base\dojutsu\DojutsuRegistry.java" $content

# ================================================================
# 4. ScrollItem.java
# ================================================================
Write-Host "[4/14] ScrollItem..." -ForegroundColor White
$content = @'
package com.example.shinobicore.item;

import net.minecraft.client.item.TooltipContext;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
import net.minecraft.world.World;
import java.util.List;

public class ScrollItem extends Item {
    public ScrollItem(Settings settings) { super(settings); }

    public static String getJutsuId(ItemStack stack) {
        NbtCompound nbt = stack.getNbt();
        if (nbt != null && nbt.contains("JutsuId")) return nbt.getString("JutsuId");
        return null;
    }

    public static void setJutsuId(ItemStack stack, String jutsuId) {
        stack.getOrCreateNbt().putString("JutsuId", jutsuId);
    }

    @Override
    public Text getName(ItemStack stack) {
        String id = getJutsuId(stack);
        if (id != null) return Text.literal("Scroll: " + id.replace("shinobicore:", "")).formatted(Formatting.GOLD);
        return Text.literal("Empty Scroll").formatted(Formatting.GRAY);
    }

    @Override
    public void appendTooltip(ItemStack stack, World world, List<Text> tooltip, TooltipContext context) {
        String id = getJutsuId(stack);
        if (id != null) tooltip.add(Text.literal("Grants: " + id).formatted(Formatting.YELLOW));
        else tooltip.add(Text.literal("An empty scroll").formatted(Formatting.GRAY));
    }

    @Override
    public boolean hasGlint(ItemStack stack) { return getJutsuId(stack) != null; }
}
'@
Write-File "$base\item\ScrollItem.java" $content

# ================================================================
# 5. Patch JutsuDefinition — add fields
# ================================================================
Write-Host "[5/14] Patch JutsuDefinition..." -ForegroundColor White
Patch-File "$base\jutsu\JutsuDefinition.java" `
    "Map<String, Integer> requirements
) {" `
    "Map<String, Integer> requirements,
    String requiresDojutsu,
    String requiresScroll
) {"

# ================================================================
# 6. Patch JutsuRegistry — parse new fields
# ================================================================
Write-Host "[6/14] Patch JutsuRegistry..." -ForegroundColor White
Patch-File "$base\jutsu\JutsuRegistry.java" `
    "return new JutsuDefinition(
            id, name, category, nature, type, behaviorClass, params,
            baseCost, baseDamage, strain,
            requiredUses, requirements
        );" `
    "String requiresDojutsu = json.has(""requiresDojutsu"") && !json.get(""requiresDojutsu"").isJsonNull()
            ? json.get(""requiresDojutsu"").getAsString() : null;
        String requiresScroll = json.has(""requiresScroll"") && !json.get(""requiresScroll"").isJsonNull()
            ? json.get(""requiresScroll"").getAsString() : null;
        return new JutsuDefinition(
            id, name, category, nature, type, behaviorClass, params,
            baseCost, baseDamage, strain,
            requiredUses, requirements, requiresDojutsu, requiresScroll
        );"

# ================================================================
# 7. Patch JutsuCaster — dojutsu/scroll check
# ================================================================
Write-Host "[7/14] Patch JutsuCaster..." -ForegroundColor White
Patch-File "$base\jutsu\JutsuCaster.java" `
    "if (!NinjaFormula.checkRequirements(def, data)) {" `
    "// === DOJUTSU CHECK ===
        if (def.requiresDojutsu() != null) {
            String active = data.getActiveDojutsu();
            if (active == null || !active.equals(def.requiresDojutsu())) {
                boolean hasScroll = false;
                for (int i = 0; i < player.getInventory().size(); i++) {
                    net.minecraft.item.ItemStack st = player.getInventory().getStack(i);
                    if (st.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                        String sid = com.example.shinobicore.item.ScrollItem.getJutsuId(st);
                        if (def.id().equals(sid)) { hasScroll = true; break; }
                    }
                }
                if (!hasScroll) {
                    player.sendMessage(Text.literal(""\u00a7cRequires "" + def.requiresDojutsu() + ""!""), false);
                    return false;
                }
            }
        }
        // === SCROLL CHECK ===
        if (def.requiresScroll() != null && def.requiresDojutsu() == null) {
            boolean hasScroll = false;
            for (int i = 0; i < player.getInventory().size(); i++) {
                net.minecraft.item.ItemStack st = player.getInventory().getStack(i);
                if (st.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                    String sid = com.example.shinobicore.item.ScrollItem.getJutsuId(st);
                    if (def.id().equals(sid)) { hasScroll = true; break; }
                }
            }
            if (!hasScroll) {
                player.sendMessage(Text.literal(""\u00a7cRequires scroll: "" + def.requiresScroll()), false);
                return false;
            }
        }
        if (!NinjaFormula.checkRequirements(def, data)) {"

# ================================================================
# 8. Patch NinjaPlayerData — activeDojutsu
# ================================================================
Write-Host "[8/14] Patch NinjaPlayerData..." -ForegroundColor White
Patch-File "$base\stat\NinjaPlayerData.java" `
    "private boolean chakraMode = false;" `
    "private boolean chakraMode = false;
    private String activeDojutsu = null;"

Patch-File "$base\stat\NinjaPlayerData.java" `
    "public boolean isChakraMode() { return chakraMode; }" `
    "public boolean isChakraMode() { return chakraMode; }
    public String getActiveDojutsu() { return activeDojutsu; }
    public void setActiveDojutsu(String d) { this.activeDojutsu = d; statsDirty = true; }"

Patch-File "$base\stat\NinjaPlayerData.java" `
    "nbt.putBoolean(""ChakraMode"", chakraMode);" `
    "nbt.putBoolean(""ChakraMode"", chakraMode);
        if (activeDojutsu != null) nbt.putString(""ActiveDojutsu"", activeDojutsu);"

Patch-File "$base\stat\NinjaPlayerData.java" `
    "chakraMode = nbt.getBoolean(""ChakraMode"");" `
    "chakraMode = nbt.getBoolean(""ChakraMode"");
        if (nbt.contains(""ActiveDojutsu"")) activeDojutsu = nbt.getString(""ActiveDojutsu"");"

# ================================================================
# 9. Patch ShinobiCore — load DojutsuRegistry + auto-set
# ================================================================
Write-Host "[9/14] Patch ShinobiCore..." -ForegroundColor White
Patch-File "$base\ShinobiCore.java" `
    "import com.example.shinobicore.jutsu.JutsuRegistry;" `
    "import com.example.shinobicore.dojutsu.DojutsuRegistry;
import com.example.shinobicore.jutsu.JutsuRegistry;"

Patch-File "$base\ShinobiCore.java" `
    "SkillTreeRegistry.reload(server.getResourceManager());" `
    "SkillTreeRegistry.reload(server.getResourceManager());
                DojutsuRegistry.reload(server.getResourceManager());"

Patch-File "$base\ShinobiCore.java" `
    "data.setClanChosen(true);" `
    "data.setClanChosen(true);
                    if (randomClan.hasDojutsu() && randomClan.dojutsuHook() != null) {
                        data.setActiveDojutsu(randomClan.dojutsuHook());
                    }"

# ================================================================
# 10. Patch ClientNinjaState
# ================================================================
Write-Host "[10/14] Patch ClientNinjaState..." -ForegroundColor White
Patch-File "$base\client\ClientNinjaState.java" `
    "public static String affinityId = null;" `
    "public static String affinityId = null;
    public static String activeDojutsu = null;"

# ================================================================
# 11. Patch ShinobiCoreClient — sync dojutsu
# ================================================================
Write-Host "[11/14] Patch ShinobiCoreClient..." -ForegroundColor White
Patch-File "$base\client\ShinobiCoreClient.java" `
    "ClientNinjaState.affinityId = affinity.isEmpty() ? null : affinity;" `
    "ClientNinjaState.affinityId = affinity.isEmpty() ? null : affinity;
                if (buf.readableBytes() > 0) {
                    String dojutsu = buf.readString();
                    ClientNinjaState.activeDojutsu = dojutsu.isEmpty() ? null : dojutsu;
                }"

# ================================================================
# 12. Patch sendBodySync
# ================================================================
Write-Host "[12/14] Patch sendBodySync..." -ForegroundColor White
Patch-File "$base\ShinobiCore.java" `
    "buf.writeString(data.getAffinity() != null ? data.getAffinity().getId() : """");
        ServerPlayNetworking.send(player, ModPackets.BODY_SYNC_ID, buf);" `
    "buf.writeString(data.getAffinity() != null ? data.getAffinity().getId() : """");
        buf.writeString(data.getActiveDojutsu() != null ? data.getActiveDojutsu() : """");
        ServerPlayNetworking.send(player, ModPackets.BODY_SYNC_ID, buf);"

# ================================================================
# 13. Patch ModItems — register ScrollItem
# ================================================================
Write-Host "[13/14] Patch ModItems..." -ForegroundColor White
Patch-File "$base\item\ModItems.java" `
    "public static void register() {" `
    "public static final Item SCROLL = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, ""scroll""),
        new ScrollItem(new Item.Settings().maxCount(1)));

    public static void register() {"

# ================================================================
# 14. Patch NinjaProjectileEntity — elemental impact
# ================================================================
Write-Host "[14/14] Patch NinjaProjectileEntity..." -ForegroundColor White
Patch-File "$base\entity\NinjaProjectileEntity.java" `
    "this.discard();
        return;
    }
    this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);" `
    "// === ELEMENTAL INTERACTIONS ===
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
    this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);"

# ================================================================
# JSON RESOURCES
# ================================================================
Write-Host ""
Write-Host "--- JSON Resources ---" -ForegroundColor Cyan

Write-File "$res\dojutsu\sharingan.json" @'
{
    "id": "sharingan",
    "name": "Sharingan",
    "clanId": "uchiha",
    "grantedJutsu": ["shinobicore:amaterasu", "shinobicore:uchiha_amaterasu"],
    "damageMultiplier": 1.15,
    "costReduction": 0.10,
    "description": "The copy wheel eye of the Uchiha clan."
}
'@

Write-File "$res\dojutsu\byakugan.json" @'
{
    "id": "byakugan",
    "name": "Byakugan",
    "clanId": "hyuga",
    "grantedJutsu": ["shinobicore:hyu_64", "shinobicore:hyu_128"],
    "damageMultiplier": 1.10,
    "costReduction": 0.05,
    "description": "The all-seeing white eye of the Hyuga clan."
}
'@

# ================================================================
# Patch jutsu JSONs
# ================================================================
$amaFile = "$res\jutsu\amaterasu.json"
if (Test-Path $amaFile) {
    $c = [System.IO.File]::ReadAllText($amaFile, $utf8)
    if (-not $c.Contains("requiresDojutsu")) {
        $c = $c.TrimEnd()
        if ($c.EndsWith("}")) {
            $c = $c.Substring(0, $c.Length - 1) + ',"requiresDojutsu":"sharingan"}'
        }
        [System.IO.File]::WriteAllText($amaFile, $c, $utf8)
        Write-Host "[OK] amaterasu.json + requiresDojutsu" -ForegroundColor Green; $ok++
    }
}

$uaFile = "$res\jutsu\uchiha_amaterasu.json"
if (Test-Path $uaFile) {
    $c = [System.IO.File]::ReadAllText($uaFile, $utf8)
    if (-not $c.Contains("requiresDojutsu")) {
        $c = $c.TrimEnd()
        if ($c.EndsWith("}")) {
            $c = $c.Substring(0, $c.Length - 1) + ',"requiresDojutsu":"sharingan"}'
        }
        [System.IO.File]::WriteAllText($uaFile, $c, $utf8)
        Write-Host "[OK] uchiha_amaterasu.json + requiresDojutsu" -ForegroundColor Green; $ok++
    }
}

$egFile = "$res\jutsu\forbidden_eight_gates.json"
if (Test-Path $egFile) {
    $c = [System.IO.File]::ReadAllText($egFile, $utf8)
    if (-not $c.Contains("requiresScroll")) {
        $c = $c.TrimEnd()
        if ($c.EndsWith("}")) {
            $c = $c.Substring(0, $c.Length - 1) + ',"requiresScroll":"scroll_of_eight_gates"}'
        }
        [System.IO.File]::WriteAllText($egFile, $c, $utf8)
        Write-Host "[OK] forbidden_eight_gates.json + requiresScroll" -ForegroundColor Green; $ok++
    }
}

$etFile = "$res\jutsu\forbidden_edo_tensei.json"
if (Test-Path $etFile) {
    $c = [System.IO.File]::ReadAllText($etFile, $utf8)
    if (-not $c.Contains("requiresScroll")) {
        $c = $c.TrimEnd()
        if ($c.EndsWith("}")) {
            $c = $c.Substring(0, $c.Length - 1) + ',"requiresScroll":"scroll_of_edo_tensei"}'
        }
        [System.IO.File]::WriteAllText($etFile, $c, $utf8)
        Write-Host "[OK] forbidden_edo_tensei.json + requiresScroll" -ForegroundColor Green; $ok++
    }
}

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  PHASE 1 COMPLETE" -ForegroundColor Green
Write-Host "  OK: $ok | SKIP: $skip | ERR: $err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: .\gradlew.bat build" -ForegroundColor Yellow