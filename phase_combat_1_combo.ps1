# ============================================================
#  PHASE 1: РАСШИРЕНИЕ КОМБО + СПЕЦУДАРЫ (прыжок/спринт)
#  Запуск: powershell -ExecutionPolicy Bypass -File .\phase_combat_1_combo.ps1
# ============================================================
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$java = "E:\Games\mod\src\main\java\com\example\shinobicore"
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
    if ($c.Contains($new)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $c.Contains($old)) { Write-Host "[FAIL] pattern: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host "`n=== PHASE 1: COMBO + SPECIAL ATTACKS ===`n" -ForegroundColor Cyan

# ================================================================
# 1. KenjutsuFormulas.java — ПОЛНАЯ ПЕРЕЗАПИСЬ (6 шагов + jump/sprint)
# ================================================================
Write-Host "[1/7] KenjutsuFormulas.java..." -ForegroundColor White
Write-File "$java\combat\KenjutsuFormulas.java" @'
package com.example.shinobicore.combat;

import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

/**
 * Kenjutsu damage/cooldown formulas.
 * Combo: 6 steps (0-5). Step 5 = finisher (360 AOE).
 * Special attacks: JUMP (airborne), SPRINT (sprinting).
 */
public class KenjutsuFormulas {
    // 6-step combo multipliers
    private static final float[] STEP_MULT = {1.0f, 1.0f, 1.15f, 1.3f, 1.5f, 2.2f};
    private static final float[] STEP_KB   = {0.3f, 0.3f, 0.35f, 0.4f, 0.6f, 1.4f};
    public static final int MAX_COMBO_STEPS = 6;

    // Special attack multipliers
    private static final float JUMP_MULT = 2.5f;
    private static final float JUMP_KB = 1.8f;
    private static final float SPRINT_MULT = 1.6f;
    private static final float SPRINT_KB = 1.0f;

    public static float baseDamage(int taiLevel) { return 6.0f + taiLevel * 0.35f; }

    public static float computeDamage(int taiLevel, KenjutsuStance stance,
                                      boolean chakraMode, int step, boolean exhausted) {
        int clampedStep = Math.max(0, Math.min(MAX_COMBO_STEPS - 1, step));
        float d = baseDamage(taiLevel) * STEP_MULT[clampedStep] * stance.getDamageMult();
        if (chakraMode) d *= stance.getChakraDamageMult();
        if (exhausted) d *= 0.5f;
        return d;
    }

    public static float computeJumpDamage(int taiLevel, KenjutsuStance stance,
                                          boolean chakraMode, boolean exhausted) {
        float d = baseDamage(taiLevel) * JUMP_MULT * stance.getDamageMult();
        if (chakraMode) d *= stance.getChakraDamageMult();
        if (exhausted) d *= 0.5f;
        return d;
    }

    public static float computeSprintDamage(int taiLevel, KenjutsuStance stance,
                                            boolean chakraMode, boolean exhausted) {
        float d = baseDamage(taiLevel) * SPRINT_MULT * stance.getDamageMult();
        if (chakraMode) d *= stance.getChakraDamageMult();
        if (exhausted) d *= 0.5f;
        return d;
    }

    public static long cooldownMs(KenjutsuStance stance) {
        return Math.max(180, (long)(450 / stance.getSpeedMult()));
    }

    public static long jumpCooldownMs() { return 900; }
    public static long sprintCooldownMs() { return 600; }

    public static float getKnockback(int step) {
        return STEP_KB[Math.max(0, Math.min(MAX_COMBO_STEPS - 1, step))];
    }

    public static float getJumpKnockback() { return JUMP_KB; }
    public static float getSprintKnockback() { return SPRINT_KB; }

    public static float getFatiguePerHit(KenjutsuStance stance) {
        return 1.5f * stance.getFatigueMult();
    }

    public static float getJumpFatigue() { return 4.0f; }
    public static float getSprintFatigue() { return 2.5f; }

    public static List<LivingEntity> findTargetsInCone(ServerWorld world, LivingEntity attacker,
                                                        Vec3d look, double range, double angleDeg) {
        List<LivingEntity> out = new ArrayList<>();
        Vec3d dir = look.normalize();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class,
                attacker.getBoundingBox().expand(range + 1), t -> t != attacker && t.isAlive())) {
            Vec3d to = e.getPos().add(0, e.getHeight() / 2.0, 0)
                    .subtract(attacker.getPos().add(0, attacker.getEyeHeight(attacker.getPose()), 0));
            if (to.length() > range) continue;
            double dot = dir.dotProduct(to.normalize());
            if (Math.toDegrees(Math.acos(Math.max(-1, Math.min(1, dot)))) <= angleDeg / 2) out.add(e);
        }
        return out;
    }

    public static List<LivingEntity> findInRadius(ServerWorld world, LivingEntity attacker, double range) {
        List<LivingEntity> out = new ArrayList<>();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class,
                attacker.getBoundingBox().expand(range), t -> t != attacker && t.isAlive())) {
            if (e.getPos().distanceTo(attacker.getPos()) <= range) out.add(e);
        }
        return out;
    }
}
'@

