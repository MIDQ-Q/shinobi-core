package com.example.shinobicore.parkour;

import com.example.shinobicore.combat.ParkourActions;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.IParkourComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.stat.component.NinjaPose;
import net.minecraft.block.BlockState;
import net.minecraft.block.Blocks;
import net.minecraft.entity.EntityPose;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

public class ParkourServerHandler {

    private static final float WALL_WALK_SPEED_MULT = 0.8f;
    private static final float SLIDE_BOOST = 0.45f;
    private static final int SLIDE_DURATION = 15;
    private static final int SLIDE_CHAKRA_DURATION = 25;

    public static void handleAction(ServerPlayerEntity player, int action, float yaw) {
        IParkourComponent parkour = NinjaComponents.getParkour(player);
        if (parkour == null) return;
        switch (action) {
            case ParkourActions.DOUBLE_JUMP -> handleDoubleJump(player, parkour, yaw);
            case ParkourActions.DASH -> handleDodge(player, parkour, yaw);
            case ParkourActions.CRAWL -> handleCrawl(player, parkour);
            case ParkourActions.SLIDE -> handleSlide(player, parkour, yaw);
            case ParkourActions.WALL_WALK -> handleWallWalkAction(player, parkour);
            case ParkourActions.WALL_JUMP -> handleWallJump(player, parkour);
        }
    }

    // === DOUBLE JUMP ===
    private static void handleDoubleJump(ServerPlayerEntity player, IParkourComponent parkour, float yaw) {
        if (player.isOnGround() || player.getVelocity().y > 0.0) return;
        if (parkour.getJumpsLeft() <= 0) return;
        parkour.setJumpsLeft(parkour.getJumpsLeft() - 1);
        float jumpY = 0.95f;
        float forwardBoost = 1.3f;
        Vec3d vel = player.getVelocity();
        float rad = yaw * 0.017453292F;
        double boostX = -Math.sin(rad) * forwardBoost;
        double boostZ = Math.cos(rad) * forwardBoost;
        player.setVelocity((vel.x * 0.5) + boostX, jumpY, (vel.z * 0.5) + boostZ);
        player.velocityModified = true;
        NinjaComponents.PARKOUR.sync(player, parkour);
    }

    // === DODGE ===
    private static void handleDodge(ServerPlayerEntity player, IParkourComponent parkour, float yaw) {
        if (parkour.getDodgeCooldown() > 0) return;
        if (parkour.getCurrentPose() == NinjaPose.DODGING) return;
        parkour.setCurrentPose(NinjaPose.DODGING);
        parkour.setDodgeCooldown(30);
        parkour.setIframeTicks(8);
        player.setPose(EntityPose.SWIMMING);
        float rad = yaw * 0.017453292F;
        float dashStrength = 1.8f;
        float dashHeight = 0.4f;
        Vec3d dashVel = new Vec3d(-Math.sin(rad) * dashStrength, dashHeight, Math.cos(rad) * dashStrength);
        player.setVelocity(dashVel.x, dashVel.y, dashVel.z);
        player.velocityModified = true;
        NinjaComponents.PARKOUR.sync(player, parkour);
    }

    // === CRAWL ===
    private static void handleCrawl(ServerPlayerEntity player, IParkourComponent parkour) {
        if (parkour.getCurrentPose() == NinjaPose.CRAWLING) {
            parkour.setCurrentPose(NinjaPose.NORMAL);
            if (player.getPose() == EntityPose.SWIMMING) {
                player.setPose(EntityPose.STANDING);
            }
        } else {
            parkour.setCurrentPose(NinjaPose.CRAWLING);
            player.setPose(EntityPose.SWIMMING);
        }
        NinjaComponents.PARKOUR.sync(player, parkour);
    }

    // === SLIDE ===
    private static void handleSlide(ServerPlayerEntity player, IParkourComponent parkour, float yaw) {
        if (parkour.getCurrentPose() == NinjaPose.SLIDING) return;
        if (!player.isOnGround()) return;
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        boolean chakraMode = chakra != null && chakra.isChakraMode();
        parkour.setCurrentPose(NinjaPose.SLIDING);
        player.setPose(EntityPose.SWIMMING);
        float rad = yaw * 0.017453292F;
        float boost = chakraMode ? SLIDE_BOOST * 1.8f : SLIDE_BOOST;
        Vec3d slideVel = new Vec3d(-Math.sin(rad) * boost, 0.0, Math.cos(rad) * boost);
        player.setVelocity(player.getVelocity().x + slideVel.x, 0.0, player.getVelocity().z + slideVel.z);
        player.velocityModified = true;
        int duration = chakraMode ? SLIDE_CHAKRA_DURATION : SLIDE_DURATION;
        parkour.setIframeTicks(duration);
        NinjaComponents.PARKOUR.sync(player, parkour);
    }

    // === WALL WALK (pose sync only, physics on client) ===
    private static void handleWallWalkAction(ServerPlayerEntity player, IParkourComponent parkour) {
        if (parkour.getCurrentPose() != NinjaPose.WALL_WALKING) {
            parkour.setCurrentPose(NinjaPose.WALL_WALKING);
            NinjaComponents.PARKOUR.sync(player, parkour);
        }
    }

    // === WALL JUMP (client already applied velocity) ===
    private static void handleWallJump(ServerPlayerEntity player, IParkourComponent parkour) {
        parkour.setCurrentPose(NinjaPose.AIRBORNE);
        parkour.resetJumps();
        NinjaComponents.PARKOUR.sync(player, parkour);
        // NO setVelocity here - client is authoritative
    }

