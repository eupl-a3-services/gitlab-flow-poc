#!/bin/bash

menu(){
    local NC="\033[0m"
    local YELLOW="\033[0;33m"
    
    local MENU_ITEMS=(
        "session-token"
        "session-vault"
        "env-session-request"
        "kube-session-request"
        "[EXIT SESSION MANAGER]"
        "[CLOSE SESSION]"
    )

    local LAST_CHOICE=""

    while true; do
        DISPLAY_MENU=()

        if [ -n "${LAST_CHOICE}" ]; then
            DISPLAY_MENU+=("[LAST USED] » ${LAST_CHOICE}")
        fi

        for item in "${MENU_ITEMS[@]}"; do
            if [[ "$item" == \[* ]]; then
                DISPLAY_MENU+=("${NC}${item}${NC}")
            else
                DISPLAY_MENU+=("${YELLOW}${item}${NC}")
            fi
        done

        CHOICE=$(printf "%b\n" "${DISPLAY_MENU[@]}" | \
            fzf --ansi --prompt="Session actions: " --height=10 --border --reverse --no-info)

        if [ -z "${CHOICE}" ]; then
            printc MAGENTA "ESC" "You pressed ESC or cancelled – exiting."
            break
        fi

        if [[ "${CHOICE}" == "[LAST USED] » "* ]]; then
            CHOICE="${CHOICE#\[LAST USED\] » }"
        fi

        echo

        LAST_CHOICE="${CHOICE}"

        case "${CHOICE}" in
            "[EXIT SESSION MANAGER]")
                printc YELLOW "EXIT SESSION MANAGER" "Goodbye!"
                exit
                ;;
            "[CLOSE SESSION]")
                printc YELLOW "CLOSE SESSION" "Goodbye!"
                source /home/$(whoami)/.bash_trap
                kill -KILL "$PPID"
                ;;
            *)
                if [[ -x "${SESSION_MANAGER}/${CHOICE}" ]]; then
                    printc YELLOW "ACTION" "Running '${SESSION_MANAGER}/${CHOICE}'"
                    "${SESSION_MANAGER}/${CHOICE}"
                    printc YELLOW "ACTION" "Done"
                else
                    printc RED "UNKNOWN" "Unknown or non-executable: '${SESSION_MANAGER}/${CHOICE}'"
                fi
                ;;
        esac
    done
}

SESSION_MANAGER="$(dirname "$(readlink -f "$0")")"

printc MAGENTA "SESSION_MANAGER" ${SESSION_MANAGER}
printc GREEN "PDS_TOKEN" ${PDS_TOKEN}

menu