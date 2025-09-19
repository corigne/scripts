#!/bin/bash

### FUNCTIONS

graceful_shutdown () {
    printf "\nReceived SIGTERM, attempting graceful shutdown."

    # Kill any running background jobs
    jobs -p | xargs -r kill -TERM 2>/dev/null

    rm -f "$PIDFILE"
    trap - SIGTERM
    exit 0
}

# Replace your sleep with an interruptible version
interruptible_sleep() {
    local duration=$1
    sleep "$duration" &
    local sleep_pid=$!
    wait $sleep_pid 2>/dev/null
    return $?
}

next_image () {
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
            pairs+=("$current_img;${DISPLAY_LIST[i]}")
            ((img_index++))
        done

        echo "Setting wallpapers: ${current_images[*]}"

        # Process all displays in parallel with different images
        printf '%s\n' "${pairs[@]}" |
            parallel --colsep ';' -j "$NUM_DISPLAYS" process_wallpaper {1} {2}

        interruptible_sleep "$INTERVAL"
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

        interruptible_sleep "$INTERVAL"
    fi
}

###

trap graceful_shutdown SIGTERM
trap "next_image $1" SIGUSR1

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

# Configuration
export SWWW_TRANSITION_FPS=144
export SWWW_TRANSITION_STEP=6
INTERVAL=300
RESIZE_TYPE="crop"
FILTER_TYPE="Lanczos3"
FILL_COLOR="223344"
TRANSITION="random"

# Get display list once
count=0
until [ ${#DISPLAY_LIST[@]} -ge 1 ]; do
    if [ $count -ge 500 ]; then
        echo "Unable to find a display via swww query."
        exit 1
    fi
    sleep 0.01s
    DISPLAY_LIST=($(swww query | awk -F': ' '/^: / {print $2}'))
    count=$count+1
done

NUM_DISPLAYS=${#DISPLAY_LIST[@]}
    echo "Found displays: $DISPLAY_LIST"

# Function to process a single wallpaper for a display
process_wallpaper() {
    local img="$1"
    local display="$2"
    printf "Calling swww img:\n"
    printf "\tImage: $img\n"
    printf "\tDisplay: $display...\n"

    # Check if file is a GIF
    if [[ $(file --mime-type -b "$img") == "image/gif" ]]; then
        # swww img --filter="$FILTER_TYPE" \
        #     --transition-type=$($IS_RUNNING && IS_RUNNING=false && echo "none" || echo $TRANSITION) \
        #     --resize="$RESIZE_TYPE" \
        #     --fill-color="$FILL_COLOR" \
        #     --outputs "$display" $img
        waypaper --wallpaper $img
    else
        # Use gowall for other image formats
        gowall convert "$img" $THEME - --format png |
            swww img --filter="$FILTER_TYPE" \
            --transition-type=$($IS_RUNNING && IS_RUNNING=false && echo "none" || echo $TRANSITION) \
            --resize="$RESIZE_TYPE" \
            --fill-color="$FILL_COLOR" \
            --outputs "$display" -
    fi

}
export -f process_wallpaper
export THEME RESIZE_TYPE FILTER_TYPE TRANSITION FILL_COLOR

# Function to get shuffled image list
get_shuffled_images() {
    #find "$1" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) \
    #   -print0 | shuf -z | tr '\0' '\n'

    find "$1" -type f -exec file --mime-type {} + | \
        grep -E "image/.*" | \
        cut -d: -f1 | \
        shuf
    }

echo "Starting wallpaper randomizer for ${NUM_DISPLAYS} display(s)"

while true; do
    next_image $1
done
