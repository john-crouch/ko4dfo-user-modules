# USER/VARA Module Design

**Date:** 2025-12-26
**Status:** Approved
**Author:** KO4DFO with Claude Code

## Summary

Create a new USER/VARA module that replaces the broken CORE VARA module. Uses Wine Mono instead of native .NET Framework to support both VARA (VB6) and VarAC (.NET) applications.

## Problem

The CORE VARA module's Wine prefix contains corrupted `machine.config` with invalid XML (30 lines with stray `-->` tags). This breaks any .NET application (like VarAC) that uses sockets or crypto initialization.

## Solution

1. Disable CORE/30_VARA.sh by moving it into VARA/ subdirectory
2. Create USER/VARA module with Wine Mono + msdatsrc.tlb
3. Simplify USER/VARAC to use VARA's Wine prefix

## Module Structure

```
VARA/
├── 20_VARA.sh              # Main module script
├── README                  # User instructions
├── bin/
│   └── start-vara-hf.sh
├── config/
│   ├── VARA.ini
│   └── VARAFM.ini
├── applications/
│   ├── VARA.desktop
│   └── VARA FM.desktop
├── icons/
│   ├── F302_VARA.0.png
│   └── C497_VARAFM.0.png
├── exe/
│   ├── VB6.0-KB290887-X86.exe
│   ├── vc_redist.x86.exe
│   ├── wine-mono-7.4.0-x86.msi
│   ├── VARA HF v4.8.9 setup.zip
│   └── VARA FM v4.3.9 setup.zip
└── dll/
    ├── pdh.dll
    └── msdatsrc.tlb
```

## Module Script Logic

### deploy_vara() - Main Entry Point

**If tarball exists** (`$SAVE_DIR/wine_vara.tar`):
- Extract tarball to `~/.wine_vara_32`
- Copy icons and desktop files
- Install launcher script
- Set Wine registry (COM1, ALSA devices)
- Restore registration code if saved

**If no tarball** (first boot):
1. `prepare_vara()` - Create Wine prefix
   - `wineboot --init` (fresh 32-bit prefix)
   - Install Wine Mono 7.4.0 via msiexec
   - `winetricks -q vb6run`
   - `winetricks -q vcrun2015`
   - Copy pdh.dll to system32
   - Copy and register msdatsrc.tlb
   - Set Wine registry (COM1, ALSA)

2. `install_vara()` - Silent installation
   - Unzip and run VARA HF installer with /SILENT
   - Unzip and run VARA FM installer with /SILENT

3. `config_vara()` - Configure
   - Copy ini files with $MYCALL substitution
   - Install launcher and desktop files

4. `persist_vara()` - Save tarball
   - `tar -cf $SAVE_DIR/wine_vara.tar .wine_vara_32`

5. `register_vara()` - Optional registration prompt

## Key Technical Changes

| Aspect | CORE Module | USER Module |
|--------|-------------|-------------|
| .NET Runtime | Native dotnet40+dotnet48 (broken) | Wine Mono 7.4.0 |
| Wine Mono | Removed via winetricks | Kept/installed |
| msdatsrc.tlb | Not present | Installed (fixes port 8300) |
| Installation | Interactive | Silent (/SILENT flag) |
| machine.config | Corrupted XML | Clean (Wine Mono default) |

## VARAC Module Changes

VARAC module simplified to:
- Remove Wine prefix creation (VARA handles it)
- Remove Wine Mono installation (VARA handles it)
- Remove msdatsrc.tlb installation (VARA handles it)
- Keep: VarAC extraction, config, launcher, persistence

## Execution Order

```
ENABLED_MODULES:
  20_VARA.sh      # Creates Wine prefix
  30_VARAC.sh     # Uses existing prefix
```

## Disabling CORE Module

Move script into subdirectory:
```bash
mv /arcHIVE/.../CORE/30_VARA.sh /arcHIVE/.../CORE/VARA/30_VARA.sh
```

This preserves the original for reference/rollback but prevents execution.

## Testing

1. Disable CORE module (move script)
2. Clear existing state (`~/.wine_vara_32`, `$SAVE_DIR/VARA/`)
3. Enable USER modules in ENABLED_MODULES
4. Reboot and run station-setup
5. Verify VARA launches, opens ports 8300/8100
6. Verify VarAC connects without .NET errors
7. Test PTT/CAT via rigctld
8. Reboot and verify tarball restore works

## Success Criteria

- [ ] VARA HF launches without errors
- [ ] VARA opens TCP port 8300 and 8100
- [ ] VarAC launches without .NET configuration errors
- [ ] VarAC connects to VARA modem
- [ ] PTT/CAT works through rigctld
- [ ] Configuration persists across reboot

## Rollback Plan

1. Move `30_VARA.sh` back to CORE root
2. Restore original Wine prefix tarball
3. Remove USER/VARA from ENABLED_MODULES
