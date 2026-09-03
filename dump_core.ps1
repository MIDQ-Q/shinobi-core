<writeToFile>
<path>shinobi-editor/setup_editor.ps1</path>
<content>
# Shinobi Editor Setup Script
# Создает полный проект Tauri + React + TypeScript + Three.js
# Запуск: .\setup_editor.ps1 из E:\Games\mod

$ErrorActionPreference = "Stop"
$rootPath = Get-Location
$editorPath = Join-Path $rootPath "shinobi-editor"

Write-Host "=== Shinobi Editor Setup ===" -ForegroundColor Cyan
Write-Host "Root: $rootPath" -ForegroundColor Gray
Write-Host "Editor: $editorPath" -ForegroundColor Gray
Write-Host ""

# Проверка Node.js
try {
    $nodeVersion = node --version
    Write-Host "[OK] Node.js $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Node.js not found. Install from https://nodejs.org/" -ForegroundColor Red
    exit 1
}

# Проверка Rust
try {
    $rustVersion = rustc --version
    Write-Host "[OK] $rustVersion" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Rust not found. Install from https://rustup.rs/" -ForegroundColor Red
    exit 1
}

# 1. Создание структуры папок
Write-Host "`n[1/10] Creating directory structure..." -ForegroundColor Yellow
$dirs = @(
    "src\components\VoxelEditor",
    "src\components\ScenePreview",
    "src\components\PipelineEditor",
    "src\components\UI",
    "src\scenes",
    "src\models",
    "src\stores",
    "src\types",
    "src-tauri\src",
    "src-tauri\icons",
    "public"
)
foreach ($dir in $dirs) {
    $fullPath = Join-Path $editorPath $dir
    if (!(Test-Path $fullPath)) {
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
        Write-Host "  [OK] $dir" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] $dir exists" -ForegroundColor Yellow
    }
}

# Функция для записи UTF-8 без BOM
function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $fullPath = Join-Path $editorPath $Path
    $dir = Split-Path $fullPath -Parent
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
    Write-Host "  [OK] $Path" -ForegroundColor Green
}

# 2. package.json
Write-Host "`n[2/10] Creating package.json..." -ForegroundColor Yellow
$packageJson = @'
{
  "name": "shinobi-editor",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "tauri": "tauri"
  },
  "dependencies": {
    "@react-three/drei": "^9.99.0",
    "@react-three/fiber": "^8.15.0",
    "@tauri-apps/api": "^1.5.3",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "three": "^0.161.0",
    "zustand": "^4.5.0"
  },
  "devDependencies": {
    "@tauri-apps/cli": "^1.5.9",
    "@types/react": "^18.2.48",
    "@types/react-dom": "^18.2.18",
    "@types/three": "^0.161.0",
    "@vitejs/plugin-react": "^4.2.1",
    "typescript": "^5.3.3",
    "vite": "^5.0.12"
  }
}
'@
Write-Utf8NoBom "package.json" $packageJson

# 3. vite.config.ts
Write-Host "`n[3/10] Creating vite.config.ts..." -ForegroundColor Yellow
$viteConfig = @'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
  },
  envPrefix: ["VITE_", "TAURI_"],
  build: {
    target: ["es2021", "chrome100", "safari13"],
    minify: !process.env.TAURI_DEBUG ? "esbuild" : false,
    sourcemap: !!process.env.TAURI_DEBUG,
  },
});
'@
Write-Utf8NoBom "vite.config.ts" $viteConfig