# ================================================================
# 2. KenjutsuStance.java — ПОЛНАЯ ПЕРЕЗАПИСЬ (новые параметры)
# ================================================================
Write-Host "[2/7] KenjutsuStance.java..." -ForegroundColor White
Write-File "$java\combat\KenjutsuStance.java" @'
package com.example.shinobicore.combat;

/**
 * Kenjutsu stances with extended parameters.
 * AGGRESSIVE: fast + strong, high fatigue.
 * SEIGAN: defensive, parry/deflect, chakra generation.
 * IAI: slow but devastating first strike.
 */
public enum KenjutsuStance {
    AGGRESSIVE("aggressive", 1.15f, 1.25f, true, 1.0f, 1.4f, 1.3f, 0f),
    SEIGAN("seigan", 0.85f, 1.0f, true, 0.5f, 0.8f, 1.0f, 0.5f),
    IAI("iai", 1.0f, 0.85f, false, 1.0f, 1.0f, 1.5f, 0f);

    private final String id;
    private final float damageMult;
    private final float speedMult;
    private final boolean canDeflect;
    private final float shieldSlow;
    private final float fatigueMult;
    private final float chakraDamageMult;
    private final float parryChakraGain;

    KenjutsuStance(String id, float damageMult, float speedMult, boolean canDeflect,
                   float shieldSlow, float fatigueMult, float chakraDamageMult, float parryChakraGain) {
        this.id = id;
        this.damageMult = damageMult;
        this.speedMult = speedMult;
        this.canDeflect = canDeflect;
        this.shieldSlow = shieldSlow;
        this.fatigueMult = fatigueMult;
        this.chakraDamageMult = chakraDamageMult;
        this.parryChakraGain = parryChakraGain;
    }

    public String getId() { return id; }
    public float getDamageMult() { return damageMult; }
    public float getSpeedMult() { return speedMult; }
    public boolean canDeflect() { return canDeflect; }
    public float getShieldSlow() { return shieldSlow; }
    public float getFatigueMult() { return fatigueMult; }
    public float getChakraDamageMult() { return chakraDamageMult; }
    public float getParryChakraGain() { return parryChakraGain; }

    public static KenjutsuStance fromId(String id) {
        for (KenjutsuStance s : values()) if (s.id.equals(id)) return s;
        return AGGRESSIVE;
    }
}
'@

# ================================================================
# 3. KenjutsuClientHandler.java — заменить tryAttack
# ================================================================
Write-Host "[3/7] Patching KenjutsuClientHandler.java..." -ForegroundColor White

$oldTryAttack = @'
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
        if (stance.equals("iai")) KenjutsuAnimations.playIaiSlash(player); else KenjutsuAnimations.playSlash(player, comboStep); // PHASE_A_IAI_HOOK
        playSlashParticles(player, comboStep);
        SwordTrailRenderer.playSlashTrail(player, comboStep); // PHASE_K1_TRAIL_HOOKED
        TaijutsuSounds.playKatanaSlash(comboStep);
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
'@

