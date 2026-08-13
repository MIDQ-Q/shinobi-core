$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
$res = "E:\Games\mod\src\main\resources"

function WriteFile($path, $content) {
    $dir = Split-Path $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("[NEW] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

function PatchFile($path, $marker, $insert, $name, $sentinel) {
    if (-not (Test-Path $path)) { Write-Host ("[SKIP] " + $name + " (no file)") -ForegroundColor Red; return }
    $c = [System.IO.File]::ReadAllText($path, $utf8)
    $cn = $c.Replace("`r`n", "`n")
    if ($sentinel -ne "" -and $cn.Contains($sentinel)) { Write-Host ("[OK] " + $name + " (already)") -ForegroundColor Gray; return }
    $mn = $marker.Replace("`r`n", "`n")
    if ($cn.Contains($mn)) {
        $cn = $cn.Replace($mn, $insert.Replace("`r`n", "`n"))
        [System.IO.File]::WriteAllText($path, $cn, $utf8)
        Write-Host ("[OK] " + $name) -ForegroundColor Green
    } else {
        Write-Host ("[SKIP] " + $name + " (marker not found)") -ForegroundColor Yellow
    }
}

Write-Host "=== KATANA APPLY (fixed syntax) ===" -ForegroundColor Cyan

# ============ 1. KatanaItem ============
$f = @'
package com.example.shinobicore.item;
import net.minecraft.item.Item;
import net.minecraft.item.SwordItem;
import net.minecraft.item.ToolMaterials;
public class KatanaItem extends SwordItem {
    public KatanaItem() {
        super(ToolMaterials.IRON, 4, -2.0f, new Item.Settings().maxCount(1));
    }
}
'@
WriteFile "$src\item\KatanaItem.java" $f

# ============ 2. KenjutsuStance ============
$f = @'
package com.example.shinobicore.combat;
public enum KenjutsuStance {
    AGGRESSIVE("aggressive", 1.15f, 1.15f, true, 1.0f),
    SEIGAN("seigan", 0.85f, 1.0f, true, 0.5f),
    IAI("iai", 1.0f, 0.9f, false, 1.0f);
    private final String id;
    private final float damageMult;
    private final float speedMult;
    private final boolean canDeflect;
    private final float shieldSlow;
    KenjutsuStance(String id, float damageMult, float speedMult, boolean canDeflect, float shieldSlow) {
        this.id = id; this.damageMult = damageMult; this.speedMult = speedMult;
        this.canDeflect = canDeflect; this.shieldSlow = shieldSlow;
    }
    public String getId() { return id; }
    public float getDamageMult() { return damageMult; }
    public float getSpeedMult() { return speedMult; }
    public boolean canDeflect() { return canDeflect; }
    public float getShieldSlow() { return shieldSlow; }
    public static KenjutsuStance fromId(String id) {
        for (KenjutsuStance s : values()) if (s.id.equals(id)) return s;
        return AGGRESSIVE;
    }
}
'@
WriteFile "$src\combat\KenjutsuStance.java" $f

# ============ 3. KenjutsuFormulas ============
$f = @'
package com.example.shinobicore.combat;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;
public class KenjutsuFormulas {
    private static final float[] STEP_MULT = {1.0f, 1.0f, 1.2f, 1.8f};
    private static final float[] STEP_KB = {0.3f, 0.3f, 0.4f, 1.2f};
    public static float baseDamage(int taiLevel) { return 6.0f + taiLevel * 0.35f; }
    public static float computeDamage(int taiLevel, KenjutsuStance stance, boolean chakraMode, int step, boolean exhausted) {
        float d = baseDamage(taiLevel) * STEP_MULT[Math.max(0, Math.min(3, step))] * stance.getDamageMult();
        if (chakraMode) d *= 1.2f;
        if (exhausted) d *= 0.5f;
        return d;
    }
    public static long cooldownMs(KenjutsuStance stance) {
        return Math.max(200, (long)(450 / stance.getSpeedMult()));
    }
    public static float getKnockback(int step) { return STEP_KB[Math.max(0, Math.min(3, step))]; }
    public static List<LivingEntity> findTargetsInCone(ServerWorld world, LivingEntity attacker, Vec3d look, double range, double angleDeg) {
        List<LivingEntity> out = new ArrayList<>();
        Vec3d dir = look.normalize();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class, attacker.getBoundingBox().expand(range + 1),
                t -> t != attacker && t.isAlive())) {
            Vec3d to = e.getPos().add(0, e.getHeight() / 2.0, 0).subtract(attacker.getPos().add(0, attacker.getEyeHeight(attacker.getPose()), 0));
            if (to.length() > range) continue;
            double dot = dir.dotProduct(to.normalize());
            if (Math.toDegrees(Math.acos(Math.max(-1, Math.min(1, dot)))) <= angleDeg / 2) out.add(e);
        }
        return out;
    }
    public static List<LivingEntity> findInRadius(ServerWorld world, LivingEntity attacker, double range) {
        List<LivingEntity> out = new ArrayList<>();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class, attacker.getBoundingBox().expand(range),
                t -> t != attacker && t.isAlive())) {
            if (e.getPos().distanceTo(attacker.getPos()) <= range) out.add(e);
        }
        return out;
    }
}
'@
WriteFile "$src\combat\KenjutsuFormulas.java" $f

