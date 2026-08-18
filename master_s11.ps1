# ============================================================
# SHINOBICORE MASTER SCRIPT: SPRINT 11 - Modes & Gates
# S11-01..S11-04: 8 Gates, Survival, Arena, Progression
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$modesDir = Join-Path $srcBase "modes"
$blockDir = Join-Path $srcBase "block"
$blockEntityDir = Join-Path $srcBase "block\entity"
$resBase = Join-Path $root "src\main\resources"
$texBlockDir = Join-Path $resBase "assets\shinobicore\textures\block"
$bsDir = Join-Path $resBase "assets\shinobicore\blockstates"
$mbDir = Join-Path $resBase "assets\shinobicore\models\block"
$miDir = Join-Path $resBase "assets\shinobicore\models\item"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 11: Modes & Gates (S11-01..S11-04)" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("  [OK] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host ("  [MISS] " + $p) -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host ("  [SKIP] already: " + (Split-Path $p -Leaf)) -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host ("  [FAIL] pattern: " + (Split-Path $p -Leaf)) -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host ("  [PATCH] " + (Split-Path $p -Leaf)) -ForegroundColor Green
    return $true
}

# ============================================================
# S11-03: GATES MANAGER
# ============================================================
Write-Host "[S11-03] Creating GatesManager..." -ForegroundColor Yellow

$gatesManager = @'
package com.example.shinobicore.modes;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import java.util.UUID;

/**
 * S11-03: Eight Gates manager.
 * Activation: hold chakra key (C) for 5 seconds per gate.
 * Deactivation: hold M key for 5 seconds (except Gate 8).
 * Gate 8: cannot deactivate, must survive 3 minutes.
 */
public class GatesManager {
    // {attackSpeedBonus, damageBonus, speedBonus, hpDamagePer40Ticks, particleCount}
    private static final float[][] GATE_DATA = {
        {0.20f, 0.20f, 0.20f, 0.5f, 3},
        {0.50f, 0.50f, 0.25f, 0.5f, 5},
        {0.80f, 0.80f, 0.30f, 1.0f, 7},
        {1.10f, 1.10f, 0.35f, 1.0f, 9},
        {1.40f, 1.40f, 0.40f, 1.5f, 11},
        {1.70f, 1.70f, 0.45f, 1.5f, 13},
        {2.00f, 2.00f, 0.50f, 2.0f, 15},
        {5.00f, 5.00f, 0.65f, 0.0f, 20},
    };

    private static final UUID ATK_UUID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567801");
    private static final UUID DMG_UUID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567802");
    private static final UUID SPD_UUID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567803");

    public static final int GATE8_DURATION = 3 * 60 * 20;
    public static final int GATE8_COOLDOWN = 15 * 60 * 20;

    public static boolean activateNextGate(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int current = data.getActiveGate();
        int next = current + 1;
        if (next > 8) return false;
        if (next == 8 && data.getGateCooldownTicks() > 0) {
            player.sendMessage(Text.literal("\u00a7cGate 8 on cooldown."), false);
            return false;
        }
        String node = gateNode(next);
        if (!data.getUnlockedNodes().contains(node)) {
            player.sendMessage(Text.literal("\u00a7cGate " + next + " not unlocked in tree."), false);
            return false;
        }
        if (current > 0) removeModifiers(player);
        data.setActiveGate(next);
        applyModifiers(player, next);
        if (next == 8) data.setGate8RemainingTicks(GATE8_DURATION);
        player.sendMessage(Text.literal("\u00a7a\u26a1 Gate " + next + " opened!"), false);
        sync(player);
        return true;
    }

    public static boolean deactivateGate(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int gate = data.getActiveGate();
        if (gate == 0) return false;
        if (gate == 8) {
            player.sendMessage(Text.literal("\u00a7cGate 8 cannot be closed!"), false);
            return false;
        }
        removeModifiers(player);
        data.setActiveGate(0);
        player.sendMessage(Text.literal("\u00a77Gates closed."), false);
        sync(player);
        return true;
    }

    public static void tick(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int gate = data.getActiveGate();
        if (gate == 0) {
            if (data.getGateCooldownTicks() > 0) data.setGateCooldownTicks(data.getGateCooldownTicks() - 1);
            return;
        }
        float[] gd = GATE_DATA[gate - 1];
        if (gd[3] > 0 && player.age % 40 == 0) {
            player.damage(player.getDamageSources().magic(), gd[3]);
        }
        if (gate == 8) {
            int rem = data.getGate8RemainingTicks();
            if (rem > 0) {
                data.setGate8RemainingTicks(rem - 1);
            } else {
                removeModifiers(player);
                data.setActiveGate(0);
                data.setGateCooldownTicks(GATE8_COOLDOWN);
                player.sendMessage(Text.literal("\u00a7aGate 8 expired. You survived!"), false);
                ModeProgression.award(player, "survived_gate8");
                sync(player);
                return;
            }
        }
        if (player.getWorld() instanceof ServerWorld sw && player.age % 2 == 0) {
            int count = (int) gd[4];
            for (int i = 0; i < count; i++) {
                double a = sw.getRandom().nextDouble() * Math.PI * 2;
                double d = 0.3 + sw.getRandom().nextDouble() * 0.4;
                sw.spawnParticles(ParticleTypes.DAMAGE_INDICATOR,
                    player.getX() + Math.cos(a) * d,
                    player.getY() + 0.5 + sw.getRandom().nextDouble() * 1.5,
                    player.getZ() + Math.sin(a) * d, 1, 0, 0, 0, 0);
            }
        }
    }

