$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"
$res  = "E:\Games\mod\src\main\resources\data\shinobicore"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] Created: $($p.Replace('E:\Games\mod\src\main\', ''))" -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    if ($c.Contains($new)) { Write-Host "[SKIP] Already applied: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; return }
    if (-not $c.Contains($old)) { Write-Host "[FAIL] Pattern not found in: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; return }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] Patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  KATANA TIERS, ANBU ARMOR & BACK SCABBARD SYSTEM" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. KatanaItem.java
Write-File "$base\item\KatanaItem.java" @'
package com.example.shinobicore.item;

import net.minecraft.item.Item;
import net.minecraft.item.SwordItem;
import net.minecraft.item.ToolMaterial;

public class KatanaItem extends SwordItem {
    public KatanaItem(ToolMaterial material, Item.Settings settings) {
        super(material, 4, -2.4f, settings);
    }
}
'@

# 2. ModArmorMaterials.java
Write-File "$base\item\ModArmorMaterials.java" @'
package com.example.shinobicore.item;

import net.minecraft.item.ArmorItem;
import net.minecraft.item.ArmorMaterial;
import net.minecraft.item.Items;
import net.minecraft.recipe.Ingredient;
import net.minecraft.sound.SoundEvent;
import net.minecraft.sound.SoundEvents;

public class ModArmorMaterials {
    public static final ArmorMaterial NARUTO_FLAK = new ArmorMaterial() {
        @Override public int getDurability(ArmorItem.Type type) { return switch(type) { case HELMET -> 165; case CHESTPLATE -> 240; case LEGGINGS -> 225; case BOOTS -> 195; }; }
        @Override public int getProtection(ArmorItem.Type type) { return switch(type) { case HELMET -> 2; case CHESTPLATE -> 6; case LEGGINGS -> 5; case BOOTS -> 2; }; }
        @Override public int getEnchantability() { return 15; }
        @Override public SoundEvent getEquipSound() { return SoundEvents.ITEM_ARMOR_EQUIP_IRON; }
        @Override public Ingredient getRepairIngredient() { return Ingredient.ofItems(Items.IRON_INGOT); }
        @Override public String getName() { return "shinobicore:naruto_flak"; }
        @Override public float getToughness() { return 1.0f; }
        @Override public float getKnockbackResistance() { return 0.0f; }
    };
}
'@

# 3. ModItems.java
Write-File "$base\item\ModItems.java" @'
package com.example.shinobicore.item;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.item.ArmorItem;
import net.minecraft.item.Item;
import net.minecraft.item.ToolMaterials;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

public class ModItems {
    public static final Item KATANA_IRON = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "katana_iron"), new KatanaItem(ToolMaterials.IRON, new Item.Settings().maxCount(1)));
    public static final Item KATANA_DIAMOND = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "katana_diamond"), new KatanaItem(ToolMaterials.DIAMOND, new Item.Settings().maxCount(1)));
    public static final Item KATANA_NETHERITE = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "katana_netherite"), new KatanaItem(ToolMaterials.NETHERITE, new Item.Settings().maxCount(1).fireproof()));
    
    public static final Item KATANA = KATANA_IRON; // Alias for backwards compatibility

    public static final Item FLAK_VEST = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "flak_vest"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.CHESTPLATE, new Item.Settings()));
    public static final Item NINJA_PANTS = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "ninja_pants"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.LEGGINGS, new Item.Settings()));
    public static final Item NINJA_SANDALS = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "ninja_sandals"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.BOOTS, new Item.Settings()));
    public static final Item NINJA_HOOD = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "ninja_hood"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.HELMET, new Item.Settings()));

    public static final Item SHURIKEN = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "shuriken"),
        new ThrowingWeaponItem(new Item.Settings().maxCount(16), 3f, 3.0f, 8));
    public static final Item KUNAI = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "kunai"),
        new ThrowingWeaponItem(new Item.Settings().maxCount(16), 5f, 2.2f, 12));
    public static final Item SCROLL = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "scroll"),
        new ScrollItem(new Item.Settings().maxCount(1)));

    public static void register() {
        ShinobiCore.LOGGER.info("Registered katanas, armor, shuriken/kunai items");
    }
}
'@

