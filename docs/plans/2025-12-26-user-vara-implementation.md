# USER/VARA Module Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create USER/VARA module with Wine Mono that replaces broken CORE VARA module.

**Architecture:** Module follows arcOS pattern - tarball persistence on first boot, restore on subsequent boots. Uses Wine Mono instead of native .NET Framework. Silent VARA installation.

**Tech Stack:** Bash, Wine 9.0, Wine Mono, winetricks, tar/zstd

---

### Task 1: Disable CORE VARA Module

**Files:**
- Move: `/arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/30_VARA.sh` → `CORE/VARA/30_VARA.sh`

**Step 1: Move CORE module script to disable it**

```bash
mv /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/30_VARA.sh \
   /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/VARA/30_VARA.sh
```

**Step 2: Verify script moved**

Run: `ls -la /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/30_VARA.sh`
Expected: "No such file or directory"

Run: `ls -la /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/VARA/30_VARA.sh`
Expected: File exists

**Step 3: Commit**

```bash
git -C /arcHIVE/QRV/KO4DFO/arcos-linux-modules add CORE/30_VARA.sh CORE/VARA/30_VARA.sh
git -C /arcHIVE/QRV/KO4DFO/arcos-linux-modules commit -m "chore: disable CORE VARA module (moved to VARA/)"
```

---

### Task 2: Create USER/VARA Module Directory Structure

**Files:**
- Create: `VARA/` directory structure

**Step 1: Create directory structure**

```bash
cd /arcHIVE/QRV/KO4DFO/arcos-linux-modules/USER/ko4dfo-user-modules
mkdir -p VARA/{bin,config,applications,icons,exe,dll}
```

**Step 2: Verify structure**

Run: `ls -la VARA/`
Expected: bin, config, applications, icons, exe, dll directories

---

### Task 3: Copy Resources from CORE Module

**Files:**
- Copy: exe/, dll/, config/, applications/, icons/ from CORE/VARA

**Step 1: Copy executables and DLLs**

```bash
cd /arcHIVE/QRV/KO4DFO/arcos-linux-modules/USER/ko4dfo-user-modules
cp /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/VARA/exe/*.exe VARA/exe/
cp /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/VARA/exe/*.zip VARA/exe/
cp /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/VARA/dll/pdh.dll VARA/dll/
```

**Step 2: Copy config files**

```bash
cp /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/VARA/config/*.ini VARA/config/
```

**Step 3: Copy desktop and icon files**

```bash
cp /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/VARA/applications/*.desktop VARA/applications/
cp /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/VARA/icons/*.png VARA/icons/
```

**Step 4: Copy launcher script**

```bash
cp /arcHIVE/QRV/KO4DFO/arcos-linux-modules/CORE/VARA/bin/start-vara-hf.sh VARA/bin/
```

**Step 5: Verify all files**

Run: `find VARA -type f | wc -l`
Expected: ~10-12 files

---

### Task 4: Add msdatsrc.tlb

**Files:**
- Create: `VARA/dll/msdatsrc.tlb`

**Step 1: Copy msdatsrc.tlb from extracted location**

```bash
cp /tmp/extract_tlb/.wine_vara_32/drive_c/windows/system32/msdatsrc.tlb \
   /arcHIVE/QRV/KO4DFO/arcos-linux-modules/USER/ko4dfo-user-modules/VARA/dll/
```

**Step 2: Verify file**

Run: `ls -la VARA/dll/msdatsrc.tlb`
Expected: File exists, ~2.5KB

---

### Task 5: Write 20_VARA.sh Module Script

**Files:**
- Create: `VARA/20_VARA.sh`

**Step 1: Create the module script**

