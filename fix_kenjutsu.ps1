$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"

# === [1] IdlePoseSystem.java (полностью переписан) ===
$code = @'
package com.example.shinobicore.client;
import com.example.shinobicore.item.ModItems;
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
        boolean weapon = !main.isEmpty() && (main.getItem() instanceof SwordItem
                || main.getItem() == ModItems.SHURIKEN || main.getItem() == ModItems.KUNAI);
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
[System.IO.File]::WriteAllText("$src\client\IdlePoseSystem.java", $code, $utf8)
Write-Host "[OK] IdlePoseSystem.java rewritten" -ForegroundColor Green

# === [2] KeyBindings.java: новые клавиши F и X для катаны ===
$file = "$src\client\KeyBindings.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("SWITCH_STANCE")) {
    $c = $c.Replace("public static KeyBinding SWITCH_STYLE; // === НОВОЕ ===",
        "public static KeyBinding SWITCH_STYLE; // === НОВОЕ ===
    public static KeyBinding SWITCH_STANCE;
    public static KeyBinding KATANA_DEFLECT;")
    $c = $c.Replace('"key.shinobicore.switch_style", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, COMBAT_CATEGORY));',
        '"key.shinobicore.switch_style", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, COMBAT_CATEGORY));
        SWITCH_STANCE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.switch_stance", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_F, COMBAT_CATEGORY));
        KATANA_DEFLECT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.katana_deflect", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_X, COMBAT_CATEGORY));')
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] KeyBindings: added SWITCH_STANCE (F) and KATANA_DEFLECT (X)" -ForegroundColor Green
}

# === [3] ClientInputHandler.java: заменить V/B на X/F ===
$file = "$src\client\ClientInputHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if ($c.Contains("KeyBindings.KICK.wasPressed()")) {
    $c = $c.Replace(
        "KeyBindings.KICK.wasPressed()
            } else if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.tryDeflect(client.player);
            }",
        "KeyBindings.KICK.wasPressed()) {
                TaijutsuKickHandler.tryKick(client.player);
            } else if (KeyBindings.KATANA_DEFLECT.wasPressed()
                    && client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.tryDeflect(client.player);
            }")
    $c = $c.Replace(
        "if (KeyBindings.SWITCH_STYLE.wasPressed()) {
            if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.cycleStance(client.player);
                return;
            }",
        "if (KeyBindings.SWITCH_STANCE.wasPressed()
                && client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            com.example.shinobicore.client.combat.KenjutsuClientHandler.cycleStance(client.player);
        }
        if (KeyBindings.SWITCH_STYLE.wasPressed()) {")
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] ClientInputHandler: katana on F/X" -ForegroundColor Green
}

# === [4] en_us.json: новые переводы ===
$file = "E:\Games\mod\src\main\resources\assets\shinobicore\lang\en_us.json"
$j = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $j.Contains("switch_stance")) {
    $j = $j.Replace('"key.shinobicore.toggle_sensory": "Toggle Sensory",',
        '"key.shinobicore.toggle_sensory": "Toggle Sensory",
  "key.shinobicore.switch_stance": "Switch Katana Stance (F)",
  "key.shinobicore.katana_deflect": "Katana Deflect (X)",')
    [System.IO.File]::WriteAllText($file, $j, $utf8)
    Write-Host "[OK] en_us.json: added key translations" -ForegroundColor Green
}

Write-Host "`nRun: .\gradlew.bat build" -ForegroundColor Cyan