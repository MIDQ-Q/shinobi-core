package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.FormDefinition;
import net.minecraft.block.BlockState;
import net.minecraft.block.Blocks;
import net.minecraft.registry.Registries;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import java.util.*;

public class ConstructSystem {
    private static class Construct {
        final ServerWorld world; final Map<BlockPos, BlockState> original = new HashMap<>(); int duration;
        Construct(ServerWorld world, int duration) { this.world = world; this.duration = duration; }
    }
    private static final List<Construct> ACTIVE = new ArrayList<>();
    public static void start(CastContext ctx, FormDefinition form) {
        ServerWorld world = ctx.world();
        Vec3d look0 = ctx.caster.getRotationVector();
        Vec3d flat = new Vec3d(look0.x, 0, look0.z);
        if (flat.lengthSquared() < 0.001) flat = new Vec3d(0, 0, 1);
        flat = flat.normalize();
        Vec3d center = ctx.caster.getPos().add(flat.multiply(3));
        BlockPos base = BlockPos.ofFloored(center);
        int w = form.getInt("width", 5);
        int h = form.getInt("height", 3);
        int d = form.getInt("depth", 1);
        int duration = form.getInt("duration", 200);
        String shape = form.getString("shape", "wall");
        String blockType = form.getString("blockType", "earth");
        boolean permanent = ctx.hasProp("permanent");
        BlockState state = resolveBlock(blockType);
        Construct c = new Construct(world, permanent ? Integer.MAX_VALUE : duration);
        List<BlockPos> positions = generateShape(base, w, h, d, shape, flat);
        for (BlockPos p : positions) {
            if (world.getBlockState(p).isAir() || world.getBlockState(p).isReplaceable()) {
                c.original.put(p, world.getBlockState(p));
                world.setBlockState(p, state, 3);
            }
        }
        ACTIVE.add(c);
        Fx.elementBurst(world, center, ctx.jutsu.getElement(), 25);
        JutsuSoundHelper.playCastSound(ctx.caster, ctx.jutsu);
    }
    private static List<BlockPos> generateShape(BlockPos base, int w, int h, int d, String shape, Vec3d look) {
        List<BlockPos> r = new ArrayList<>();
        double ax = Math.abs(look.x), az = Math.abs(look.z);
        boolean faceX = az >= ax;
        for (int yy = 0; yy < h; yy++) for (int i = -w / 2; i <= w / 2; i++) for (int j = -d / 2; j <= d / 2; j++) {
            int dx, dz;
            if (shape.equals("wall")) { dx = faceX ? i : j; dz = faceX ? j : i; }
            else if (shape.equals("pillar")) { if (i == 0 && j == 0) { dx = 0; dz = 0; } else continue; }
            else if (shape.equals("platform")) { if (yy != 0) continue; dx = i; dz = j; }
            else if (shape.equals("dome")) { if (i*i + j*j > (w/2.0)*(w/2.0)) continue; dx = i; dz = j; }
            else if (shape.equals("cage")) {
                boolean onEdge = (Math.abs(i) == w/2) || (Math.abs(j) == d/2);
                if (!onEdge) continue;
                dx = i; dz = j;
            }
            else { dx = i; dz = j; }
            r.add(base.add(dx, yy, dz));
        }
        return r;
    }
    private static BlockState resolveBlock(String blockType) {
        return switch (blockType) {
            case "earth" -> Blocks.DIRT.getDefaultState();
            case "stone" -> Blocks.STONE.getDefaultState();
            case "ice" -> Blocks.ICE.getDefaultState();
            case "wood" -> Blocks.OAK_PLANKS.getDefaultState();
            default -> {
                var opt = Registries.BLOCK.getOrEmpty(new Identifier(blockType));
                yield opt.map(b -> b.getDefaultState()).orElse(Blocks.STONE.getDefaultState());
            }
        };
    }
    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Construct> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Construct c = it.next();
            if (c.duration == Integer.MAX_VALUE) continue;
            c.duration--;
            if (c.duration <= 0) {
                for (Map.Entry<BlockPos, BlockState> e : c.original.entrySet()) {
                    if (c.world.getBlockState(e.getKey()) != e.getValue()) c.world.setBlockState(e.getKey(), e.getValue(), 3);
                }
                it.remove();
            }
        }
    }
}