# 4. NarutoArmorRenderer.java
Write-File "$base\client\render\NarutoArmorRenderer.java" @'
package com.example.shinobicore.client.render;

import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.entity.EquipmentSlot;
import net.minecraft.entity.LivingEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.util.Identifier;
import org.joml.Matrix4f;
import com.example.shinobicore.item.ModItems;

public class NarutoArmorRenderer {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public static void register() {
        net.fabricmc.fabric.api.client.rendering.v1.ArmorRenderer.register(
            NarutoArmorRenderer::renderArmor, 
            ModItems.FLAK_VEST, ModItems.NINJA_PANTS, ModItems.NINJA_SANDALS, ModItems.NINJA_HOOD
        );
    }

    private static void renderArmor(MatrixStack matrices, VertexConsumerProvider vertices, ItemStack stack, 
                                    LivingEntity entity, EquipmentSlot slot, int light, BipedEntityModel<?> model) {
        matrices.push();
        VertexConsumer vc = vertices.getBuffer(RenderLayer.getEntityTranslucent(TEX));

        if (slot == EquipmentSlot.CHEST) {
            matrices.multiply(model.body.getRotation());
            matrices.translate(0, 0.25, 0);
            drawFlakJacket(matrices, vc, light);
        } else if (slot == EquipmentSlot.LEGS) {
            matrices.multiply(model.rightLeg.getRotation());
            drawPants(matrices, vc, light, true);
            matrices.pop();
            matrices.push();
            matrices.multiply(model.leftLeg.getRotation());
            drawPants(matrices, vc, light, false);
        } else if (slot == EquipmentSlot.FEET) {
            matrices.multiply(model.rightLeg.getRotation());
            drawSandals(matrices, vc, light, true);
            matrices.pop();
            matrices.push();
            matrices.multiply(model.leftLeg.getRotation());
            drawSandals(matrices, vc, light, false);
        } else if (slot == EquipmentSlot.HEAD) {
            matrices.multiply(model.head.getRotation());
            drawHood(matrices, vc, light);
        }

        matrices.pop();
    }

    private static void drawFlakJacket(MatrixStack m, VertexConsumer vc, int light) {
        cuboid(m, vc, light, -0.26f, -0.1f, -0.16f, 0.52f, 0.7f, 0.32f, 0.1f, 0.1f, 0.1f);
        cuboid(m, vc, light, -0.28f, 0.0f, -0.18f, 0.56f, 0.5f, 0.36f, 0.35f, 0.55f, 0.25f);
        cuboid(m, vc, light, -0.28f, 0.45f, -0.18f, 0.56f, 0.15f, 0.36f, 0.5f, 0.6f, 0.5f);
        cuboid(m, vc, light, -0.20f, 0.1f, -0.19f, 0.15f, 0.15f, 0.02f, 0.25f, 0.45f, 0.15f);
        cuboid(m, vc, light, 0.05f, 0.1f, -0.19f, 0.15f, 0.15f, 0.02f, 0.25f, 0.45f, 0.15f);
    }

    private static void drawPants(MatrixStack m, VertexConsumer vc, int light, boolean isRightLeg) {
        float x = isRightLeg ? -0.1f : -0.1f;
        cuboid(m, vc, light, x - 0.1f, -0.1f, -0.1f, 0.2f, 0.7f, 0.2f, 0.1f, 0.1f, 0.1f);
    }