    private static void applyModifiers(ServerPlayerEntity p, int gate) {
        float[] gd = GATE_DATA[gate - 1];
        var as = p.getAttributeInstance(EntityAttributes.GENERIC_ATTACK_SPEED);
        var dm = p.getAttributeInstance(EntityAttributes.GENERIC_ATTACK_DAMAGE);
        var sp = p.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (as != null) as.addTemporaryModifier(new EntityAttributeModifier(ATK_UUID, "gate_as", gd[0], EntityAttributeModifier.Operation.MULTIPLY_TOTAL));
        if (dm != null) dm.addTemporaryModifier(new EntityAttributeModifier(DMG_UUID, "gate_dm", gd[1], EntityAttributeModifier.Operation.MULTIPLY_TOTAL));
        if (sp != null) sp.addTemporaryModifier(new EntityAttributeModifier(SPD_UUID, "gate_sp", gd[2], EntityAttributeModifier.Operation.MULTIPLY_TOTAL));
    }

    private static void removeModifiers(ServerPlayerEntity p) {
        var as = p.getAttributeInstance(EntityAttributes.GENERIC_ATTACK_SPEED);
        var dm = p.getAttributeInstance(EntityAttributes.GENERIC_ATTACK_DAMAGE);
        var sp = p.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (as != null) as.removeModifier(ATK_UUID);
        if (dm != null) dm.removeModifier(DMG_UUID);
        if (sp != null) sp.removeModifier(SPD_UUID);
    }

    private static String gateNode(int g) {
        switch (g) {
            case 1: return "gate_one"; case 2: return "gate_two";
            case 3: return "gate_three"; case 4: return "gate_four";
            case 5: return "gate_five"; case 6: return "gate_six";
            case 7: return "gate_seven"; case 8: return "gate_eight";
            default: return "";
        }
    }

    private static void sync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getActiveGate());
        buf.writeInt(data.getGate8RemainingTicks());
        buf.writeInt(data.getGateCooldownTicks());
        ServerPlayNetworking.send(player, ModPackets.GATE_SYNC_ID, buf);
    }
}
'@
Write-File (Join-Path $modesDir "GatesManager.java") $gatesManager

# ============================================================
# S11-01: SURVIVAL MODE
# ============================================================
Write-Host "[S11-01] Creating SurvivalMode..." -ForegroundColor Yellow

$survivalMode = @'
package com.example.shinobicore.modes;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.enemy.NinjaEnemyEntity;
import com.example.shinobicore.entity.enemy.NinjaRank;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.item.Items;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import java.util.UUID;

/**
 * S11-01: Survival mode.
 * 10 waves, each wave: 2 + (wave * 2) enemies.
 * Enemy ranks scale with wave number.
 * Rewards: XP + netherite.
 * Death: progress lost, inventory preserved, 2-day altar cooldown.
 */
public class SurvivalMode {
    public static final int MAX_WAVES = 10;
    public static final int ALTAR_COOLDOWN_TICKS = 2 * 24 * 60 * 60 * 20; // 2 days

    public static void startWave(ServerWorld world, BlockPos altarPos, int wave, UUID playerUuid) {
        int enemyCount = 2 + wave * 2;
        NinjaRank rank = getWaveRank(wave);
        PlayerEntity player = world.getPlayerByUuid(playerUuid);
        if (player == null) return;

        player.sendMessage(Text.literal("\u00a7e\u2694 Wave " + wave + "/" + MAX_WAVES
            + " - " + enemyCount + " enemies (" + rank.getId() + ")"), false);

        Vec3d center = new Vec3d(altarPos.getX() + 0.5, altarPos.getY(), altarPos.getZ() + 0.5);
        for (int i = 0; i < enemyCount; i++) {
            double angle = (i / (double) enemyCount) * Math.PI * 2;
            double dist = 8 + world.getRandom().nextDouble() * 24;
            double x = center.x + Math.cos(angle) * dist;
            double z = center.z + Math.sin(angle) * dist;
            int y = world.getTopY(net.minecraft.world.Heightmap.Type.WORLD_SURFACE,
                (int) x, (int) z);

            NinjaEnemyEntity enemy = new NinjaEnemyEntity(ModEntities.NINJA_ENEMY, world);
            enemy.setRank(rank);
            enemy.setPosition(x, y, z);
            enemy.setTarget(player);
            world.spawnEntity(enemy);
        }
    }

    public static NinjaRank getWaveRank(int wave) {
        if (wave <= 3) return NinjaRank.GENIN;
        if (wave <= 6) return NinjaRank.CHUNIN;
        if (wave <= 8) return NinjaRank.JONIN;
        return NinjaRank.ANBU;
    }

