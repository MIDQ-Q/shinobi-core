package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.BlockState;
import net.minecraft.block.Blocks;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Direction;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

public class WallBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        // Стена только на земле
        if (!player.isOnGround()) {
            player.sendMessage(Text.literal("§cYou must be on the ground to create a wall!"), false);
            return;
        }

        int width = params.has("width") ? params.get("width").getAsInt() : 3;
        int height = params.has("height") ? params.get("height").getAsInt() : 3;
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;
        String blockType = params.has("block") ? params.get("block").getAsString() : "earth";

        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        // === ИСПРАВЛЕНО: используем вектор взгляда напрямую для диагональных направлений ===
        Vec3d look = player.getRotationVector();
        look = new Vec3d(look.x, 0, look.z).normalize();

        // Позиция перед игроком (2 блока вперёд)
        BlockPos centerPos = player.getBlockPos().add(
                (int) Math.round(look.x * 2),
                0,
                (int) Math.round(look.z * 2)
        );

        // === ИСПРАВЛЕНО: перпендикуляр через векторное произведение ===
        // Это работает для ЛЮБОГО направления, включая диагонали
        Vec3d up = new Vec3d(0, 1, 0);
        Vec3d perpendicular = look.crossProduct(up).normalize();

        // Блок для стены
        BlockState wallBlock = switch (blockType) {
            case "earth" -> Blocks.DIRT.getDefaultState();
            case "stone" -> Blocks.STONE.getDefaultState();
            case "cobblestone" -> Blocks.COBBLESTONE.getDefaultState();
            case "ice" -> Blocks.PACKED_ICE.getDefaultState();
            case "water" -> Blocks.ICE.getDefaultState();
            default -> Blocks.DIRT.getDefaultState();
        };

        // === ЛОГИРОВАНИЕ: параметры стены ===
        ShinobiCore.LOGGER.info("[WALL] Cast: width={}, height={}, lifetime={}, block={}, look=({}, {}), perp=({}, {})",
                width, height, lifetime, blockType,
                String.format("%.2f", look.x), String.format("%.2f", look.z),
                String.format("%.2f", perpendicular.x), String.format("%.2f", perpendicular.z));

        // Создаём стену
        List<BlockPos> placedBlocks = new ArrayList<>();
        int halfWidth = width / 2;

        for (int w = -halfWidth; w <= halfWidth; w++) {
            for (int h = 0; h < height; h++) {
                // === ИСПРАВЛЕНО: используем вектор перпендикуляра напрямую ===
                BlockPos pos = centerPos.add(
                        (int) Math.round(perpendicular.x * w),
                        h,
                        (int) Math.round(perpendicular.z * w)
                );

                // Проверяем что блок пустой
                if (serverWorld.getBlockState(pos).isAir()) {
                    serverWorld.setBlockState(pos, wallBlock, 3);
                    placedBlocks.add(pos);
                }
            }
        }

        // Планируем удаление стены через lifetime тиков
        if (!placedBlocks.isEmpty()) {
            WallRemovalTask.schedule(serverWorld, placedBlocks, lifetime);
            ShinobiCore.LOGGER.info("[WALL] Created wall with {} blocks, lifetime={} ticks",
                    placedBlocks.size(), lifetime);
        }
    }
}