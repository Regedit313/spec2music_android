
#!/data/data/com.termux/files/usr/bin/bash

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"
MUSICS_DIR="$APP_DIR/musics"
SPECS_DIR="$MUSICS_DIR/specs"

mkdir -p "$SPECS_DIR" || exit 1

pause_screen() {
    echo
    read -r -p "Press Enter to continue..."
}

generate_specs() {
    clear

    echo
    echo "Generate Specs"
    echo

    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "Error: FFmpeg is not installed."
        echo "Run Setup / Update first."
        pause_screen
        return
    fi

    # Remove all previous spectrograms.
    if ! rm -rf -- "$SPECS_DIR" || \
       ! mkdir -p "$SPECS_DIR"; then
        echo "Error: cannot prepare the specs folder."
        pause_screen
        return
    fi

    local input output
    local total=0
    local successful=0
    local failed=0

    for input in "$MUSICS_DIR"/*; do

        [ -f "$input" ] || continue

        case "${input,,}" in
            *.mp3|*.flac|*.wav|*.m4a|*.aac|*.ogg|*.opus|*.wma|*.aif|*.aiff|*.ape|*.wv|*.mp4)
                ;;
            *)
                continue
                ;;
        esac

        output="$SPECS_DIR/${input##*/}.png"

        total=$((total + 1))

        echo "Generating: ${input##*/}"

        if ffmpeg -hide_banner -loglevel error -y \
            -i "$input" \
            -lavfi "showspectrumpic=s=1920x1080:legend=1:fscale=lin:scale=log:drange=100" \
            -frames:v 1 \
            "$output"; then

            successful=$((successful + 1))

        else
            failed=$((failed + 1))
            echo "Failed: ${input##*/}"
        fi

        echo

    done

    echo
    echo "Generation completed."
    echo
    echo "Musics found: $total"
    echo "Successful: $successful"
    echo "Failed: $failed"
    echo
    echo "Output: $SPECS_DIR"

    pause_screen
}

clear_musics() {
    if rm -rf -- "$MUSICS_DIR" && \
       mkdir -p "$SPECS_DIR"; then

        echo
        echo "Musics folder cleared."
        sleep 1

    else
        echo
        echo "Error: cannot clear the musics folder."
        pause_screen
    fi
}

run_setup() {
    if [ ! -f "$APP_DIR/spec2music_setup.sh" ]; then
        echo
        echo "Error: setup file is missing."
        pause_screen
        return
    fi

    bash "$APP_DIR/spec2music_setup.sh"
}

while true; do
    clear

    echo
    echo "spec2music_android"
    echo
    echo
    echo "1) Generate Specs"
    echo
    echo "3) Clear Musics Folder"
    echo
    echo
    echo "9) Run Setup / Update"
    echo
    echo "0) Exit"
    echo

    if ! read -r -p "Choose what to do: " choice; then
        echo
        exit 0
    fi

    case "$choice" in

        1)
            generate_specs
            ;;

        3)
            clear_musics
            ;;

        9)
            clear
            run_setup
            ;;

        0)
            clear
            exit 0
            ;;

        *)
            echo
            echo "Invalid choice."
            sleep 1
            ;;

    esac
done
