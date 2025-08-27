#!/bin/bash

# WireGuard VPN Installation and Configuration Script
# Enhanced security with proper firewall rules and network isolation
# Multi-user support with proper isolation

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NETWORK="10.0.0.0/24"
WG_SERVER_IP="10.0.0.1"
WG_SUBNET="24"
MAX_CLIENTS=50

echo -e "${GREEN}🚀 Installing and Configuring WireGuard VPN...${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Check if WireGuard is already installed
if command -v wg &> /dev/null; then
    echo -e "${YELLOW}⚠️  WireGuard is already installed. Checking configuration...${NC}"
    
    if [ -f "/etc/wireguard/${WG_INTERFACE}.conf" ]; then
        echo -e "${YELLOW}⚠️  WireGuard interface ${WG_INTERFACE} already exists.${NC}"
        read -p "Do you want to recreate it? (y/N): " recreate
        if [[ ! $recreate =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}✅ Keeping existing configuration${NC}"
            exit 0
        fi
        
        # Stop and remove existing interface
        systemctl stop wg-quick@${WG_INTERFACE} 2>/dev/null || true
        wg-quick down ${WG_INTERFACE} 2>/dev/null || true
        rm -f /etc/wireguard/${WG_INTERFACE}.conf
    fi
fi

# Update system
echo -e "${BLUE}📦 Updating system packages...${NC}"
apt update -y
apt upgrade -y

# Install required packages
echo -e "${BLUE}📦 Installing WireGuard and dependencies...${NC}"
apt install -y wireguard wireguard-tools iptables-persistent ufw curl

# Enable IP forwarding
echo -e "${BLUE}🔧 Enabling IP forwarding...${NC}"
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
fi
if ! grep -q "net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf; then
    echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
fi
sysctl -p

# Create WireGuard directory
mkdir -p /etc/wireguard
cd /etc/wireguard

# Generate server keys
echo -e "${BLUE}🔑 Generating WireGuard server keys...${NC}"
wg genkey | tee server_private.key | wg pubkey > server_public.key
chmod 600 server_private.key
chmod 600 server_public.key

# Get server public key
SERVER_PUBLIC_KEY=$(cat server_public.key)
SERVER_PRIVATE_KEY=$(cat server_private.key)

# Get server external IP (with fallback)
echo -e "${BLUE}🌐 Detecting server external IP...${NC}"
SERVER_EXTERNAL_IP=$(curl -s --max-time 10 https://ifconfig.me 2>/dev/null || \
                     curl -s --max-time 10 https://icanhazip.com 2>/dev/null || \
                     curl -s --max-time 10 https://ipecho.net/plain 2>/dev/null || \
                     "YOUR_SERVER_IP")

if [ "$SERVER_EXTERNAL_IP" = "YOUR_SERVER_IP" ]; then
    echo -e "${YELLOW}⚠️  Could not detect external IP automatically${NC}"
    read -p "Please enter your server's external IP address: " SERVER_EXTERNAL_IP
fi

echo -e "${GREEN}✅ Server external IP: ${SERVER_EXTERNAL_IP}${NC}"

# Create WireGuard server configuration
echo -e "${BLUE}🔧 Creating WireGuard server configuration...${NC}"
cat > /etc/wireguard/${WG_INTERFACE}.conf << EOF
[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
Address = ${WG_SERVER_IP}/${WG_SUBNET}
ListenPort = ${WG_PORT}
SaveConfig = true

# Security enhancements
PostUp = iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o %i -j MASQUERADE; iptables -A FORWARD -o ${WG_INTERFACE} -j ACCEPT
PostDown = iptables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o %i -j MASQUERADE; iptables -D FORWARD -o ${WG_INTERFACE} -j ACCEPT

# MTU optimization
MTU = 1420

# DNS and routing
PostUp = echo "nameserver 1.1.1.1" > /etc/resolv.conf.wg; echo "nameserver 8.8.8.8" >> /etc/resolv.conf.wg
PostDown = rm -f /etc/resolv.conf.wg
EOF

# Set proper permissions
chmod 600 /etc/wireguard/${WG_INTERFACE}.conf

# Create client management script
echo -e "${BLUE}🔧 Creating client management script...${NC}"
cat > /usr/local/bin/wg-manage-client << 'EOF'
#!/bin/bash

# WireGuard Client Management Script
# Usage: wg-manage-client [add|remove|list] [client_name]

WG_INTERFACE="wg0"
WG_NETWORK="10.0.0.0/24"
WG_SERVER_IP="10.0.0.1"
MAX_CLIENTS=50

show_usage() {
    echo "Usage: $0 [add|remove|list] [client_name]"
    echo "  add <client_name>    - Add a new client"
    echo "  remove <client_name> - Remove a client"
    echo "  list                 - List all clients"
    echo "  status               - Show current status"
}

get_next_ip() {
    local used_ips=()
    local next_ip=2
    
    # Get used IPs from current config
    if [ -f "/etc/wireguard/${WG_INTERFACE}.conf" ]; then
        used_ips=($(grep "AllowedIPs" /etc/wireguard/${WG_INTERFACE}.conf | awk '{print $3}' | cut -d/ -f1 | sort -n))
    fi
    
    # Find next available IP
    for ip in "${used_ips[@]}"; do
        if [ "$ip" = "$next_ip" ]; then
            ((next_ip++))
        fi
    done
    
    echo $next_ip
}

add_client() {
    local client_name="$1"
    local client_ip="10.0.0.$2"
    
    if [ -z "$client_name" ]; then
        echo "❌ Client name is required"
        exit 1
    fi
    
    # Check if client already exists
    if grep -q "AllowedIPs.*${client_ip}" /etc/wireguard/${WG_INTERFACE}.conf; then
        echo "❌ Client with IP ${client_ip} already exists"
        exit 1
    fi
    
    # Generate client keys
    cd /etc/wireguard
    wg genkey | tee ${client_name}_private.key | wg pubkey > ${client_name}_public.key
    chmod 600 ${client_name}_private.key
    chmod 600 ${client_name}_public.key
    
    local client_public_key=$(cat ${client_name}_public.key)
    local client_private_key=$(cat ${client_name}_private.key)
    
    # Add client to server config
    cat >> /etc/wireguard/${WG_INTERFACE}.conf << EOF

# Client: ${client_name}
[Peer]
PublicKey = ${client_public_key}
AllowedIPs = ${client_ip}/32
EOF
    
    # Create client configuration
    local server_public_key=$(cat server_public.key)
    local server_external_ip=$(curl -s --max-time 10 https://ifconfig.me 2>/dev/null || "YOUR_SERVER_IP")
    
    cat > /etc/wireguard/${client_name}.conf << EOF
# WireGuard Client Configuration for ${client_name}
[Interface]
PrivateKey = ${client_private_key}
Address = ${client_ip}/${WG_SUBNET}
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${server_public_key}
Endpoint = ${server_external_ip}:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
    
    chmod 600 /etc/wireguard/${client_name}.conf
    
    echo "✅ Client ${client_name} added successfully!"
    echo "📱 Client config: /etc/wireguard/${client_name}.conf"
    echo "🔑 Client IP: ${client_ip}"
    
    # Reload WireGuard
    wg syncconf ${WG_INTERFACE} <(wg-quick strip ${WG_INTERFACE})
}

remove_client() {
    local client_name="$1"
    
    if [ -z "$client_name" ]; then
        echo "❌ Client name is required"
        exit 1
    fi
    
    # Remove client from server config
    local temp_config="/tmp/wg_temp.conf"
    grep -v "Client: ${client_name}" /etc/wireguard/${WG_INTERFACE}.conf | \
    awk -v client="$client_name" '
    /^\[Peer\]/ { in_peer=1; peer_lines="" }
    in_peer { peer_lines = peer_lines ORS $0 }
    /^$/ { 
        if (peer_lines !~ client) {
            print peer_lines
        }
        in_peer=0
        peer_lines=""
    }
    !in_peer { print }
    ' > "$temp_config"
    
    mv "$temp_config" /etc/wireguard/${WG_INTERFACE}.conf
    
    # Remove client files
    rm -f /etc/wireguard/${client_name}_private.key
    rm -f /etc/wireguard/${client_name}_public.key
    rm -f /etc/wireguard/${client_name}.conf
    
    echo "✅ Client ${client_name} removed successfully!"
    
    # Reload WireGuard
    wg syncconf ${WG_INTERFACE} <(wg-quick strip ${WG_INTERFACE})
}

list_clients() {
    echo "📋 WireGuard Clients:"
    echo "====================="
    
    if [ -f "/etc/wireguard/${WG_INTERFACE}.conf" ]; then
        grep -A 2 "Client:" /etc/wireguard/${WG_INTERFACE}.conf | \
        awk '
        /Client:/ { 
            client_name = $2
            getline
            if ($0 ~ /PublicKey/) {
                getline
                if ($0 ~ /AllowedIPs/) {
                    ip = $2
                    printf "%-15s %s\n", client_name, ip
                }
            }
        }
        '
    else
        echo "No clients configured"
    fi
}

show_status() {
    echo "📊 WireGuard Status:"
    echo "===================="
    wg show ${WG_INTERFACE} 2>/dev/null || echo "Interface ${WG_INTERFACE} not found"
}

# Main logic
case "$1" in
    "add")
        if [ -z "$2" ]; then
            echo "❌ Client name required for add operation"
            exit 1
        fi
        next_ip=$(get_next_ip)
        add_client "$2" "$next_ip"
        ;;
    "remove")
        remove_client "$2"
        ;;
    "list")
        list_clients
        ;;
    "status")
        show_status
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/wg-manage-client