# ============ 4. KenjutsuAnimations ============
$f = @'
package com.example.shinobicore.client.combat;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
public class KenjutsuAnimations {
    private static final Map<UUID, SlashState> SLASHES = new HashMap<>();
    private static final Map<UUID, Long> DEFLECTS = new HashMap<>();
    public static class SlashState {
        public final int step; public final long start;
        public SlashState(int step) { this.step = step; this.start = System.currentTimeMillis(); }
        public float getProgress() { return Math.min(1f, (System.currentTimeMillis() - start) / duration(step)); }
        public boolean isFinished() { return System.currentTimeMillis() - start >= duration(step); }
        private float duration(int s) { return switch (s) { case 0, 1 -> 260f; case 2 -> 340f; default -> 520f; }; }
    }
    public static void playSlash(AbstractClientPlayerEntity p, int step) { SLASHES.put(p.getUuid(), new SlashState(step)); }
    public static void playDeflect(AbstractClientPlayerEntity p) { DEFLECTS.put(p.getUuid(), System.currentTimeMillis() + 300); }
    public static boolean isDeflecting(AbstractClientPlayerEntity p) {
        Long t = DEFLECTS.get(p.getUuid());
        if (t == null) return false;
        if (System.currentTimeMillis() >= t) { DEFLECTS.remove(p.getUuid()); return false; }
        return true;
    }
    private static SlashState get(AbstractClientPlayerEntity p) {
        SlashState s = SLASHES.get(p.getUuid());
        if (s != null && s.isFinished()) { SLASHES.remove(p.getUuid()); return null; }
        return s;
    }
    public static boolean isAttacking(AbstractClientPlayerEntity p) { return get(p) != null; }
    private static float curve(float p) {
        if (p < 0.3f) return (float) Math.sin(p / 0.3f * Math.PI / 2);
        if (p < 0.5f) return 1.0f + 0.15f * (float) Math.sin((p - 0.3f) / 0.2f * Math.PI);
        return 1.0f - (float) Math.sin((p - 0.5f) / 0.5f * Math.PI / 2);
    }
    public static void applySlash(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head) {
        SlashState s = get(p); if (s == null) return;
        float c = curve(s.getProgress());
        switch (s.step) {
            case 0 -> { rArm.yaw = -1.9f + c * 3.2f; rArm.pitch = -0.85f; rArm.roll = 0.2f; body.yaw += c * 0.6f - 0.3f; lArm.yaw = 0.4f; lArm.pitch = -0.6f; }
            case 1 -> { rArm.yaw = 1.9f - c * 3.2f; rArm.pitch = -0.85f; rArm.roll = -0.2f; body.yaw -= c * 0.6f - 0.3f; lArm.yaw = -0.4f; lArm.pitch = -0.6f; }
            case 2 -> { rArm.pitch = 2.3f - c * 4.0f; rArm.yaw = -0.2f; body.pitch += c * 0.35f; lArm.pitch = -0.9f; lArm.yaw = 0.5f; }
            default -> { body.yaw += s.getProgress() * 6.283f; rArm.pitch = -1.5f; rArm.roll = 0.6f; lArm.pitch = -1.5f; lArm.yaw = -0.6f; head.pitch -= 0.1f; }
        }
    }
    public static void applyDeflect(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm) {
        rArm.pitch = -1.4f; rArm.yaw = -0.3f; lArm.pitch = -1.0f; lArm.yaw = 0.4f;
    }
}
'@
WriteFile "$src\client\combat\KenjutsuAnimations.java" $f

