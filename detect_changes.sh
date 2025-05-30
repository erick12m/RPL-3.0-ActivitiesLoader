#!/bin/bash

set -e  # Exit on any error

# Configuration
ACTIVITIES_DIR="${ACTIVITIES_DIR:-activities}"

# Colors for logging
RED='\033[0;31m'
BLUE='\033[0;34m'
NO_COLOR='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NO_COLOR} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NO_COLOR} $1" >&2
}

# Get changed files from git
get_changed_activities_files() {
    local changed_files
    
    # Check if there is a previous commit
    if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
        changed_files=$(git diff --name-only HEAD~1 HEAD)
    else
        # If no previous commit, get all files
        changed_files=$(git ls-files)
    fi

    local changed_activities_files

    changed_activities_files=$(echo "$changed_files" | grep "^$ACTIVITIES_DIR/" || true)
    echo "$changed_activities_files"
}

main() {
    log_info "Detecting changes in RPL Activities"
    
    # Check if activities directory exists
    if [[ ! -d "$ACTIVITIES_DIR" ]]; then
        log_error "Activities directory '$ACTIVITIES_DIR' not found"
        exit 1
    fi
    
    local changed_files
    changed_files=$(get_changed_activities_files)
    
    if [[ -z "$changed_files" ]]; then
        log_info "No activity changes detected"
        exit 0
    fi
    
    log_info "Found changed activities:"
    echo "$changed_files" | while read -r file; do
        log_info "  - $file"
    done
    
    # Final output
    echo "$changed_files"
}

# Run main function
main "$@" 