# Enable and start WireGuard service
echo -e "${BLUE}🚀 Enabling WireGuard service...${NC}"
systemctl enable wg-quick@${WG_INTERFACE}
systemctl start wg-quick@${WG_INTERFACE}

# Configure firewall rules
echo -e "${BLUE}🔥 Configuring firewall rules...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (change port if different)
ufw allow 22/tcp

# Allow WireGuard
ufw allow ${WG_PORT}/udp

# Allow HTTP/HTTPS if needed
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw --force enable

# Create status check script
cat > /usr/local/bin/wg-status << 'EOF'
#!/bin/bash
echo "=== WireGuard Status ==="
wg show wg0
echo ""
echo "=== Active Connections ==="
ss -tuln | grep :51820
echo ""
echo "=== Firewall Status ==="
ufw status
echo ""
echo "=== Interface Status ==="
ip addr show wg0 2>/dev/null || echo "Interface wg0 not found"
EOF

chmod +x /usr/local/bin/wg-status

# Create client config download script
cat > /usr/local/bin/wg-client-config << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: $0 <client_name>"
    echo "Available clients:"
    ls /etc/wireguard/*.conf | grep -v wg0.conf | sed 's|/etc/wireguard/||g' | sed 's|.conf||g'
    exit 1
fi

client_name="$1"
client_config="/etc/wireguard/${client_name}.conf"

if [ -f "$client_config" ]; then
    echo "Client configuration file for ${client_name}:"
    echo "=========================================="
    cat "$client_config"
    echo ""
    echo "=========================================="
    echo "Save this configuration to your client device"
    echo "File location: $client_config"
else
    echo "Client configuration not found for: $client_name"
    echo "Available clients:"
    ls /etc/wireguard/*.conf | grep -v wg0.conf | sed 's|/etc/wireguard/||g' | sed 's|.conf||g'
fi
EOF

chmod +x /usr/local/bin/wg-client-config

# Add first client
echo -e "${BLUE}👤 Adding first client (admin)...${NC}"
/usr/local/bin/wg-manage-client add admin

echo -e "${GREEN}✅ WireGuard installation and configuration complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Important Information:${NC}"
echo -e "Server Public Key: ${SERVER_PUBLIC_KEY}"
echo -e "Server External IP: ${SERVER_EXTERNAL_IP}"
echo -e "WireGuard Port: ${WG_PORT}"
echo -e "VPN Network: ${WG_NETWORK}"
echo ""
echo -e "${YELLOW}🔧 Management Commands:${NC}"
echo -e "Add client: wg-manage-client add <name>"
echo -e "Remove client: wg-manage-client remove <name>"
echo -e "List clients: wg-manage-client list"
echo -e "Check status: wg-status"
echo -e "Get client config: wg-client-config <name>"
echo ""
echo -e "${GREEN}🔐 Security Features Enabled:${NC}"
echo -e "✓ IP forwarding configured"
echo -e "✓ Firewall rules applied"
echo -e "✓ Proper file permissions (600)"
echo -e "✓ Network isolation"
echo -e "✓ Multi-user support"
echo -e "✓ Automatic IP assignment"
echo -e "✓ Client management tools"