$newTryAttack = @'
    // Attack types: 0=normal combo, 1=jump attack, 2=sprint attack
    public static boolean tryAttack(ClientPlayerEntity player) {
        if (!(player.getMainHandStack().getItem() instanceof KatanaItem)) return false;
        long now = System.currentTimeMillis();
        if (now < cooldownEnd) return false;
        if (now - lastAttack > 1500) comboStep = 0;
        String stance = ClientNinjaState.kenjutsuStance;

        // Detect special attack type
        int attackType = 0; // normal
        if (!player.isOnGround() && player.getVelocity().y < -0.1) {
            attackType = 1; // jump attack (falling)
        } else if (player.isSprinting() && player.isOnGround()) {
            attackType = 2; // sprint attack
        }

        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(comboStep);
        buf.writeString(stance);
        buf.writeInt(attackType);
        ClientPlayNetworking.send(ModPackets.KATANA_ATTACK_ID, buf);

        // Client-side animations
        if (attackType == 1) {
            KenjutsuAnimations.playJumpSlash(player);
            SwordTrailRenderer.playJumpTrail(player);
            TaijutsuSounds.playKatanaSlash(5);
            CinematicCamera.addShake(0.15f);
        } else if (attackType == 2) {
            KenjutsuAnimations.playSprintSlash(player);
            SwordTrailRenderer.playSprintTrail(player);
            TaijutsuSounds.playKatanaSlash(4);
        } else {
            if (stance.equals("iai")) KenjutsuAnimations.playIaiSlash(player);
            else KenjutsuAnimations.playSlash(player, comboStep);
            playSlashParticles(player, comboStep);
            SwordTrailRenderer.playSlashTrail(player, comboStep);
            TaijutsuSounds.playKatanaSlash(comboStep);
            if (comboStep == 5) {
                TaijutsuSounds.playKickSound();
                CinematicCamera.addShake(0.18f);
            }
        }

        player.swingHand(Hand.MAIN_HAND);

        long cd;
        if (attackType == 1) cd = KenjutsuFormulas.jumpCooldownMs();
        else if (attackType == 2) cd = KenjutsuFormulas.sprintCooldownMs();
        else cd = KenjutsuFormulas.cooldownMs(KenjutsuStance.fromId(stance));
        cooldownEnd = now + cd;
        lastAttack = now;
        if (attackType == 0) comboStep = (comboStep + 1) % KenjutsuFormulas.MAX_COMBO_STEPS;
        return true;
    }
'@

Patch-File "$java\client\combat\KenjutsuClientHandler.java" $oldTryAttack $newTryAttack

# Добавить импорт KenjutsuFormulas если нет
Patch-File "$java\client\combat\KenjutsuClientHandler.java" `
    "import com.example.shinobicore.item.KatanaItem;" `
    "import com.example.shinobicore.combat.KenjutsuFormulas;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.item.KatanaItem;"

# ================================================================
# 4. ModPackets.java — заменить обработчик KATANA_ATTACK_ID
# ================================================================
Write-Host "[4/7] Patching ModPackets.java (KATANA_ATTACK_ID)..." -ForegroundColor White

$oldKatanaHandler = @'
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
                if (stance == KenjutsuStance.IAI && now - data.getKatanaLastAttackMs() > 2000) {
                    damage *= 2.2f;
                    player.sendMessage(Text.literal("\u00a76IAI CRIT!"), false);
                    player.playSound(net.minecraft.sound.SoundEvents.ENTITY_PLAYER_ATTACK_CRIT, 1.0f, 0.8f);
                    if (player.getWorld() instanceof ServerWorld sw3) {
                        sw3.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(), 20, 0.5, 0.5, 0.5, 0.1);
                    }
                }
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
'@

