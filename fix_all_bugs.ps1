$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
Write-Host "=== FIX ALL BUGS ===" -ForegroundColor Cyan

# === [1] KeyBindings: переписываем полностью с правильными полями ===
$file = "$src\client\KeyBindings.java"
$code = @'
package com.example.shinobicore.client;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;
public class KeyBindings {
    public static final String CATEGORY = "key.categories.shinobicore";
    public static final String COMBAT_CATEGORY = "key.categories.shinobicore.combat";
    public static KeyBinding MEDITATE;
    public static KeyBinding CAST_A;
    public static KeyBinding CAST_B;
    public static KeyBinding CYCLE_A;
    public static KeyBinding CYCLE_B;
    public static KeyBinding PROGRESSION;
    public static KeyBinding CHAKRA_MODE;
    public static KeyBinding DODGE_LEFT;
    public static KeyBinding DODGE_RIGHT;
    public static KeyBinding CRAWL;
    public static KeyBinding KICK;
    public static KeyBinding SWITCH_STYLE;
    public static KeyBinding SWITCH_STANCE;
    public static KeyBinding KATANA_DEFLECT;
    public static void register() {
        MEDITATE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.meditate", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, CATEGORY));
        PROGRESSION = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.progression", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_K, CATEGORY));
        CHAKRA_MODE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.chakra_mode", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_L, CATEGORY));
        CAST_A = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cast", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_R, CATEGORY));
        CAST_B = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cast_b", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_T, CATEGORY));
        CYCLE_A = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cycle_slot", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_G, CATEGORY));
        CYCLE_B = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cycle_b", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_H, CATEGORY));
        DODGE_LEFT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.dodge_left", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Z, CATEGORY));
        DODGE_RIGHT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.dodge_right", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_C, CATEGORY));
        CRAWL = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.crawl", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_N, CATEGORY));
        KICK = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.kick", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_V, COMBAT_CATEGORY));
        SWITCH_STYLE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.switch_style", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, COMBAT_CATEGORY));
        SWITCH_STANCE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.switch_stance", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_F, COMBAT_CATEGORY));
        KATANA_DEFLECT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.katana_deflect", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_X, COMBAT_CATEGORY));
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[OK] KeyBindings.java rewritten" -ForegroundColor Green

# === [2] IdlePoseSystem: переписываем — заменяем += на = ===
$file = "$src\client\IdlePoseSystem.java"
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
        m.head.pitch = 0.25f; m.body.pitch = 0.12f;
        m.rightLeg.yaw = 0.5f; m.leftLeg.yaw = -0.5f;
        m.rightLeg.pitch = -1.1f; m.leftLeg.pitch = -1.1f;
    }
    private static void applyWallStick(BipedEntityModel<?> m) {
        m.rightArm.pitch = -1.5f; m.leftArm.pitch = -1.5f;
        m.rightArm.yaw = -0.15f; m.leftArm.yaw = 0.15f;
        m.head.pitch = -0.1f;
    }
    private static void applyWeaponStance(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -1.15f + breath; m.rightArm.yaw = -0.25f;
        m.leftArm.pitch = -0.75f + breath; m.leftArm.yaw = 0.45f;
        m.body.pitch = 0.10f;
        m.rightLeg.yaw = -0.25f; m.leftLeg.yaw = 0.25f;
        m.head.pitch = -0.08f;
    }
    private static void applyNinjaGuard(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -0.95f + breath; m.rightArm.yaw = -0.40f;
        m.leftArm.pitch = -0.70f + breath; m.leftArm.yaw = 0.50f;
        m.body.pitch = 0.12f;
        m.rightLeg.yaw = -0.22f; m.leftLeg.yaw = 0.22f;
        m.rightLeg.pitch = 0.08f; m.leftLeg.pitch = 0.08f;
        m.head.pitch = -0.10f;
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
        m.body.pitch = 0.08f;
        m.rightLeg.yaw = -0.2f; m.leftLeg.yaw = 0.2f;
        m.head.pitch = -0.06f;
    }
    private static void applyNormalIdle(BipedEntityModel<?> m, float breath, AbstractClientPlayerEntity player) {
        m.body.pitch = breath * 0.6f;
        m.rightArm.pitch = breath; m.leftArm.pitch = breath;
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
                    case 0 -> m.head.yaw = f * 0.6f;
                    case 1 -> { m.body.roll = f * 0.06f; m.rightLeg.yaw = -f * 0.15f; m.leftLeg.yaw = f * 0.15f; }
                    case 2 -> { m.rightArm.pitch = -1.6f * f; m.rightArm.yaw = -0.5f * f; }
                }
            }
        } else if (now >= st.nextFidgetAt) {
            st.fidget = (int)(Math.random() * 3);
            st.fidgetStart = now;
        }
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[OK] IdlePoseSystem.java rewritten (+= -> =)" -ForegroundColor Green

