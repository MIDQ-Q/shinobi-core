package com.example.shinobicore.modules.clans.ui;

import com.example.shinobicore.modules.clans.view.ClanVisualView;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.font.TextRenderer;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
import java.util.Map;
import java.util.Optional;

public final class ClanTab {
    private ClanTab() {}

    public static void render(DrawContext ctx, int x, int y, PlayerEntity player) {
        TextRenderer tr = player.getWorld().isClient
            ? net.minecraft.client.MinecraftClient.getInstance().textRenderer
            : null;
        if (tr == null) return;

        Optional<ClanVisualView> viewOpt =
            com.example.shinobicore.core.view.CoreViews.get(player, ClanVisualView.class);

        if (viewOpt.isEmpty()) {
            ctx.drawTextWithShadow(tr,
                Text.literal("No clan data").formatted(Formatting.GRAY),
                x, y, 0xAAAAAA);
            return;
        }

        ClanVisualView view = viewOpt.get();
        int currentY = y;

        String clanName = view.hasClan() ? view.getClanName() : "No Clan";
        int colorHex = parseColor(view.getClanColor());

        // Line 1: Clan name
        ctx.drawTextWithShadow(tr,
            Text.literal("Clan: " + clanName).formatted(Formatting.BOLD),
            x, currentY, colorHex);
        currentY += 12;

        if (view.hasClan()) {
            // Line 2: Affinity
            ctx.drawTextWithShadow(tr,
                Text.literal("Affinity: " + view.getAffinity()),
                x, currentY, 0xAAAAAA);
            currentY += 10;

            // Line 3: Dojutsu (if any)
            if (view.hasDojutsuHook()) {
                String dojutsuId = view.getDojutsuId();
                ctx.drawTextWithShadow(tr,
                    Text.literal("Dojutsu: " + (dojutsuId != null ? dojutsuId : "unknown"))
                        .formatted(Formatting.LIGHT_PURPLE),
                    x, currentY, 0xFF55FF);
                currentY += 10;
            }

            // Line 4: Reputation header
            ctx.drawTextWithShadow(tr,
                Text.literal("Reputation:"),
                x, currentY, 0x55FF55);
            currentY += 10;

            // Line 5+: Reputation entries
            Map<String, Integer> reps = view.getAllReputations();
            if (reps == null || reps.isEmpty()) {
                ctx.drawTextWithShadow(tr,
                    Text.literal("  (none)"),
                    x, currentY, 0x888888);
                currentY += 10;
            } else {
                for (Map.Entry<String, Integer> entry : reps.entrySet()) {
                    String repLine = "  " + entry.getKey() + ": " + entry.getValue();
                    int repColor = (entry.getValue() != null && entry.getValue() >= 0)
                        ? 0x55FF55 : 0xFF5555;
                    ctx.drawTextWithShadow(tr,
                        Text.literal(repLine),
                        x, currentY, repColor);
                    currentY += 10;
                }
            }
        }
    }

    private static int parseColor(String hex) {
        if (hex == null || !hex.startsWith("#") || hex.length() != 7) return 0xFFFFFF;
        try {
            return Integer.parseInt(hex.substring(1), 16);
        } catch (NumberFormatException e) {
            return 0xFFFFFF;
        }
    }
}