# ============ 5. KenjutsuClientHandler ============
$f = @'
package com.example.shinobicore.client.combat;
import com.example.shinobicore.client.CinematicCamera;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.item.KatanaItem;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.Hand;
import net.minecraft.util.math.Vec3d;
public class KenjutsuClientHandler {
    private static int comboStep = 0;
    private static long lastAttack = 0;
    private static long cooldownEnd = 0;
    private static final String[] ORDER = {"aggressive", "seigan", "iai"};
    public static boolean tryAttack(ClientPlayerEntity player) {
        if (!(player.getMainHandStack().getItem() instanceof KatanaItem)) return false;
        long now = System.currentTimeMillis();
        if (now < cooldownEnd) return false;
        if (now - lastAttack > 1500) comboStep = 0;
        String stance = ClientNinjaState.kenjutsuStance;
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(comboStep);
        buf.writeString(stance);
        ClientPlayNetworking.send(ModPackets.KATANA_ATTACK_ID, buf);
        KenjutsuAnimations.playSlash(player, comboStep);
        playSlashParticles(player, comboStep);
        TaijutsuSounds.playWhoosh();
        if (comboStep == 3) {
            TaijutsuSounds.playKickSound();
            CinematicCamera.addShake(0.12f);
        }
        player.swingHand(Hand.MAIN_HAND);
        long cd = stance.equals("aggressive") ? 350 : stance.equals("seigan") ? 450 : 500;
        cooldownEnd = now + cd;
        lastAttack = now;
        comboStep = (comboStep + 1) % 4;
        return true;
    }
    public static void setDeflectHeld(ClientPlayerEntity player, boolean held) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(held);
        ClientPlayNetworking.send(ModPackets.KATANA_DEFLECT_ID, buf);
        ClientNinjaState.deflectHeld = held;
        if (held) {
            KenjutsuAnimations.playDeflect(player);
            player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 0.4f, 1.5f);
        }
    }
    public static void cycleStance(ClientPlayerEntity player) {
        String cur = ClientNinjaState.kenjutsuStance;
        String next = ORDER[(java.util.Arrays.asList(ORDER).indexOf(cur) + 1) % ORDER.length];
        ClientNinjaState.kenjutsuStance = next;
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(next);
        ClientPlayNetworking.send(ModPackets.KATANA_STANCE_ID, buf);
        player.sendMessage(Text.literal("§aStance: " + next), false);
    }
    private static void playSlashParticles(ClientPlayerEntity player, int step) {
        MinecraftClient client = MinecraftClient.getInstance();
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        Vec3d pos = player.getPos().add(0, 1.2, 0);
        int count = step == 3 ? 24 : 12;
        for (int i = 0; i < count; i++) {
            float t = (i / (float) count) * 2f - 1f;
            Vec3d dir = look.add(right.multiply(step % 2 == 0 ? t : -t)).normalize();
            client.world.addParticle(step == 3 ? ParticleTypes.ENCHANT : ParticleTypes.SWEEP_ATTACK,
                    pos.x + dir.x * 1.5, pos.y + dir.y * 1.5 + t * 0.3, pos.z + dir.z * 1.5,
                    dir.x * 0.1, dir.y * 0.1, dir.z * 0.1);
        }
        if (step == 3) {
            for (int i = 0; i < 12; i++) {
                double a = (i / 12.0) * Math.PI * 2;
                client.world.addParticle(ParticleTypes.CRIT,
                        pos.x + Math.cos(a) * 1.8, pos.y, pos.z + Math.sin(a) * 1.8, 0, 0.1, 0);
            }
        }
    }
}
'@
WriteFile "$src\client\combat\KenjutsuClientHandler.java" $f

# ============ 6. ModItems ============
$f = @'
package com.example.shinobicore.item;
import com.example.shinobicore.ShinobiCore;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;
public class ModItems {
    public static final Item KATANA = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana"), new KatanaItem());
    public static void register() {
        ShinobiCore.LOGGER.info("Registered katana item");
    }
}
'@
WriteFile "$src\item\ModItems.java" $f

