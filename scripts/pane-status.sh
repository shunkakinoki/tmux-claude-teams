#!/usr/bin/env bash
STATUS_FILE="$1"
clear
while true; do
    if [ -f "$STATUS_FILE" ]; then
        clear
        STATUS=$(head -1 "$STATUS_FILE")
        DESC=$(tail -n +2 "$STATUS_FILE")
        case "$STATUS" in
            RUNNING)
                printf '\033[1;33m>>> Agent Running\033[0m\n\n'
                printf '%s\n' "$DESC"
                printf '\n\033[2m[working...]\033[0m'
                ;;
            DONE)
                printf '\033[1;32m>>> Agent Done\033[0m\n\n'
                printf '%s\n' "$DESC"
                sleep 3
                exit 0
                ;;
        esac
    fi
    sleep 0.5
done
