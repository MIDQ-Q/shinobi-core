$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$mixinDir = "E:\Games\mod\src\main\java\com\example\shinobicore\mixin"
$mixinsJson = "E:\Games\mod\src\main\resources\shinobicore.mixins.json"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

Write-File "$mixinDir\CameraAccessor.java" @'
package com.example.shinobicore.mixin;

import net.minecraft.client.render.Camera;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Invoker;

@Mixin(Camera.class)
public interface CameraAccessor {
    @Invoker("setPos")
    void shinobicore$setPos(double x, double y, double z);
}
'@

$mx = [System.IO.File]::ReadAllText($mixinsJson, $utf8)
if (-not $mx.Contains("CameraAccessor")) {
    $mx = $mx.Replace('"CameraMixin",', '"CameraMixin",
    "CameraAccessor",')
    [System.IO.File]::WriteAllText($mixinsJson, $mx, $utf8)
    Write-Host "[OK] mixins.json: CameraAccessor added"
}

# Update CameraMixin to use accessor
$cm = "$mixinDir\CameraMixin.java"
$c = [System.IO.File]::ReadAllText($cm, $utf8)
$c = $c.Replace("self.setPos(smooth.x, smooth.y, smooth.z);",
    "((com.example.shinobicore.mixin.CameraAccessor) self).shinobicore\$setPos(smooth.x, smooth.y, smooth.z);")
[System.IO.File]::WriteAllText($cm, $c, $utf8)
Write-Host "[OK] CameraMixin: use accessor for setPos"