    public static void onWaveComplete(ServerWorld world, BlockPos altarPos, int wave, UUID playerUuid) {
        PlayerEntity player = world.getPlayerByUuid(playerUuid);
        if (player == null) return;

        float xpReward = wave * 15.0f;
        player.addExperience((int) xpReward);
        player.sendMessage(Text.literal("\u00a7aWave " + wave + " complete! +" + (int) xpReward + " XP"), false);

        if (wave == MAX_WAVES) {
            player.giveItemStack(new ItemStack(Items.NETHERITE_SCRAP, 1));
            player.sendMessage(Text.literal("\u00a76\u2605 SURVIVAL COMPLETE! Netherite Scrap awarded!"), false);
            ModeProgression.award((ServerPlayerEntity) player, "survival_10_waves");
        }
        if (wave == 1) {
            ModeProgression.award((ServerPlayerEntity) player, "survival_first_wave");
        }
    }

    public static void onPlayerDeath(ServerWorld world, BlockPos altarPos, UUID playerUuid) {
        PlayerEntity player = world.getPlayerByUuid(playerUuid);
        if (player != null) {
            player.sendMessage(Text.literal("\u00a7cSurvival failed. Progress lost. Altar on cooldown."), false);
        }
    }
}
'@
Write-File (Join-Path $modesDir "SurvivalMode.java") $survivalMode

# ============================================================
# S11-02: ARENA MODE
# ============================================================
Write-Host "[S11-02] Creating ArenaMode..." -ForegroundColor Yellow

$arenaMode = @'
package com.example.shinobicore.modes;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import java.util.UUID;

/**
 * S11-02: Arena mode (PvP).
 * 24x24 area, 60 second timer, all techniques allowed.
 * Winner gets XP, draw = half XP to both.
 */
public class ArenaMode {
    public static final int ARENA_SIZE = 24;
    public static final int MATCH_DURATION_TICKS = 60 * 20; // 60 seconds
    public static final float WIN_XP = 100.0f;

    public static void startMatch(ServerWorld world, BlockPos altarPos,
                                  UUID player1, UUID player2) {
        PlayerEntity p1 = world.getPlayerByUuid(player1);
        PlayerEntity p2 = world.getPlayerByUuid(player2);
        if (p1 == null || p2 == null) return;

        Vec3d center = new Vec3d(altarPos.getX() + 0.5, altarPos.getY(), altarPos.getZ() + 0.5);
        double half = ARENA_SIZE / 2.0;

        p1.teleport(center.x - half + 2, center.y, center.z);
        p2.teleport(center.x + half - 2, center.y, center.z);

        p1.sendMessage(Text.literal("\u00a7e\u2694 ARENA MATCH START!"), false);
        p2.sendMessage(Text.literal("\u00a7e\u2694 ARENA MATCH START!"), false);
    }

    public static void onMatchEnd(ServerWorld world, BlockPos altarPos,
                                  UUID winnerUuid, UUID loserUuid, boolean isDraw) {
        if (isDraw) {
            PlayerEntity p1 = world.getPlayerByUuid(winnerUuid);
            PlayerEntity p2 = world.getPlayerByUuid(loserUuid);
            if (p1 != null) {
                p1.addExperience((int)(WIN_XP / 2));
                p1.sendMessage(Text.literal("\u00a7eDraw! +" + (int)(WIN_XP/2) + " XP"), false);
            }
            if (p2 != null) {
                p2.addExperience((int)(WIN_XP / 2));
                p2.sendMessage(Text.literal("\u00a7eDraw! +" + (int)(WIN_XP/2) + " XP"), false);
            }
        } else {
            PlayerEntity winner = world.getPlayerByUuid(winnerUuid);
            PlayerEntity loser = world.getPlayerByUuid(loserUuid);
            if (winner != null) {
                winner.addExperience((int) WIN_XP);
                winner.sendMessage(Text.literal("\u00a76\u2605 VICTORY! +" + (int) WIN_XP + " XP"), false);
                ModeProgression.award((ServerPlayerEntity) winner, "arena_first_win");
            }
            if (loser != null) {
                loser.sendMessage(Text.literal("\u00a7cDefeat."), false);
            }
        }
    }
}
'@
Write-File (Join-Path $modesDir "ArenaMode.java") $arenaMode

# ============================================================
# S11-04: MODE PROGRESSION (Achievements + Titles)
# ============================================================
Write-Host "[S11-04] Creating ModeProgression..." -ForegroundColor Yellow

$progression = @'
package com.example.shinobicore.modes;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.HashMap;
import java.util.Map;

/**
 * S11-04: Mode progression system.
 * Tracks achievements, awards XP and titles.
 */
public class ModeProgression {
    private static final Map<String, AchievementDef> ACHIEVEMENTS = new HashMap<>();

    static {
        ACHIEVEMENTS.put("survival_first_wave", new AchievementDef("First Blood", 20, "Survivor"));
        ACHIEVEMENTS.put("survival_10_waves", new AchievementDef("Unbreakable", 200, "Iron Wall"));
        ACHIEVEMENTS.put("arena_first_win", new AchievementDef("First Victory", 50, "Champion"));
        ACHIEVEMENTS.put("gates_all_opened", new AchievementDef("Eight Gates", 300, "Gate Master"));
        ACHIEVEMENTS.put("survived_gate8", new AchievementDef("Death Defied", 500, "Immortal"));
    }

    public static void award(ServerPlayerEntity player, String achievementId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (data.getAchievements().contains(achievementId)) return;

        AchievementDef def = ACHIEVEMENTS.get(achievementId);
        if (def == null) return;

        data.getAchievements().add(achievementId);
        player.addExperience(def.xpReward);
        player.sendMessage(Text.literal("\u00a76\u2605 Achievement: " + def.name
            + " | Title: " + def.title + " | +" + def.xpReward + " XP"), false);
        ShinobiCore.LOGGER.info("[PROGRESSION] {} earned achievement: {}",
            player.getName().getString(), achievementId);
    }

