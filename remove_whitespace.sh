#!/bin/bash

# Function to strip whitespace from filenames
strip_whitespace() {
    local dir="$1"
    local recursive="$2"

    echo -e "\033[1;34mStripping whitespace from files in: $dir\033[0m"

    # First, collect all items and separate files from directories
    local files=()
    local dirs=()

    for item in "$dir"/*; do
        # Skip if glob didn't match anything
        [ ! -e "$item" ] && continue

        if [ -f "$item" ]; then
            files+=("$item")
        elif [ -d "$item" ]; then
            dirs+=("$item")
        fi
    done

    # Process files first
    for file in "${files[@]}"; do
        local dirname=$(dirname "$file")
        local basename=$(basename "$file")
        local new_basename=$(echo "$basename" | tr -d '[:space:]')

        if [ "$basename" != "$new_basename" ]; then
            local new_path="$dirname/$new_basename"
            echo -e "\033[1;32mRenaming file:\033[0m"
            echo -e "  \033[31m$basename\033[0m"
            echo -e "  \033[32m$new_basename\033[0m"
            mv "$file" "$new_path"
        fi
    done

    # Process directories (only if recursive mode is enabled)
    if [ "$recursive" = "true" ]; then
        for directory in "${dirs[@]}"; do
            # First recursively process the directory contents
            strip_whitespace "$directory" "$recursive"

            # Then rename the directory itself if it contains whitespace
            local dirname=$(dirname "$directory")
            local basename=$(basename "$directory")
            local new_basename=$(echo "$basename" | tr -d '[:space:]')

            if [ "$basename" != "$new_basename" ]; then
                local new_path="$dirname/$new_basename"
                echo -e "\033[1;33mRenaming directory:\033[0m"
                echo -e "  \033[31m$basename\033[0m"
                echo -e "  \033[32m$new_basename\033[0m"
                mv "$directory" "$new_path"
            fi
        done
    fi
}

# Parse arguments
recursive=false
target_dir=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -R|--recursive)
            recursive=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-R|--recursive] <directory>"
            echo "Strip whitespace from filenames in the specified directory"
            echo ""
            echo "Options:"
            echo "  -R, --recursive    Process directories recursively"
            echo "  -h, --help        Show this help message"
            exit 0
            ;;
        *)
            if [ -z "$target_dir" ]; then
                target_dir="$1"
            else
                echo "Error: Too many arguments"
                echo "Usage: $0 [-R|--recursive] <directory>"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if directory argument was provided
if [ -z "$target_dir" ]; then
    echo "Error: Directory argument required"
    echo "Usage: $0 [-R|--recursive] <directory>"
    exit 1
fi

# Check if directory exists
if [ ! -d "$target_dir" ]; then
    echo "Error: Directory '$target_dir' does not exist"
    exit 1
fi

# Convert to absolute path to avoid issues with relative paths during recursion
target_dir=$(realpath "$target_dir")

echo -e "\033[1;34mStripping whitespace from all files in $target_dir\033[0m"
if [ "$recursive" = "true" ]; then
    echo -e "\033[1;36mRecursive mode enabled\033[0m"
fi

strip_whitespace "$target_dir" "$recursive"

echo -e "\033[1;32mDone!\033[0m"
