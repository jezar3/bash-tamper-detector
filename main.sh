#!/bin/bash

scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
demoDir="$scriptDir/demo"
dataDir="$scriptDir/data"
logsDir="$scriptDir/logs"
styleFile="$scriptDir/red-glow.css"
logFile="$logsDir/tamper.log"

logMessage() {
    mkdir -p -- "$logsDir"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$logFile"
}

showNotice() {
    yad --info \
        --title="File Integrity Monitor" \
        --width=400 \
        --center \
        --gtkrc="$styleFile" \
        --text="$1"
}

resetDemo() {
   
    if [[ -z "$demoDir" || "$demoDir" == "/" ]]; then
        printf 'Safety stop: demoDir is empty or /\n' >&2
        return 1
    fi

    if [[ -d "$demoDir" ]]; then
        rm -r -- "$demoDir" || return 1
    fi

    mkdir -p -- "$demoDir/notes" || return 1
    
    touch "$demoDir/empty.txt"
}

createBaseline() {
    showNotice "Baseline creation is not implemented yet."
}

checkForChanges() {
    showNotice "Change auditing is not implemented yet."
}

viewLog() {
    yad --text-info \
        --title="Activity log" \
        --filename="$logFile" \
        --width=620 \
        --height=400 \
        --center \
        --gtkrc="$styleFile" \
        --button="Close:0"
}

showMenu() {
    while true; do
        selectedAction="$(yad --list \
            --title="File Integrity Monitor" \
            --text="Choose an action for the monitored sample files." \
            --column="Action" \
            --no-headers \
            --width=460 \
            --height=270 \
            --center \
            --gtkrc="$styleFile" \
            --button="Select:0" \
            --button="Quit:1" \
            "Reset demo files" \
            "Create baseline" \
            "Check for changes" \
            "View log" \
            "Quit")"
        menuExitCode=$?

        if [[ "$menuExitCode" -eq 1 || "$menuExitCode" -eq 252 ]]; then
            logMessage "Quit"
            break
        fi

        if [[ "$menuExitCode" -ne 0 ]]; then
            printf 'YAD stopped with exit code %s.\n' "$menuExitCode" >&2
            break
        fi

        case "$selectedAction" in
            "Reset demo files")
                logMessage "Reset demo files"
                if resetDemo; then
                    showNotice "Sample files restored."
                else
                    showNotice "The demo folder could not be reset."
                fi
                ;;
            "Create baseline")
                logMessage "Create baseline"
                createBaseline
                ;;
            "Check for changes")
                logMessage "Check for changes"
                checkForChanges
                ;;
            "View log")
                logMessage "View log"
                viewLog
                ;;
            "Quit")
                logMessage "Quit"
                break
                ;;
        esac
    done
}

if ! command -v yad >/dev/null 2>&1; then
    printf 'Please install YAD' >&2
    exit 1
fi

showMenu
