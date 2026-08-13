$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\mixin\PlayerRenderAnimationMixin.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)

if ($c.Contains("private void applyWaterRun")) {
    Write-Host "[SKIP] Methods already exist"
} else {
    $methods = @"

    // === BATCH 3: Water Run / Wall Run / Slide Poses ===
    private void applyWaterRun(float limbAngle, float limbDistance) {
        float bob = MathHelper.sin(limbAngle * 2.0f) * 0.1f * limbDistance;
        rightArm.pitch = -0.3f + bob;
        rightArm.yaw = -0.9f;
        rightArm.roll = 0.3f;
        leftArm.pitch = -0.3f + bob;
        leftArm.yaw = 0.9f;
        leftArm.roll = -0.3f;
        body.pitch = 0.25f;
        head.pitch -= 0.15f;
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.3f;
        rightLeg.pitch = legSwing;
        rightLeg.yaw = -0.15f;
        leftLeg.pitch = -legSwing;
        leftLeg.yaw = 0.15f;
    }

    private void applyWallRun(float limbAngle, float limbDistance) {
        body.roll = 0.3f;
        body.pitch = 0.2f;
        rightArm.pitch = -1.5f;
        rightArm.yaw = -0.8f;
        rightArm.roll = 0.5f;
        leftArm.pitch = 0.5f;
        leftArm.yaw = 0.5f;
        head.yaw += 0.2f;
        head.pitch -= 0.1f;
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.2f;
        rightLeg.pitch = legSwing;
        leftLeg.pitch = -legSwing;
    }

    private void applySlidePose() {
        rightLeg.pitch = -1.0f;
        rightLeg.yaw = 0.1f;
        leftLeg.pitch = -0.7f;
        leftLeg.yaw = -0.1f;
        body.pitch = -0.4f;
        body.roll = 0.05f;
        rightArm.pitch = 0.6f;
        rightArm.yaw = -0.3f;
        leftArm.pitch = 0.6f;
        leftArm.yaw = 0.3f;
        head.pitch -= 0.2f;
    }
"@
    $lastBrace = $c.LastIndexOf("}")
    if ($lastBrace -ge 0) {
        $c = $c.Insert($lastBrace, $methods + "`n")
    } else {
        $c += $methods + "`n}`n"
    }
    [System.IO.File]::WriteAllText($f, $c, $utf8)
    Write-Host "[OK] Added missing pose methods to PlayerRenderAnimationMixin"
}