$newKatanaHandler = @'
        ServerPlayNetworking.registerGlobalReceiver(KATANA_ATTACK_ID, (server, player, handler, buf, responseSender) -> {
            final int stepParam = buf.readInt();
            final String stanceParam = buf.readString();
            final int attackType = buf.readInt(); // 0=normal, 1=jump, 2=sprint
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;
                if (data.isKatanaDeflectHeld()) return;
                KenjutsuStance stance = KenjutsuStance.fromId(stanceParam);
                long now = System.currentTimeMillis();
                int tai = data.getStatLevel(StatType.TAIJUTSU);
                boolean chakra = data.isChakraMode();

                // === JUMP ATTACK (attackType=1) ===
                if (attackType == 1) {
                    if (player.isOnGround()) return; // anticheat: must be airborne
                    if (now - data.getKatanaLastAttackMs() < KenjutsuFormulas.jumpCooldownMs() - 50) return;
                    float damage = KenjutsuFormulas.computeJumpDamage(tai, stance, chakra, data.isExhausted());
                    Vec3d look = player.getRotationVector();
                    java.util.List<LivingEntity> targets = KenjutsuFormulas.findTargetsInCone(
                            (ServerWorld) player.getWorld(), player, look, 4.0, 140);
                    for (LivingEntity t : targets) {
                        t.damage(player.getDamageSources().playerAttack(player), damage);
                        Vec3d kb = t.getPos().subtract(player.getPos()).normalize()
                                .multiply(KenjutsuFormulas.getJumpKnockback());
                        t.addVelocity(kb.x, -0.4, kb.z); // slam down
                        t.velocityModified = true;
                    }
                    data.setFatigue(data.getFatigue() + KenjutsuFormulas.getJumpFatigue());
                    if (chakra) data.setCurrentChakra(Math.max(0, data.getCurrentChakra() - 3.0f));
                    data.setKatanaLastAttackMs(now);
                    data.setKatanaStanceId(stanceParam);
                    return;
                }

                // === SPRINT ATTACK (attackType=2) ===
                if (attackType == 2) {
                    if (!player.isSprinting()) return; // anticheat: must be sprinting
                    if (now - data.getKatanaLastAttackMs() < KenjutsuFormulas.sprintCooldownMs() - 50) return;
                    float damage = KenjutsuFormulas.computeSprintDamage(tai, stance, chakra, data.isExhausted());
                    Vec3d look = player.getRotationVector();
                    java.util.List<LivingEntity> targets = KenjutsuFormulas.findTargetsInCone(
                            (ServerWorld) player.getWorld(), player, look, 4.5, 60);
                    for (LivingEntity t : targets) {
                        t.damage(player.getDamageSources().playerAttack(player), damage);
                        Vec3d kb = look.normalize().multiply(KenjutsuFormulas.getSprintKnockback());
                        t.addVelocity(kb.x, 0.15, kb.z); // push forward
                        t.velocityModified = true;
                    }
                    data.setFatigue(data.getFatigue() + KenjutsuFormulas.getSprintFatigue());
                    if (chakra) data.setCurrentChakra(Math.max(0, data.getCurrentChakra() - 1.5f));
                    data.setKatanaLastAttackMs(now);
                    data.setKatanaStanceId(stanceParam);
                    return;
                }

                // === NORMAL COMBO (attackType=0) ===
                int step = stepParam;
                if (step != data.getKatanaComboStep()) return;
                if (now - data.getKatanaLastAttackMs() < KenjutsuFormulas.cooldownMs(stance) - 50) return;
                if (now - data.getKatanaLastAttackMs() > 1500) { data.setKatanaComboStep(0); step = 0; }

                float damage = KenjutsuFormulas.computeDamage(tai, stance, chakra, step, data.isExhausted());

                // IAI first-strike bonus
                if (stance == KenjutsuStance.IAI && now - data.getKatanaLastAttackMs() > 2000) {
                    damage *= 2.2f;
                    player.sendMessage(Text.literal("\u00a76IAI CRIT!"), false);
                    player.playSound(net.minecraft.sound.SoundEvents.ENTITY_PLAYER_ATTACK_CRIT, 1.0f, 0.8f);
                    if (player.getWorld() instanceof ServerWorld sw3) {
                        sw3.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT,
                                player.getX(), player.getY() + 1, player.getZ(), 20, 0.5, 0.5, 0.5, 0.1);
                    }
                }

                Vec3d look = player.getRotationVector();
                boolean isFinisher = (step == KenjutsuFormulas.MAX_COMBO_STEPS - 1);
                java.util.List<LivingEntity> targets = isFinisher
                        ? KenjutsuFormulas.findInRadius((ServerWorld) player.getWorld(), player, 4.0)
                        : KenjutsuFormulas.findTargetsInCone((ServerWorld) player.getWorld(), player, look, 3.75, 100);

                for (LivingEntity t : targets) {
                    t.damage(player.getDamageSources().playerAttack(player), damage);
                    Vec3d kb = t.getPos().subtract(player.getPos()).normalize()
                            .multiply(KenjutsuFormulas.getKnockback(step));
                    t.addVelocity(kb.x, isFinisher ? 0.4 : 0.2, kb.z);
                    t.velocityModified = true;
                }

                data.setFatigue(data.getFatigue() + KenjutsuFormulas.getFatiguePerHit(stance));
                if (chakra) data.setCurrentChakra(Math.max(0, data.getCurrentChakra() - 0.5f));
                data.setKatanaLastAttackMs(now);
                data.setKatanaComboStep((step + 1) % KenjutsuFormulas.MAX_COMBO_STEPS);
                data.setKatanaStanceId(stanceParam);
            });
        });
