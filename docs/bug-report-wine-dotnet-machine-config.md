# Bug Report: Corrupted machine.config in arcOS Wine Prefix

## Summary

The arcOS-baked Wine prefix for VARA/VarAC contains a corrupted `machine.config` file that causes .NET applications (like VarAC) to fail with XML parsing errors.

## Environment

- **arcOS Version**: [Insert version]
- **Wine Version**: 9.0 (Ubuntu 9.0~repack-4build3)
- **Wine Prefix**: `~/.wine_vara_32` (32-bit)
- **Affected Applications**: VarAC (any .NET application using sockets/crypto)

## Bug Details

### Symptoms

When launching VarAC, the application crashes with:

```
System.Configuration.ConfigurationErrorsException: Configuration system failed to initialize
---> System.ApplicationException: Invalid XML in file
'C:\windows\Microsoft.NET\Framework\v4.0.30319\config\machine.config'
near element '<configSections>'.
---> System.Runtime.InteropServices.COMException: Exception from HRESULT: 0xC00CE503
```

### Root Cause

The `machine.config` file contains **30 lines with invalid XML syntax** - stray `-->` comment closing tags at the end of element definitions.

**Location**: `~/.wine_vara_32/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/Config/machine.config`

**Example of corrupted lines**:
```xml
<!-- Line 6 - nested comments (invalid) -->
<!-- <!-- <section name="configProtectedData" ... /> --> -->

<!-- Lines 7-8 - stray closing comment tags -->
<section name="appSettings" ... /> -->
<section name="connectionStrings" ... /> -->
```

### Winetricks Configuration

The prefix was created with:
```
remove_mono internal
remove_mono internal
winxp
dotnet40
dotnet48
vb6run
```

This configuration removes Wine Mono and installs native .NET Framework 4.0 + 4.8, which is known to be fragile under Wine.

## Reproduction Steps

1. Boot arcOS fresh (uses baked-in Wine prefix tarball)
2. Launch VarAC: `/opt/arcOS/bin/varac-launch`
3. VarAC opens but crashes when trying to connect to VARA modem
4. Error dialog appears with XML parsing exception

## Affected Lines in machine.config

Total corrupted lines: **30**

```
Line 6:  <!-- <!-- <section name="configProtectedData"... /> --> -->
Line 7:  <section name="appSettings"... /> -->
Line 8:  <section name="connectionStrings"... /> -->
Line 24: <section name="authorization"... /> -->
Line 25: <section name="browserCaps"... /> -->
Line 26: <section name="clientTarget"... /> -->
Line 27: <section name="compilation"... /> -->
Line 28: <section name="customErrors"... /> -->
Line 30: <section name="globalization"... /> -->
Line 33: <section name="httpCookies"... /> -->
Line 34: <section name="httpHandlers"... /> -->
Line 35: <section name="httpModules"... /> -->
Line 36: <section name="httpRuntime"... /> -->
Line 37: <section name="identity"... /> -->
Line 38: <section name="machineKey"... /> -->
Line 39: <section name="membership"... /> -->
Line 42: <section name="pages"... /> -->
Line 47: <section name="sessionPageState"... /> -->
Line 50: <section name="trace"... /> -->
Line 53: <section name="webControls"... /> -->
... (10 more lines)
```

## Recommended Fix

### Option 1: Fix machine.config (Quick Fix)

Remove stray `-->` from affected lines:
```bash
sed -i 's/ \/> -->/ \/>/' ~/.wine_vara_32/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/Config/machine.config
```

### Option 2: Use Wine Mono (Recommended)

Instead of native .NET Framework via winetricks, use Wine Mono:

1. Remove `remove_mono`, `dotnet40`, `dotnet48` from winetricks installation
2. Install Wine Mono 7.4.0 or later
3. Wine Mono is specifically designed to work reliably under Wine

### Option 3: Rebuild Prefix with Working machine.config

1. Source a known-good machine.config from a working Windows/.NET installation
2. Replace corrupted file during arcOS build process
3. Update tarball

## Additional Notes

- VarAC is a .NET application (`PE32 executable (GUI) Intel 80386 Mono/.Net assembly`)
- VARA is a VB6 application (works fine with current prefix)
- The issue only affects .NET applications that use socket/crypto initialization
- The same prefix may have previously shown `mscoree.dll not found` errors (different failure mode of the same underlying .NET configuration issue)

## Files for Reference

- Corrupted config: `~/.wine_vara_32/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/Config/machine.config`
- Winetricks log: `~/.wine_vara_32/winetricks.log`
- Wine prefix tarball: `/arcHIVE/QRV/$MYCALL/SAVED/VARA/wine_vara.tar`

---
*Report generated: 2025-12-26*
*Reporter: Claude Code (assisting KO4DFO)*
