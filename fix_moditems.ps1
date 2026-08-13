$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"

# Проверяем существование файлов сюрикенов
$throwingWeaponExists = Test-Path "$src\item\ThrowingWeaponItem.java"
$shurikenEntityExists = Test-Path "$src\entity\ShurikenEntity.java"
$shurikenRendererExists = Test-Path "$src\entity\ShurikenRenderer.java"

Write-Host "=== CHECKING SHURIKEN FILES ===" -ForegroundColor Cyan
Write-Host "ThrowingWeaponItem.java: $throwingWeaponExists"
Write-Host "ShurikenEntity.java: $shurikenEntityExists"
Write-Host "ShurikenRenderer.java: $shurikenRendererExists"

if ($throwingWeaponExists -and $shurikenEntityExists) {
    # Все файлы есть — добавляем регистрацию в ModItems
    Write-Host "Adding SHURIKEN/KUNAI to ModItems.java" -ForegroundColor Green
    
    $modItemsCode = @'
package com.example.shinobicore.item;
import com.example.shinobicore.ShinobiCore;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;
public class ModItems {
    public static final Item KATANA = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana"), new KatanaItem());
    public static final Item SHURIKEN = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "shuriken"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 3f, 3.0f, 8));
    public static final Item KUNAI = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "kunai"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 5f, 2.2f, 12));
    public static void register() {
        ShinobiCore.LOGGER.info("Registered katana/shuriken/kunai items");
    }
}
'@
    [System.IO.File]::WriteAllText("$src\item\ModItems.java", $modItemsCode, $utf8)
    Write-Host "[OK] ModItems.java updated with SHURIKEN/KUNAI" -ForegroundColor Green
} else {
    # Файлов нет — переписываем IdlePoseSystem без упоминания ModItems.SHURIKEN/KUNAI
    Write-Host "Shuriken files missing — rewriting IdlePoseSystem.java" -ForegroundColor Yellow
    
    $idlePoseCode = @'
package com.example.shinobicore.client;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.item.ItemStack;
import net.minecraft.item.SwordItem;
import net.minecraft.util.math.MathHelper;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
public class IdlePoseSystem {
    private static final Map<UUID, FidgetState> STATES = new HashMap<>();
    private static class FidgetState {
        long nextFidgetAt = 0; int fidget = -1; long fidgetStart = 0;
    }
    public static void apply(AbstractClientPlayerEntity player, BipedEntityModel<?> model,
                             float moveAmount, float animProgress) {
        if (moveAmount > 0.1f) return;
        float breath = MathHelper.sin(animProgress * 0.07f) * 0.03f;
        if (ClientNinjaState.meditating) { applyMeditate(model, breath); return; }
        if (ChakraPhysicsClient.stickingToWall) { applyWallStick(model); return; }
        ItemStack main = player.getMainHandStack();
        if (main.getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            applyKatanaStance(model, breath);
            return;
        }
        // === БЕЗ UPOMINANIYA SHURIKEN/KUNAI — используем проверку по имени ===
        boolean isThrowingWeapon = main.getItem() != null && 
                main.getItem().toString().toLowerCase().contains("shuriken");
        boolean weapon = !main.isEmpty() && (main.getItem() instanceof SwordItem || isThrowingWeapon);
        boolean chakra = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        if (weapon) applyWeaponStance(model, breath);
        else if (chakra) applyNinjaGuard(model, breath);
        else applyNormalIdle(model, breath, player);
    }
    private static void applyMeditate(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -0.9f + breath; m.leftArm.pitch = -0.9f + breath;
        m.rightArm.yaw = -0.5f; m.leftArm.yaw = 0.5f;
        m.head.pitch += 0.25f; m.body.pitch += 0.12f;
        m.rightLeg.yaw = 0.5f; m.leftLeg.yaw = -0.5f;
        m.rightLeg.pitch = -1.1f; m.leftLeg.pitch = -1.1f;
    }
    private static void applyWallStick(BipedEntityModel<?> m) {
        m.rightArm.pitch = -1.5f; m.leftArm.pitch = -1.5f;
        m.rightArm.yaw = -0.15f; m.leftArm.yaw = 0.15f;
        m.head.pitch -= 0.1f;
    }
    private static void applyWeaponStance(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -1.15f + breath; m.rightArm.yaw = -0.25f;
        m.leftArm.pitch = -0.75f + breath; m.leftArm.yaw = 0.45f;
        m.body.pitch += 0.10f;
        m.rightLeg.yaw = -0.25f; m.leftLeg.yaw = 0.25f;
        m.head.pitch -= 0.08f;
    }
    private static void applyNinjaGuard(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -0.95f + breath; m.rightArm.yaw = -0.40f;
        m.leftArm.pitch = -0.70f + breath; m.leftArm.yaw = 0.50f;
        m.body.pitch += 0.12f;
        m.rightLeg.yaw = -0.22f; m.leftLeg.yaw = 0.22f;
        m.rightLeg.pitch += 0.08f; m.leftLeg.pitch += 0.08f;
        m.head.pitch -= 0.10f;
    }
    private static void applyKatanaStance(BipedEntityModel<?> m, float breath) {
        String st = ClientNinjaState.kenjutsuStance;
        switch (st) {
            case "seigan" -> {
                m.rightArm.pitch = -1.2f + breath; m.rightArm.yaw = -0.2f;
                m.leftArm.pitch = -0.7f + breath; m.leftArm.yaw = 0.3f;
            }
            case "iai" -> {
                m.rightArm.pitch = 0.15f + breath; m.rightArm.yaw = -0.5f;
                m.leftArm.pitch = -0.9f + breath; m.leftArm.yaw = 0.6f;
            }
            default -> {
                m.rightArm.pitch = -1.1f + breath; m.rightArm.yaw = -0.3f;
                m.leftArm.pitch = -1.0f + breath; m.leftArm.yaw = 0.2f;
            }
        }
        m.body.pitch += 0.08f;
        m.rightLeg.yaw = -0.2f; m.leftLeg.yaw = 0.2f;
        m.head.pitch -= 0.06f;
    }
    private static void applyNormalIdle(BipedEntityModel<?> m, float breath, AbstractClientPlayerEntity player) {
        m.body.pitch += breath * 0.6f;
        m.rightArm.pitch += breath; m.leftArm.pitch += breath;
        FidgetState st = STATES.computeIfAbsent(player.getUuid(), u -> new FidgetState());
        long now = System.currentTimeMillis();
        if (st.fidget >= 0) {
            float p = (now - st.fidgetStart) / 2500f;
            if (p >= 1f) {
                st.fidget = -1;
                st.nextFidgetAt = now + 5000 + (long)(Math.random() * 7000);
            } else {
                float f = MathHelper.sin(p * (float) Math.PI);
                switch (st.fidget) {
                    case 0 -> m.head.yaw += f * 0.6f;
                    case 1 -> { m.body.roll += f * 0.06f; m.rightLeg.yaw -= f * 0.15f; m.leftLeg.yaw += f * 0.15f; }
                    case 2 -> { m.rightArm.pitch += f * -1.6f; m.rightArm.yaw += f * -0.5f; }
                }
            }
        } else if (now >= st.nextFidgetAt) {
            st.fidget = (int)(Math.random() * 3);
            st.fidgetStart = now;
        }
    }
}
'@
    [System.IO.File]::WriteAllText("$src\client\IdlePoseSystem.java", $idlePoseCode, $utf8)
    Write-Host "[OK] IdlePoseSystem.java rewritten (no SHURIKEN/KUNAI references)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== BUILDING ===" -ForegroundColor Cyan
& "E:\Games\mod\gradlew.bat" build 2>&1 | Select-Object -Last 30