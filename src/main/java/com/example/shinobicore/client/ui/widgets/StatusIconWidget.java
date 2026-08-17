package com.example.shinobicore.client.ui.widgets;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.client.RasenshurikenClientState;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.ui.HudConfig;
import com.example.shinobicore.client.ui.HudWidget;
import com.example.shinobicore.combat.TaijutsuStyle;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

import java.util.ArrayList;
import java.util.List;

/**
 * S3-04: Status icons for buffs/debuffs/states.
 * Renders a row of icons below resource bars.
 * States: sensory, stance, chakra mode, gates, kawarimi CD, charge.
 * Icons are text-based (Unicode symbols) for simplicity.
 */
public class StatusIconWidget extends HudWidget {

    private static final int ICON_SIZE = 16;
    private static final int ICON_SPACING = 3;
    private static final int ICON_BG = 0xAA111111;
    private static final int ICON_BORDER = 0xFF333333;

    public StatusIconWidget() {
        super("status_icons");
        setX(10);
        setY(55);
    }

    @Override
    public int getPriority() { return 20; }

    @Override
    public boolean shouldRender(MinecraftClient client) {
        if (!HudConfig.instance.showStatusIcons) return false;
        if (client.player == null) return false;
        // Show if at least one status is active
        return getActiveStatuses().size() > 0;
    }

    @Override
    public void render(DrawContext ctx, MinecraftClient client, float tickDelta) {
        if (client.player == null) return;

        List<StatusIcon> statuses = getActiveStatuses();
        if (statuses.isEmpty()) return;

        int bx = getX() + HudConfig.instance.hudOffsetX;
        int by = getY() + HudConfig.instance.hudOffsetY;

        for (StatusIcon icon : statuses) {
            // Background
            drawRect(ctx, bx - 1, by - 1, ICON_SIZE + 2, ICON_SIZE + 2, ICON_BORDER);
            drawRect(ctx, bx, by, ICON_SIZE, ICON_SIZE, ICON_BG);

            // Icon symbol
            int symbolColor = icon.color;
            if (icon.pulse) {
                int alpha = (int)(180 + 75 * Math.sin(System.currentTimeMillis() / 120.0));
                int r = (icon.color >> 16) & 0xFF;
                int g = (icon.color >> 8) & 0xFF;
                int b = icon.color & 0xFF;
                symbolColor = (alpha << 24) | (r << 16) | (g << 8) | b;
            }

            // Draw symbol centered in icon box
            int tw = client.textRenderer.getWidth(icon.symbol);
            ctx.drawTextWithShadow(client.textRenderer, icon.symbol,
                bx + (ICON_SIZE - tw) / 2, by + (ICON_SIZE - 8) / 2, symbolColor);

            // Cooldown overlay if applicable
            if (icon.cooldownRatio > 0 && icon.cooldownRatio < 1.0f) {
                int cdHeight = (int)(ICON_SIZE * icon.cooldownRatio);
                drawRect(ctx, bx, by + ICON_SIZE - cdHeight, ICON_SIZE, cdHeight, 0x88000000);
            }

            bx += ICON_SIZE + ICON_SPACING;
        }
    }

    private List<StatusIcon> getActiveStatuses() {
        List<StatusIcon> list = new ArrayList<>();

        // Chakra Mode
        if (ClientNinjaState.chakraMode) {
            list.add(new StatusIcon("C", 0xFFFF8800, false, 0));
        }

        // Sensory
        if (ClientNinjaState.unlockedNodes.contains("sen_glow")) {
            if (ClientNinjaState.sensoryEnabled) {
                list.add(new StatusIcon("S", 0xFF66DDFF, false, 0));
            }
        }

        // Danger Sense active
        if (ClientNinjaState.dangerSense) {
            list.add(new StatusIcon("!", 0xFFFF4444, true, 0));
        }

        // Taijutsu style (non-default)
        TaijutsuStyle style = TaijutsuClientHandler.getCurrentStyle();
        if (style == TaijutsuStyle.STRONG_FIST) {
            list.add(new StatusIcon("F", 0xFF44FF44, false, 0));
        }

        // Kenjutsu stance
        String stance = ClientNinjaState.kenjutsuStance;
        if (stance != null && !stance.equals("aggressive")) {
            String symbol = stance.equals("seigan") ? "D" : "I";
            int color = stance.equals("seigan") ? 0xFF66AAFF : 0xFFFFAA00;
            list.add(new StatusIcon(symbol, color, false, 0));
        }

        // Rasengan charging/ready
        if (RasenganClientState.charging) {
            list.add(new StatusIcon("R", 0xFF44AAFF, true, 0));
        } else if (RasenganClientState.ready) {
            list.add(new StatusIcon("R", 0xFF44AAFF, true, 0));
        }

        // Rasenshuriken charging/ready
        if (RasenshurikenClientState.charging || RasenshurikenClientState.ready) {
            list.add(new StatusIcon("W", 0xFF88CCFF, true, 0));
        }

        // Blocking
        if (ClientNinjaState.isBlockingClient) {
            list.add(new StatusIcon("B", 0xFFAAAAAA, false, 0));
        }

        // Meditating
        if (ClientNinjaState.meditating) {
            list.add(new StatusIcon("M", 0xFFAA88FF, false, 0));
        }

        // Dojutsu active
        if (ClientNinjaState.activeDojutsu != null) {
            String djSymbol = ClientNinjaState.activeDojutsu.equals("sharingan") ? "E" : "O";
            int djColor = ClientNinjaState.activeDojutsu.equals("sharingan") ? 0xFFFF2222 : 0xFFCCCCFF;
            list.add(new StatusIcon(djSymbol, djColor, false, 0));
        }

        return list;
    }

    private static class StatusIcon {
        final String symbol;
        final int color;
        final boolean pulse;
        final float cooldownRatio; // 0 = no cooldown, 0-1 = cooldown remaining

        StatusIcon(String symbol, int color, boolean pulse, float cooldownRatio) {
            this.symbol = symbol;
            this.color = color;
            this.pulse = pulse;
            this.cooldownRatio = cooldownRatio;
        }
    }
}