```bash
#!/bin/bash

######################
# VARA QRV MODULE    #
######################
MODULE="VARA"

# STATION INFO
source $HOME/.station-info

# PATHS
ARCOS_DATA=/arcHIVE
MODULE_DIR=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/$MODULE
LOGFILE=$MODULE_DIR/$MODULE.log
SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE
########################

### MODULE COMMANDS FUNCTION ###
module_commands () {

export WINEARCH=win32
export WINEPREFIX=$HOME/.wine_vara_32

prepare_vara () {
    echo "[VARA] Initializing Wine prefix..."

    # Create fresh 32-bit Wine prefix (keeps Wine Mono)
    wineboot --init
    wineserver -w

    # Cache and install VB6 runtime
    mkdir -p $HOME/.cache/winetricks/vb6run
    cp $MODULE_DIR/exe/VB6.0-KB290887-X86.exe $HOME/.cache/winetricks/vb6run/
    winetricks -q vb6run

    # Cache and install VC++ 2015 runtime
    mkdir -p $HOME/.cache/winetricks/vcrun2015
    cp $MODULE_DIR/exe/vc_redist.x86.exe $HOME/.cache/winetricks/vcrun2015/
    winetricks -q vcrun2015

    # Copy pdh.dll
    cp $MODULE_DIR/dll/pdh.dll $HOME/.wine_vara_32/drive_c/windows/system32/

    # Copy and register msdatsrc.tlb (required for VARA TCP port 8300)
    cp $MODULE_DIR/dll/msdatsrc.tlb $HOME/.wine_vara_32/drive_c/windows/system32/
    wine regtlib C:\\windows\\system32\\msdatsrc.tlb

    # Configure COM port and ALSA audio for DigiRig
    wine reg add "HKLM\\Software\\Wine\\Ports" /v COM1 /d /dev/digirig /t REG_SZ /f
    wine reg add "HKCU\\Software\\Wine\\Drivers\\winealsa.drv" /v ALSAInputDevices /d digirig-rx /t REG_MULTI_SZ /f
    wine reg add "HKCU\\Software\\Wine\\Drivers\\winealsa.drv" /v ALSAOutputDevices /d digirig-tx /t REG_MULTI_SZ /f

    # Set Windows 10 mode for better .NET compatibility
    wine reg add "HKCU\\Software\\Wine" /v Version /t REG_SZ /d win10 /f

    wineserver -w
    echo "[VARA] Wine prefix prepared"
}

install_vara () {
    echo "[VARA] Installing VARA HF..."
    unzip -o -d /tmp $MODULE_DIR/exe/"VARA HF v4.8.9 setup.zip"
    wine /tmp/"VARA setup (Run as Administrator)".exe /SILENT
    wineserver -w
    sleep 2

    echo "[VARA] Installing VARA FM..."
    unzip -o -d /tmp $MODULE_DIR/exe/"VARA FM v4.3.9 setup.zip"
    wine /tmp/"VARA FM setup (Run as Administrator)".exe /SILENT
    wineserver -w
    sleep 2

    # Clean up installer files
    rm -f /tmp/"VARA setup (Run as Administrator)".exe
    rm -f /tmp/"VARA FM setup (Run as Administrator)".exe

    echo "[VARA] Installation complete"
}

config_vara () {
    echo "[VARA] Configuring VARA..."

    # Copy config files with callsign substitution
    cp $MODULE_DIR/config/VARA.ini $HOME/.wine_vara_32/drive_c/VARA/VARA.ini
    sed -i "s/XXXCALLSIGNXXX/$MYCALL/" $HOME/.wine_vara_32/drive_c/VARA/VARA.ini

    cp $MODULE_DIR/config/VARAFM.ini $HOME/.wine_vara_32/drive_c/VARA\ FM/VARAFM.ini
    sed -i "s/XXXCALLSIGNXXX/$MYCALL/" $HOME/.wine_vara_32/drive_c/VARA\ FM/VARAFM.ini

    # Install launcher script
    sudo cp $MODULE_DIR/bin/start-vara-hf.sh /opt/arcOS/bin/
    sudo chmod +x /opt/arcOS/bin/start-vara-hf.sh

    # Install desktop files
    mkdir -p $HOME/.local/share/applications/wine/Programs/VARA
    mkdir -p $HOME/.local/share/applications/wine/Programs/VARA\ FM
    cp $MODULE_DIR/applications/VARA.desktop $HOME/.local/share/applications/wine/Programs/VARA/
    cp "$MODULE_DIR/applications/VARA FM.desktop" "$HOME/.local/share/applications/wine/Programs/VARA FM/"

    # Install icons
    mkdir -p $HOME/.local/share/icons/hicolor/48x48/apps
    cp $MODULE_DIR/icons/F302_VARA.0.png $HOME/.local/share/icons/hicolor/48x48/apps/
    cp $MODULE_DIR/icons/C497_VARAFM.0.png $HOME/.local/share/icons/hicolor/48x48/apps/

    echo "[VARA] Configuration complete"
}

persist_vara () {
    echo "[VARA] Saving Wine prefix to persistent storage..."
    mkdir -p $SAVE_DIR/{icons,applications}

    # Save entire Wine prefix as tarball
    tar -C $HOME -cf $SAVE_DIR/wine_vara.tar .wine_vara_32

    # Save icons and desktop files for fast restore
    cp $MODULE_DIR/icons/F302_VARA.0.png $SAVE_DIR/icons/
    cp $MODULE_DIR/icons/C497_VARAFM.0.png $SAVE_DIR/icons/
    cp $MODULE_DIR/applications/VARA.desktop $SAVE_DIR/applications/
    cp "$MODULE_DIR/applications/VARA FM.desktop" $SAVE_DIR/applications/

    echo "[VARA] Saved to $SAVE_DIR"
}

register_vara () {
    REG_CODE=$(yad --title="VARA Registration..." \
        --window-icon="dialog-password-symbolic" \
        --undecorated \
        --form --borders=36 \
        --center \
        --fixed \
        --field="" \
        --text="Enter VARA Registration Code, or leave empty to continue without registration.\n\n" \
        --no-escape \
        --button="OK" \
        --buttons-layout=end)

    REG_CODE=$(echo -n "$REG_CODE" | sed 's/|//')

    if [ -n "$REG_CODE" ]; then
        echo "$REG_CODE" > $SAVE_DIR/REGISTRATION_CODE
        sed -i 's/^Registration Code=.*$/Registration Code='"$REG_CODE"'/' $HOME/.wine_vara_32/drive_c/VARA/VARA.ini
        sed -i 's/^Registration Code=.*$/Registration Code='"$REG_CODE"'/' $HOME/.wine_vara_32/drive_c/VARA\ FM/VARAFM.ini

        # Re-save tarball with registration
        tar -C $HOME -cf $SAVE_DIR/wine_vara.tar .wine_vara_32
    fi
}

deploy_vara () {
    if [ -f $SAVE_DIR/wine_vara.tar ]; then
        echo "[VARA] Restoring from saved tarball..."

        # Restore Wine prefix
        tar -C $HOME -xf $SAVE_DIR/wine_vara.tar

        # Restore icons
        mkdir -p $HOME/.local/share/icons/hicolor/48x48/apps
        cp $SAVE_DIR/icons/F302_VARA.0.png $HOME/.local/share/icons/hicolor/48x48/apps/
        cp $SAVE_DIR/icons/C497_VARAFM.0.png $HOME/.local/share/icons/hicolor/48x48/apps/

        # Restore desktop files
        mkdir -p $HOME/.local/share/applications/wine/Programs/VARA
        mkdir -p "$HOME/.local/share/applications/wine/Programs/VARA FM"
        cp $SAVE_DIR/applications/VARA.desktop $HOME/.local/share/applications/wine/Programs/VARA/
        cp "$SAVE_DIR/applications/VARA FM.desktop" "$HOME/.local/share/applications/wine/Programs/VARA FM/"

        # Add Categories if missing
        if ! grep -q "Categories" $HOME/.local/share/applications/wine/Programs/VARA/VARA.desktop 2>/dev/null; then
            echo "Categories=Wine" >> $HOME/.local/share/applications/wine/Programs/VARA/VARA.desktop
        fi
        if ! grep -q "Categories" "$HOME/.local/share/applications/wine/Programs/VARA FM/VARA FM.desktop" 2>/dev/null; then
            echo "Categories=Wine" >> "$HOME/.local/share/applications/wine/Programs/VARA FM/VARA FM.desktop"
        fi

        # Install launcher
        sudo cp $MODULE_DIR/bin/start-vara-hf.sh /opt/arcOS/bin/
        sudo chmod +x /opt/arcOS/bin/start-vara-hf.sh

        # Set Wine registry (COM port, ALSA)
        wine reg add "HKLM\\Software\\Wine\\Ports" /v COM1 /d /dev/digirig /t REG_SZ /f
        wine reg add "HKCU\\Software\\Wine\\Drivers\\winealsa.drv" /v ALSAInputDevices /d digirig-rx /t REG_MULTI_SZ /f
        wine reg add "HKCU\\Software\\Wine\\Drivers\\winealsa.drv" /v ALSAOutputDevices /d digirig-tx /t REG_MULTI_SZ /f
        wineserver -w

        # Restore registration code if saved
        if [ -f $SAVE_DIR/REGISTRATION_CODE ]; then
            REG_CODE=$(cat $SAVE_DIR/REGISTRATION_CODE)
            sed -i 's/^Registration Code=.*$/Registration Code='"$REG_CODE"'/' $HOME/.wine_vara_32/drive_c/VARA/VARA.ini
            sed -i 's/^Registration Code=.*$/Registration Code='"$REG_CODE"'/' $HOME/.wine_vara_32/drive_c/VARA\ FM/VARAFM.ini
        fi

        echo "[VARA] Restore complete"
    else
        echo "[VARA] First boot - full installation"
        if command -v wine > /dev/null; then
            notify-send --icon=wine "VARA" "Preparing to install VARA (first boot)..."
            if prepare_vara && install_vara && config_vara && persist_vara; then
                register_vara
                notify-send --icon=info "VARA" "VARA installed successfully."
            else
                notify-send --icon=error "$MODULE" "$MODULE installation failed!"
                return 1
            fi
        else
            notify-send --icon=error "VARA" "Wine is not available. Installation failed!"
            return 1
        fi
    fi
}

deploy_vara

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
```