# ============ 7. KatanaDeflectMixin ============
$f = @'
package com.example.shinobicore.mixin;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.projectile.PersistentProjectileEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
@Mixin(LivingEntity.class)
public abstract class KatanaDeflectMixin {
    @Inject(method = "damage", at = @At("HEAD"), cancellable = true)
    private void shinobicore_katanaDeflect(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (!(self instanceof ServerPlayerEntity player)) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (data == null) return;
        long now = System.currentTimeMillis();
        KenjutsuStance stance = KenjutsuStance.fromId(data.getKatanaStanceId());
        boolean tapActive = now < data.getKatanaDeflectUntil();
        boolean holdActive = data.isKatanaDeflectHeld() && stance.canDeflect();
        if (!tapActive && !holdActive) return;
        if (now - data.getLastDeflectReflectMs() < 200) return;
        Entity projectile = source.getSource();
        if (projectile == null) return;
        if (projectile instanceof ServerPlayerEntity) return;
        boolean isSeiganShield = holdActive && stance == KenjutsuStance.SEIGAN;
        if (!isSeiganShield) {
            Vec3d toProj = projectile.getPos().subtract(player.getPos());
            Vec3d look = player.getRotationVector();
            Vec3d lookFlat = new Vec3d(look.x, 0, look.z);
            if (lookFlat.lengthSquared() > 0.001 && toProj.lengthSquared() > 0.001) {
                double dot = lookFlat.normalize().dotProduct(new Vec3d(toProj.x, 0, toProj.z).normalize());
                if (dot < -0.2) return;
            }
        }
        LivingEntity shooter = null;
        boolean reflected = false;
        if (projectile instanceof PersistentProjectileEntity proj) {
            Entity owner = proj.getOwner();
            if (owner == player) return;
            if (owner instanceof LivingEntity l) shooter = l;
            proj.setVelocity(proj.getVelocity().multiply(-1.3));
            proj.setOwner(player);
            proj.velocityDirty = true;
            reflected = true;
        }
        if (!reflected) return;
        data.setLastDeflectReflectMs(now);
        player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);
        if (player.getWorld() instanceof ServerWorld sw) {
            sw.spawnParticles(ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(), 12, 0.4, 0.4, 0.4, 0.05);
        }
        if (shooter != null) {
            shooter.damage(player.getDamageSources().playerAttack(player), 4f);
        }
        player.sendMessage(Text.literal("§eDEFLECTED!"), false);
        cir.setReturnValue(false);
    }
}
'@
WriteFile "$src\mixin\KatanaDeflectMixin.java" $f

# ============ 8. KeyBindings (полный rewrite) ============
$f = @'
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
    public static KeyBinding TOGGLE_SENSORY;
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
        TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.toggle_sensory", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));
    }
}
'@
WriteFile "$src\client\KeyBindings.java" $f

