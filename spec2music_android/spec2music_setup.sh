
#!/data/data/com.termux/files/usr/bin/bash

clear

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"
MUSICS_DIR="$APP_DIR/musics"
SPECS_DIR="$MUSICS_DIR/specs"

echo
echo "spec2music_android Setup / Update"
echo

echo "Creating application folders..."
echo

if ! mkdir -p "$SPECS_DIR"; then
    echo "Error: cannot create the application folders."
    echo
    read -r -p "Press Enter to continue..."
    exit 1
fi

echo "Updating Termux packages..."
echo

if ! pkg update -y; then
    echo
    echo "Warning: package update failed."
fi

echo
if [ ! -d ~/storage/shared ]; then
    echo
    echo "Setting up storage..."
    echo "If Android asks for permission, please allow it."
    echo

    if command -v termux-setup-storage >/dev/null 2>&1; then
        termux-setup-storage
    else
        echo
        echo "Warning: termux-setup-storage command was not found."
        echo "Storage access may not be configured correctly."
    fi
else
    echo
    echo "Storage is already configured."
fi

echo "Installing FFmpeg..."
echo

if ! pkg install -y ffmpeg; then
    echo
    echo "Error: FFmpeg installation failed."
fi

echo
echo "Setting script permissions..."
echo

for file in \
    "$APP_DIR/spec2music.sh" \
    "$APP_DIR/spec2music_setup.sh" \
    "$APP_DIR/spec2music_termuxshortcut.sh"; do

    if [ -f "$file" ]; then
        chmod +x "$file" 2>/dev/null || true
    fi

done

echo
if command -v ffmpeg >/dev/null 2>&1; then
    echo "FFmpeg is ready."
else
    echo "Warning: FFmpeg is not available."
fi

echo
echo "Musics folder: $MUSICS_DIR"
echo "Specs folder: $SPECS_DIR"
echo
echo "Setup completed."
echo

read -r -p "Press Enter to continue..."
