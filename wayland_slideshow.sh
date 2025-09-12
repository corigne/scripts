#!/bin/bash
# Multi-monitor wallpaper randomizer with GNU parallel support
if [[ $# -lt 1 ]] || [[ ! -d $1 ]]; then
    echo "Usage: $0 <dir containing images> [theme]"
    exit 1
fi

# Validate and set theme
THEME=""
if [[ -n "$2" ]] && gowall list | grep -q "^$2$"; then
    THEME="-t $2"
fi
echo "Using theme: $THEME"

# Single instance check
PIDFILE=~/.local/state/swww-randomize-pidfile.txt
if [[ -e "$PIDFILE" ]]; then
    OLD_PID="$(<$PIDFILE)"
    if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Another instance is already running (PID: $OLD_PID)"
        exit 1
    fi
fi
echo "No instance of wallpaper script running, continuing with PID: $$."
echo "$$" >"$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

# Configuration
export SWWW_TRANSITION_FPS=144
export SWWW_TRANSITION_STEP=6
INTERVAL=300
RESIZE_TYPE="crop"
FILTER_TYPE="CatmullRom"
FILL_COLOR="b7bdf8"
TRANSITION="random"

# Get display list once
local count=0
until [ ${#DISPLAY_LIST[@]} -ge 1 ]; do
    if [$count -ge 500 ]; then
        echo "Unable to find a display via swww query."
        exit 1
    fi
    sleep 0.01s
    DISPLAY_LIST=($(swww query | awk -F': ' '/^: / {print $2}'))
    $count++
done

NUM_DISPLAYS=${#DISPLAY_LIST[@]}
echo "Found displays: $DISPLAY_LIST"

# Function to process a single wallpaper for a display
process_wallpaper() {
    local img="$1"
    local display="$2"
    printf "Attempting set:"
    printf "\tImage: $img"
    printf "\tDisplay: $display..."
    gowall convert "$img" $THEME - --format png |
        swww img --filter="$FILTER_TYPE" \
            --transition-type="$TRANSITION" \
            --resize="$RESIZE_TYPE" \
            --fill-color="$FILL_COLOR" \
            --outputs "$display" -
}
export -f process_wallpaper
export THEME RESIZE_TYPE FILTER_TYPE TRANSITION FILL_COLOR

# Function to get shuffled image list
get_shuffled_images() {
    find "$1" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) \
        -print0 | shuf -z | tr '\0' '\n'
}

echo "Starting wallpaper randomizer for ${NUM_DISPLAYS} display(s)"

while true; do
    # Get shuffled list of images
    readarray -t images < <(get_shuffled_images "$1")

    if [[ ${#images[@]} -eq 0 ]]; then
        echo "No images found in $1"
        exit 1
    fi

    # Check if we have enough images for all displays
    if [[ ${#images[@]} -lt $NUM_DISPLAYS ]]; then
        echo "Warning: Only ${#images[@]} images found, but $NUM_DISPLAYS displays detected"
        echo "Some displays will reuse images"
    fi

    # Save current list for reference
    printf '%s\n' "${images[@]}" >~/.local/state/swww-randomize-list.txt

    # Calculate how many complete cycles we can do
    if [[ ${#images[@]} -ge $NUM_DISPLAYS ]]; then
        CYCLES=$((${#images[@]} / NUM_DISPLAYS))
        REMAINDER=$((${#images[@]} % NUM_DISPLAYS))
    else
        CYCLES=1
        REMAINDER=0
    fi

    img_index=0

    # Process complete cycles
    for ((cycle = 0; cycle < CYCLES; cycle++)); do
        echo "Cycle $((cycle + 1))/$CYCLES"

        # Create array of image-display pairs for this cycle
        pairs=()
        current_images=()

        for ((i = 0; i < NUM_DISPLAYS; i++)); do
            current_img="${images[img_index]}"
            current_images+=("$(basename "$current_img")")
            pairs+=("$current_img ${DISPLAY_LIST[i]}")
            ((img_index++))
        done

        echo "Setting wallpapers: ${current_images[*]}"

        # Process all displays in parallel with different images
        printf '%s\n' "${pairs[@]}" |
            parallel --colsep ' ' -j "$NUM_DISPLAYS" process_wallpaper {1} {2}

        sleep "$INTERVAL"
    done

    # Handle remaining images if any
    if [[ $REMAINDER -gt 0 ]]; then
        echo "Processing remaining $REMAINDER images"

        pairs=()
        current_images=()

        for ((i = 0; i < REMAINDER; i++)); do
            current_img="${images[img_index]}"
            current_images+=("$(basename "$current_img")")
            pairs+=("$current_img ${DISPLAY_LIST[i]}")
            ((img_index++))
        done

        echo "Setting wallpapers: ${current_images[*]}"

        # Process remaining displays in parallel
        printf '%s\n' "${pairs[@]}" |
            parallel --colsep ' ' -j "$REMAINDER" process_wallpaper {1} {2}

        sleep "$INTERVAL"
    fi
done