# ============ 9. ClientInputHandler (полный rewrite) ============
$f = @'
package com.example.shinobicore.client;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.combat.TaijutsuKickHandler;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.combat.KenjutsuClientHandler;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.combat.TaijutsuFormulas;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;
public class ClientInputHandler {
    private static boolean prevMeditatePressed = false;
    private static boolean prevDeflectDown = false;
    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ClientInputHandler::onClientTick);
    }
    private static void onClientTick(MinecraftClient client) {
        if (client.player == null) return;
        if (KeyBindings.CHAKRA_MODE.wasPressed()) {
            ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
            if (client.getNetworkHandler() != null) {
                PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                buf.writeBoolean(ClientNinjaState.chakraMode);
                ClientPlayNetworking.send(ModPackets.CHAKRA_MODE_ID, buf);
            }
        }
        boolean meditatePressed = KeyBindings.MEDITATE.isPressed();
        if (meditatePressed && !prevMeditatePressed) sendMeditatePacket(client, true);
        else if (!meditatePressed && prevMeditatePressed) sendMeditatePacket(client, false);
        prevMeditatePressed = meditatePressed;
        boolean hasKatana = client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
        if (KeyBindings.KICK.wasPressed()) {
            boolean handEmpty = client.player.getMainHandStack().isEmpty();
            if (handEmpty || hasKatana) TaijutsuKickHandler.tryKick(client.player);
        }
        if (KeyBindings.SWITCH_STANCE.wasPressed() && hasKatana) {
            KenjutsuClientHandler.cycleStance(client.player);
        }
        boolean deflectDown = KeyBindings.KATANA_DEFLECT.isPressed();
        if (deflectDown != prevDeflectDown) {
            prevDeflectDown = deflectDown;
            if (hasKatana) KenjutsuClientHandler.setDeflectHeld(client.player, deflectDown);
        }
        if (KeyBindings.SWITCH_STYLE.wasPressed()) {
            if (hasKatana) {
                KenjutsuClientHandler.cycleStance(client.player);
            } else {
                TaijutsuStyle currentStyle = TaijutsuClientHandler.getCurrentStyle();
                TaijutsuStyle newStyle;
                if (currentStyle == TaijutsuStyle.STANDARD) {
                    int taijutsuLevel = ClientNinjaState.statLevels.getOrDefault("taijutsu", 0);
                    if (!TaijutsuFormulas.canUseStrongFist(taijutsuLevel)) {
                        client.player.sendMessage(Text.literal("§cYou need Taijutsu level " +
                                TaijutsuFormulas.strongFistUnlockLevel() + " to use Strong Fist!"), false);
                        return;
                    }
                    newStyle = TaijutsuStyle.STRONG_FIST;
                } else {
                    newStyle = TaijutsuStyle.STANDARD;
                }
                TaijutsuClientHandler.setStyle(newStyle);
                client.player.sendMessage(Text.literal("§aStyle: " + newStyle.getId()), false);
                if (client.getNetworkHandler() != null) {
                    PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                    buf.writeString(newStyle.getId());
                    ClientPlayNetworking.send(ModPackets.TAIJUTSU_STYLE_ID, buf);
                }
            }
        }
        if (KeyBindings.TOGGLE_SENSORY.wasPressed()) {
            boolean newState = !ClientNinjaState.sensoryEnabled;
            ClientNinjaState.sensoryEnabled = newState;
            if (client.getNetworkHandler() != null) {
                PacketByteBuf senBuf = new PacketByteBuf(Unpooled.buffer());
                senBuf.writeBoolean(newState);
                ClientPlayNetworking.send(ModPackets.SENSORY_TOGGLE_ID, senBuf);
            }
            client.player.sendMessage(Text.literal(newState ? "§aSensory: ON" : "§7Sensory: OFF"), false);
        }
        if (KeyBindings.CAST_A.wasPressed()) ClientNinjaState.castActiveJutsu(0);
        if (KeyBindings.CAST_B.wasPressed()) ClientNinjaState.castActiveJutsu(1);
        if (KeyBindings.CYCLE_A.wasPressed()) ClientNinjaState.cycleLoadout(0);
        if (KeyBindings.CYCLE_B.wasPressed()) ClientNinjaState.cycleLoadout(1);
        if (KeyBindings.PROGRESSION.wasPressed()) client.setScreen(new ProgressionScreen());
        if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info("[INPUT] CRAWL (N) pressed");
    }
    private static void sendMeditatePacket(MinecraftClient client, boolean start) {
        if (client.getNetworkHandler() != null) {
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(start);
            ClientPlayNetworking.send(ModPackets.MEDITATE_ID, buf);
        }
    }
}
'@
WriteFile "$src\client\ClientInputHandler.java" $f

# ============ 10. Патчи существующих файлов ============

# NinjaPlayerData: поля
$m = @'
    private String currentStyleId = "standard";
'@
$i = @'
    private String currentStyleId = "standard";
    private int katanaComboStep = 0;
    private long katanaLastAttackMs = 0;
    private String katanaStanceId = "aggressive";
    private long katanaDeflectUntil = 0;
    private boolean katanaDeflectHeld = false;
    private long lastDeflectReflectMs = 0;
'@
PatchFile "$src\stat\NinjaPlayerData.java" $m $i "NinjaPlayerData: katana fields" "katanaStanceId"

$m = @'
    public void setCurrentStyleId(String id) { this.currentStyleId = id != null ? id : "standard"; }
