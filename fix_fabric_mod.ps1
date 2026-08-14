$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$fabric = "E:\Games\mod\src\main\resources\fabric.mod.json"

$json = @'
{
  "schemaVersion": 1,
  "id": "shinobicore",
  "version": "1.0.0",
  "name": "Shinobi Core",
  "description": "Naruto-themed mod for Minecraft",
  "authors": ["You"],
  "contact": {},
  "license": "MIT",
  "icon": "assets/shinobicore/icon.png",
  "environment": "*",
  "entrypoints": {
    "main": [
      "com.example.shinobicore.ShinobiCore",
      "com.example.shinobicore.DebugCommands"
    ],
    "client": [
      "com.example.shinobicore.client.ShinobiCoreClient"
    ]
  },
  "mixins": [
    "shinobicore.mixins.json"
  ],
  "depends": {
    "fabricloader": ">=0.14.21",
    "minecraft": "~1.20.1",
    "java": ">=21",
    "fabric-api": "*"
  }
}
'@

[System.IO.File]::WriteAllText($fabric, $json, $utf8)
Write-Host "[OK] fabric.mod.json fixed (proper JSON)"