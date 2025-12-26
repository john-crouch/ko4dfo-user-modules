# VARAC Module Build Documentation

This document captures the build process, requirements, and known issues for running VarAC and VARA HF modem under Wine on arcOS.

## Overview

VarAC is a Windows amateur radio chat application that uses the VARA HF modem for digital communication. Running it on Linux requires Wine with specific configurations.

**Status as of 2024-12-26**: VarAC and VARA successfully communicate over TCP port 8300. PTT via rigctld requires further testing.

## What Works

| Component | Status | Notes |
|-----------|--------|-------|
| VARA TCP server (port 8300) | Working | Requires msdatsrc.tlb |
| VARA KISS port (port 8100) | Working | |
| VarAC ↔ VARA communication | Working | Requires specific VarAC.ini settings |
| VarAC platform detection bypass | Working | Requires LinuxCompatibleMode + Windows 10 mode |
| rigctld CAT control | Working | Tested with TS-570S |
| rigctld PTT | Working | Direct `rigctl T 1` works |
| VarAC → rigctld PTT | Untested | Configuration in place but not verified |

## Critical Requirements

### 1. msdatsrc.tlb (MANDATORY)

**Without this file, VARA will NOT open TCP port 8300.**

- **Symptom when missing**: VARA starts, KISS port 8100 opens, but port 8300 never opens
- **Wine debug output**: `err:ole:TLB_ReadTypeLib Loading of typelib L"msdatsrc.tlb" failed with error 2`

**Source**: Windows SDK on GitHub
```bash
curl -L -o /tmp/msdatsrc.tlb "https://github.com/tpn/winsdk-7/raw/master/v7.1A/Lib/msdatsrc.tlb"
```

**Installation**:
```bash
cp /tmp/msdatsrc.tlb $WINEPREFIX/drive_c/windows/system32/
```

**File details**: 2528 bytes, Microsoft Data Source Interfaces type library

### 2. VarAC.ini Configuration (MANDATORY)

VarAC reads its configuration from **two locations**. Both must be configured:

1. `/home/user/VarAC.ini` (Linux home, accessed via Wine Z: drive)
2. `$WINEPREFIX/drive_c/users/user/VarAC.ini` (Windows user profile)

**Critical settings**:

```ini
[Setup]
LinuxCompatibleMode=1      ; MUST be in [Setup] section
AutoLaunchVARA=0           ; Prevent VarAC from launching VARA

[VARAHF_CONFIG]
VarahfMainPath=            ; EMPTY - prevents VarAC from finding VARA to launch
VarahfLaunchOnModemConnect=OFF   ; Prevent launch on modem connect
```

**Important**: Do NOT have `LinuxCompatibleMode` in multiple sections. Remove any duplicate from `[OTHER]` section.

### 3. VarAC GUI Setting (MANDATORY)

In addition to the ini file settings, you MUST disable this in the VarAC GUI:

**Settings → Uncheck "Start modem upon startup"**

**Investigation results**: This setting is NOT stored in:
- VarAC.ini (no change detected before/after checkbox toggle)
- Wine registry (user.reg, system.reg, userdef.reg - no VarAC entries)
- VarAC.db SQLite database (only contains db_version, logins, timestamps)
- AppData folders (empty)
- Any .NET config files

**The setting DOES persist** - VarAC logs confirm the behavior changes after unchecking and persists across restarts. Storage location is unknown (possibly embedded in the .NET runtime state or binary serialization).

**IMPORTANT**: The ini file settings (`AutoLaunchVARA=0`, `VarahfLaunchOnModemConnect=OFF`) did NOT prevent the auto-launch. Only the GUI checkbox successfully prevented VarAC from launching VARA. For arcOS persistence, the saved Wine prefix tarball contains the correct checkbox state.

### 4. Wine Windows 10 Mode (MANDATORY)

VarAC performs platform detection that fails under Wine. Setting Windows 10 mode bypasses this:

```bash
WINEPREFIX=$WINEPREFIX wine winecfg /v win10
```

**Symptom when not set**: VarAC shows "platform not supported" error on startup.

### 5. Startup Order (MANDATORY)

**VARA must be started BEFORE VarAC.**

If VarAC starts first, or if VarAC's auto-launch settings are enabled, you will see:
- "Another instance of VARA is running in this folder" error

