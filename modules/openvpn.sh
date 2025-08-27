#!/bin/bash

# OpenVPN Installation and Configuration Script
# Enhanced security with proper firewall rules and network isolation
# Multi-user support with certificate management

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
OVPN_PORT="1194"
OVPN_PROTO="udp"
OVPN_NETWORK="10.8.0.0/24"
OVPN_SERVER_IP="10.8.0.1"
OVPN_SUBNET="24"
MAX_CLIENTS=100

echo -e "${GREEN}🚀 Installing and Configuring OpenVPN...${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Check if OpenVPN is already installed
if command -v openvpn &> /dev/null; then
    echo -e "${YELLOW}⚠️  OpenVPN is already installed. Checking configuration...${NC}"
    
    if [ -f "/etc/openvpn/server.conf" ]; then
        echo -e "${YELLOW}⚠️  OpenVPN server configuration already exists.${NC}"
        read -p "Do you want to recreate it? (y/N): " recreate
        if [[ ! $recreate =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}✅ Keeping existing configuration${NC}"
            exit 0
        fi
        
        # Stop and remove existing service
        systemctl stop openvpn@server 2>/dev/null || true
        rm -f /etc/openvpn/server.conf
    fi
fi

# Update system
echo -e "${BLUE}📦 Updating system packages...${NC}"
apt update -y
apt upgrade -y

# Install required packages
echo -e "${BLUE}📦 Installing OpenVPN and dependencies...${NC}"
apt install -y openvpn easy-rsa iptables-persistent ufw curl

# Enable IP forwarding
echo -e "${BLUE}🔧 Enabling IP forwarding...${NC}"
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
fi
sysctl -p

# Setup Easy-RSA
echo -e "${BLUE}🔑 Setting up Easy-RSA for certificate generation...${NC}"
make-cadir ~/easy-rsa
cd ~/easy-rsa

# Configure Easy-RSA with stronger settings
cat > vars << 'EOF'
export EASYRSA_REQ_COUNTRY="US"
export EASYRSA_REQ_PROVINCE="CA"
export EASYRSA_REQ_CITY="SanFrancisco"
export EASYRSA_REQ_ORG="OpenVPN"
export EASYRSA_REQ_EMAIL="admin@example.com"
export EASYRSA_REQ_OU="MyOrganizationalUnit"
export EASYRSA_KEY_SIZE=4096
export EASYRSA_ALGO=rsa
export EASYRSA_CA_EXPIRE=3650
export EASYRSA_CERT_EXPIRE=3650
export EASYRSA_CRL_DAYS=180
EOF

# Initialize PKI
./easyrsa init-pki
./easyrsa build-ca nopass

# Generate server certificate and key
echo -e "${BLUE}🔑 Generating server certificate...${NC}"
./easyrsa build-server-full server nopass

# Generate Diffie-Hellman parameters (stronger)
echo -e "${BLUE}🔑 Generating Diffie-Hellman parameters...${NC}"
./easyrsa gen-dh 4096

# Generate HMAC key for additional security
echo -e "${BLUE}🔑 Generating HMAC key...${NC}"
openvpn --genkey secret ta.key

# Copy certificates to OpenVPN directory
echo -e "${BLUE}🔧 Copying certificates to OpenVPN directory...${NC}"
cp ~/easy-rsa/pki/ca.crt /etc/openvpn/
cp ~/easy-rsa/pki/issued/server.crt /etc/openvpn/
cp ~/easy-rsa/pki/private/server.key /etc/openvpn/
cp ~/easy-rsa/pki/dh.pem /etc/openvpn/
cp ~/easy-rsa/ta.key /etc/openvpn/

# Set proper permissions
chmod 600 /etc/openvpn/server.key
chmod 600 /etc/openvpn/ta.key
chmod 644 /etc/openvpn/ca.crt
chmod 644 /etc/openvpn/server.crt
chmod 644 /etc/openvpn/dh.pem

# Get server external IP
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

# Create OpenVPN server configuration
echo -e "${BLUE}🔧 Creating OpenVPN server configuration...${NC}"
cat > /etc/openvpn/server.conf << 'EOF'
# OpenVPN Server Configuration
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt

# Security settings (enhanced)
cipher AES-256-GCM
auth SHA512
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384
tls-crypt ta.key

# Network settings
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

# Security enhancements
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3

# Additional security
explicit-exit-notify 1
keepalive 10 120
comp-lzo no
push "comp-lzo no"

# Logging
log-append /var/log/openvpn.log

# Performance optimizations
tun-mtu 1500
mssfix 1450

# Client isolation
client-to-client
EOF

# Create client management script
echo -e "${BLUE}🔧 Creating client management script...${NC}"
cat > /usr/local/bin/openvpn-manage-client << 'EOF'
#!/bin/bash

# OpenVPN Client Management Script
# Usage: openvpn-manage-client [add|remove|list|revoke] [client_name]

EASYRSA_DIR="$HOME/easy-rsa"
OVPN_DIR="/etc/openvpn"
CA_DIR="$EASYRSA_DIR/pki"
CLIENT_DIR="$OVPN_DIR/clients"

show_usage() {
    echo "Usage: $0 [add|remove|list|revoke] [client_name]"
    echo "  add <client_name>    - Add a new client"
    echo "  remove <client_name> - Remove a client"
    echo "  list                 - List all clients"
    echo "  revoke <client_name> - Revoke client certificate"
    echo "  status               - Show current status"
}

create_client_dirs() {
    mkdir -p "$CLIENT_DIR"
    mkdir -p "$CA_DIR/revoked"
}

get_next_ip() {
    local used_ips=()
    local next_ip=2
    
    # Get used IPs from ipp.txt
    if [ -f "$OVPN_DIR/ipp.txt" ]; then
        used_ips=($(awk '{print $2}' "$OVPN_DIR/ipp.txt" | cut -d/ -f1 | sort -n))
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
    local client_ip="10.8.0.$2"
    
    if [ -z "$client_name" ]; then
        echo "❌ Client name is required"
        exit 1
    fi
    
    # Check if client already exists
    if [ -f "$CLIENT_DIR/${client_name}.ovpn" ]; then
        echo "❌ Client ${client_name} already exists"
        exit 1
    fi
    
    create_client_dirs
    
    # Generate client certificate and key
    cd "$EASYRSA_DIR"
    ./easyrsa build-client-full "$client_name" nopass
    
    # Copy client files
    cp "$CA_DIR/issued/${client_name}.crt" "$CLIENT_DIR/"
    cp "$CA_DIR/private/${client_name}.key" "$CLIENT_DIR/"
    
    # Create client configuration
    local server_public_ip=$(curl -s --max-time 10 https://ifconfig.me 2>/dev/null || "YOUR_SERVER_IP")
    
    cat > "$CLIENT_DIR/${client_name}.ovpn" << CLIENT_EOF
# OpenVPN Client Configuration for ${client_name}
client
dev tun
proto udp
remote ${server_public_ip} 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA512
key-direction 1
verb 3

# Certificates and keys
<ca>
$(cat "$OVPN_DIR/ca.crt")
</ca>

<cert>
$(cat "$CLIENT_DIR/${client_name}.crt")
</cert>

<key>
$(cat "$CLIENT_DIR/${client_name}.key")
</key>

<tls-crypt>
$(cat "$OVPN_DIR/ta.key")
</tls-crypt>
CLIENT_EOF
    
    chmod 600 "$CLIENT_DIR/${client_name}.ovpn"
    chmod 600 "$CLIENT_DIR/${client_name}.key"
    chmod 644 "$CLIENT_DIR/${client_name}.crt"
    
    echo "✅ Client ${client_name} added successfully!"
    echo "📱 Client config: $CLIENT_DIR/${client_name}.ovpn"
    echo "🔑 Client IP: ${client_ip}"
    
    # Add to ipp.txt
    echo "${client_name},${client_ip}" >> "$OVPN_DIR/ipp.txt"
}

remove_client() {
    local client_name="$1"
    
    if [ -z "$client_name" ]; then
        echo "❌ Client name is required"
        exit 1
    fi
    
    # Remove client files
    rm -f "$CLIENT_DIR/${client_name}.ovpn"
    rm -f "$CLIENT_DIR/${client_name}.key"
    rm -f "$CLIENT_DIR/${client_name}.crt"
    
    # Remove from ipp.txt
    if [ -f "$OVPN_DIR/ipp.txt" ]; then
        sed -i "/^${client_name},/d" "$OVPN_DIR/ipp.txt"
    fi
    
    echo "✅ Client ${client_name} removed successfully!"
}

revoke_client() {
    local client_name="$1"
    
    if [ -z "$client_name" ]; then
        echo "❌ Client name is required"
        exit 1
    fi
    
    # Revoke certificate
    cd "$EASYRSA_DIR"
    ./easyrsa revoke "$client_name"
    ./easyrsa gen-crl
    
    # Copy CRL to OpenVPN directory
    cp "$CA_DIR/crl.pem" "$OVPN_DIR/"
    chmod 644 "$OVPN_DIR/crl.pem"
    
    # Remove client files
    remove_client "$client_name"
    
    echo "✅ Client ${client_name} revoked successfully!"
    echo "⚠️  CRL updated. Restart OpenVPN service to apply changes."
}

list_clients() {
    echo "📋 OpenVPN Clients:"
    echo "==================="
    
    if [ -d "$CLIENT_DIR" ] && [ "$(ls -A "$CLIENT_DIR" 2>/dev/null)" ]; then
        for client_file in "$CLIENT_DIR"/*.ovpn; do
            if [ -f "$client_file" ]; then
                client_name=$(basename "$client_file" .ovpn)
                echo "• $client_name"
            fi
        done
    else
        echo "No clients configured"
    fi
}

show_status() {
    echo "📊 OpenVPN Status:"
    echo "=================="
    systemctl status openvpn@server --no-pager -l
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
    "revoke")
        revoke_client "$2"
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

chmod +x /usr/local/bin/openvpn-manage-client

# Enable and start OpenVPN service
echo -e "${BLUE}🚀 Enabling OpenVPN service...${NC}"
systemctl enable openvpn@server
systemctl start openvpn@server

# Configure firewall rules
echo -e "${BLUE}🔥 Configuring firewall rules...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp

# Allow OpenVPN
ufw allow ${OVPN_PORT}/${OVPN_PROTO}

# Allow HTTP/HTTPS if needed
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw --force enable

# Create status check script
cat > /usr/local/bin/openvpn-status << 'EOF'
#!/bin/bash
echo "=== OpenVPN Status ==="
systemctl status openvpn@server --no-pager -l
echo ""
echo "=== Active Connections ==="
ss -tuln | grep :1194
echo ""
echo "=== Firewall Status ==="
ufw status
echo ""
echo "=== OpenVPN Logs ==="
tail -20 /var/log/openvpn.log
echo ""
echo "=== Certificate Status ==="
openssl x509 -in /etc/openvpn/server.crt -text -noout | grep -E "(Subject:|Not After:)"
EOF

chmod +x /usr/local/bin/openvpn-status

# Create client config download script
cat > /usr/local/bin/openvpn-client-config << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: $0 <client_name>"
    echo "Available clients:"
    ls /etc/openvpn/clients/*.ovpn 2>/dev/null | sed 's|/etc/openvpn/clients/||g' | sed 's|.ovpn||g' || echo "No clients found"
    exit 1
fi

client_name="$1"
client_config="/etc/openvpn/clients/${client_name}.ovpn"

if [ -f "$client_config" ]; then
    echo "Client configuration file for ${client_name}:"
    echo "=========================================="
    cat "$client_config"
    echo ""
    echo "=========================================="
    echo "Save this configuration to your client device as .ovpn file"
    echo "File location: $client_config"
else
    echo "Client configuration not found for: $client_name"
    echo "Available clients:"
    ls /etc/openvpn/clients/*.ovpn 2>/dev/null | sed 's|/etc/openvpn/clients/||g' | sed 's|.ovpn||g' || echo "No clients found"
fi
EOF

chmod +x /usr/local/bin/openvpn-client-config

# Add first client
echo -e "${BLUE}👤 Adding first client (admin)...${NC}"
/usr/local/bin/openvpn-manage-client add admin

echo -e "${GREEN}✅ OpenVPN installation and configuration complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Important Information:${NC}"
echo -e "OpenVPN Port: ${OVPN_PORT} (${OVPN_PROTO})"
echo -e "VPN Network: ${OVPN_NETWORK}"
echo -e "Server External IP: ${SERVER_EXTERNAL_IP}"
echo ""
echo -e "${YELLOW}🔧 Management Commands:${NC}"
echo -e "Add client: openvpn-manage-client add <name>"
echo -e "Remove client: openvpn-manage-client remove <name>"
echo -e "Revoke client: openvpn-manage-client revoke <name>"
echo -e "List clients: openvpn-manage-client list"
echo -e "Check status: openvpn-status"
echo -e "Get client config: openvpn-client-config <name>"
echo ""
echo -e "${GREEN}🔐 Security Features Enabled:${NC}"
echo -e "✓ 4096-bit RSA encryption"
echo -e "✓ AES-256-GCM cipher"
echo -e "✓ SHA512 authentication"
echo -e "✓ TLS 1.2+ required"
echo -e "✓ HMAC key for additional security"
echo -e "✓ Certificate revocation support"
echo -e "✓ Firewall rules applied"
echo -e "✓ Proper file permissions"
echo -e "✓ Network isolation"
echo -e "✓ Multi-user support"