    private static void drawSandals(MatrixStack m, VertexConsumer vc, int light, boolean isRightLeg) {
        float x = isRightLeg ? -0.1f : -0.1f;
        cuboid(m, vc, light, x - 0.12f, 0.4f, -0.15f, 0.24f, 0.2f, 0.3f, 0.15f, 0.15f, 0.15f);
        cuboid(m, vc, light, x - 0.1f, 0.45f, 0.05f, 0.2f, 0.15f, 0.1f, 0.9f, 0.9f, 0.9f);
    }

    private static void drawHood(MatrixStack m, VertexConsumer vc, int light) {
        cuboid(m, vc, light, -0.26f, -0.26f, -0.26f, 0.52f, 0.52f, 0.52f, 0.1f, 0.1f, 0.1f);
    }

    private static void cuboid(MatrixStack matrices, VertexConsumer vc, int light,
                               float x, float y, float z, float w, float h, float d,
                               float r, float g, float b) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        face(vc, m, x, y, z2, x2, y, z2, x2, y2, z2, x, y2, z2, r, g, b, light);
        face(vc, m, x2, y, z, x, y, z, x, y2, z, x2, y2, z, r, g, b, light);
        face(vc, m, x, y, z, x, y, z2, x, y2, z2, x, y2, z, r, g, b, light);
        face(vc, m, x2, y, z2, x2, y, z, x2, y2, z, x2, y2, z2, r, g, b, light);
        face(vc, m, x, y2, z2, x2, y2, z2, x2, y2, z, x, y2, z, r, g, b, light);
        face(vc, m, x, y, z, x2, y, z, x2, y, z2, x, y, z2, r, g, b, light);
    }

    private static void face(VertexConsumer vc, Matrix4f m,
                             float x1, float y1, float z1, float x2, float y2, float z2,
                             float x3, float y3, float z3, float x4, float y4, float z4,
                             float r, float g, float b, int light) {
        v(vc, m, x1, y1, z1, r, g, b, light); v(vc, m, x2, y2, z2, r, g, b, light);
        v(vc, m, x3, y3, z3, r, g, b, light); v(vc, m, x4, y4, z4, r, g, b, light);
        v(vc, m, x4, y4, z4, r, g, b, light); v(vc, m, x3, y3, z3, r, g, b, light);
        v(vc, m, x2, y2, z2, r, g, b, light); v(vc, m, x1, y1, z1, r, g, b, light);
    }

    private static void v(VertexConsumer vc, Matrix4f m, float x, float y, float z,
                          float r, float g, float b, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
          .overlay(net.minecraft.client.render.OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
}
'@

# 5. BackKatanaRenderer.java
Write-File "$base\client\render\BackKatanaRenderer.java" @'
package com.example.shinobicore.client.render;

import com.example.shinobicore.item.KatanaItem;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.feature.FeatureRenderer;
import net.minecraft.client.render.entity.feature.FeatureRendererContext;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class BackKatanaRenderer extends FeatureRenderer<PlayerEntity, PlayerEntityModel<PlayerEntity>> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public BackKatanaRenderer(FeatureRendererContext<PlayerEntity, PlayerEntityModel<PlayerEntity>> context) {
        super(context);
    }

    @Override
    public void render(MatrixStack matrices, VertexConsumerProvider vertices, int light, PlayerEntity entity, 
                       float limbAngle, float limbDistance, float tickDelta, float animationProgress, float headYaw, float headPitch) {
        
        ItemStack sheathedKatana = findSheathedKatana(entity);
        if (sheatheKatana == null) return;

        matrices.push();
        this.getContextModel().body.rotate(matrices);
        
        matrices.translate(0.15f, 0.1f, 0.25f);
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(35f));
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(180f));

        VertexConsumer vc = vertices.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        
        cuboid(matrices, vc, light, -0.04f, -0.6f, -0.04f, 0.08f, 0.8f, 0.08f, 0.25f, 0.15f, 0.10f);
        cuboid(matrices, vc, light, -0.03f, 0.2f, -0.03f, 0.06f, 0.25f, 0.06f, 0.70f, 0.15f, 0.10f);
        cuboid(matrices, vc, light, -0.06f, 0.18f, -0.06f, 0.12f, 0.02f, 0.12f, 0.60f, 0.45f, 0.15f);

        matrices.pop();
    }

    private ItemStack findSheathedKatana(PlayerEntity player) {
        for (int i = 0; i < player.getInventory().size(); i++) {
            ItemStack stack = player.getInventory().getStack(i);
            if (stack.getItem() instanceof KatanaItem) {
                NbtCompound nbt = stack.getNbt();
                if (nbt != null && nbt.getBoolean("Sheathed")) {
                    return stack;
                }
            }
        }
        return null;
    }

    private static void cuboid(MatrixStack matrices, VertexConsumer vc, int light,
                               float x, float y, float z, float w, float h, float d,
                               float r, float g, float b) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        face(vc, m, x, y, z2, x2, y, z2, x2, y2, z2, x, y2, z2, r, g, b, light);
        face(vc, m, x2, y, z, x, y, z, x, y2, z, x2, y2, z, r, g, b, light);
        face(vc, m, x, y, z, x, y, z2, x, y2, z2, x, y2, z, r, g, b, light);
        face(vc, m, x2, y, z2, x2, y, z, x2, y2, z, x2, y2, z2, r, g, b, light);
        face(vc, m, x, y2, z2, x2, y2, z2, x2, y2, z, x, y2, z, r, g, b, light);
        face(vc, m, x, y, z, x2, y, z, x2, y, z2, x, y, z2, r, g, b, light);
    }

    private static void face(VertexConsumer vc, Matrix4f m,
                             float x1, float y1, float z1, float x2, float y2, float z2,
                             float x3, float y3, float z3, float x4, float y4, float z4,
                             float r, float g, float b, int light) {
        v(vc, m, x1, y1, z1, r, g, b, light); v(vc, m, x2, y2, z2, r, g, b, light);
        v(vc, m, x3, y3, z3, r, g, b, light); v(vc, m, x4, y4, z4, r, g, b, light);
        v(vc, m, x4, y4, z4, r, g, b, light); v(vc, m, x3, y3, z3, r, g, b, light);
        v(vc, m, x2, y2, z2, r, g, b, light); v(vc, m, x1, y1, z1, r, g, b, light);
    }

    private static void v(VertexConsumer vc, Matrix4f m, float x, float y, float z,
                          float r, float g, float b, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
          .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
}
'@

