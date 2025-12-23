#!/bin/bash
MODULE="SET-ARCOS-THEME"
source $HOME/.station-info
ARCOS_DATA=/arcHIVE
MODULE_DIR=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/$MODULE
LOGFILE=$MODULE_DIR/$MODULE.log
SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE
module_commands () {
    # Install save-theme utility
    sudo cp ${MODULE_DIR}/bin/save-theme /opt/arcOS/bin/
    sudo chmod +x /opt/arcOS/bin/save-theme
    cp ${MODULE_DIR}/save-theme.desktop $HOME/.local/share/applications/
    chmod +x $HOME/.local/share/applications/save-theme.desktop

    # Install custom cursor theme system-wide (so it persists)
    if [ ! -d /usr/share/icons/Bibata-Modern-Amber ]; then
        sudo cp -rL ${MODULE_DIR}/Bibata-Modern-Amber /usr/share/icons/
        sudo update-alternatives --install /usr/share/icons/default/index.theme x-cursor-theme /usr/share/icons/Bibata-Modern-Amber/cursor.theme 120
    fi

    # Set as default cursor theme via alternatives
    sudo update-alternatives --set x-cursor-theme /usr/share/icons/Bibata-Modern-Amber/cursor.theme

    # Set default cursor theme in user directory
    mkdir -p $HOME/.icons/default
    cat > $HOME/.icons/default/index.theme << 'EOF'
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=Bibata-Modern-Amber
EOF

    # Set Xcursor theme for X11 applications
    echo "Xcursor.theme: Bibata-Modern-Amber" > $HOME/.Xresources
    xrdb -merge $HOME/.Xresources 2>/dev/null || true

    # Restore saved theme settings
    mkdir -p ${SAVE_DIR}
    if [ -f ${SAVE_DIR}/theme.conf ]; then
        echo "Restoring theme settings from ${SAVE_DIR}/theme.conf..."
        source ${SAVE_DIR}/theme.conf

        # Update arcos-customization.sh to use saved theme values
        # This preserves the "apply on every shell" behavior with user's theme
        if [ -f /etc/profile.d/arcos-customization.sh ]; then
            sudo sed -i "
                s|gtk-theme \"Mint-Y-[^\"]*\"|gtk-theme \"${GTK_THEME}\"|g
                s|theme name \"Mint-Y-[^\"]*\"|theme name \"${CINNAMON_THEME}\"|g
            " /etc/profile.d/arcos-customization.sh
            echo "Updated arcos-customization.sh with saved theme: ${GTK_THEME}"
        fi

        # Also apply immediately
        gsettings set org.cinnamon.desktop.interface gtk-theme "${GTK_THEME}"
        gsettings set org.cinnamon.desktop.interface icon-theme "${ICON_THEME}"
        gsettings set org.cinnamon.desktop.interface cursor-theme "${CURSOR_THEME}"
        gsettings set org.cinnamon.theme name "${CINNAMON_THEME}"
        gsettings set org.gnome.desktop.interface gtk-theme "${GTK_THEME}"
        gsettings set org.gnome.desktop.interface icon-theme "${ICON_THEME}"
        gsettings set org.gnome.desktop.interface cursor-theme "${CURSOR_THEME}"

        echo "Theme applied: ${GTK_THEME}"
    else
        echo "No theme.conf found - using system defaults"
    fi
}
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