**Step 2: Make executable**

```bash
chmod +x VARA/20_VARA.sh
```

**Step 3: Verify script syntax**

Run: `bash -n VARA/20_VARA.sh`
Expected: No output (no syntax errors)

---

### Task 6: Create README

**Files:**
- Create: `VARA/README`

**Step 1: Create README**

```
### INSTRUCTIONS ###

1) Ensure the ko4dfo-user-modules repository is cloned into the USER Module directory.

2) Disable the CORE VARA module by moving its script:
   mv /arcHIVE/QRV/$MYCALL/arcos-linux-modules/CORE/30_VARA.sh \
      /arcHIVE/QRV/$MYCALL/arcos-linux-modules/CORE/VARA/

3) Add 20_VARA.sh to the ENABLED_MODULES file:
   echo "20_VARA.sh" >> ko4dfo-user-modules/ENABLED_MODULES

4) Reboot or re-run Station Setup.

Notes:
- First boot will take several minutes to install VARA (silent install).
- Subsequent boots restore from saved tarball (fast).
- This module uses Wine Mono instead of native .NET Framework.
- Required for VarAC module to function properly.
- VARA HF and VARA FM will appear in the Wine category of the Main Menu.
```

---

### Task 7: Update ENABLED_MODULES

**Files:**
- Modify: `ENABLED_MODULES`

