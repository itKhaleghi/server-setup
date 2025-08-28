#!/bin/bash

# Main Server Setup Script with Enhanced Menu and Error Handling
# Enhanced security with proper validation and user feedback

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_status $RED "❌ This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to check system requirements
check_system() {
    print_status $BLUE "🔍 Checking system requirements..."
    
    # Check if running on Ubuntu/Debian
    if ! command -v apt &> /dev/null; then
        print_status $RED "❌ This script is designed for Ubuntu/Debian systems"
        exit 1
    fi
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        print_status $RED "❌ No internet connection detected"
        exit 1
    fi
    
    print_status $GREEN "✅ System requirements met"
}

# Function to show banner
show_banner() {
    clear
    echo -e "${GREEN}================================================"
    echo "   🚀 Advanced Server Setup Menu"
    echo "   Enhanced Security & Automation"
    echo "================================================${NC}"
    echo ""
}

# Function to show current system info
show_system_info() {
    print_status $CYAN "📊 Current System Information:"
    echo -e "${YELLOW}OS:${NC} $(lsb_release -d | cut -f2)"
    echo -e "${YELLOW}Kernel:${NC} $(uname -r)"
    echo -e "${YELLOW}Architecture:${NC} $(uname -m)"
    echo -e "${YELLOW}Hostname:${NC} $(hostname)"
    echo -e "${YELLOW}IP Address:${NC} $(hostname -I | awk '{print $1}')"
    echo ""
}

# Function to install module
install_module() {
    local module_name=$1
    local script_path=$2
    
    print_status $BLUE "🚀 Installing ${module_name}..."
    
    if [ -f "$script_path" ]; then
        if bash "$script_path"; then
            print_status $GREEN "✅ ${module_name} installation completed successfully!"
        else
            print_status $RED "❌ ${module_name} installation failed!"
            return 1
        fi
    else
        print_status $RED "❌ Script not found: $script_path"
        return 1
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to show module status
show_module_status() {
    print_status $CYAN "📋 Module Status:"
    
    # Check WireGuard
    if systemctl is-active --quiet wg-quick@wg0; then
        echo -e "${GREEN}✓ WireGuard: Running${NC}"
    else
        echo -e "${RED}✗ WireGuard: Not running${NC}"
    fi
    
    # Check OpenVPN
    if systemctl is-active --quiet openvpn@server; then
        echo -e "${GREEN}✓ OpenVPN: Running${NC}"
    else
        echo -e "${RED}✗ OpenVPN: Not running${NC}"
    fi
    
    # Check firewall
    if ufw status | grep -q "Status: active"; then
        echo -e "${GREEN}✓ Firewall: Active${NC}"
    else
        echo -e "${RED}✗ Firewall: Not active${NC}"
    fi
    
    echo ""
}

# Function to show help
show_help() {
    print_status $CYAN "📖 Help & Information:"
    echo ""
    echo -e "${YELLOW}VPN Services:${NC}"
    echo "• WireGuard: Modern, fast VPN with 256-bit encryption"
    echo "• OpenVPN: Traditional VPN with certificate-based auth"
    echo ""
    echo -e "${YELLOW}Security Features:${NC}"
    echo "• Automatic firewall configuration"
    echo "• Proper file permissions"
    echo "• Network isolation"
    echo "• Service monitoring"
    echo ""
    echo -e "${YELLOW}Management Commands:${NC}"
    echo "• wg-status: Check WireGuard status"
    echo "• openvpn-status: Check OpenVPN status"
    echo "• wg-client-config: Get WireGuard client config"
    echo "• openvpn-client-config: Get OpenVPN client config"
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu function
main_menu() {
    while true; do
        show_banner
        show_system_info
        show_module_status
        
        echo -e "${GREEN}Available Modules:${NC}"
        echo "1. 🛡️  WireGuard VPN (Modern & Fast)"
        echo "2. 🔐 OpenVPN (Traditional & Secure)"
        echo "3. 🚀 Laravel (PHP Framework)"
        echo "4. 🌐 WordPress (CMS)"
        echo "5. ⚡ Golang (Gin Framework)"
        echo "6. 🟢 Node.js (Express)"
        echo "7. 🌊 V2Ray (Proxy Server)"
        echo ""
        echo "8. 📊 System Status"
        echo "9. 📖 Help & Information"
        echo "10. 🧹 Cleanup & Reset"
        echo "0. 🚪 Exit"
        echo ""
        
        PS3="Select an option (0-10): "
        read -p "Enter your choice: " choice
        
        case $choice in
            1)
                install_module "WireGuard VPN" "modules/wireguard.sh"
                ;;
            2)
                install_module "OpenVPN" "modules/openvpn.sh"
                ;;
            3)
                install_module "Laravel" "modules/laravel.sh"
                ;;
            4)
                install_module "WordPress" "modules/wordpress.sh"
                ;;
            5)
                install_module "Golang" "modules/golang.sh"
                ;;
            6)
                install_module "Node.js" "modules/nodejs.sh"
                ;;
            7)
                install_module "V2Ray" "modules/v2ray.sh"
                ;;
            8)
                show_module_status
                read -p "Press Enter to continue..."
                ;;
            9)
                show_help
                ;;
            10)
                print_status $YELLOW "🧹 Cleanup options will be implemented in future versions"
                read -p "Press Enter to continue..."
                ;;
            0)
                print_status $GREEN "👋 Thank you for using Server Setup!"
                exit 0
                ;;
            *)
                print_status $RED "❌ Invalid option. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Main execution
main() {
    check_root
    check_system
    main_menu
}

# Run main function
main