    // === MAIN TICK ===
    public static void tick(ServerPlayerEntity player) {
        IParkourComponent parkour = NinjaComponents.getParkour(player);
        if (parkour == null) return;
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        boolean chakraMode = chakra != null && chakra.isChakraMode() && chakra.getCurrentChakra() > 0;

        // --- GROUND RESET ---
        if (player.isOnGround() && parkour.getJumpsLeft() < 3) {
            parkour.resetJumps();
            if (parkour.getCurrentPose() != NinjaPose.CRAWLING
                && parkour.getCurrentPose() != NinjaPose.WATER_WALKING
                && parkour.getCurrentPose() != NinjaPose.SLIDING) {
                parkour.setCurrentPose(NinjaPose.NORMAL);
                if (player.getPose() == EntityPose.SWIMMING) {
                    player.setPose(EntityPose.STANDING);
                }
            }
        }

        // --- COOLDOWNS ---
        if (parkour.getDodgeCooldown() > 0) parkour.setDodgeCooldown(parkour.getDodgeCooldown() - 1);

        // --- SLIDE TIMER ---
        if (parkour.getCurrentPose() == NinjaPose.SLIDING) {
            if (parkour.getIframeTicks() > 0) {
                parkour.setIframeTicks(parkour.getIframeTicks() - 1);
                if (player.getPose() != EntityPose.SWIMMING) {
                    player.setPose(EntityPose.SWIMMING);
                }
            } else {
                parkour.setCurrentPose(NinjaPose.NORMAL);
                if (player.getPose() == EntityPose.SWIMMING) {
                    player.setPose(EntityPose.STANDING);
                }
            }
        }

        // --- DODGE IFRAMES ---
        if (parkour.getIframeTicks() > 0 && parkour.getCurrentPose() == NinjaPose.DODGING) {
            parkour.setIframeTicks(parkour.getIframeTicks() - 1);
            if (parkour.getIframeTicks() == 0) {
                parkour.setCurrentPose(NinjaPose.NORMAL);
                if (player.getPose() == EntityPose.SWIMMING) {
                    player.setPose(EntityPose.STANDING);
                }
            }
        }

        // --- WALL WALKING (SHINOBI_V1_WALL_PHYSICS: client-authoritative) ---
        // Server syncs pose, drains chakra, and prevents rubberbanding by cancelling gravity.
        if (chakraMode && parkour.getCurrentPose() == NinjaPose.WALL_WALKING) {
            chakra.spendChakra(0.075f);
            player.fallDistance = 0.0f;
            
            // SERVER-SIDE GRAVITY CANCELLATION (Prevents rubberbanding)
            if (player.horizontalCollision && !player.isOnGround()) {
                Vec3d vel = player.getVelocity();
                if (vel.y < -0.05) {
                    player.setVelocity(vel.x, -0.05, vel.z);
                    player.velocityModified = true;
                }
            }

            if (chakra.getCurrentChakra() <= 0) {
                parkour.setCurrentPose(NinjaPose.NORMAL);
            }
        } else if (!chakraMode && parkour.getCurrentPose() == NinjaPose.WALL_WALKING) {
            parkour.setCurrentPose(NinjaPose.NORMAL);
        }

        // --- WATER WALKING ---
        if (chakraMode && parkour.getCurrentPose() != NinjaPose.CRAWLING
            && parkour.getCurrentPose() != NinjaPose.WALL_WALKING) {
            BlockPos belowPos = player.getBlockPos().down();
            BlockState below = player.getWorld().getBlockState(belowPos);
            boolean isWater = below.isOf(Blocks.WATER);
            boolean isOnSurface = player.getY() >= belowPos.getY() + 0.85
                && player.getY() <= belowPos.getY() + 1.15;
            boolean isFallingOrStill = player.getVelocity().y <= 0.05;
            if (isWater && isOnSurface && isFallingOrStill && !player.isSwimming()) {
                Vec3d vel = player.getVelocity();
                if (vel.y < 0.0) {
                    player.setVelocity(vel.x, 0.0, vel.z);
                    player.velocityModified = true;
                }
                player.fallDistance = 0.0f;
                chakra.spendChakra(0.05f);
                if (chakra.getCurrentChakra() <= 0.0f) {
                    parkour.setCurrentPose(NinjaPose.NORMAL);
                } else {
                    parkour.setCurrentPose(NinjaPose.WATER_WALKING);
                }
            } else if (parkour.getCurrentPose() == NinjaPose.WATER_WALKING) {
                parkour.setCurrentPose(NinjaPose.NORMAL);
            }
        }

        // --- CRAWLING MAINTENANCE ---
        if (parkour.getCurrentPose() == NinjaPose.CRAWLING) {
            if (player.getPose() != EntityPose.SWIMMING) {
                player.setPose(EntityPose.SWIMMING);
            }
        }

        NinjaComponents.PARKOUR.sync(player, parkour);
    }

    // === HELPER: Get wall normal via raycast ===
    private static Vec3d getWallNormal(ServerPlayerEntity player) {
        net.minecraft.world.World world = player.getWorld();
        Vec3d eye = player.getEyePos();
        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
        for (int[] d : dirs) {
            Vec3d dir = new Vec3d(d[0], 0, d[1]);
            Vec3d end = eye.add(dir.multiply(0.6));
            net.minecraft.util.hit.BlockHitResult hit = world.raycast(
                new net.minecraft.world.RaycastContext(
                    eye, end,
                    net.minecraft.world.RaycastContext.ShapeType.COLLIDER,
                    net.minecraft.world.RaycastContext.FluidHandling.NONE,
                    player
                )
            );
            if (hit.getType() == net.minecraft.util.hit.HitResult.Type.BLOCK) {
                return new Vec3d(-d[0], 0, -d[1]).normalize();
            }
        }
        return null;
    }
}