# === [3] CastingClientVisual: цветные частицы по стихии ===
$file = "$src\client\CastingClientVisual.java"
$code = @'
package com.example.shinobicore.client;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;
public class CastingClientVisual {
    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(CastingClientVisual::tick);
    }
    private static void tick(MinecraftClient client) {
        if (client.world == null) return;
        for (AbstractClientPlayerEntity p : client.world.getPlayers()) {
            CastingClientState.Cast c = CastingClientState.get(p);
            if (c == null) continue;
            int color = CastingClientState.color(c.nature);
            float r = ((color >> 16) & 0xFF) / 255f;
            float g = ((color >> 8) & 0xFF) / 255f;
            float b = (color & 0xFF) / 255f;
            DustParticleEffect effect = new DustParticleEffect(new Vector3f(r, g, b), 1.0f);
            Vec3d hand = handPos(p);
            for (int i = 0; i < 3; i++) {
                client.world.addParticle(effect,
                    hand.x + (Math.random() - 0.5) * 0.3,
                    hand.y + (Math.random() - 0.5) * 0.3,
                    hand.z + (Math.random() - 0.5) * 0.3,
                    0, 0.03, 0);
            }
        }
    }
    private static Vec3d handPos(AbstractClientPlayerEntity p) {
        Vec3d look = p.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        return p.getEyePos().add(look.multiply(0.6)).add(right.multiply(0.3)).add(0, -0.35, 0);
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[OK] CastingClientVisual.java rewritten (color particles)" -ForegroundColor Green

# === [4] ClientInputHandler: переписываем с F/X для катаны ===
$file = "$src\client\ClientInputHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

# 4a. Убираем старый блок KICK (заменяем на новый с ветвлением)
$marker = @'
        // === УДАР НОГОЙ (V) ===
        if (KeyBindings.KICK.wasPressed()) {
            boolean handEmpty = client.player.getMainHandStack().isEmpty();
            ShinobiCore.LOGGER.info("[INPUT] KICK (V) pressed, handEmpty={}", handEmpty);
            if (handEmpty) {
                TaijutsuKickHandler.tryKick(client.player);
            }
        }
'@.Replace("`r`n", "`n")
$insert = @'
        // === УДАР НОГОЙ (V) / ДЕФЛЕКТ КАТАНЫ (X) ===
        if (KeyBindings.KICK.wasPressed()) {
            boolean handEmpty = client.player.getMainHandStack().isEmpty();
            boolean hasKatana = client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
            ShinobiCore.LOGGER.info("[INPUT] KICK (V) pressed, handEmpty={}, hasKatana={}", handEmpty, hasKatana);
            if (handEmpty) {
                TaijutsuKickHandler.tryKick(client.player);
            } else if (hasKatana) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.tryDeflect(client.player);
            }
        }
        if (KeyBindings.KATANA_DEFLECT.wasPressed()
                && client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            com.example.shinobicore.client.combat.KenjutsuClientHandler.tryDeflect(client.player);
        }
'@.Replace("`r`n", "`n")
$c = $c.Replace($marker, $insert)

# 4b. Переключение стиля/стойки (B/F)
$marker2 = @'
        // === НОВОЕ: ПЕРЕКЛЮЧЕНИЕ СТИЛЯ (B) ===
        if (KeyBindings.SWITCH_STYLE.wasPressed()) {
            TaijutsuStyle currentStyle = TaijutsuClientHandler.getCurrentStyle();
            TaijutsuStyle newStyle;
'@.Replace("`r`n", "`n")
$insert2 = @'
        // === ПЕРЕКЛЮЧЕНИЕ СТОЙКИ КАТАНЫ (F) ===
        if (KeyBindings.SWITCH_STANCE.wasPressed()
                && client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            com.example.shinobicore.client.combat.KenjutsuClientHandler.cycleStance(client.player);
        }

        // === НОВОЕ: ПЕРЕКЛЮЧЕНИЕ СТИЛЯ (B) ===
        if (KeyBindings.SWITCH_STYLE.wasPressed()) {
            TaijutsuStyle currentStyle = TaijutsuClientHandler.getCurrentStyle();
            TaijutsuStyle newStyle;
'@.Replace("`r`n", "`n")
$c = $c.Replace($marker2, $insert2)

[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] ClientInputHandler: V/X/F handling" -ForegroundColor Green

Write-Host "`n=== BUILD ===" -ForegroundColor Cyan
& "E:\Games\mod\gradlew.bat" build
Write-Host "`n=== DONE ===" -ForegroundColor Cyan
Write-Host "Test:" -ForegroundColor Yellow
Write-Host "  F with katana -> cycle stance (HUD: AGGRESSIVE/SEIGAN/IAI)" -ForegroundColor White
Write-Host "  X in Seigan -> DEFLECTED!" -ForegroundColor White
Write-Host "  R/T cast -> colored particles (not red!)" -ForegroundColor White
Write-Host "  Idle with katana -> proper stance pose, no zombie" -ForegroundColor White