'@
$i = @'
    public void setCurrentStyleId(String id) { this.currentStyleId = id != null ? id : "standard"; }
    public int getKatanaComboStep() { return katanaComboStep; }
    public void setKatanaComboStep(int v) { this.katanaComboStep = v; }
    public long getKatanaLastAttackMs() { return katanaLastAttackMs; }
    public void setKatanaLastAttackMs(long v) { this.katanaLastAttackMs = v; }
    public String getKatanaStanceId() { return katanaStanceId; }
    public void setKatanaStanceId(String v) { this.katanaStanceId = v != null ? v : "aggressive"; }
    public long getKatanaDeflectUntil() { return katanaDeflectUntil; }
    public void setKatanaDeflectUntil(long v) { this.katanaDeflectUntil = v; }
    public boolean isKatanaDeflectHeld() { return katanaDeflectHeld; }
    public void setKatanaDeflectHeld(boolean v) { this.katanaDeflectHeld = v; }
    public long getLastDeflectReflectMs() { return lastDeflectReflectMs; }
    public void setLastDeflectReflectMs(long v) { this.lastDeflectReflectMs = v; }
'@
PatchFile "$src\stat\NinjaPlayerData.java" $m $i "NinjaPlayerData: katana getters" "getKatanaStanceId()"

# ClientNinjaState: поля
$m = @'
    public static boolean chakraMode = false;
'@
$i = @'
    public static boolean chakraMode = false;
    public static String kenjutsuStance = "aggressive";
    public static boolean deflectHeld = false;
'@
PatchFile "$src\client\ClientNinjaState.java" $m $i "ClientNinjaState: kenjutsu fields" "kenjutsuStance"

# ModPackets: IDs
$m = @'
    public static final Identifier RASENGAN_STRIKE_ID = new Identifier("shinobicore", "rasengan_strike");
'@
$i = @'
    public static final Identifier RASENGAN_STRIKE_ID = new Identifier("shinobicore", "rasengan_strike");
    public static final Identifier KATANA_ATTACK_ID = new Identifier("shinobicore", "katana_attack");
    public static final Identifier KATANA_STANCE_ID = new Identifier("shinobicore", "katana_stance");
    public static final Identifier KATANA_DEFLECT_ID = new Identifier("shinobicore", "katana_deflect");
'@
PatchFile "$src\network\ModPackets.java" $m $i "ModPackets: katana IDs" "KATANA_ATTACK_ID"

