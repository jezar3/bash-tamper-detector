#!/bin/bash


scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
demoDir="$scriptDir/demo"
dataDir="$scriptDir/data"
baselineFile="$dataDir/baseline.txt"
currentFile="$dataDir/current.txt"
reportFile="$dataDir/changes.txt"
styleFile="$scriptDir/red-glow.css"
popupWidth=670
popupHeight=180
lockHash="$(printf '%s' "$scriptDir" | sha256sum)"
lockHash="${lockHash%% *}"
lockFile="${TMPDIR:-/tmp}/tamper-detector-${UID}-${lockHash}.lock"

exec {lockFd}>"$lockFile" || {
    printf 'Could not create the Tamper Detector lock file.\n' >&2
    exit 1
}

if ! flock -n "$lockFd"; then
    printf 'Tamper Detector is already running. Close the open window before starting it again.\n' >&2
    exit 0
fi

if [[ -n "${DISPLAY:-}" ]]; then
    export GDK_BACKEND=x11
fi


showMessage() {
    local popupText
    printf -v popupText '<big><b>Tamper Detector</b></big>\n\n%s' "$1"
    # YAD 0.40
    yad --info --gtkrc="$styleFile" --title="Tamper Detector" --undecorated --center --on-top \
        --width="$popupWidth" --height="$popupHeight" --text="$popupText"
}

showError() {
    local popupText
    printf -v popupText '<big><b>Tamper Detector</b></big>\n\n%s' "$1"
    # YAD 0.40
    yad --error --gtkrc="$styleFile" --title="Tamper Detector" --undecorated --center --on-top \
        --width="$popupWidth" --height="$popupHeight" --text="$popupText"
}

showChangesReport() {
    if [[ ! -s "$reportFile" ]]; then
        showError "No saved change report. Choose Check for changes first."
        return
    fi

    # YAD 0.40
    yad --text-info --gtkrc="$styleFile" --title="Tamper detected" --undecorated --center --on-top --width=900 --height=600 \
        --filename="$reportFile" --button="Close:0"
}

scanDemo() {
    (
        cd -- "$demoDir" || exit 1
        find . -type f -exec sha256sum -- {} \; | LC_ALL=C sort -k 2
    )
}

createBaseline() {
    local fileCount
    local replacePrompt

    if [[ ! -d "$demoDir" ]]; then
        showError "The demo/ folder is missing."
        return
    fi

    mkdir -p -- "$dataDir" || {
        showError "Could not create the data/ folder."
        return
    }

    if [[ -f "$baselineFile" ]]; then
        printf -v replacePrompt '<big><b>Replace baseline?</b></big>\n\nReplace the old baseline with the current demo/ files?'
        # YAD 0.40
        yad --question --gtkrc="$styleFile" --title="Replace baseline?" --center \
            --undecorated --width="$popupWidth" --height="$popupHeight" \
            --text="$replacePrompt" \
            --button="Cancel:1" --button="Replace:0"
        local replaceChoice=$?
        if [[ "$replaceChoice" -ne 0 ]]; then
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

    rm -f -- "$reportFile"

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
        rm -f -- "$reportFile"
        showMessage "No changes found in demo/."
    else
        printf 'Someone tampered with files in demo/.\n\n' > "$reportFile"
        diff -u --label "Baseline" --label "Current" \
            "$baselineFile" "$currentFile" >> "$reportFile"
        local diffExitCode=$?

        if [[ "$diffExitCode" -gt 1 ]]; then
            rm -f -- "$reportFile"
            showError "Could not create the change report."
            return
        fi

        showMessage "Someone tampered with files in demo/."
    fi
}

showMenu() {
    local menuExitCode
    local menuText
    printf -v menuText '<big><b>Tamper Detector</b></big>\n\nSave a baseline, check demo/ for changes, or open the latest report.'

    while true; do
        # YAD 0.40
        yad --info --gtkrc="$styleFile" --title="Tamper Detector" --undecorated --center --on-top \
            --width="$popupWidth" --height="$popupHeight" \
            --text="$menuText" \
            --button="SAVE CURRENT STATE:2" \
            --button="SECURITY:3" \
            --button="DETAILS:4" \
            --button="Quit:1"
        menuExitCode=$?

        case "$menuExitCode" in
            2)
                createBaseline
                ;;
            3)
                checkForChanges
                ;;
            4)
                showChangesReport
                ;;
            *) break ;;
        esac
    done
}

if [[ "${1:-}" == "--check" ]]; then
    checkForChanges
else
    showMenu
fi