**Step 1: Add VARA module before VARAC**

The module should run before VARAC. Current ENABLED_MODULES has VARAC.sh at the end.

```bash
# Edit ENABLED_MODULES to add 20_VARA.sh before VARAC.sh
# Replace VARAC.sh line with:
# 20_VARA.sh
# VARAC.sh
```

**Step 2: Verify order**

Run: `grep -E "VARA|VARAC" ENABLED_MODULES`
Expected:
```
20_VARA.sh
VARAC.sh
```

---

### Task 8: Simplify VARAC Module

**Files:**
- Modify: `VARAC/VARAC.sh`

**Step 1: Remove Wine prefix creation from VARAC.sh**

Remove or comment out:
- Wine prefix creation (wineboot)
- Wine Mono installation
- msdatsrc.tlb installation
- VB6/VC++ runtime installation

Keep:
- VarAC extraction and installation
- VarAC.ini configuration
- varac-launch script installation
- Desktop file installation
- Config persistence

**Step 2: Add dependency check**

At start of module_commands(), add:
```bash
# Check that VARA module has created the Wine prefix
if [ ! -d "$WINEPREFIX/drive_c/VARA" ]; then
    notify-send --icon=error "VarAC" "VARA module must run first. Enable 20_VARA.sh in ENABLED_MODULES."
    return 1
fi
```

---

### Task 9: Clear Existing State and Test

**Step 1: Clear existing Wine prefix**

```bash
rm -rf ~/.wine_vara_32
```

**Step 2: Clear existing VARA saved state**

```bash
rm -rf /arcHIVE/QRV/KO4DFO/SAVED/VARA
```

**Step 3: Run VARA module manually**

```bash
./VARA/20_VARA.sh
```

**Step 4: Verify VARA installed**

Run: `ls ~/.wine_vara_32/drive_c/VARA/VARA.exe`
Expected: File exists

Run: `ls ~/.wine_vara_32/drive_c/windows/system32/msdatsrc.tlb`
Expected: File exists

**Step 5: Test VARA launch**

```bash
export WINEPREFIX=~/.wine_vara_32
wine ~/.wine_vara_32/drive_c/VARA/VARA.exe &
sleep 5
ss -tlnp | grep 8300
```
Expected: Port 8300 listening

---

### Task 10: Test VarAC Integration

**Step 1: Run VARAC module**

```bash
./VARAC/VARAC.sh
```

**Step 2: Launch VarAC**

```bash
/opt/arcOS/bin/varac-launch
```

**Step 3: Verify no .NET errors**

Expected: VarAC launches without XML configuration errors

**Step 4: Verify VARA connection**

Expected: VarAC connects to VARA modem on port 8300

---

### Task 11: Commit All Changes

**Step 1: Stage all new files**

```bash
git add VARA/
git add ENABLED_MODULES
git add VARAC/VARAC.sh
```

**Step 2: Commit**

```bash
git commit -m "feat: add USER/VARA module with Wine Mono support

- New VARA module uses Wine Mono instead of broken native .NET
- Includes msdatsrc.tlb for VARA TCP port 8300
- Silent VARA installation (no interactive prompts)
- VARAC simplified to use VARA's Wine prefix
- CORE 30_VARA.sh disabled (moved to VARA/ subdir)"
```

---

## Success Criteria

- [ ] CORE 30_VARA.sh disabled (moved)
- [ ] USER/VARA module created with all resources
- [ ] VARA installs silently on first boot
- [ ] VARA opens TCP port 8300
- [ ] VarAC launches without .NET errors
- [ ] VarAC connects to VARA
- [ ] Configuration persists across reboot