# 6. Patch KeyBindings.java
Patch-File "$base\client\KeyBindings.java" `
"public static KeyBinding TOGGLE_SENSORY;" `
"public static KeyBinding TOGGLE_SENSORY;`n    public static KeyBinding TOGGLE_SCABBARD;"

Patch-File "$base\client\KeyBindings.java" `
"TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.toggle_sensory"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));" `
"TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.toggle_sensory"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));`n        TOGGLE_SCABBARD = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n            ""key.shinobicore.toggle_scabbard"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_O, CATEGORY));"

# 7. Patch ClientInputHandler.java
Patch-File "$base\client\ClientInputHandler.java" `
"if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info(""[INPUT] CRAWL (N) pressed"");" `
"if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info(""[INPUT] CRAWL (N) pressed"");`n`n        if (KeyBindings.TOGGLE_SCABBARD.wasPressed()) {`n            net.minecraft.item.ItemStack mainHand = client.player.getMainHandStack();`n            if (mainHand.getItem() instanceof com.example.shinobicore.item.KatanaItem) {`n                net.minecraft.nbt.NbtCompound nbt = mainHand.getOrCreateNbt();`n                boolean isSheathed = nbt.getBoolean(""Sheathed"");`n                nbt.putBoolean(""Sheathed"", !isSheathed);`n                client.player.sendMessage(net.minecraft.text.Text.literal(!isSheathed ? ""\u00a7aКатана убрана в ножны на спине"" : ""\u00a7cКатана снята со спины""), true);`n            }`n        }"

# 8. Patch ShinobiCoreClient.java
Patch-File "$base\client\ShinobiCoreClient.java" `
"import com.example.shinobicore.client.combat.HitStopManager;" `
"import com.example.shinobicore.client.combat.HitStopManager;`nimport com.example.shinobicore.client.render.NarutoArmorRenderer;`nimport com.example.shinobicore.client.render.BackKatanaRenderer;`nimport net.fabricmc.fabric.api.client.rendering.v1.LivingEntityFeatureRendererRegistrationCallback;`nimport net.minecraft.entity.EntityType;`nimport net.minecraft.client.render.entity.model.PlayerEntityModel;"