Correct startup sequence:
```bash
# 1. Start VARA first
WINEPREFIX=$WINEPREFIX wine $WINEPREFIX/drive_c/VARA/VARA.exe &

# 2. Wait for VARA to initialize (port 8300 must be listening)
sleep 8
ss -tlnp | grep 8300   # Verify LISTEN state

# 3. Start VarAC
WINEPREFIX=$WINEPREFIX wine $WINEPREFIX/drive_c/VarAC/VarAC.exe &
```

## System Requirements

### Disk Space
- **Critical**: Wine prefix requires ~1.9GB when fully configured
- arcOS overlay filesystem is only 3.8GB total
- Must have at least 2GB free overlay space before extraction
- **Tip**: Extract to /tmp (separate tmpfs with ~3.8GB) to avoid overlay space issues
- **Recommendation**: Clean apt cache before build: `sudo apt-get clean`

### Software
- Wine 9.0+ (Ubuntu/Debian package: `wine`)
- winetricks (for VB6 runtime installation)

## Build Process

### Step 1: Create 32-bit Wine Prefix

```bash
export WINEARCH=win32
export WINEPREFIX=/tmp/.wine_vara_32   # Use /tmp to avoid overlay space issues
wineboot --init
```

Wait for Wine to initialize. Ignore OLE/RPC errors during init.

### Step 2: Install Wine Mono 7.4.0

**Important**: Use Wine Mono 7.4.0 specifically.

```bash
MONO_VERSION="7.4.0"
MONO_MSI="/tmp/wine-mono-${MONO_VERSION}-x86.msi"
wget -O "$MONO_MSI" "https://dl.winehq.org/wine/wine-mono/${MONO_VERSION}/wine-mono-${MONO_VERSION}-x86.msi"
WINEPREFIX=$WINEPREFIX wine msiexec /i "$MONO_MSI" /q
```

**Do NOT install native .NET Framework** via winetricks (dotnet40, dotnet48, etc.). This conflicts with Wine Mono.

### Step 3: Install VB6 Runtime

```bash
WINEPREFIX=$WINEPREFIX winetricks -q vb6run
```

### Step 4: Install msdatsrc.tlb

```bash
curl -L -o /tmp/msdatsrc.tlb "https://github.com/tpn/winsdk-7/raw/master/v7.1A/Lib/msdatsrc.tlb"
cp /tmp/msdatsrc.tlb $WINEPREFIX/drive_c/windows/system32/
```

### Step 5: Install VARA HF Modem

Copy VARA folder to `$WINEPREFIX/drive_c/VARA/`

### Step 6: Register OCX Controls

```bash
for ocx in COMDLG32 MSCHRT20 MSCOMCTL MSCOMM32 MSWINSCK; do
    WINEPREFIX=$WINEPREFIX wine regsvr32 "C:\\VARA\\OCX\\${ocx}.OCX"
done
WINEPREFIX=$WINEPREFIX wineserver -w   # Sync registry
```

### Step 7: Install VarAC

Copy VarAC folder to `$WINEPREFIX/drive_c/VarAC/`

### Step 8: Set Windows 10 Mode

```bash
WINEPREFIX=$WINEPREFIX wine winecfg /v win10
```

### Step 9: Configure COM Port for DigiRig

```bash
ln -sf /dev/digirig $WINEPREFIX/dosdevices/com1
```

### Step 10: Configure VarAC.ini

Create/edit `/home/user/VarAC.ini` with required settings (see Critical Requirements section).

Copy to Wine prefix:
```bash
cp /home/user/VarAC.ini $WINEPREFIX/drive_c/users/user/VarAC.ini
```

### Step 11: Disable "Start modem upon startup" in GUI

1. Start VARA manually
2. Start VarAC (dismiss any error)
3. Go to Settings
4. Uncheck "Start modem upon startup"
5. Save and exit

## Configuration Files

### VARA.ini ($WINEPREFIX/drive_c/VARA/VARA.ini)

```ini
[Soundcard]
Input Device Name=In: digirig-rx
Output Device Name=Out: digirig-tx
ALC Drive Level=-5

[PTT]
Rig=140                    ; Kenwood TS-570S
PTTPort=COM1
CATPort=COM1
Baud=9600
Via=3                      ; CAT control

[Setup]
Callsign Licence 0=YOURCALL
TCP Command Port=8300
Enable KISS=1
KISS Port=8100

[Monitor]
Monitor Mode=0
Monitor Path=C:\VARA\VARA.exe
```

### VarAC.ini (~/VarAC.ini)

