# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec — Antares Launcher 3.0 (spec 3.0 mục 65).
#
# Layout Portable (mục 65):
#   Antares/
#     Antares.exe        (hoặc ./antares/ dir trên Linux)
#     _internal/         (onedir runtime — startup nhanh hơn onefile, mục 29)
#     frontend/          (UI assets — copy bên cạnh exe, tách khỏi binary)
#
# Data path nằm ở ./data khi có portable.flag (AppPaths.portable) — người dùng
# chỉ cần tạo file rỗng `portable.flag` cạnh exe để bật portable mode.
# Build:  pyinstaller packaging/antares.spec --noconfirm

import os
from pathlib import Path

ROOT = Path(SPECPATH).parent          # antares-src/

block_cipher = None

hiddenimports = [
    "webview.platforms.edgechromium",   # Windows WebView2 backend
    "webview.platforms.cocoa",          # macOS (nếu build trên Mac)
    "webview.platforms.gtk",            # Linux fallback
    "psutil",
]

datas = [
    (str(ROOT / "frontend"), "frontend"),
]

# authlib-injector jar cho ely.by (nếu tồn tại trong repo)
authlib_jar = ROOT / "authlib"
if authlib_jar.is_dir():
    for jar in authlib_jar.glob("*.jar"):
        datas.append((str(jar), "authlib"))

a = Analysis(
    [str(ROOT / "app" / "main.py")],
    pathex=[str(ROOT)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        "tkinter",          # không dùng — giảm dung lượng
        "pytest",
        "pip",
        "setuptools",
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="Antares",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,               # UPX hay bị antivirus report false-positive (mục 42 spirit)
    console=False,           # GUI app — không console window
    icon=str(ROOT / "packaging" / "icon.ico") if (ROOT / "packaging" / "icon.ico").exists() else None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    name="Antares",
)
