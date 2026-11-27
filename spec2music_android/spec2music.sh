
#!/data/data/com.termux/files/usr/bin/bash

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"
MUSICS_DIR="$APP_DIR/musics"
SPECS_DIR="$MUSICS_DIR/specs"

mkdir -p "$SPECS_DIR"

pause_screen() {
    echo
    read -r -p "Press Enter to continue..."
}

probe_audio() {
    ffprobe -v error -select_streams a:0 \
        -show_entries "stream=$1" \
        -of default=nw=1:nk=1 "$2" 2>/dev/null
}

probe_format() {
    ffprobe -v error \
        -show_entries "format=$1" \
        -of default=nw=1:nk=1 "$2" 2>/dev/null
}

generate_with_info() {
    local input="$1"
    local output="$2"
    local filename="${input##*/}"

    local codec rate channels bits bitrate duration
    local seconds depth title_size line2 line3
    local tmpdir result

    # If FFprobe is unavailable, use the original generation.
    if ! command -v ffprobe >/dev/null 2>&1; then
        ffmpeg -hide_banner -loglevel error -y \
            -i "$input" \
            -lavfi "showspectrumpic=s=1920x1080:legend=1:fscale=lin:scale=log:drange=100" \
            -frames:v 1 \
            "$output"
        return $?
    fi

    codec="$(probe_audio codec_name "$input")"
    rate="$(probe_audio sample_rate "$input")"
    channels="$(probe_audio channel_layout "$input")"
    bits="$(probe_audio bits_per_raw_sample "$input")"

    if [ -z "$bits" ] || [ "$bits" = "N/A" ]; then
        bits="$(probe_audio bits_per_sample "$input")"
    fi

    bitrate="$(probe_format bit_rate "$input")"
    duration="$(probe_format duration "$input")"

    [ -n "$codec" ] && [ "$codec" != "N/A" ] || codec="Unknown"
    [ -n "$rate" ] && [ "$rate" != "N/A" ] || rate="Unknown"

    if [ -z "$channels" ] || [ "$channels" = "N/A" ]; then
        channels="$(probe_audio channels "$input")"

        if [ -n "$channels" ] && [ "$channels" != "N/A" ]; then
            channels="$channels ch"
        else
            channels="Unknown"
        fi
    fi

    if [[ "$bitrate" =~ ^[0-9]+$ ]]; then
        bitrate="$((bitrate / 1000)) kbps"
    else
        bitrate="Unknown bitrate"
    fi

    if [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        seconds="${duration%%.*}"
        duration="$(printf '%02d:%02d' \
            "$((seconds / 60))" "$((seconds % 60))")"
    else
        duration="Unknown"
    fi

    if [[ "$bits" =~ ^[0-9]+$ ]] && [ "$bits" -gt 0 ]; then
        depth="$bits-bit"
    else
        depth=""
    fi

    # Adjust the title size for long filenames.
    title_size=30

    if [ "${#filename}" -gt 55 ]; then
        title_size=25
    fi

    if [ "${#filename}" -gt 80 ]; then
        title_size=20
    fi

    if [ "${#filename}" -gt 110 ]; then
        title_size=18
    fi

    line2="${codec^^} | $bitrate | $rate Hz"
    line3="$channels | $duration"

    if [ -n "$depth" ]; then
        line3="$line3 | $depth"
    fi

    tmpdir="$(mktemp -d)" || return 1

    printf '%s\n' "$filename" > "$tmpdir/title.txt"
    printf '%s\n' "$line2" > "$tmpdir/info1.txt"
    printf '%s\n' "$line3" > "$tmpdir/info2.txt"

    ffmpeg -hide_banner -loglevel error -y \
        -i "$input" \
        -lavfi "showspectrumpic=s=1920x1080:legend=1:fscale=lin:scale=log:drange=100,pad=iw:ih+120:0:120:black,drawtext=textfile=$tmpdir/title.txt:fontcolor=white:fontsize=$title_size:x=20:y=10,drawtext=textfile=$tmpdir/info1.txt:fontcolor=white:fontsize=26:x=20:y=50,drawtext=textfile=$tmpdir/info2.txt:fontcolor=white:fontsize=25:x=20:y=85" \
        -frames:v 1 \
        "$output"

    result=$?

    rm -rf -- "$tmpdir"

    # Fall back to the original spectrogram if the info filter fails.
    if [ "$result" -ne 0 ]; then
        echo "Info generation failed. Trying original spectrogram..."

        ffmpeg -hide_banner -loglevel error -y \
            -i "$input" \
            -lavfi "showspectrumpic=s=1920x1080:legend=1:fscale=lin:scale=log:drange=100" \
            -frames:v 1 \
            "$output"

        return $?
    fi

    return 0
}

generate_specs() {
    local mode="$1"

    clear

    echo
    if [ "$mode" = "info" ]; then
        echo "Generate Specs + Info"
    else
        echo "Generate Specs"
    fi
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

        if [ "$mode" = "info" ]; then

            if generate_with_info "$input" "$output"; then
                successful=$((successful + 1))
            else
                failed=$((failed + 1))
                echo "Failed: ${input##*/}"
            fi

        else

            # Original FFmpeg generation without FFprobe or drawtext.
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
    echo "1) Generate Specs + Info"
    echo
    echo "2) Generate Specs"
    echo
    echo
    echo "4) Clear Musics Folder"
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
            generate_specs "info"
            ;;

        2)
            generate_specs "original"
            ;;

        4)
            clear_musics
            ;;

        9)
            clear
            run_setup
            ;;

        0|"")
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