# 4. tsconfig.json
Write-Host "`n[4/10] Creating tsconfig.json..." -ForegroundColor Yellow
$tsconfig = @'
{
  "compilerOptions": {
    "target": "ES2021",
    "useDefineForClassFields": true,
    "lib": ["ES2021", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
'@
Write-Utf8NoBom "tsconfig.json" $tsconfig

$tsconfigNode = @'
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
'@
Write-Utf8NoBom "tsconfig.node.json" $tsconfigNode

# 5. index.html
Write-Host "`n[5/10] Creating index.html..." -ForegroundColor Yellow
$indexHtml = @'
<!doctype html>
<html lang="ru">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Shinobi Editor</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
'@
Write-Utf8NoBom "index.html" $indexHtml

# 6. React файлы
Write-Host "`n[6/10] Creating React files..." -ForegroundColor Yellow

$mainTsx = @'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
'@
Write-Utf8NoBom "src/main.tsx" $mainTsx

$indexCss = @'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
  background: #1a1a1a;
  color: #e0e0e0;
}

#root {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
}
'@
Write-Utf8NoBom "src/index.css" $indexCss

$AppTsx = @'
import { useState } from 'react';
import './App.css';

function App() {
  const [activeTab, setActiveTab] = useState('home');

  return (
    <div className="app">
      <header className="app-header">
        <h1>Shinobi Editor</h1>
        <nav>
          <button onClick={() => setActiveTab('home')}>Home</button>
          <button onClick={() => setActiveTab('voxel')}>Voxel Editor</button>
          <button onClick={() => setActiveTab('scene')}>Scene Preview</button>
          <button onClick={() => setActiveTab('pipeline')}>Pipeline</button>
        </nav>
      </header>
      <main className="app-main">
        {activeTab === 'home' && <div>Home Tab</div>}
        {activeTab === 'voxel' && <div>Voxel Editor (TODO)</div>}
        {activeTab === 'scene' && <div>Scene Preview (TODO)</div>}
        {activeTab === 'pipeline' && <div>Pipeline Editor (TODO)</div>}
      </main>
    </div>
  );
}

export default App;
'@
Write-Utf8NoBom "src/App.tsx" $AppTsx

$AppCss = @'
.app {
  display: flex;
  flex-direction: column;
  height: 100vh;
}

.app-header {
  background: #252525;
  padding: 12px 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid #333;
}

.app-header h1 {
  font-size: 20px;
  color: #ff6b35;
}

.app-header nav {
  display: flex;
  gap: 8px;
}

.app-header button {
  background: #333;
  border: 1px solid #444;
  color: #e0e0e0;
  padding: 6px 16px;
  border-radius: 4px;
  cursor: pointer;
}

.app-header button:hover {
  background: #444;
}

.app-main {
  flex: 1;
  padding: 24px;
  overflow: auto;
}
'@
Write-Utf8NoBom "src/App.css" $AppCss

# 7. Tauri конфиг
Write-Host "`n[7/10] Creating Tauri configuration..." -ForegroundColor Yellow

$tauriConf = @'
{
  "build": {
    "beforeDevCommand": "npm run dev",
    "beforeBuildCommand": "npm run build",
    "devPath": "http://localhost:1420",
    "distDir": "../dist",
    "withGlobalTauri": false
  },
  "package": {
    "productName": "Shinobi Editor",
    "version": "1.0.0"
  },
  "tauri": {
    "allowlist": {
      "all": false,
      "shell": {
        "all": false,
        "open": true
      },
      "fs": {
        "all": true,
        "scope": ["**"]
      },
      "dialog": {
        "all": true
      }
    },
    "bundle": {
      "active": true,
      "targets": "all",
      "identifier": "com.shinobicore.editor",
      "icon": [
        "icons/32x32.png",
        "icons/128x128.png",
        "icons/128x128@2x.png",
        "icons/icon.icns",
        "icons/icon.ico"
      ]
    },
    "security": {
      "csp": null
    },
    "windows": [
      {
        "fullscreen": false,
        "resizable": true,
        "title": "Shinobi Editor",
        "width": 1400,
        "height": 900,
        "minWidth": 1000,
        "minHeight": 700
      }
    ]
  }
}
'@
Write-Utf8NoBom "src-tauri/tauri.conf.json" $tauriConf

# 8. Cargo.toml
Write-Host "`n[8/10] Creating Cargo.toml..." -ForegroundColor Yellow

$cargoToml = @'
[package]
name = "shinobi-editor"
version = "1.0.0"
description = "Shinobi Jutsu Editor"
authors = ["you"]
license = ""
repository = ""
edition = "2021"

[build-dependencies]
tauri-build = { version = "1.5", features = [] }

[dependencies]
tauri = { version = "1.5", features = ["shell-open", "fs-all", "dialog-all"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

[features]
default = ["custom-protocol"]
custom-protocol = ["tauri/custom-protocol"]
'@
Write-Utf8NoBom "src-tauri/Cargo.toml" $cargoToml

# 9. Rust файлы
Write-Host "`n[9/10] Creating Rust files..." -ForegroundColor Yellow

$mainRs = @'
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
'@
Write-Utf8NoBom "src-tauri/src/main.rs" $mainRs

$buildRs = @'
fn main() {
    tauri_build::build()
}
'@
Write-Utf8NoBom "src-tauri/build.rs" $buildRs

# 10. README
Write-Host "`n[10/10] Creating README..." -ForegroundColor Yellow

$readme = @'
# Shinobi Editor

Редактор техник для ShinobiCore на базе Tauri + React + TypeScript + Three.js.

## Установка

```bash
cd shinobi-editor
npm install
```

## Запуск в режиме разработки

```bash
npm run tauri dev
```

## Сборка релизной версии

```bash
npm run tauri build
```

## Структура проекта

```
shinobi-editor/
├── src/                    # React + TypeScript frontend
│   ├── components/
│   ├── stores/
│   ├── types/
│   └── App.tsx
├── src-tauri/             # Rust backend
│   ├── src/
│   │   └── main.rs
│   ├── Cargo.toml
│   └── tauri.conf.json
└── package.json
```

## Следующие шаги

1. Добавить Three.js сцену для воксельного редактора
2. Реализовать компоненты UI
3. Добавить загрузку/сохранение JSON
4. Интегрировать с папкой мода
'@
Write-Utf8NoBom "README.md" $readme

# 11. Установка зависимостей
Write-Host "`n[11/11] Installing dependencies..." -ForegroundColor Yellow
Push-Location $editorPath
try {
    Write-Host "Running npm install..." -ForegroundColor Gray
    npm install
    Write-Host "[OK] npm install completed" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] npm install failed" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

# Завершение
Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. cd shinobi-editor" -ForegroundColor White
Write-Host "  2. npm run tauri dev" -ForegroundColor White
Write-Host ""
Write-Host "This will:" -ForegroundColor Gray
Write-Host "  - Start Vite dev server on http://localhost:1420" -ForegroundColor Gray
Write-Host "  - Launch Tauri desktop app" -ForegroundColor Gray
Write-Host "  - Enable hot reload for both frontend and backend" -ForegroundColor Gray
Write-Host ""
</content>
</writeToFile>
