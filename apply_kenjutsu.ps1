$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
$res = "E:\Games\mod\src\main\resources"
Write-Host "=== KENJUTSU + CAST ANIMS ===" -ForegroundColor Cyan

function PatchN($file, $marker, $insert, $name) {
    if (-not (Test-Path $file)) { Write-Host "[SKIP] $name (no file)" -ForegroundColor Red; return }
    $c = [System.IO.File]::ReadAllText($file, $utf8).Replace("`r`n", "`n")
    $mn = $marker.Replace("`r`n", "`n")
    if ($c.Contains($mn)) {
        $c = $c.Replace($mn, $insert.Replace("`r`n", "`n"))
        [System.IO.File]::WriteAllText($file, $c, $utf8)
        Write-Host "[OK] $name" -ForegroundColor Green
    } else { Write-Host "[SKIP] $name (marker not found)" -ForegroundColor Red }
}

# ================= НОВЫЕ ФАЙЛЫ =================
[System.IO.File]::WriteAllText("$src\item\KatanaItem.java", @'
package com.example.shinobicore.item;
import net.minecraft.item.Item;
import net.minecraft.item.SwordItem;
import net.minecraft.item.ToolMaterials;
public class KatanaItem extends SwordItem {
    public KatanaItem() {
        super(ToolMaterials.IRON, 4, -2.0f, new Item.Settings().maxCount(1));
    }
}
'@, $utf8); Write-Host "[F] KatanaItem.java" -ForegroundColor Green

[System.IO.File]::WriteAllText("$src\combat\KenjutsuStance.java", @'
package com.example.shinobicore.combat;
public enum KenjutsuStance {
    AGGRESSIVE("aggressive", 1.15f, 1.15f, false),
    SEIGAN("seigan", 0.85f, 1.0f, true),
    IAI("iai", 1.0f, 0.9f, false);
    private final String id;
    private final float damageMult;
    private final float speedMult;
    private final boolean canDeflect;
    KenjutsuStance(String id, float damageMult, float speedMult, boolean canDeflect) {
        this.id = id; this.damageMult = damageMult; this.speedMult = speedMult; this.canDeflect = canDeflect;
    }
    public String getId() { return id; }
    public float getDamageMult() { return damageMult; }
    public float getSpeedMult() { return speedMult; }
    public boolean canDeflect() { return canDeflect; }
    public static KenjutsuStance fromId(String id) {
        for (KenjutsuStance s : values()) if (s.id.equals(id)) return s;
        return AGGRESSIVE;
    }
}
'@, $utf8); Write-Host "[F] KenjutsuStance.java" -ForegroundColor Green

[System.IO.File]::WriteAllText("$src\combat\KenjutsuFormulas.java", @'
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
            Vec3d to = e.getPos().add(0, e.getHeight() / 2, 0).subtract(attacker.getPos().add(0, attacker.getEyeHeight(attacker.getPose()), 0));
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
'@, $utf8); Write-Host "[F] KenjutsuFormulas.java" -ForegroundColor Green

[System.IO.File]::WriteAllText("$src\client\combat\KenjutsuAnimations.java", @'
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
'@, $utf8); Write-Host "[F] KenjutsuAnimations.java" -ForegroundColor Green

[System.IO.File]::WriteAllText("$src\client\combat\KenjutsuClientHandler.java", @'
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
    private static long deflectCd = 0;
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
    public static void tryDeflect(ClientPlayerEntity player) {
        long now = System.currentTimeMillis();
        if (now < deflectCd) return;
        if (!ClientNinjaState.kenjutsuStance.equals("seigan")) {
            player.sendMessage(Text.literal("§cDeflect requires Seigan stance!"), false);
            return;
        }
        ClientPlayNetworking.send(ModPackets.KATANA_DEFLECT_ID, new PacketByteBuf(Unpooled.buffer()));
        KenjutsuAnimations.playDeflect(player);
        player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 0.4f, 1.5f);
        deflectCd = now + 1000;
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
'@, $utf8); Write-Host "[F] KenjutsuClientHandler.java" -ForegroundColor Green

[System.IO.File]::WriteAllText("$src\client\CastingClientState.java", @'
package com.example.shinobicore.client;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
public class CastingClientState {
    public static class Cast {
        public final long start; public final String nature;
        public Cast(long start, String nature) { this.start = start; this.nature = nature; }
    }
    private static final Map<UUID, Cast> CASTS = new HashMap<>();
    public static void startCast(UUID id, String nature) { CASTS.put(id, new Cast(System.currentTimeMillis(), nature)); }
    public static Cast get(AbstractClientPlayerEntity p) {
        Cast c = CASTS.get(p.getUuid());
        if (c == null) return null;
        if (System.currentTimeMillis() - c.start > 500) { CASTS.remove(p.getUuid()); return null; }
        return c;
    }
    public static boolean isCasting(AbstractClientPlayerEntity p) { return get(p) != null; }
    public static int color(String nature) {
        return switch (nature) {
            case "fire" -> 0xFFFF6622;
            case "water" -> 0xFF4488FF;
            case "wind" -> 0xFF88DDAA;
            case "lightning" -> 0xFFFFEE44;
            case "earth" -> 0xFFBB8844;
            default -> 0xFF88AAFF;
        };
    }
}
'@, $utf8); Write-Host "[F] CastingClientState.java" -ForegroundColor Green

[System.IO.File]::WriteAllText("$src\client\CastingClientVisual.java", @'
package com.example.shinobicore.client;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.util.math.Vec3d;
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
            float r = ((color >> 16) & 0xFF) / 255f, g = ((color >> 8) & 0xFF) / 255f, b = (color & 0xFF) / 255f;
            Vec3d hand = handPos(p);
            for (int i = 0; i < 3; i++) {
                client.world.addParticle(net.minecraft.particle.DustParticleEffect.DEFAULT,
                        hand.x + (Math.random() - 0.5) * 0.3, hand.y + (Math.random() - 0.5) * 0.3, hand.z + (Math.random() - 0.5) * 0.3,
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
'@, $utf8); Write-Host "[F] CastingClientVisual.java" -ForegroundColor Green

[System.IO.File]::WriteAllText("$src\mixin\KatanaDeflectMixin.java", @'
package com.example.shinobicore.mixin;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.projectile.PersistentProjectileEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundEvents;
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
        if (System.currentTimeMillis() >= data.getKatanaDeflectUntil()) return;
        if (!(source.getSource() instanceof PersistentProjectileEntity proj)) return;
        if (proj.getOwner() == player) return;
        LivingEntity shooter = proj.getOwner() instanceof LivingEntity l ? l : null;
        proj.setVelocity(proj.getVelocity().multiply(-1.3));
        proj.setOwner(player);
        player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);
        if (player.getWorld() instanceof ServerWorld sw) {
            sw.spawnParticles(ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(), 12, 0.4, 0.4, 0.4, 0.05);
        }
        if (shooter != null) {
            shooter.damage(player.getDamageSources().playerAttack(player), 4f);
        }
        player.sendMessage(net.minecraft.text.Text.literal("§eDEFLECTED!"), false);
        cir.setReturnValue(false);
    }
}
'@, $utf8); Write-Host "[F] KatanaDeflectMixin.java" -ForegroundColor Green

# ================= РЕСУРСЫ =================
$dir = "$res\data\shinobicore\recipes"
[System.IO.File]::WriteAllText("$dir\katana.json", @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["i", "i", "s"],
  "key": { "i": { "item": "minecraft:iron_ingot" }, "s": { "item": "minecraft:stick" } },
  "result": { "item": "shinobicore:katana", "count": 1 }
}
'@, $utf8)
$dir = "$res\assets\shinobicore\models\item"
[System.IO.File]::WriteAllText("$dir\katana.json", @'
{ "parent": "item/handheld", "textures": { "layer0": "shinobicore:item/katana" } }
'@, $utf8)
$dir = "$res\assets\shinobicore\lang"
[System.IO.File]::WriteAllText("$dir\en_us.json", @'
{
  "item.shinobicore.shuriken": "Shuriken",
  "item.shinobicore.kunai": "Kunai",
  "item.shinobicore.katana": "Katana",
  "key.shinobicore.skill_tree": "Skill Tree",
  "key.shinobicore.toggle_sensory": "Toggle Sensory",
  "key.categories.shinobicore": "Shinobi Core",
  "key.categories.shinobicore.combat": "Shinobi Core: Combat"
}
'@, $utf8)
try {
    Add-Type -AssemblyName System.Drawing
    $dir = "$res\assets\shinobicore\textures\item"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path "$dir\katana.png")) {
        $bmp = New-Object System.Drawing.Bitmap(16, 16)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Transparent)
        $blade = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 220, 220, 230))
        $hilt = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 90, 40, 30))
        $tsuba = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 200, 160, 60))
        for ($i = 0; $i -lt 9; $i++) { $g.FillRectangle($blade, 14 - $i, 1 + $i, 2, 1) }
        $g.FillRectangle($tsuba, 5, 10, 3, 1)
        $g.FillRectangle($hilt, 4, 11, 2, 4)
        $bmp.Save("$dir\katana.png", [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
        Write-Host "[F] katana.png" -ForegroundColor Green
    }
} catch { Write-Host "[SKIP] katana texture: $($_.Exception.Message)" -ForegroundColor Yellow }
Write-Host "[F] resources" -ForegroundColor Green

# ================= ПАТЧИ =================
PatchN "$src\item\ModItems.java" 'public static void register() {' @'
public static final Item KATANA = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana"), new KatanaItem());

    public static void register() {
'@ "ModItems: KATANA"

PatchN "$src\network\ModPackets.java" 'public static final Identifier RASENGAN_STRIKE_ID = new Identifier("shinobicore", "rasengan_strike");' @'
public static final Identifier RASENGAN_STRIKE_ID = new Identifier("shinobicore", "rasengan_strike");
    public static final Identifier KATANA_ATTACK_ID = new Identifier("shinobicore", "katana_attack");
    public static final Identifier KATANA_STANCE_ID = new Identifier("shinobicore", "katana_stance");
    public static final Identifier KATANA_DEFLECT_ID = new Identifier("shinobicore", "katana_deflect");
    public static final Identifier CAST_FX_ID = new Identifier("shinobicore", "cast_fx");
'@ "ModPackets: katana IDs"

PatchN "$src\network\ModPackets.java" 'ServerPlayNetworking.registerGlobalReceiver(DODGE_ID,' @'
ServerPlayNetworking.registerGlobalReceiver(KATANA_ATTACK_ID, (server, player, handler, buf, responseSender) -> {
            int step = buf.readInt();
            String stanceId = buf.readString();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;
                KenjutsuStance stance = KenjutsuStance.fromId(stanceId);
                long now = System.currentTimeMillis();
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
                data.setKatanaStanceId(stanceId);
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(KATANA_STANCE_ID, (server, player, handler, buf, responseSender) -> {
            String stanceId = buf.readString();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setKatanaStanceId(stanceId));
        });
        ServerPlayNetworking.registerGlobalReceiver(KATANA_DEFLECT_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (KenjutsuStance.fromId(data.getKatanaStanceId()).canDeflect()) {
                    data.setKatanaDeflectUntil(System.currentTimeMillis() + 300);
                }
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(DODGE_ID,
'@ "ModPackets: katana handlers"

PatchN "$src\network\ModPackets.java" 'import com.example.shinobicore.combat.TaijutsuStyle;' @'
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.combat.KenjutsuFormulas;
import com.example.shinobicore.combat.KenjutsuStance;
'@ "ModPackets: kenjutsu imports"

PatchN "$src\stat\NinjaPlayerData.java" 'private String currentStyleId = "standard";' @'
private String currentStyleId = "standard";
    private int katanaComboStep = 0;
    private long katanaLastAttackMs = 0;
    private String katanaStanceId = "aggressive";
    private long katanaDeflectUntil = 0;
'@ "NinjaPlayerData: katana fields"

PatchN "$src\stat\NinjaPlayerData.java" 'public void setCurrentStyleId(String id) { this.currentStyleId = id != null ? id : "standard"; }' @'
public void setCurrentStyleId(String id) { this.currentStyleId = id != null ? id : "standard"; }
    public int getKatanaComboStep() { return katanaComboStep; }
    public void setKatanaComboStep(int v) { this.katanaComboStep = v; }
    public long getKatanaLastAttackMs() { return katanaLastAttackMs; }
    public void setKatanaLastAttackMs(long v) { this.katanaLastAttackMs = v; }
    public String getKatanaStanceId() { return katanaStanceId; }
    public void setKatanaStanceId(String v) { this.katanaStanceId = v != null ? v : "aggressive"; }
    public long getKatanaDeflectUntil() { return katanaDeflectUntil; }
    public void setKatanaDeflectUntil(long v) { this.katanaDeflectUntil = v; }
'@ "NinjaPlayerData: katana getters"

PatchN "$src\stat\NinjaPlayerData.java" 'nbt.putString("Style", currentStyleId);' @'
nbt.putString("Style", currentStyleId);
        nbt.putString("KatanaStance", katanaStanceId);
'@ "NinjaPlayerData: katana NBT write"

PatchN "$src\stat\NinjaPlayerData.java" 'if (nbt.contains("Affinity")) {' @'
if (nbt.contains("KatanaStance")) katanaStanceId = nbt.getString("KatanaStance");
        if (nbt.contains("Affinity")) {
'@ "NinjaPlayerData: katana NBT read"

PatchN "$src\mixin\PlayerAttackMixin.java" 'if (player.getMainHandStack().isEmpty()) {' @'
if (player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            if (com.example.shinobicore.client.combat.KenjutsuClientHandler.tryAttack(player)) {
                ci.cancel();
                return;
            }
        }
        if (player.getMainHandStack().isEmpty()) {
'@ "PlayerAttackMixin: katana branch"

PatchN "$src\client\ClientInputHandler.java" @'
            if (handEmpty) {
                TaijutsuKickHandler.tryKick(client.player);
            }
'@ @'
            if (handEmpty) {
                TaijutsuKickHandler.tryKick(client.player);
            } else if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.tryDeflect(client.player);
            }
'@ "ClientInputHandler: V = deflect with katana"

PatchN "$src\client\ClientInputHandler.java" 'if (KeyBindings.SWITCH_STYLE.wasPressed()) {' @'
if (KeyBindings.SWITCH_STYLE.wasPressed()) {
            if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                com.example.shinobicore.client.combat.KenjutsuClientHandler.cycleStance(client.player);
                return;
            }
'@ "ClientInputHandler: B = stance with katana"

PatchN "$src\mixin\PlayerRenderAnimationMixin.java" '        if (TaijutsuAnimations.isKicking(player)) {' @'
        // === ПЕЧАТИ ПРИ КАСТЕ ===
        if (com.example.shinobicore.client.CastingClientState.isCasting(player)) {
            rightArm.pitch = -1.25f; rightArm.yaw = -0.45f;
            leftArm.pitch = -1.25f; leftArm.yaw = 0.45f;
            head.pitch += 0.1f;
        }
        // === KENJUTSU: SLASH / DEFLECT ===
        if (KenjutsuAnimations.isDeflecting(player)) {
            KenjutsuAnimations.applyDeflect(player, rightArm, leftArm);
        }
        if (KenjutsuAnimations.isAttacking(player)) {
            KenjutsuAnimations.applySlash(player, rightArm, leftArm, body, head);
        }
        if (TaijutsuAnimations.isKicking(player)) {
'@ "Mixin: cast seals + kenjutsu anims"

PatchN "$src\mixin\PlayerRenderAnimationMixin.java" 'import com.example.shinobicore.client.combat.TaijutsuAnimations;' @'
import com.example.shinobicore.client.combat.TaijutsuAnimations;
import com.example.shinobicore.client.combat.KenjutsuAnimations;
'@ "Mixin: KenjutsuAnimations import"

PatchN "$src\client\IdlePoseSystem.java" 'ItemStack main = player.getMainHandStack();' @'
ItemStack main = player.getMainHandStack();
        if (main.getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            applyKatanaStance(model, breath);
            return;
        }
'@ "IdlePoseSystem: katana stances"

PatchN "$src\client\IdlePoseSystem.java" 'private static void applyNormalIdle(' @'
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

    private static void applyNormalIdle('
'@ "IdlePoseSystem: katana stance method"

PatchN "$src\client\CinematicCamera.java" 'public static Vec3d getShakeOffset() {' @'
public static void addShake(float intensity) {
        shakeIntensity = Math.max(shakeIntensity, intensity);
    }

    public static Vec3d getShakeOffset() {
'@ "CinematicCamera: addShake"

PatchN "$src\jutsu\JutsuCaster.java" 'JutsuBehavior behavior = BehaviorRegistry.getFor(def);' @'
ShinobiCore.broadcastCastFx(player, def.hasNature() ? def.nature().getId() : "none");
        JutsuBehavior behavior = BehaviorRegistry.getFor(def);
'@ "JutsuCaster: broadcast cast FX"

PatchN "$src\ShinobiCore.java" 'public static void sendRasenganSync(ServerPlayerEntity player) {' @'
public static void broadcastCastFx(ServerPlayerEntity player, String natureId) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(player.getId());
        buf.writeString(natureId);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(player)) {
            ServerPlayNetworking.send(p, ModPackets.CAST_FX_ID, buf);
        }
        ServerPlayNetworking.send(player, ModPackets.CAST_FX_ID, buf);
    }

    public static void sendRasenganSync(ServerPlayerEntity player) {
'@ "ShinobiCore: broadcastCastFx"

PatchN "$src\client\ShinobiCoreClient.java" 'HudRenderCallback.EVENT.register(ChakraHudRenderer::render);' @'
ClientPlayNetworking.registerGlobalReceiver(ModPackets.CAST_FX_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            String nature = buf.readString();
            client.execute(() -> {
                if (client.world != null && client.world.getEntityById(entityId) instanceof AbstractClientPlayerEntity p) {
                    CastingClientState.startCast(p.getUuid(), nature);
                }
            });
        });
        CastingClientVisual.register();
        HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
'@ "ShinobiCoreClient: CAST_FX receiver"

PatchN "$src\client\ShinobiCoreClient.java" 'import com.example.shinobicore.client.combat.TaijutsuClientHandler;' @'
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import net.minecraft.client.network.AbstractClientPlayerEntity;
'@ "ShinobiCoreClient: import"

PatchN "$src\client\ClientNinjaState.java" 'public static boolean meditating = false;' @'
public static boolean meditating = false;
    public static String kenjutsuStance = "aggressive";
'@ "ClientNinjaState: kenjutsuStance"

PatchN "$src\client\ChakraHudRenderer.java" @'
        context.drawTextWithShadow(client.textRenderer, Text.literal(styleName), 10, y + 10, styleColor);
        y += 12;
'@ @'
        context.drawTextWithShadow(client.textRenderer, Text.literal(styleName), 10, y + 10, styleColor);
        y += 12;
        if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            String st = ClientNinjaState.kenjutsuStance;
            int stColor = st.equals("seigan") ? 0xFF66AAFF : st.equals("iai") ? 0xFFFFAA00 : 0xFFFF5555;
            context.drawTextWithShadow(client.textRenderer, Text.literal("[" + st.toUpperCase() + "]"), 10, y + 10, stColor);
            y += 12;
        }
'@ "HUD: stance indicator"

PatchN "$res\shinobicore.mixins.json" '"CameraMixin"' @'
"CameraMixin",
    "KatanaDeflectMixin"
'@ "mixins.json: KatanaDeflectMixin"

Write-Host "`n=== BUILD ===" -ForegroundColor Cyan
& "E:\Games\mod\gradlew.bat" build