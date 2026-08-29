package com.example.shinobicore.entity;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.ai.goal.LookAroundGoal;
import net.minecraft.entity.ai.goal.LookAtEntityGoal;
import net.minecraft.entity.ai.goal.SwimGoal;
import net.minecraft.entity.mob.PathAwareEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.world.World;

/**
 * S7-08: Samurai teacher NPC.
 * Steve model with samurai skin. Grants teacher approval for S-rank nodes.
 */
public class SamuraiTeacherEntity extends PathAwareEntity {

    public SamuraiTeacherEntity(EntityType<? extends PathAwareEntity> entityType, World world) {
        super(entityType, world);
    }

    @Override
    protected void initGoals() {
        this.goalSelector.add(0, new SwimGoal(this));
        this.goalSelector.add(1, new LookAtEntityGoal(this, PlayerEntity.class, 8.0f));
        this.goalSelector.add(2, new LookAroundGoal(this));
    }

    @Override
    public ActionResult interactMob(PlayerEntity player, Hand hand) {
        if (this.getWorld().isClient) return ActionResult.SUCCESS;

        if (player instanceof ServerPlayerEntity sp) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

            // Grant teacher approval for S-rank nodes
            // The specific node IDs would be determined by the skill tree
            player.sendMessage(Text.literal("\u00a76\u2694 Samurai Teacher: \"I shall teach you the forbidden arts.\""), false);
            player.sendMessage(Text.literal("\u00a77Check your skill tree for newly available techniques."), false);

            // Mark teacher as interacted (for tree unlock logic)
            data.setTeacherInteracted(true);
            com.example.shinobicore.ShinobiCore.sendTreeSync(sp);
        }

        return ActionResult.SUCCESS;
    }

    @Override
    public boolean cannotDespawn() {
        return true;
    }
}