package com.example.shinobicore.client.ui;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * S3-01: Central manager for all HUD widgets.
 * Handles registration, ordering, and rendering.
 * Widgets are rendered in priority order (lower priority first).
 */
public class HudWidgetManager {

    private static final List<HudWidget> widgets = new ArrayList<>();
    private static boolean initialized = false;
    private static int tickCounter = 0;

    public static void register(HudWidget widget) {
        widgets.add(widget);
        widgets.sort(Comparator.comparingInt(HudWidget::getPriority));
        ShinobiCore.LOGGER.info("[UI] Registered widget: {}", widget.getId());
    }

    public static void initAll(MinecraftClient client) {
        if (initialized) return;
        for (HudWidget w : widgets) {
            try {
                w.init(client);
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("[UI] Failed to init widget {}: {}", w.getId(), e.getMessage());
            }
        }
        initialized = true;
    }

    public static void render(DrawContext ctx, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client == null || client.player == null) return;
        if (!initialized) initAll(client);

        for (HudWidget w : widgets) {
            if (!w.isEnabled()) continue;
            try {
                if (w.shouldRender(client)) {
                    w.render(ctx, client, tickDelta);
                }
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("[UI] Render error in widget {}: {}", w.getId(), e.getMessage());
            }
        }
    }

    public static void tick(MinecraftClient client) {
        tickCounter++;
        for (HudWidget w : widgets) {
            if (!w.isEnabled()) continue;
            try {
                w.tick(client);
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("[UI] Tick error in widget {}: {}", w.getId(), e.getMessage());
            }
        }
    }

    public static HudWidget getWidget(String id) {
        for (HudWidget w : widgets) {
            if (w.getId().equals(id)) return w;
        }
        return null;
    }

    public static void cleanup() {
        widgets.clear();
        initialized = false;
    }
}