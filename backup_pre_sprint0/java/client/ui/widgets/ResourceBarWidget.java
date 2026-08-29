package com.example.shinobicore.client.ui.widgets;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.ui.HudConfig;
import com.example.shinobicore.client.ui.HudWidget;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

/**
 * S3-02: Contextual resource bars.
 * - Chakra bar visible only when chakra < 100% OR in combat OR chakra mode active.
 * - Stamina bar visible only when stamina < 100% OR in combat.
 * - Outside combat with full resources: bars are hidden.
 * - Fatigue bar shown only when fatigue > 0.
 */
public class ResourceBarWidget extends HudWidget {

    private static final int BAR_WIDTH = 120;
    private static final int BAR_HEIGHT = 7;
    private static final int BAR_SPACING = 2;

    private static final int CHAKRA_LIGHT = 0xFF4499FF;
    private static final int CHAKRA_DARK = 0xFF1155CC;
    private static final int STAMINA_LIGHT = 0xFF44EE44;
    private static final int STAMINA_DARK = 0xFF22AA22;
    private static final int FATIGUE_LIGHT = 0xFFEEBB33;
    private static final int FATIGUE_DARK = 0xFFBB8811;
    private static final int BG_COLOR = 0xCC222222;
    private static final int BORDER_COLOR = 0xFF000000;

    private int combatTimer = 0;
    private static final int COMBAT_TIMEOUT_TICKS = 100; // 5 seconds

    public ResourceBarWidget() {
        super("resource_bars");
        setX(10);
        setY(10);
    }

    @Override
    public int getPriority() { return 10; }

    @Override
    public void tick(MinecraftClient client) {
        // Track combat state: if player was attacked or attacked recently
        if (client.player != null) {
            if (client.player.hurtTime > 0 || client.player.getAttacking() != null) {
                combatTimer = COMBAT_TIMEOUT_TICKS;
            } else if (combatTimer > 0) {
                combatTimer--;
            }
        }
    }

    @Override
    public boolean shouldRender(MinecraftClient client) {
        if (!HudConfig.instance.showChakraBar && !HudConfig.instance.showStaminaBar) return false;
        if (client.player == null) return false;

        // If contextual hide is disabled, always show
        if (!HudConfig.instance.contextualHide) return true;

        // In combat: always show
        if (isInCombat()) return true;

        // Chakra mode active: always show
        if (ClientNinjaState.chakraMode) return true;

        // Check if any resource is not full
        float chakraRatio = ChakraHudRenderer.maxChakra > 0
            ? ChakraHudRenderer.currentChakra / ChakraHudRenderer.maxChakra : 1f;
        float stamRatio = ChakraHudRenderer.maxStamina > 0
            ? ChakraHudRenderer.currentStamina / ChakraHudRenderer.maxStamina : 1f;
        float fatigue = ChakraHudRenderer.fatigue;

        if (chakraRatio < 0.999f) return true;
        if (stamRatio < 0.999f) return true;
        if (fatigue > 0.5f) return true;

        return false;
    }

    @Override
    public void render(DrawContext ctx, MinecraftClient client, float tickDelta) {
        if (client.player == null) return;

        int bx = getX() + HudConfig.instance.hudOffsetX;
        int by = getY() + HudConfig.instance.hudOffsetY;

        // Chakra bar
        if (HudConfig.instance.showChakraBar) {
            float chakraRatio = ChakraHudRenderer.maxChakra > 0
                ? ChakraHudRenderer.currentChakra / ChakraHudRenderer.maxChakra : 0;
            boolean pulse = chakraRatio < 0.25f && !ChakraHudRenderer.exhausted;

            int chakraColor = pulse ? getFlashColor(CHAKRA_LIGHT) : CHAKRA_LIGHT;
            drawBar(ctx, bx, by, BAR_WIDTH, BAR_HEIGHT, chakraRatio, chakraColor, BG_COLOR, BORDER_COLOR);

            // Label
            String label = "CH";
            String value = (int) ChakraHudRenderer.currentChakra + "/" + (int) ChakraHudRenderer.maxChakra;
            drawScaledText(ctx, client, label, bx + 2, by + 1, 0xFFFFFFFF, 0.65f);
            int tw = (int)(client.textRenderer.getWidth(value) * 0.65f);
            drawScaledText(ctx, client, value, bx + BAR_WIDTH - 2 - tw, by + 1, 0xFFFFFFFF, 0.65f);

            by += BAR_HEIGHT + BAR_SPACING;
        }

        // Stamina bar
        if (HudConfig.instance.showStaminaBar) {
            float stamRatio = ChakraHudRenderer.maxStamina > 0
                ? ChakraHudRenderer.currentStamina / ChakraHudRenderer.maxStamina : 0;
            boolean pulse = stamRatio < 0.25f;

            int stamColor = pulse ? getFlashColor(STAMINA_LIGHT) : STAMINA_LIGHT;
            drawBar(ctx, bx, by, BAR_WIDTH, BAR_HEIGHT, stamRatio, stamColor, BG_COLOR, BORDER_COLOR);

            String label = "ST";
            String value = (int) ChakraHudRenderer.currentStamina + "/" + (int) ChakraHudRenderer.maxStamina;
            drawScaledText(ctx, client, label, bx + 2, by + 1, 0xFFFFFFFF, 0.65f);
            int tw = (int)(client.textRenderer.getWidth(value) * 0.65f);
            drawScaledText(ctx, client, value, bx + BAR_WIDTH - 2 - tw, by + 1, 0xFFFFFFFF, 0.65f);

            by += BAR_HEIGHT + BAR_SPACING;
        }

        // Fatigue bar (only when > 0)
        if (ChakraHudRenderer.fatigue > 0.5f) {
            float fatRatio = ChakraHudRenderer.fatigue / 100f;
            boolean pulse = ChakraHudRenderer.exhausted;
            int fatColor = pulse ? getFlashColor(FATIGUE_LIGHT) : FATIGUE_LIGHT;
            drawBar(ctx, bx, by, BAR_WIDTH, BAR_HEIGHT, fatRatio, fatColor, BG_COLOR, BORDER_COLOR);

            String label = "FT";
            String value = (int) ChakraHudRenderer.fatigue + "%";
            drawScaledText(ctx, client, label, bx + 2, by + 1, 0xFFFFFFFF, 0.65f);
            int tw = (int)(client.textRenderer.getWidth(value) * 0.65f);
            drawScaledText(ctx, client, value, bx + BAR_WIDTH - 2 - tw, by + 1, 0xFFFFFFFF, 0.65f);

            by += BAR_HEIGHT + BAR_SPACING;
        }

        // Chakra mode indicator
        if (ClientNinjaState.chakraMode) {
            int alpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            int color = (alpha << 24) | 0xFF8800;
            drawText(ctx, client, "CHAKRA MODE", bx, by, color);
            by += 10;
        }

        // Exhausted indicator
        if (ChakraHudRenderer.exhausted) {
            drawText(ctx, client, "EXHAUSTED", bx, by, 0xFFFF3333);
        }
    }

    private boolean isInCombat() {
        return combatTimer > 0;
    }

    private int getFlashColor(int baseColor) {
        int alpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
        int r = (baseColor >> 16) & 0xFF;
        int g = (baseColor >> 8) & 0xFF;
        int b = baseColor & 0xFF;
        return (alpha << 24) | (r << 16) | (g << 8) | b;
    }
}