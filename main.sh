#!/bin/bash


scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
demoDir="$scriptDir/demo"
dataDir="$scriptDir/data"
baselineFile="$dataDir/baseline.txt"
currentFile="$dataDir/current.txt"
reportFile="$dataDir/changes.txt"


if [[ -n "${DISPLAY:-}" ]]; then
    export GDK_BACKEND=x11
fi

showMessage() {
    yad --info --title="Tamper Detector" --center --on-top --text="$1"
}

showError() {
    yad --error --title="Tamper Detector" --center --on-top --text="$1"
}

scanDemo() {
    (
        cd -- "$demoDir" || exit 1
        find . -type f -exec sha256sum -- {} \; | LC_ALL=C sort -k 2
    )
}

createBaseline() {
    local fileCount

    if [[ ! -d "$demoDir" ]]; then
        showError "The demo/ folder is missing."
        return
    fi

    mkdir -p -- "$dataDir" || {
        showError "Could not create the data/ folder."
        return
    }

    if [[ -f "$baselineFile" ]]; then
        if ! yad --question --title="Replace baseline?" --center \
            --text="Replace the old baseline with the current demo/ files?" \
            --button="Cancel:1" --button="Replace:0"; then
            return
        fi
    fi

    if ! scanDemo > "$dataDir/baseline.tmp"; then
        showError "Could not read the files in demo/."
        return
    fi

    mv -f -- "$dataDir/baseline.tmp" "$baselineFile" || {
        showError "Could not save data/baseline.txt."
        return
    }

    fileCount="$(wc -l < "$baselineFile")"
    showMessage "Baseline created. Files saved: $fileCount"
}

checkForChanges() {
    if [[ ! -f "$baselineFile" ]]; then
        showError "No baseline yet. Choose Create baseline first."
        return
    fi

    if ! scanDemo > "$currentFile"; then
        showError "Could not read the files in demo/."
        return
    fi

    if diff -q "$baselineFile" "$currentFile" > /dev/null; then
        showMessage "No changes found in demo/."
    else
        printf 'Someone changed/Tampered in this file\n'
        printf 'Someone changed/Tampered in this file\n\n' > "$reportFile"
        diff -u "$baselineFile" "$currentFile" >> "$reportFile"
        showMessage "Someone changed/Tampered in this file"
    fi
}

showMenu() {
    local selectedAction
    local menuExitCode

    while true; do
        selectedAction="$(yad --list --title="Tamper Detector" \
            --text="Save a baseline, then check demo/ for changes." \
            --column="Action" --no-headers --width=420 --height=220 --center \
            --button="Select:0" --button="Quit:1" \
            "Create baseline" "Check for changes" "Quit")"
        menuExitCode=$?

        if [[ "$menuExitCode" -ne 0 || "$selectedAction" == "Quit" ]]; then
            break
        fi

        case "$selectedAction" in
            "Create baseline") createBaseline ;;
            "Check for changes") checkForChanges ;;
        esac
    done
}

showMenu
