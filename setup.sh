#!/bin/bash
# Main setup script with menu
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}======================================"
echo "   🚀 Server Setup Menu"
echo "======================================${NC}"

PS3="Select a module to install: "
options=("WireGuard" "OpenVPN" "Laravel" "WordPress" "Golang (Gin)" "Node.js (Express)" "Quit")

select opt in "${options[@]}"
do
    case $opt in
        "WireGuard")
            bash modules/wireguard.sh
            ;;
        "OpenVPN")
            bash modules/openvpn.sh
            ;;
        "Laravel")
            bash modules/laravel.sh
            ;;
        "WordPress")
            bash modules/wordpress.sh
            ;;
        "Golang (Gin)")
            bash modules/golang.sh
            ;;
        "Node.js (Express)")
            bash modules/nodejs.sh
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done