    public static String getActiveTitle(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (data.getAchievements().contains("survived_gate8")) return "Immortal";
        if (data.getAchievements().contains("gates_all_opened")) return "Gate Master";
        if (data.getAchievements().contains("survival_10_waves")) return "Iron Wall";
        if (data.getAchievements().contains("arena_first_win")) return "Champion";
        if (data.getAchievements().contains("survival_first_wave")) return "Survivor";
        return "";
    }

    private static class AchievementDef {
        final String name;
        final int xpReward;
        final String title;
        AchievementDef(String name, int xp, String title) {
            this.name = name; this.xpReward = xp; this.title = title;
        }
    }
}
'@
Write-File (Join-Path $modesDir "ModeProgression.java") $progression

# ============================================================
# S11-01/02: ALTAR BLOCKS + BLOCK ENTITIES
# ============================================================
Write-Host "[S11-01/02] Creating altar blocks..." -ForegroundColor Yellow

$survivalAltarBlock = @'
package com.example.shinobicore.block;

import com.example.shinobicore.block.entity.SurvivalAltarBlockEntity;
import net.minecraft.block.BlockEntityProvider;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;

public class SurvivalAltarBlock extends net.minecraft.block.Block implements BlockEntityProvider {
    public SurvivalAltarBlock(Settings settings) { super(settings); }

    @Override
    public BlockEntity createBlockEntity(BlockPos pos, BlockState state) {
        return new SurvivalAltarBlockEntity(pos, state);
    }

    @Override
    public ActionResult onUse(BlockState state, World world, BlockPos pos,
                              PlayerEntity player, Hand hand, BlockHitResult hit) {
        if (world.isClient) return ActionResult.SUCCESS;
        BlockEntity be = world.getBlockEntity(pos);
        if (be instanceof SurvivalAltarBlockEntity altar) {
            altar.onPlayerInteract(player);
        }
        return ActionResult.SUCCESS;
    }
}
'@
Write-File (Join-Path $blockDir "SurvivalAltarBlock.java") $survivalAltarBlock

$survivalAltarBE = @'
package com.example.shinobicore.block.entity;

import com.example.shinobicore.modes.SurvivalMode;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import java.util.UUID;

public class SurvivalAltarBlockEntity extends BlockEntity {
    private boolean active = false;
    private int currentWave = 0;
    private int enemiesAlive = 0;
    private long cooldownUntil = 0;
    private UUID playerUuid = null;

    public SurvivalAltarBlockEntity(BlockPos pos, BlockState state) {
        super(ModBlockEntities.SURVIVAL_ALTAR, pos, state);
    }

    public void onPlayerInteract(PlayerEntity player) {
        if (!(player instanceof ServerPlayerEntity sp)) return;
        if (!(world instanceof ServerWorld sw)) return;

        if (active) {
            player.sendMessage(Text.literal("\u00a7cSurvival already active."), false);
            return;
        }
        long now = sw.getTime();
        if (now < cooldownUntil) {
            long remaining = (cooldownUntil - now) / 20;
            player.sendMessage(Text.literal("\u00a7cAltar on cooldown: " + remaining + "s"), false);
            return;
        }

        active = true;
        currentWave = 1;
        playerUuid = player.getUuid();
        SurvivalMode.startWave(sw, pos, currentWave, playerUuid);
    }

    public void onEnemyKilled() {
        enemiesAlive--;
        if (enemiesAlive <= 0 && active && world instanceof ServerWorld sw) {
            SurvivalMode.onWaveComplete(sw, pos, currentWave, playerUuid);
            if (currentWave >= SurvivalMode.MAX_WAVES) {
                active = false;
                cooldownUntil = sw.getTime() + SurvivalMode.ALTAR_COOLDOWN_TICKS;
            } else {
                currentWave++;
                SurvivalMode.startWave(sw, pos, currentWave, playerUuid);
            }
        }
    }

    public void onPlayerDeath() {
        if (active && world instanceof ServerWorld sw) {
            SurvivalMode.onPlayerDeath(sw, pos, playerUuid);
            active = false;
            cooldownUntil = sw.getTime() + SurvivalMode.ALTAR_COOLDOWN_TICKS;
        }
    }

    public boolean isActive() { return active; }
    public int getCurrentWave() { return currentWave; }

    @Override
    protected void writeNbt(NbtCompound nbt) {
        nbt.putBoolean("Active", active);
        nbt.putInt("Wave", currentWave);
        nbt.putLong("CooldownUntil", cooldownUntil);
        if (playerUuid != null) nbt.putUuid("Player", playerUuid);
    }

    @Override
    public void readNbt(NbtCompound nbt) {
        active = nbt.getBoolean("Active");
        currentWave = nbt.getInt("Wave");
        cooldownUntil = nbt.getLong("CooldownUntil");
        if (nbt.containsUuid("Player")) playerUuid = nbt.getUuid("Player");
    }
}
'@
Write-File (Join-Path $blockEntityDir "SurvivalAltarBlockEntity.java") $survivalAltarBE