# ModPackets: handlers
$m = @'
        ServerPlayNetworking.registerGlobalReceiver(DODGE_ID,
'@
$i = @'
        ServerPlayNetworking.registerGlobalReceiver(KATANA_ATTACK_ID, (server, player, handler, buf, responseSender) -> {
            final int stepParam = buf.readInt();
            final String stanceParam = buf.readString();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;
                KenjutsuStance stance = KenjutsuStance.fromId(stanceParam);
                long now = System.currentTimeMillis();
                int step = stepParam;
                if (data.isKatanaDeflectHeld()) return;
                if (step != data.getKatanaComboStep()) return;
                if (now - data.getKatanaLastAttackMs() < KenjutsuFormulas.cooldownMs(stance) - 50) return;
                if (now - data.getKatanaLastAttackMs() > 1500) { data.setKatanaComboStep(0); step = 0; }
                int tai = data.getStatLevel(StatType.TAIJUTSU);
                float damage = KenjutsuFormulas.computeDamage(tai, stance, data.isChakraMode(), step, data.isExhausted());
                if (stance == KenjutsuStance.IAI && now - data.getKatanaLastAttackMs() > 2000) damage *= 2.2f;
                Vec3d look = player.getRotationVector();
                java.util.List<LivingEntity> targets = step == 3
                        ? KenjutsuFormulas.findInRadius((ServerWorld) player.getWorld(), player, 3.5)
                        : KenjutsuFormulas.findTargetsInCone((ServerWorld) player.getWorld(), player, look, 3.75, 100);
                for (LivingEntity t : targets) {
                    t.damage(player.getDamageSources().playerAttack(player), damage);
                    Vec3d kb = t.getPos().subtract(player.getPos()).normalize().multiply(KenjutsuFormulas.getKnockback(step));
                    t.addVelocity(kb.x, 0.2, kb.z);
                    t.velocityModified = true;
                }
                data.setFatigue(data.getFatigue() + 1.5f);
                data.setKatanaLastAttackMs(now);
                data.setKatanaComboStep((step + 1) % 4);
                data.setKatanaStanceId(stanceParam);
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(KATANA_STANCE_ID, (server, player, handler, buf, responseSender) -> {
            String stanceId = buf.readString();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setKatanaStanceId(stanceId));
        });
        ServerPlayNetworking.registerGlobalReceiver(KATANA_DEFLECT_ID, (server, player, handler, buf, responseSender) -> {
            boolean held = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                KenjutsuStance stance = KenjutsuStance.fromId(data.getKatanaStanceId());
                boolean can = stance.canDeflect();
                data.setKatanaDeflectHeld(held && can);
                if (held && can) {
                    long windowMs = stance == KenjutsuStance.SEIGAN ? 500 : 650;
                    data.setKatanaDeflectUntil(System.currentTimeMillis() + windowMs);
                }
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(DODGE_ID,
'@
PatchFile "$src\network\ModPackets.java" $m $i "ModPackets: katana handlers" "KATANA_ATTACK_ID, (server"

# ModPackets: imports
$m = @'
import com.example.shinobicore.combat.TaijutsuStyle;
'@
$i = @'
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.combat.KenjutsuFormulas;
import com.example.shinobicore.combat.KenjutsuStance;
'@
PatchFile "$src\network\ModPackets.java" $m $i "ModPackets: kenjutsu imports" "KenjutsuFormulas"

# PlayerAttackMixin: katana branch
$m = @'
        if (player.getMainHandStack().isEmpty()) {
'@
$i = @'
        if (player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            if (com.example.shinobicore.client.combat.KenjutsuClientHandler.tryAttack(player)) {
                ci.cancel();
                return;
            }
        }
        if (player.getMainHandStack().isEmpty()) {
'@
PatchFile "$src\mixin\PlayerAttackMixin.java" $m $i "PlayerAttackMixin: katana attack" "KatanaItem"

# ShinobiCore: ModItems.register
$m = @'
        ModEntities.register();
'@
$i = @'
        ModEntities.register();
        com.example.shinobicore.item.ModItems.register();
'@
PatchFile "$src\ShinobiCore.java" $m $i "ShinobiCore: ModItems.register" "ModItems.register()"

# mixins.json: KatanaDeflectMixin
$m = @'
    "CameraMixin"
'@
$i = @'
    "CameraMixin",
    "KatanaDeflectMixin"
'@
PatchFile "$res\shinobicore.mixins.json" $m $i "mixins.json: KatanaDeflectMixin" "KatanaDeflectMixin"

# NinjaTickHandler: seigan shield slow
$m = @'
            double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
'@
$i = @'
            boolean seiganShield = data.isKatanaDeflectHeld()
                    && com.example.shinobicore.combat.KenjutsuStance.fromId(data.getKatanaStanceId()) == com.example.shinobicore.combat.KenjutsuStance.SEIGAN;
            if (seiganShield) {
                player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 5, 2, false, false, false));
            }
            double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
'@
PatchFile "$src\event\NinjaTickHandler.java" $m $i "NinjaTickHandler: seigan slow" "seiganShield"

# PlayerRenderAnimationMixin: kenjutsu anims
$m = @'
        if (TaijutsuAnimations.isKicking(player)) {
'@
$i = @'
        if (com.example.shinobicore.client.combat.KenjutsuAnimations.isDeflecting(player) || ClientNinjaState.deflectHeld) {
            com.example.shinobicore.client.combat.KenjutsuAnimations.applyDeflect(player, rightArm, leftArm);
        }
        if (com.example.shinobicore.client.combat.KenjutsuAnimations.isAttacking(player)) {
            com.example.shinobicore.client.combat.KenjutsuAnimations.applySlash(player, rightArm, leftArm, body, head);
        }
        if (TaijutsuAnimations.isKicking(player)) {
'@
PatchFile "$src\mixin\PlayerRenderAnimationMixin.java" $m $i "Mixin: kenjutsu anims" "KenjutsuAnimations"

# ============ 11. Ресурсы ============
$dir = "$res\data\shinobicore\recipes"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$f = @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["i", "i", "s"],
  "key": { "i": { "item": "minecraft:iron_ingot" }, "s": { "item": "minecraft:stick" } },
  "result": { "item": "shinobicore:katana", "count": 1 }
}
'@
WriteFile "$dir\katana.json" $f

$dir = "$res\assets\shinobicore\models\item"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$f = @'
{ "parent": "item/handheld", "textures": { "layer0": "shinobicore:item/katana" } }
'@
WriteFile "$dir\katana.json" $f

$langFile = "$res\assets\shinobicore\lang\en_us.json"
$dir = Split-Path $langFile
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
if (Test-Path $langFile) {
    $lang = [System.IO.File]::ReadAllText($langFile, $utf8)
    if (-not $lang.Contains("item.shinobicore.katana")) {
        $ins = @'
  ,"item.shinobicore.katana": "Katana",
  "key.shinobicore.switch_stance": "Switch Katana Stance (F)",
  "key.shinobicore.katana_deflect": "Katana Deflect (X)"
}
'@
        $lang = $lang.TrimEnd()
        if ($lang.EndsWith("}")) { $lang = $lang.Substring(0, $lang.Length - 1) + $ins }
        [System.IO.File]::WriteAllText($langFile, $lang, $utf8)
        Write-Host "[OK] en_us.json updated" -ForegroundColor Green
    }
} else {
    $f = @'
{
  "item.shinobicore.katana": "Katana",
  "key.shinobicore.switch_stance": "Switch Katana Stance (F)",
  "key.shinobicore.katana_deflect": "Katana Deflect (X)"
}
'@
    WriteFile $langFile $f
}

$texDir = "$res\assets\shinobicore\textures\item"
if (-not (Test-Path "$texDir\katana.png")) {
    try {
        Add-Type -AssemblyName System.Drawing
        if (-not (Test-Path $texDir)) { New-Item -ItemType Directory -Path $texDir -Force | Out-Null }
        $bmp = New-Object System.Drawing.Bitmap(16, 16)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Transparent)
        $blade = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 220, 220, 230))
        $hilt = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 90, 40, 30))
        $tsuba = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 200, 160, 60))
        for ($x = 0; $x -lt 9; $x++) { $g.FillRectangle($blade, 14 - $x, 1 + $x, 2, 1) }
        $g.FillRectangle($tsuba, 5, 10, 3, 1)
        $g.FillRectangle($hilt, 4, 11, 2, 4)
        $bmp.Save("$texDir\katana.png", [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
        Write-Host "[NEW] katana.png" -ForegroundColor Green
    } catch {
        Write-Host ("[SKIP] katana texture: " + $_.Exception.Message) -ForegroundColor Yellow
    }
}