```ini
[Setup]
Callsign=YOURCALL
Gridsquare=EM65RX
LinuxCompatibleMode=1      ; REQUIRED - must be in [Setup] only
AutoLaunchVARA=0           ; REQUIRED - prevent auto-launch

[RigControl]
PTTMode=2                  ; HAMLIB-RIGCTLD
CATMode=2                  ; HAMLIB-RIGCTLD
RigModel=2016              ; TS-570S

[RIG_COM_CONFIGS]
ControlMethod=HAMLIB-RIGCTLD
TCPHost=127.0.0.1
TCPPort=4532

[RIG_CONTROL]
RigPTTControlType=HAMLIB-RIGCTLD
RigFreqControlType=HAMLIB-RIGCTLD

[RIG_HAMLIB_CONFIG]
HamlibRigctldHost=localhost
HamlibRigctldPort=4532

[VARAHF_CONFIG]
VaraModemType=VaraHF
VarahfMainPath=            ; EMPTY - prevents VarAC from launching VARA
VarahfMainPort=8300
VarahfMainHost=127.0.0.1
VarahfLaunchOnModemConnect=OFF   ; REQUIRED
```

## Verification

### Verify VARA TCP Server
```bash
# Check port 8300 is listening
ss -tlnp | grep 8300
# Expected: LISTEN 0 5 0.0.0.0:8300

# Check port 8100 (KISS) is listening
ss -tlnp | grep 8100
```

### Verify VarAC Connection to VARA
```bash
# Check established connection
ss -tnp | grep 8300
# Expected: ESTAB connection between VarAC.exe and wineserver
```

### Verify rigctld (for PTT/CAT)
```bash
# Start rigctld for TS-570S
rigctld -m 2016 -r /dev/digirig -s 9600 -t 4532 &

# Test frequency read
rigctl -m 2 -r localhost:4532 f

# Test PTT
rigctl -m 2 -r localhost:4532 T 1   # Key up
rigctl -m 2 -r localhost:4532 T 0   # Key down
```

## Known Issues

### Issue: "Another instance of VARA is running in this folder"

**Cause**: VarAC is trying to launch VARA when VARA is already running.

**Solution**: Ensure ALL of these are set:
1. `AutoLaunchVARA=0` in VarAC.ini [Setup]
2. `VarahfMainPath=` (empty) in VarAC.ini [VARAHF_CONFIG]
3. `VarahfLaunchOnModemConnect=OFF` in VarAC.ini [VARAHF_CONFIG]
4. "Start modem upon startup" unchecked in VarAC GUI

### Issue: "Platform not supported" in VarAC

**Cause**: VarAC detects it's not running on Windows.

**Solution**:
1. Set `LinuxCompatibleMode=1` in VarAC.ini [Setup] section (NOT in [OTHER])
2. Set Wine to Windows 10 mode: `wine winecfg /v win10`

### Issue: VARA starts but port 8300 not listening

**Cause**: Missing msdatsrc.tlb typelib.

**Solution**: Install msdatsrc.tlb to system32 (see Critical Requirements).

**Diagnosis**:
```bash
WINEDEBUG=err WINEPREFIX=$WINEPREFIX wine $WINEPREFIX/drive_c/VARA/VARA.exe 2>&1 | grep msdatsrc
```

### Issue: VarAC connects to rigctld but PTT doesn't work

**Status**: Under investigation. Direct rigctl commands work, but VarAC may not be sending PTT commands.

## Tarball Creation

To save a working Wine prefix for arcOS persistence:

```bash
cd /tmp
tar -cf - .wine_vara_32 | pzstd -3 > /arcHIVE/QRV/$MYCALL/SAVED/VARAC/wine_vara.tar.zst
```

**Current tarball**: `wine_vara.tar.zst` (837MB compressed, 1.9GB uncompressed)

**To restore**:
```bash
cd /tmp
pzstd -d < /arcHIVE/QRV/$MYCALL/SAVED/VARAC/wine_vara.tar.zst | tar -xf -
```

**Important**: Only create tarball when Wine prefix is in known-good state.

## References

- VARA Author (EA5HVK): https://rosmodem.wordpress.com/
- VarAC Website: https://www.varac-hamradio.com/
- msdatsrc.tlb source: https://github.com/tpn/winsdk-7
- Wine Mono Releases: https://github.com/wine-mono/wine-mono/releases

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2024-12-26 | KO4DFO/Claude | Initial documentation |
| 2024-12-26 | KO4DFO/Claude | Added msdatsrc.tlb fix, VarAC auto-launch prevention, verified working config |