$arenaAltarBlock = @'
package com.example.shinobicore.block;

import com.example.shinobicore.block.entity.ArenaAltarBlockEntity;
import net.minecraft.block.BlockEntityProvider;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;

public class ArenaAltarBlock extends net.minecraft.block.Block implements BlockEntityProvider {
    public ArenaAltarBlock(Settings settings) { super(settings); }

    @Override
    public BlockEntity createBlockEntity(BlockPos pos, BlockState state) {
        return new ArenaAltarBlockEntity(pos, state);
    }

    @Override
    public ActionResult onUse(BlockState state, World world, BlockPos pos,
                              PlayerEntity player, Hand hand, BlockHitResult hit) {
        if (world.isClient) return ActionResult.SUCCESS;
        BlockEntity be = world.getBlockEntity(pos);
        if (be instanceof ArenaAltarBlockEntity altar) {
            altar.onPlayerInteract(player);
        }
        return ActionResult.SUCCESS;
    }
}
'@
Write-File (Join-Path $blockDir "ArenaAltarBlock.java") $arenaAltarBlock

$arenaAltarBE = @'
package com.example.shinobicore.block.entity;

import com.example.shinobicore.modes.ArenaMode;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public class ArenaAltarBlockEntity extends BlockEntity {
    private boolean active = false;
    private int timerTicks = 0;
    private UUID player1 = null;
    private UUID player2 = null;
    private final List<UUID> waitingPlayers = new ArrayList<>();

    public ArenaAltarBlockEntity(BlockPos pos, BlockState state) {
        super(ModBlockEntities.ARENA_ALTAR, pos, state);
    }

    public void onPlayerInteract(PlayerEntity player) {
        if (!(player instanceof ServerPlayerEntity sp)) return;
        if (!(world instanceof ServerWorld sw)) return;

        if (active) {
            player.sendMessage(Text.literal("\u00a7cArena match in progress."), false);
            return;
        }

        waitingPlayers.add(player.getUuid());
        player.sendMessage(Text.literal("\u00a7eWaiting for opponent... (" + waitingPlayers.size() + "/2)"), false);

        if (waitingPlayers.size() >= 2) {
            player1 = waitingPlayers.get(0);
            player2 = waitingPlayers.get(1);
            waitingPlayers.clear();
            active = true;
            timerTicks = ArenaMode.MATCH_DURATION_TICKS;
            ArenaMode.startMatch(sw, pos, player1, player2);
        }
    }

    public void tick() {
        if (!active || !(world instanceof ServerWorld sw)) return;
        timerTicks--;
        if (timerTicks <= 0) {
            ArenaMode.onMatchEnd(sw, pos, player1, player2, true);
            active = false;
        }
    }

    public void onPlayerDeath(UUID deadPlayer) {
        if (!active || !(world instanceof ServerWorld sw)) return;
        UUID winner = deadPlayer.equals(player1) ? player2 : player1;
        ArenaMode.onMatchEnd(sw, pos, winner, deadPlayer, false);
        active = false;
    }

    public boolean isActive() { return active; }

    @Override
    protected void writeNbt(NbtCompound nbt) {
        nbt.putBoolean("Active", active);
        nbt.putInt("Timer", timerTicks);
        if (player1 != null) nbt.putUuid("P1", player1);
        if (player2 != null) nbt.putUuid("P2", player2);
    }

    @Override
    public void readNbt(NbtCompound nbt) {
        active = nbt.getBoolean("Active");
        timerTicks = nbt.getInt("Timer");
        if (nbt.containsUuid("P1")) player1 = nbt.getUuid("P1");
        if (nbt.containsUuid("P2")) player2 = nbt.getUuid("P2");
    }
}
'@
Write-File (Join-Path $blockEntityDir "ArenaAltarBlockEntity.java") $arenaAltarBE

# ============================================================
# TEXTURES + BLOCK MODELS
# ============================================================
Write-Host "[S11] Generating altar textures..." -ForegroundColor Yellow

if (-not (Test-Path $texBlockDir)) { New-Item -ItemType Directory -Path $texBlockDir -Force | Out-Null }

Add-Type -AssemblyName System.Drawing

# Survival altar texture (dark red/orange)
$survTex = New-Object System.Drawing.Bitmap(16, 16)
for ($x = 0; $x -lt 16; $x++) { for ($y = 0; $y -lt 16; $y++) {
    $noise = Get-Random -Minimum -10 -Maximum 10
    if (($x + $y) % 4 -lt 2) {
        $survTex.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255,
            [Math]::Max(0,[Math]::Min(255,140+$noise)), [Math]::Max(0,[Math]::Min(255,50+$noise)), [Math]::Max(0,[Math]::Min(255,20+$noise))))
    } else {
        $survTex.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255,
            [Math]::Max(0,[Math]::Min(255,100+$noise)), [Math]::Max(0,[Math]::Min(255,30+$noise)), [Math]::Max(0,[Math]::Min(255,15+$noise))))
    }
}}
$survTex.Save("$texBlockDir\survival_altar.png", [System.Drawing.Imaging.ImageFormat]::Png)
$survTex.Dispose()