Patch-File "$base\client\ShinobiCoreClient.java" `
"HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);" `
"HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);`n`n        NarutoArmorRenderer.register();`n`n        LivingEntityFeatureRendererRegistrationCallback.EVENT.register((entityType, entityModel, registrationHelper, context) -> {`n            if (entityType == EntityType.PLAYER) {`n                registrationHelper.register(new BackKatanaRenderer((PlayerEntityModel) entityModel));`n            }`n        });"

# 9. JSON Recipes
$recipeDir = "$res\recipes"
if (-not (Test-Path $recipeDir)) { New-Item -ItemType Directory -Path $recipeDir -Force | Out-Null }

Write-File "$recipeDir\katana_iron.json" @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["  I", " I ", "SL "],
  "key": {
    "I": { "item": "minecraft:iron_ingot" },
    "S": { "item": "minecraft:stick" },
    "L": { "item": "minecraft:leather" }
  },
  "result": { "item": "shinobicore:katana_iron", "count": 1 }
}
'@

Write-File "$recipeDir\katana_diamond.json" @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["  D", " D ", "SL "],
  "key": {
    "D": { "item": "minecraft:diamond" },
    "S": { "item": "minecraft:stick" },
    "L": { "item": "minecraft:leather" }
  },
  "result": { "item": "shinobicore:katana_diamond", "count": 1 }
}
'@

Write-File "$recipeDir\katana_netherite.json" @'
{
  "type": "minecraft:smithing_transform",
  "template": { "item": "minecraft:netherite_upgrade_smithing_template" },
  "base": { "item": "shinobicore:katana_diamond" },
  "addition": { "item": "minecraft:netherite_ingot" },
  "result": { "item": "shinobicore:katana_netherite" }
}
'@

Write-File "$recipeDir\flak_vest.json" @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": [
    "WBW",
    "WIW",
    "WBW"
  ],
  "key": {
    "W": { "item": "minecraft:green_wool" },
    "B": { "item": "minecraft:black_wool" },
    "I": { "item": "minecraft:iron_ingot" }
  },
  "result": { "item": "shinobicore:flak_vest", "count": 1 }
}
'@

Write-File "$recipeDir\ninja_pants.json" @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["BBB", "BIB", "B B"],
  "key": { "B": { "item": "minecraft:black_wool" }, "I": { "item": "minecraft:iron_ingot" } },
  "result": { "item": "shinobicore:ninja_pants", "count": 1 }
}
'@

Write-File "$recipeDir\ninja_sandals.json" @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["I I", "B B"],
  "key": { "B": { "item": "minecraft:black_wool" }, "I": { "item": "minecraft:iron_ingot" } },
  "result": { "item": "shinobicore:ninja_sandals", "count": 1 }
}
'@

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  UPDATE APPLIED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Build the project: .\gradlew.bat build" -ForegroundColor White
Write-Host "  2. Run the game: .\gradlew.bat runClient" -ForegroundColor White
Write-Host "  3. Give yourself items: /give @s shinobicore:katana_iron" -ForegroundColor White
Write-Host "  4. Toggle scabbard: Hold katana and press 'O'" -ForegroundColor White