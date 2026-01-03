#!/bin/bash

set -e

RED='\033[0;31m'
LIGHT_RED='\033[0;91m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'
CURR_DIR=$(pwd)

# A general confirmation prompt
confirm()
{
    while true; do
        read -p "$(echo -e ${YELLOW}Do you want to $1? [Yy/Nn]: ${RESET})" yn
        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo -e "${RED}Please answer [Y/y] or [N/n]. Try again.${RESET}" ;;
        esac
    done
}

# A general wait for input function
await_input()
{
    echo -e "${YELLOW}Press any key to continue...${RESET}"
    while true; do
    read -rsn1 key
    if [[ -n "$key" ]]; then
        echo -e "${GREEN}Continuing...${RESET}"
        break
    fi
    done
}