# Arena altar texture (dark blue/purple)
$arenaTex = New-Object System.Drawing.Bitmap(16, 16)
for ($x = 0; $x -lt 16; $x++) { for ($y = 0; $y -lt 16; $y++) {
    $noise = Get-Random -Minimum -10 -Maximum 10
    if (($x + $y) % 4 -lt 2) {
        $arenaTex.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255,
            [Math]::Max(0,[Math]::Min(255,60+$noise)), [Math]::Max(0,[Math]::Min(255,40+$noise)), [Math]::Max(0,[Math]::Min(255,140+$noise))))
    } else {
        $arenaTex.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255,
            [Math]::Max(0,[Math]::Min(255,40+$noise)), [Math]::Max(0,[Math]::Min(255,25+$noise)), [Math]::Max(0,[Math]::Min(255,100+$noise))))
    }
}}
$arenaTex.Save("$texBlockDir\arena_altar.png", [System.Drawing.Imaging.ImageFormat]::Png)
$arenaTex.Dispose()

Write-Host "  [OK] Altar textures generated" -ForegroundColor Green

# Block model JSONs
foreach ($bn in @("survival_altar", "arena_altar")) {
    $bsContent = @"
{
    "variants": {
        "": { "model": "shinobicore:block/$bn" }
    }
}
"@
    Write-File (Join-Path $bsDir "$bn.json") $bsContent

    $modelContent = @"
{
    "parent": "minecraft:block/cube_all",
    "textures": {
        "all": "shinobicore:block/$bn"
    }
}
"@
    Write-File (Join-Path $mbDir "$bn.json") $modelContent

    $itemContent = @"
{
    "parent": "shinobicore:block/$bn"
}
"@
    Write-File (Join-Path $miDir "$bn.json") $itemContent
}

# ============================================================
# PATCHES
# ============================================================
Write-Host ""
Write-Host "[REG] Patching registration files..." -ForegroundColor Yellow

# ModPackets.java
$modPacketsFile = Join-Path $srcBase "network\ModPackets.java"
Patch-File $modPacketsFile `
    "public static final Identifier SHARINGAN_SYNC_ID = new Identifier(`"shinobicore`", `"sharingan_sync`");" `
    "public static final Identifier SHARINGAN_SYNC_ID = new Identifier(`"shinobicore`", `"sharingan_sync`");`n    public static final Identifier GATE_ACTIVATE_ID = new Identifier(`"shinobicore`", `"gate_activate`");`n    public static final Identifier GATE_DEACTIVATE_ID = new Identifier(`"shinobicore`", `"gate_deactivate`");`n    public static final Identifier GATE_SYNC_ID = new Identifier(`"shinobicore`", `"gate_sync`");"

# KeyBindings.java
$keyBindingsFile = Join-Path $srcBase "client\KeyBindings.java"
Patch-File $keyBindingsFile `
    "public static KeyBinding TOGGLE_SHARINGAN;" `
    "public static KeyBinding TOGGLE_SHARINGAN;`n    public static KeyBinding CLOSE_GATES;"

