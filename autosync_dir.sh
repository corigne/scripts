#!/bin/bash
# File Sync Monitor
# Watches a directory for file changes and triggers Unison sync with debouncing

DEBOUNCE_SECONDS=2         # Default debounce time
EXTENSIONS=()              # Empty = monitor all files
LOGFILE="$HOME/file-sync-monitor.log"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] WATCH_DIR UNISON_PROFILE

Monitors a directory for file changes and triggers Unison sync.

Arguments:
    WATCH_DIR       Directory to monitor (e.g., ~/orgfiles)
    UNISON_PROFILE  Name of the Unison profile to sync

Options:
    -d, --debounce SECONDS    Seconds to wait after last event (default: 2)
    -e, --extensions EXT...   File extensions to monitor (default: all files)
                              Multiple extensions separated by spaces
    -h, --help                Show this help message

Examples:
    # Monitor all files in ~/orgfiles
    $(basename "$0") ~/orgfiles orgfiles

    # Monitor only .org files
    $(basename "$0") -e org ~/orgfiles orgfiles

    # Monitor .md and .org files with 5 second debounce
    $(basename "$0") -d 5 -e md org ~/notes notes-sync

    # Monitor .pdf and .docx files
    $(basename "$0") --extensions pdf docx /path/to/docs docs-profile

Environment Variables:
    LOGFILE    Path to log file (default: ~/file-sync-monitor.log)
EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -d|--debounce)
            DEBOUNCE_SECONDS="$2"
            shift 2
            ;;
        -e|--extensions)
            shift
            # Collect all extensions until we hit another flag or positional arg
            while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                # Check if this might be a directory (contains /)
                if [[ "$1" == */* ]] || [ -d "$1" ] || [ -d "${1/#\~/$HOME}" ]; then
                    break
                fi
                EXTENSIONS+=("$1")
                shift
            done
            ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2
            usage
            ;;
        *)
            # Positional arguments
            if [ -z "$WATCH_DIR" ]; then
                WATCH_DIR="${1/#\~/$HOME}"
            elif [ -z "$UNISON_PROFILE" ]; then
                UNISON_PROFILE="$1"
            else
                echo "ERROR: Too many positional arguments" >&2
                usage
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$WATCH_DIR" ] || [ -z "$UNISON_PROFILE" ]; then
    echo "ERROR: Missing required arguments" >&2
    usage
fi

# Validate watch directory
if [ ! -d "$WATCH_DIR" ]; then
    echo "ERROR: Directory '$WATCH_DIR' does not exist" >&2
    exit 1
fi

# Temp file to track pending sync
SYNC_PENDING="/tmp/file-sync-pending-$$"
trap "rm -f $SYNC_PENDING; exit" EXIT INT TERM

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

run_sync() {
    log "Running Unison sync..."
    if unison "$UNISON_PROFILE" -batch; then
        log "Sync completed successfully"
    else
        log "ERROR: Sync failed with exit code $?"
    fi
}

# Check if file matches any of the extensions
matches_extension() {
    local file="$1"

    # If no extensions specified, match all files
    if [ ${#EXTENSIONS[@]} -eq 0 ]; then
        return 0
    fi

    for ext in "${EXTENSIONS[@]}"; do
        if [[ "$file" == *."$ext" ]]; then
            return 0
        fi
    done
    return 1
}

# Background debouncer
debounce_sync() {
    while true; do
        if [ -f "$SYNC_PENDING" ]; then
            # Wait for debounce period
            sleep "$DEBOUNCE_SECONDS"

            # Check if file still exists (no new events during sleep)
            if [ -f "$SYNC_PENDING" ]; then
                rm -f "$SYNC_PENDING"
                run_sync
            fi
        else
            sleep 0.5
        fi
    done
}

# Start the debouncer in background
debounce_sync &
DEBOUNCER_PID=$!

log "Starting monitor on $WATCH_DIR (debounce: ${DEBOUNCE_SECONDS}s)"
log "Unison profile: $UNISON_PROFILE"
if [ ${#EXTENSIONS[@]} -eq 0 ]; then
    log "Monitoring: all files"
else
    log "Monitoring extensions: ${EXTENSIONS[*]}"
fi

# Monitor and queue syncs
inotifywait -r -e modify,create,delete,move -m "$WATCH_DIR" 2>/dev/null | \
while read -r path action file; do
    # Only process files matching our extensions (or all if no extensions specified)
    if matches_extension "$file"; then
        log "Event: $action - $file"
        # Touch the pending file to queue/reset the debounce timer
        touch "$SYNC_PENDING"
    fi
done

# Cleanup (should not reach here normally)
kill $DEBOUNCER_PID 2>/dev/null
