package com.example.shinobicore.client.ui.widgets;

import com.example.shinobicore.client.CastingClientState;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.HandSignsClientState;
import com.example.shinobicore.client.ui.HudConfig;
import com.example.shinobicore.client.ui.HudWidget;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

/**
 * S3-03: Cast bar indicator below crosshair.
 * Shows: progress, tier, charge level, interruptibility, cost.
 * Only visible during active casting.
 */
public class CastBarWidget extends HudWidget {

    private static final int BAR_WIDTH = 140;
    private static final int BAR_HEIGHT = 8;

    private static final int BAR_BG = 0xFF222222;
    private static final int BAR_BORDER = 0xFF000000;
    private static final int FILL_NORMAL = 0xFFFFAA00;
    private static final int FILL_CHARGE = 0xFF44AAFF;
    private static final int FILL_INTERRUPT = 0xFFFF4444;

    // Tier colors
    private static final int[] TIER_COLORS = {
        0xFFAAAAAA, // T0 fallback
        0xFF88CC88, // T1 - green
        0xFF88AACC, // T2 - blue
        0xFFCCAA44, // T3 - gold
        0xFFCC6644, // T4 - orange
        0xFFFF4444  // T5 - red
    };

    public CastBarWidget() {
        super("cast_bar");
    }

    @Override
    public int getPriority() { return 50; }

    @Override
    public boolean shouldRender(MinecraftClient client) {
        if (!HudConfig.instance.showCastBar) return false;
        if (client.player == null) return false;
        // Show if currently casting
        HandSignsClientState.ActiveSigns signs = HandSignsClientState.get(client.player.getId());
        return signs != null;
    }

    @Override
    public void render(DrawContext ctx, MinecraftClient client, float tickDelta) {
        if (client.player == null) return;

        HandSignsClientState.ActiveSigns signs = HandSignsClientState.get(client.player.getId());
        if (signs == null) return;

        float progress = signs.getProgress();
        String jutsuId = signs.jutsuId;
        String name = ClientNinjaState.name(jutsuId);

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

        // Position: below crosshair
        int barX = (sw - BAR_WIDTH) / 2 + HudConfig.instance.hudOffsetX;
        int barY = sh / 2 + 30 + HudConfig.instance.hudOffsetY;

        // Determine fill color based on state
        int fillColor = FILL_NORMAL;
        boolean isCharging = false;
        boolean isInterruptible = true;

        // Try to get jutsu definition for tier info
        JutsuDefinition def = null;
        try {
            def = JutsuRegistry.get(jutsuId);
        } catch (Exception e) {
            // Registry might not be available on client
        }

        int tier = 1;
        float cost = 0;
        boolean chargeable = false;
        if (def != null) {
            tier = def.tier();
            cost = def.chakraCost();
            chargeable = def.chargeable();
        }

        if (chargeable && progress >= 1.0f) {
            fillColor = FILL_CHARGE;
            isCharging = true;
        }

        // Draw background
        drawRect(ctx, barX - 2, barY - 2, BAR_WIDTH + 4, BAR_HEIGHT + 4, BAR_BORDER);
        drawRect(ctx, barX, barY, BAR_WIDTH, BAR_HEIGHT, BAR_BG);

        // Draw fill
        int filled = (int)(BAR_WIDTH * Math.min(1f, progress));
        if (filled > 0) {
            drawRect(ctx, barX, barY, filled, BAR_HEIGHT, fillColor);
            // Highlight
            int hlColor = 0x44FFFFFF;
            ctx.fill(barX, barY, barX + filled, barY + 1, hlColor);
        }

        // Draw tier indicator (small colored square on left)
        int tierColor = TIER_COLORS[Math.max(0, Math.min(tier, 5))];
        drawRect(ctx, barX - 6, barY, 4, BAR_HEIGHT, tierColor);

        // Draw text above bar
        String label = name;
        if (tier > 0 && tier <= 5) {
            label = "T" + tier + " " + name;
        }
        int labelWidth = client.textRenderer.getWidth(label);
        int alpha = (int)(200 + 55 * Math.sin(System.currentTimeMillis() / 100.0));
        int labelColor = (alpha << 24) | 0xFFFFAA00;
        ctx.drawTextWithShadow(client.textRenderer, label,
            (sw - labelWidth) / 2, barY - 12, labelColor);

        // Draw cost below bar
        if (cost > 0) {
            String costText = "Cost: " + (int) cost;
            int costWidth = client.textRenderer.getWidth(costText);
            drawScaledText(ctx, client, costText,
                barX + (BAR_WIDTH - costWidth * 0.6f) / 2, barY + BAR_HEIGHT + 2,
                0xFF888888, 0.6f);
        }

        // Draw charge indicator
        if (isCharging) {
            String chargeText = "CHARGING... release to fire";
            int cw = client.textRenderer.getWidth(chargeText);
            int chargeAlpha = (int)(180 + 75 * Math.sin(System.currentTimeMillis() / 80.0));
            int chargeColor = (chargeAlpha << 24) | 0x44AAFF;
            ctx.drawTextWithShadow(client.textRenderer, chargeText,
                (sw - cw) / 2, barY + BAR_HEIGHT + 12, chargeColor);
        }

        // Interruptible indicator
        if (isInterruptible) {
            String intText = "[Interruptible]";
            int iw = (int)(client.textRenderer.getWidth(intText) * 0.5f);
            drawScaledText(ctx, client, intText,
                barX + BAR_WIDTH - iw, barY + 1, 0xFF666666, 0.5f);
        }
    }
}