package com.example.shinobicore.client.sakura.ui;

import net.minecraft.client.gui.DrawContext;
import com.mojang.blaze3d.systems.RenderSystem;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.math.RotationAxis;

import java.util.Random;

/** Two-depth field of falling sakura petals, drawn with rotated sprites. */
public final class PetalField {
    private static final int N = 26;
    private static final float[] px = new float[N];
    private static final float[] py = new float[N];
    private static final float[] dep = new float[N];
    private static final float[] rot = new float[N];
    private static final float[] rs = new float[N];
    private static final float[] sw = new float[N];
    private static final float[] ss = new float[N];
    private static final float[] sp = new float[N];
    private static final Random R = new Random(1234);
    private static int w = 0, h = 0;
    private static long last = 0;
    private static boolean seeded = false;

    private PetalField() {}

    private static void seed() {
        for (int i = 0; i < N; i++) {
            px[i] = R.nextFloat() * w;
            py[i] = R.nextFloat() * h;
            dep[i] = 0.3f + R.nextFloat() * 0.7f;
            rot[i] = R.nextFloat() * 6.28f;
            rs[i] = (R.nextFloat() - 0.5f) * 3f;
            sw[i] = R.nextFloat() * 6.28f;
            ss[i] = 0.6f + R.nextFloat() * 1.6f;
            sp[i] = 0.5f + R.nextFloat();
        }
        seeded = true;
    }

    public static void render(DrawContext ctx, int W, int H, long now) {
        if (!SakuraTextures.ready()) return;
        if (!seeded || W != w || H != h) { w = W; h = H; seed(); }
        float dt = (last == 0) ? 0.016f : (now - last) / 1000f;
        last = now;
        if (dt > 0.1f) dt = 0.1f;

        RenderSystem.enableBlend();
        RenderSystem.defaultBlendFunc();
        for (int i = 0; i < N; i++) {
            py[i] += sp[i] * (20 + 40 * dep[i]) * dt;
            sw[i] += ss[i] * dt;
            px[i] += (float) Math.sin(sw[i]) * 18 * dt * (0.5f + dep[i]);
            rot[i] += rs[i] * dt;
            if (py[i] > h + 12) { py[i] = -12; px[i] = R.nextFloat() * w; }
            if (px[i] > w + 12) px[i] = -12;
            if (px[i] < -12) px[i] = w + 12;

            float s = 0.5f + dep[i] * 0.8f;
            float a = 0.22f + dep[i] * 0.45f;

            MatrixStack m = ctx.getMatrices();
            m.push();
            m.translate(px[i], py[i], 0);
            m.scale(s, s, 1);
            m.multiply(RotationAxis.POSITIVE_Z.rotation(rot[i]));
            RenderSystem.setShaderColor(1f, 0.86f, 0.93f, a);
            ctx.drawTexture(SakuraTextures.petal(), -8, -8, 16, 16, 0, 0, 16, 16, 16, 16);
            m.pop();
        }
        RenderSystem.setShaderColor(1f, 1f, 1f, 1f);
    }
}