Patch-File $keyBindingsFile `
    "TOGGLE_SHARINGAN = KeyBindingHelper.registerKeyBinding(new KeyBinding(" `
    "CLOSE_GATES = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n                `"key.shinobicore.close_gates`", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, CATEGORY));`n        TOGGLE_SHARINGAN = KeyBindingHelper.registerKeyBinding(new KeyBinding("

# ClientInputHandler.java — replace chakra toggle with hold-based gate activation
$inputFile = Join-Path $srcBase "client\ClientInputHandler.java"
Patch-File $inputFile `
    "if (KeyBindings.TOGGLE_CHAKRA_MODE.wasPressed()) {" `
    "// S11-03: Gate activation via hold`n        if (KeyBindings.TOGGLE_CHAKRA_MODE.isPressed()) {`n            chakraHoldTicks++;`n            if (chakraHoldTicks >= 100 && !gateActivationSent) {`n                if (client.getNetworkHandler() != null) {`n                    PacketByteBuf gBuf = new PacketByteBuf(Unpooled.buffer());`n                    ClientPlayNetworking.send(ModPackets.GATE_ACTIVATE_ID, gBuf);`n                    gateActivationSent = true;`n                }`n            }`n        } else {`n            if (chakraHoldTicks > 0 && chakraHoldTicks < 100 && !gateActivationSent) {`n                if (client.getNetworkHandler() != null) {`n                    PacketByteBuf cBuf = new PacketByteBuf(Unpooled.buffer());`n                    ClientPlayNetworking.send(ModPackets.TOGGLE_CHAKRA_MODE_ID, cBuf);`n                }`n            }`n            chakraHoldTicks = 0;`n            gateActivationSent = false;`n        }`n        // S11-03: Gate deactivation via M hold`n        if (KeyBindings.CLOSE_GATES.isPressed()) {`n            gateCloseHoldTicks++;`n            if (gateCloseHoldTicks >= 100) {`n                if (client.getNetworkHandler() != null) {`n                    PacketByteBuf dBuf = new PacketByteBuf(Unpooled.buffer());`n                    ClientPlayNetworking.send(ModPackets.GATE_DEACTIVATE_ID, dBuf);`n                }`n                gateCloseHoldTicks = 0;`n            }`n        } else {`n            gateCloseHoldTicks = 0;`n        }`n        if (false) {"

# Add static fields to ClientInputHandler
Patch-File $inputFile `
    "public class ClientInputHandler {" `
    "public class ClientInputHandler {`n    private static int chakraHoldTicks = 0;`n    private static int gateCloseHoldTicks = 0;`n    private static boolean gateActivationSent = false;"

# NinjaPlayerData.java — add gate/mode/achievement fields
$ninjaDataFile = Join-Path $srcBase "stat\NinjaPlayerData.java"
Patch-File $ninjaDataFile `
    "private boolean teacherInteracted = false;" `
    "private boolean teacherInteracted = false;`n    private int activeGate = 0;`n    private int gate8RemainingTicks = 0;`n    private int gateCooldownTicks = 0;`n    private int survivalBestWave = 0;`n    private int arenaWins = 0;`n    private final java.util.Set<String> achievements = new java.util.HashSet<>();"

Patch-File $ninjaDataFile `
    "public void setTeacherInteracted(boolean v) { this.teacherInteracted = v; statsDirty = true; }" `
    "public void setTeacherInteracted(boolean v) { this.teacherInteracted = v; statsDirty = true; }`n    public int getActiveGate() { return activeGate; }`n    public void setActiveGate(int v) { this.activeGate = v; }`n    public int getGate8RemainingTicks() { return gate8RemainingTicks; }`n    public void setGate8RemainingTicks(int v) { this.gate8RemainingTicks = v; }`n    public int getGateCooldownTicks() { return gateCooldownTicks; }`n    public void setGateCooldownTicks(int v) { this.gateCooldownTicks = v; }`n    public int getSurvivalBestWave() { return survivalBestWave; }`n    public void setSurvivalBestWave(int v) { this.survivalBestWave = v; }`n    public int getArenaWins() { return arenaWins; }`n    public void setArenaWins(int v) { this.arenaWins = v; }`n    public java.util.Set<String> getAchievements() { return achievements; }"

# NinjaTickHandler.java — add gates tick
$tickFile = Join-Path $srcBase "event\NinjaTickHandler.java"
Patch-File $tickFile `
    "// === S7-05: Chakra altar regen tick ===" `
    "// === S11-03: Gates tick ===`n            com.example.shinobicore.modes.GatesManager.tick(player);`n            // === S7-05: Chakra altar regen tick ==="

# ModBlocks.java — register altar blocks
$modBlocksFile = Join-Path $srcBase "block\ModBlocks.java"
Patch-File $modBlocksFile `
    "public static void register() {" `
    "public static final Block SURVIVAL_ALTAR = register(`"survival_altar`",`n        new SurvivalAltarBlock(FabricBlockSettings.copyOf(Blocks.STONE).luminance(state -> 6)));`n    public static final Block ARENA_ALTAR = register(`"arena_altar`",`n        new ArenaAltarBlock(FabricBlockSettings.copyOf(Blocks.STONE).luminance(state -> 6)));`n`n    public static void register() {"

Patch-File $modBlocksFile `
    "registerBlockItem(`"chakra_altar`", CHAKRA_ALTAR);" `
    "registerBlockItem(`"chakra_altar`", CHAKRA_ALTAR);`n        registerBlockItem(`"survival_altar`", SURVIVAL_ALTAR);`n        registerBlockItem(`"arena_altar`", ARENA_ALTAR);"

# ModBlockEntities.java — register altar block entities
$modBEFile = Join-Path $srcBase "block\entity\ModBlockEntities.java"
Patch-File $modBEFile `
    "public static void register() {" `
    "public static final BlockEntityType<SurvivalAltarBlockEntity> SURVIVAL_ALTAR =`n        Registry.register(Registries.BLOCK_ENTITY_TYPE,`n            new Identifier(ShinobiCore.MOD_ID, `"survival_altar`"),`n            BlockEntityType.Builder.create(SurvivalAltarBlockEntity::new, ModBlocks.SURVIVAL_ALTAR).build(null));`n`n    public static final BlockEntityType<ArenaAltarBlockEntity> ARENA_ALTAR =`n        Registry.register(Registries.BLOCK_ENTITY_TYPE,`n            new Identifier(ShinobiCore.MOD_ID, `"arena_altar`"),`n            BlockEntityType.Builder.create(ArenaAltarBlockEntity::new, ModBlocks.ARENA_ALTAR).build(null));`n`n    public static void register() {"

# ShinobiCore.java — register gate packet handlers
$shinobiCoreFile = Join-Path $srcBase "ShinobiCore.java"
Patch-File $shinobiCoreFile `
    "// Sharingan toggle handler (C2S)" `
    "// S11-03: Gate activation handler (C2S)`n        net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.registerGlobalReceiver(`n            ModPackets.GATE_ACTIVATE_ID, (server, player, handler, buf, responseSender) -> {`n            server.execute(() -> {`n                com.example.shinobicore.modes.GatesManager.activateNextGate(player);`n            });`n        });`n        // S11-03: Gate deactivation handler (C2S)`n        net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.registerGlobalReceiver(`n            ModPackets.GATE_DEACTIVATE_ID, (server, player, handler, buf, responseSender) -> {`n            server.execute(() -> {`n                com.example.shinobicore.modes.GatesManager.deactivateGate(player);`n            });`n        });`n        // Sharingan toggle handler (C2S)"

# ShinobiCoreClient.java — register gate sync receiver
$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"
Patch-File $clientFile `
    "import com.example.shinobicore.client.dojutsu.SharinganClientState;" `
    "import com.example.shinobicore.client.dojutsu.SharinganClientState;`nimport com.example.shinobicore.client.modes.GateClientState;"

# Lang files
$enLangFile = Join-Path $resBase "assets\shinobicore\lang\en_us.json"
$enContent = [System.IO.File]::ReadAllText($enLangFile, $utf8)
if (-not $enContent.Contains("block.shinobicore.survival_altar")) {
    $insert = '"block.shinobicore.survival_altar": "Survival Altar",
    "block.shinobicore.arena_altar": "Arena Altar",
    "key.shinobicore.close_gates": "Close Gates (Hold M)",
    "key.categories.shinobicore": "ShinobiCore",'
    $enContent = $enContent.Replace('"key.categories.shinobicore": "ShinobiCore",', $insert)
    [System.IO.File]::WriteAllText($enLangFile, $enContent, $utf8)
    Write-Host "  [PATCH] en_us.json updated" -ForegroundColor Green
}

$ruLangFile = Join-Path $resBase "assets\shinobicore\lang\ru_ru.json"
$ruContent = [System.IO.File]::ReadAllText($ruLangFile, $utf8)
if (-not $ruContent.Contains("block.shinobicore.survival_altar")) {
    $ruInsert = '"block.shinobicore.survival_altar": "Алтарь Выживания",
    "block.shinobicore.arena_altar": "Алтарь Арены",
    "key.shinobicore.close_gates": "Закрыть Врата (M)",
    "key.categories.shinobicore": "ShinobiCore",'
    $ruContent = $ruContent.Replace('"key.categories.shinobicore": "ShinobiCore",', $ruInsert)
    [System.IO.File]::WriteAllText($ruLangFile, $ruContent, $utf8)
    Write-Host "  [PATCH] ru_ru.json updated" -ForegroundColor Green
}

# ============================================================
# CREATE GateClientState (client-side gate display)
# ============================================================
Write-Host "[S11-03] Creating GateClientState..." -ForegroundColor Yellow

$gateClientState = @'
package com.example.shinobicore.client.modes;

/**
 * S11-03: Client-side gate state for HUD display.
 */
public class GateClientState {
    public static int activeGate = 0;
    public static int gate8RemainingTicks = 0;
    public static int gateCooldownTicks = 0;

    public static void clear() {
        activeGate = 0;
        gate8RemainingTicks = 0;
        gateCooldownTicks = 0;
    }
}
'@
$clientModesDir = Join-Path $srcBase "client\modes"
Write-File (Join-Path $clientModesDir "GateClientState.java") $gateClientState

# Register gate sync receiver in ShinobiCoreClient
Patch-File $clientFile `
    "// Sharingan sync receiver" `
    "// S11-03: Gate sync receiver`n        ClientPlayNetworking.registerGlobalReceiver(ModPackets.GATE_SYNC_ID, (client, handler, buf, responseSender) -> {`n            int gate = buf.readInt();`n            int g8ticks = buf.readInt();`n            int cd = buf.readInt();`n            client.execute(() -> {`n                com.example.shinobicore.client.modes.GateClientState.activeGate = gate;`n                com.example.shinobicore.client.modes.GateClientState.gate8RemainingTicks = g8ticks;`n                com.example.shinobicore.client.modes.GateClientState.gateCooldownTicks = cd;`n            });`n        });`n        // Sharingan sync receiver"

# Cleanup on disconnect
Patch-File $clientFile `
    "SharinganClientState.clear();" `
    "SharinganClientState.clear();`n        com.example.shinobicore.client.modes.GateClientState.clear();"

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 25 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    }
} finally { Pop-Location }

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 11 COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - modes/GatesManager.java (S11-03: 8 Gates logic)" -ForegroundColor Cyan
Write-Host "  - modes/SurvivalMode.java (S11-01: wave survival)" -ForegroundColor Cyan
Write-Host "  - modes/ArenaMode.java (S11-02: PvP arena)" -ForegroundColor Cyan
Write-Host "  - modes/ModeProgression.java (S11-04: achievements)" -ForegroundColor Cyan
Write-Host "  - block/SurvivalAltarBlock.java (S11-01: altar block)" -ForegroundColor Cyan
Write-Host "  - block/entity/SurvivalAltarBlockEntity.java" -ForegroundColor Cyan
Write-Host "  - block/ArenaAltarBlock.java (S11-02: altar block)" -ForegroundColor Cyan
Write-Host "  - block/entity/ArenaAltarBlockEntity.java" -ForegroundColor Cyan
Write-Host "  - client/modes/GateClientState.java (client HUD state)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Gate Buffs:" -ForegroundColor White
Write-Host "  Gate 1: +20% atk/dmg/spd | Gate 4: +110% | Gate 7: +200%" -ForegroundColor Yellow
Write-Host "  Gate 8: +500% atk/dmg, +65% spd, 3 min, no exit" -ForegroundColor Yellow
Write-Host ""
Write-Host "Controls:" -ForegroundColor White
Write-Host "  Hold C 5s: activate next gate" -ForegroundColor Yellow
Write-Host "  Hold M 5s: deactivate current gate (not gate 8)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Achievements:" -ForegroundColor White
Write-Host "  First Blood, Unbreakable, First Victory, Eight Gates, Death Defied" -ForegroundColor Yellow
Write-Host ""