# ============ 12. Сборка + проверка ============
Write-Host "=== BUILDING ===" -ForegroundColor Cyan
& "E:\Games\mod\gradlew.bat" build 2>&1 | Select-Object -Last 25

Write-Host "=== VERIFICATION ===" -ForegroundColor Cyan
$kb = [System.IO.File]::ReadAllText("$src\client\KeyBindings.java", $utf8)
if ($kb.Contains("SWITCH_STANCE")) { Write-Host "[OK] SWITCH_STANCE" -ForegroundColor Green } else { Write-Host "[FAIL] SWITCH_STANCE" -ForegroundColor Red }
if ($kb.Contains("KATANA_DEFLECT")) { Write-Host "[OK] KATANA_DEFLECT" -ForegroundColor Green } else { Write-Host "[FAIL] KATANA_DEFLECT" -ForegroundColor Red }
$ci = [System.IO.File]::ReadAllText("$src\client\ClientInputHandler.java", $utf8)
if ($ci.Contains("SWITCH_STANCE.wasPressed")) { Write-Host "[OK] F handler" -ForegroundColor Green } else { Write-Host "[FAIL] F handler" -ForegroundColor Red }
if ($ci.Contains("KATANA_DEFLECT.isPressed")) { Write-Host "[OK] X handler" -ForegroundColor Green } else { Write-Host "[FAIL] X handler" -ForegroundColor Red }
foreach ($p in @("$src\item\KatanaItem.java", "$src\combat\KenjutsuStance.java", "$src\client\combat\KenjutsuClientHandler.java", "$src\mixin\KatanaDeflectMixin.java")) {
    if (Test-Path $p) { Write-Host ("[OK] " + (Split-Path $p -Leaf)) -ForegroundColor Green } else { Write-Host ("[FAIL] " + (Split-Path $p -Leaf)) -ForegroundColor Red }
}
Write-Host "=== DONE ===" -ForegroundColor Cyan