'@

Patch-File "$java\network\ModPackets.java" $oldKatanaHandler $newKatanaHandler

# ================================================================
# 5. KenjutsuAnimations.java — добавить jump/sprint анимации
# ================================================================
Write-Host "[5/7] Patching KenjutsuAnimations.java..." -ForegroundColor White

Patch-File "$java\client\combat\KenjutsuAnimations.java" `
    "public static void playDeflect(AbstractClientPlayerEntity p) { DEFLECTS.put(p.getUuid(), System.currentTimeMillis() + 300); }" `
    "public static void playDeflect(AbstractClientPlayerEntity p) { DEFLECTS.put(p.getUuid(), System.currentTimeMillis() + 300); }
    public static void playJumpSlash(AbstractClientPlayerEntity p) { SLASHES.put(p.getUuid(), new SlashState(6)); }
    public static void playSprintSlash(AbstractClientPlayerEntity p) { SLASHES.put(p.getUuid(), new SlashState(7)); }"

# Расширить duration для новых шагов
Patch-File "$java\client\combat\KenjutsuAnimations.java" `
    "private float duration(int s) { return switch (s) { case 0, 1 -> 260f; case 2 -> 340f; case 4 -> 350f; default -> 520f; }; }" `
    "private float duration(int s) { return switch (s) { case 0, 1 -> 260f; case 2 -> 340f; case 4 -> 350f; case 6 -> 450f; case 7 -> 300f; default -> 520f; }; }"

# Добавить анимации в applySlash
Patch-File "$java\client\combat\KenjutsuAnimations.java" `
    "default -> { body.yaw += (float) Math.sin(s.getProgress() * Math.PI) * 1.2f; rArm.pitch = -1.5f; rArm.roll = 0.6f; lArm.pitch = -1.5f; lArm.yaw = -0.6f; head.pitch -= 0.1f; }" `
    "case 6 -> { rArm.pitch = -2.8f + c * 3.5f; rArm.yaw = 0f; rArm.roll = 0f; body.pitch = -0.3f + c * 0.5f; lArm.pitch = -1.0f; lArm.yaw = 0.4f; head.pitch += 0.2f * c; }
            case 7 -> { rArm.yaw = -0.5f + c * 1.5f; rArm.pitch = -1.2f; body.yaw += c * 0.8f; body.pitch = 0.15f; lArm.pitch = -0.8f; }
            default -> { body.yaw += (float) Math.sin(s.getProgress() * Math.PI) * 1.2f; rArm.pitch = -1.5f; rArm.roll = 0.6f; lArm.pitch = -1.5f; lArm.yaw = -0.6f; head.pitch -= 0.1f; }"

