package com.example.shinobicore.modules.jutsu.editor;

import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.client.gui.widget.TextFieldWidget;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public class JutsuEditorScreen extends Screen {
    private TextFieldWidget nameField;
    private TextFieldWidget idField;
    private TextFieldWidget costField;
    private TextFieldWidget cooldownField;
    private TextFieldWidget damageField;
    private TextFieldWidget elementField;
    private TextFieldWidget behaviorField;

    public JutsuEditorScreen() {
        super(Text.literal("Jutsu Editor"));
    }

    @Override
    protected void init() {
        super.init();
        int cx = this.width / 2;
        int leftX = cx - 160;
        int fieldWidth = 320;
        int y = 45;
        int rowHeight = 35;

        // Row 1: Name
        nameField = new TextFieldWidget(this.textRenderer, leftX, y, fieldWidth, 20, Text.literal("Name"));
        nameField.setMaxLength(64);
        nameField.setText("New Jutsu");
        this.addDrawableChild(nameField);
        y += rowHeight;

        // Row 2: ID
        idField = new TextFieldWidget(this.textRenderer, leftX, y, fieldWidth, 20, Text.literal("ID"));
        idField.setMaxLength(64);
        idField.setText("shinobicore:new_jutsu");
        this.addDrawableChild(idField);
        y += rowHeight;

        // Row 3: Element + Behavior side by side
        int halfWidth = (fieldWidth - 10) / 2;
        elementField = new TextFieldWidget(this.textRenderer, leftX, y, halfWidth, 20, Text.literal("Element"));
        elementField.setMaxLength(16);
        elementField.setText("fire");
        this.addDrawableChild(elementField);

        behaviorField = new TextFieldWidget(this.textRenderer, leftX + halfWidth + 10, y, halfWidth, 20, Text.literal("Behavior"));
        behaviorField.setMaxLength(20);
        behaviorField.setText("projectile");
        this.addDrawableChild(behaviorField);
        y += rowHeight;

        // Row 4: Cost + Cooldown
        costField = new TextFieldWidget(this.textRenderer, leftX, y, halfWidth, 20, Text.literal("Chakra Cost"));
        costField.setMaxLength(5);
        costField.setText("15");
        this.addDrawableChild(costField);

        cooldownField = new TextFieldWidget(this.textRenderer, leftX + halfWidth + 10, y, halfWidth, 20, Text.literal("Cooldown (ticks)"));
        cooldownField.setMaxLength(5);
        cooldownField.setText("40");
        this.addDrawableChild(cooldownField);
        y += rowHeight;

        // Row 5: Damage + Range
        damageField = new TextFieldWidget(this.textRenderer, leftX, y, halfWidth, 20, Text.literal("Damage"));
        damageField.setMaxLength(5);
        damageField.setText("6.0");
        this.addDrawableChild(damageField);

        TextFieldWidget rangeField = new TextFieldWidget(this.textRenderer, leftX + halfWidth + 10, y, halfWidth, 20, Text.literal("Range"));
        rangeField.setMaxLength(5);
        rangeField.setText("16.0");
        this.addDrawableChild(rangeField);
        y += rowHeight + 10;

        // Buttons
        this.addDrawableChild(ButtonWidget.builder(
            Text.literal("Save").formatted(Formatting.GREEN),
            btn -> saveJutsu()
        ).dimensions(cx - 105, this.height - 35, 100, 20).build());

        this.addDrawableChild(ButtonWidget.builder(
            Text.literal("Cancel"),
            btn -> this.close()
        ).dimensions(cx + 5, this.height - 35, 100, 20).build());
    }

    @Override
    public void render(DrawContext ctx, int mouseX, int mouseY, float delta) {
        this.renderBackground(ctx);
        ctx.drawCenteredTextWithShadow(this.textRenderer,
            Text.literal("JUTSU EDITOR").formatted(Formatting.GOLD).formatted(Formatting.BOLD),
            this.width / 2, 12, 0xFFFFFF);
        ctx.drawCenteredTextWithShadow(this.textRenderer,
            Text.literal("Fill the fields and press Save to create the jutsu JSON file"),
            this.width / 2, 28, 0xAAAAAA);
        super.render(ctx, mouseX, mouseY, delta);

        // Draw labels
        int leftX = this.width / 2 - 160;
        int y = 45;
        int rowHeight = 35;
        this.textRenderer.getClass(); // dummy to avoid unused var
    }

    private void saveJutsu() {
        JutsuEditorData data = new JutsuEditorData();
        data.name = nameField.getText();
        data.id = idField.getText();
        data.element = elementField.getText();
        data.behaviorType = behaviorField.getText();
        data.baseCost = parseIntSafe(costField.getText(), 10);
        data.cooldownTicks = parseIntSafe(cooldownField.getText(), 20);
        data.damage = parseFloatSafe(damageField.getText(), 5.0f);
        data.range = 16.0f;
        JutsuEditorIO.save(data);

        if (this.client != null && this.client.player != null) {
            this.client.player.sendMessage(Text.literal("[Jutsu Editor] Saved: " + data.id).formatted(Formatting.GREEN), false);
            this.client.player.sendMessage(Text.literal("Run /shinobicore jutsu reload to apply").formatted(Formatting.YELLOW), false);
        }
        this.close();
    }

    private int parseIntSafe(String s, int fallback) {
        try { return Integer.parseInt(s.trim()); }
        catch (NumberFormatException e) { return fallback; }
    }

    private float parseFloatSafe(String s, float fallback) {
        try { return Float.parseFloat(s.trim()); }
        catch (NumberFormatException e) { return fallback; }
    }

    @Override
    public boolean shouldPause() { return false; }
}