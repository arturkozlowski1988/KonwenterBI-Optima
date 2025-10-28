# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['app_entry.py'],
    pathex=[],
    binaries=[],
    datas=[('bi_converter/settings.json', 'bi_converter'), ('bi_converter/config.json', 'bi_converter')],
    hiddenimports=['bi_converter'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='app_entry',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