# ================================================================
# 6. SwordTrailRenderer.java — добавить jump/sprint трейлы
# ================================================================
Write-Host "[6/7] Patching SwordTrailRenderer.java..." -ForegroundColor White

Patch-File "$java\client\combat\SwordTrailRenderer.java" `
    "case 3 -> spawnFinisherRing(client, pos);                     // 360 ring" `
    "case 3 -> spawnFinisherRing(client, pos);                     // 360 ring
        case 4 -> spawnHorizontalArc(client, pos, right, up, true);   // step 4
        case 5 -> spawnFinisherRing(client, pos);                     // step 5 finisher"

Patch-File "$java\client\combat\SwordTrailRenderer.java" `
    "/**
     * Called when a projectile is deflected." `
    "/**
     * Jump attack trail: downward arc.
     */
    public static void playJumpTrail(AbstractClientPlayerEntity player) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.world == null) return;
        Vec3d pos = player.getPos().add(0, 1.5, 0);
        Vec3d look = player.getRotationVector();
        for (int i = 0; i < 18; i++) {
            float t = (float) i / 18;
            Vec3d offset = look.multiply(0.5 + t * 1.5)
                    .add(new Vec3d(0, -t * 2.0, 0));
            Vec3d p = pos.add(offset);
            client.world.addParticle(ParticleTypes.SWEEP_ATTACK, p.x, p.y, p.z, 0, -0.1, 0);
            if (i % 3 == 0) client.world.addParticle(ParticleTypes.CRIT, p.x, p.y, p.z, 0, -0.05, 0);
        }
        client.world.addParticle(ParticleTypes.EXPLOSION, pos.x + look.x * 1.5, pos.y - 1.5, pos.z + look.z * 1.5, 0, 0, 0);
    }

    /**
     * Sprint attack trail: forward thrust.
     */
    public static void playSprintTrail(AbstractClientPlayerEntity player) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.world == null) return;
        Vec3d pos = player.getPos().add(0, 1.2, 0);
        Vec3d look = player.getRotationVector();
        for (int i = 0; i < 12; i++) {
            float t = (float) i / 12;
            Vec3d p = pos.add(look.multiply(t * 3.0))
                    .add(new Vec3d((Math.random()-0.5)*0.3, (Math.random()-0.5)*0.3, (Math.random()-0.5)*0.3));
            client.world.addParticle(ParticleTypes.SWEEP_ATTACK, p.x, p.y, p.z, look.x * 0.1, 0, look.z * 0.1);
        }
        for (int i = 0; i < 6; i++) {
            client.world.addParticle(ParticleTypes.CLOUD,
                    pos.x + look.x * 2.5 + (Math.random()-0.5)*0.5,
                    pos.y + (Math.random()-0.5)*0.5,
                    pos.z + look.z * 2.5 + (Math.random()-0.5)*0.5, 0, 0.02, 0);
        }
    }

    /**
     * Called when a projectile is deflected."

# ================================================================
# 7. NinjaPlayerData.java — обновить комбо-степ
# ================================================================
Write-Host "[7/7] Patching NinjaPlayerData.java..." -ForegroundColor White

Patch-File "$java\stat\NinjaPlayerData.java" `
    "public void advanceComboStep() {
        this.serverComboStep = (this.serverComboStep + 1) % com.example.shinobicore.combat.TaijutsuCombo.MAX_STEPS;
    }" `
    "public void advanceComboStep() {
        this.serverComboStep = (this.serverComboStep + 1) % com.example.shinobicore.combat.TaijutsuCombo.MAX_STEPS;
    }
    public void advanceKatanaComboStep() {
        this.katanaComboStep = (this.katanaComboStep + 1) % com.example.shinobicore.combat.KenjutsuFormulas.MAX_COMBO_STEPS;
    }"

# ================================================================
Write-Host "`n=== PHASE 1 COMPLETE: OK=$ok SKIP=$skip ERR=$err ===`n" -ForegroundColor Green
Write-Host "Next: .\gradlew.bat build" -ForegroundColor Yellow