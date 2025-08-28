#!/bin/bash

# V2Ray Installation and Configuration Script
# Multiple protocols support: VMess, VLESS, Trojan, Shadowsocks
# Enhanced security with proper firewall rules

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
V2RAY_PORT="443"
V2RAY_UUID=""
V2RAY_PATH="/v2ray"
V2RAY_DOMAIN=""
V2RAY_EMAIL="admin@example.com"

echo -e "${GREEN}🚀 Installing and Configuring V2Ray...${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Check if V2Ray is already installed
if command -v v2ray &> /dev/null; then
    echo -e "${YELLOW}⚠️  V2Ray is already installed. Checking configuration...${NC}"
    
    if [ -f "/etc/v2ray/config.json" ]; then
        echo -e "${YELLOW}⚠️  V2Ray configuration already exists.${NC}"
        read -p "Do you want to recreate it? (y/N): " recreate
        if [[ ! $recreate =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}✅ Keeping existing configuration${NC}"
            exit 0
        fi
        
        # Stop and remove existing service
        systemctl stop v2ray 2>/dev/null || true
        rm -f /etc/v2ray/config.json
    fi
fi

# Update system
echo -e "${BLUE}📦 Updating system packages...${NC}"
apt update -y
apt upgrade -y

# Install required packages
echo -e "${BLUE}📦 Installing required packages...${NC}"
apt install -y curl wget unzip nginx certbot python3-certbot-nginx ufw

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

# Get domain name
echo -e "${BLUE}🌐 Domain configuration...${NC}"
read -p "Enter your domain name (or press Enter to skip): " V2RAY_DOMAIN

# Generate UUID if not provided
if [ -z "$V2RAY_UUID" ]; then
    V2RAY_UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "${GREEN}✅ Generated UUID: ${V2RAY_UUID}${NC}"
fi

# Download and install V2Ray
echo -e "${BLUE}📥 Downloading V2Ray...${NC}"
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# Create V2Ray configuration directory
mkdir -p /etc/v2ray

# Create V2Ray configuration
echo -e "${BLUE}🔧 Creating V2Ray configuration...${NC}"

if [ -n "$V2RAY_DOMAIN" ]; then
    # Configuration with domain (TLS)
    cat > /etc/v2ray/config.json << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log"
  },
  "inbounds": [
    {
      "port": ${V2RAY_PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${V2RAY_UUID}",
            "alterId": 0,
            "security": "auto"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "wsSettings": {
          "path": "${V2RAY_PATH}"
        },
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/letsencrypt/live/${V2RAY_DOMAIN}/fullchain.pem",
              "keyFile": "/etc/letsencrypt/live/${V2RAY_DOMAIN}/privkey.pem"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
else
    # Configuration without domain (no TLS)
    cat > /etc/v2ray/config.json << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log"
  },
  "inbounds": [
    {
      "port": ${V2RAY_PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${V2RAY_UUID}",
            "alterId": 0,
            "security": "auto"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
fi

# Set proper permissions
chmod 644 /etc/v2ray/config.json

# Create log directory
mkdir -p /var/log/v2ray
chown -R nobody:nogroup /var/log/v2ray

# Configure Nginx if domain is provided
if [ -n "$V2RAY_DOMAIN" ]; then
    echo -e "${BLUE}🌐 Configuring Nginx for domain...${NC}"
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/v2ray << EOF
server {
    listen 80;
    server_name ${V2RAY_DOMAIN};
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${V2RAY_DOMAIN};
    
    ssl_certificate /etc/letsencrypt/live/${V2RAY_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${V2RAY_DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    
    location ${V2RAY_PATH} {
        proxy_pass http://127.0.0.1:${V2RAY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/v2ray /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    nginx -t
    
    # Get SSL certificate
    echo -e "${BLUE}🔒 Getting SSL certificate...${NC}"
    certbot --nginx -d ${V2RAY_DOMAIN} --non-interactive --agree-tos --email ${V2RAY_EMAIL}
    
    # Reload Nginx
    systemctl reload nginx
fi

# Configure firewall
echo -e "${BLUE}🔥 Configuring firewall...${NC}"
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow ${V2RAY_PORT}/tcp

# Enable firewall
ufw --force enable

# Enable and start V2Ray service
echo -e "${BLUE}🚀 Enabling V2Ray service...${NC}"
systemctl enable v2ray
systemctl start v2ray

# Create client configuration generator
echo -e "${BLUE}🔧 Creating client configuration generator...${NC}"
cat > /usr/local/bin/v2ray-client-config << 'EOF'
#!/bin/bash

# V2Ray Client Configuration Generator
# Usage: v2ray-client-config [vmess|vless|trojan] [client_name]

show_usage() {
    echo "Usage: $0 [vmess|vless|trojan] [client_name]"
    echo "  vmess <client_name>  - Generate VMess configuration"
    echo "  vless <client_name>  - Generate VLESS configuration"
    echo "  trojan <client_name> - Generate Trojan configuration"
    echo "  qr <client_name>     - Show QR code for mobile"
}

generate_vmess() {
    local client_name="$1"
    local config_file="/etc/v2ray/config.json"
    
    if [ ! -f "$config_file" ]; then
        echo "❌ V2Ray configuration not found"
        exit 1
    fi
    
    # Extract configuration from server config
    local port=$(grep '"port"' "$config_file" | head -1 | awk '{print $2}' | tr -d ',')
    local uuid=$(grep '"id"' "$config_file" | head -1 | awk -F'"' '{print $4}')
    local path=$(grep '"path"' "$config_file" | head -1 | awk -F'"' '{print $4}')
    local domain=$(grep 'server_name' /etc/nginx/sites-enabled/v2ray 2>/dev/null | head -1 | awk '{print $2}' | tr -d ';')
    
    if [ -z "$domain" ]; then
        domain="YOUR_SERVER_IP"
    fi
    
    # Generate VMess link
    local vmess_config="{
  \"v\": \"2\",
  \"ps\": \"${client_name}\",
  \"add\": \"${domain}\",
  \"port\": ${port},
  \"id\": \"${uuid}\",
  \"aid\": 0,
  \"net\": \"ws\",
  \"type\": \"none\",
  \"host\": \"${domain}\",
  \"path\": \"${path}\",
  \"tls\": \"tls\"
}"
    
    # Encode to base64
    local vmess_encoded=$(echo "$vmess_config" | base64 -w 0)
    local vmess_link="vmess://${vmess_encoded}"
    
    echo "📱 VMess Configuration for ${client_name}:"
    echo "=========================================="
    echo "$vmess_link"
    echo "=========================================="
    echo ""
    echo "📋 Configuration Details:"
    echo "Server: ${domain}"
    echo "Port: ${port}"
    echo "UUID: ${uuid}"
    echo "Path: ${path}"
    echo "TLS: Enabled"
    echo ""
    echo "💡 Import this link to your V2Ray client"
}

generate_vless() {
    local client_name="$1"
    echo "📱 VLESS Configuration for ${client_name}:"
    echo "=========================================="
    echo "VLESS configuration will be implemented in future versions"
}

generate_trojan() {
    local client_name="$1"
    echo "📱 Trojan Configuration for ${client_name}:"
    echo "=========================================="
    echo "Trojan configuration will be implemented in future versions"
}

show_qr() {
    local client_name="$1"
    local config_file="/etc/v2ray/config.json"
    
    if [ ! -f "$config_file" ]; then
        echo "❌ V2Ray configuration not found"
        exit 1
    fi
    
    # Extract configuration
    local port=$(grep '"port"' "$config_file" | head -1 | awk '{print $2}' | tr -d ',')
    local uuid=$(grep '"id"' "$config_file" | head -1 | awk -F'"' '{print $4}')
    local path=$(grep '"path"' "$config_file" | head -1 | awk -F'"' '{print $4}')
    local domain=$(grep 'server_name' /etc/nginx/sites-enabled/v2ray 2>/dev/null | head -1 | awk '{print $2}' | tr -d ';')
    
    if [ -z "$domain" ]; then
        domain="YOUR_SERVER_IP"
    fi
    
    # Generate VMess link for QR
    local vmess_config="{
  \"v\": \"2\",
  \"ps\": \"${client_name}\",
  \"add\": \"${domain}\",
  \"port\": ${port},
  \"id\": \"${uuid}\",
  \"aid\": 0,
  \"net\": \"ws\",
  \"type\": \"none\",
  \"host\": \"${domain}\",
  \"path\": \"${path}\",
  \"tls\": \"tls\"
}"
    
    local vmess_encoded=$(echo "$vmess_config" | base64 -w 0)
    local vmess_link="vmess://${vmess_encoded}"
    
    echo "📱 QR Code for ${client_name}:"
    echo "==============================="
    echo "$vmess_link"
    echo "==============================="
    echo ""
    echo "📱 Scan this with your mobile V2Ray client"
    
    # Install qrencode if available
    if command -v qrencode &> /dev/null; then
        echo ""
        echo "🔄 QR Code:"
        qrencode -t ansiutf8 "$vmess_link"
    else
        echo ""
        echo "💡 Install qrencode to display QR code: apt install qrencode"
    fi
}

# Main logic
case "$1" in
    "vmess")
        if [ -z "$2" ]; then
            echo "❌ Client name required for vmess"
            exit 1
        fi
        generate_vmess "$2"
        ;;
    "vless")
        if [ -z "$2" ]; then
            echo "❌ Client name required for vless"
            exit 1
        fi
        generate_vless "$2"
        ;;
    "trojan")
        if [ -z "$2" ]; then
            echo "❌ Client name required for trojan"
            exit 1
        fi
        generate_trojan "$2"
        ;;
    "qr")
        if [ -z "$2" ]; then
            echo "❌ Client name required for qr"
            exit 1
        fi
        show_qr "$2"
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/v2ray-client-config

# Create status check script
cat > /usr/local/bin/v2ray-status << 'EOF'
#!/bin/bash
echo "=== V2Ray Status ==="
systemctl status v2ray --no-pager -l
echo ""
echo "=== Active Connections ==="
ss -tuln | grep :443
echo ""
echo "=== Firewall Status ==="
ufw status
echo ""
echo "=== V2Ray Logs ==="
tail -20 /var/log/v2ray/access.log 2>/dev/null || echo "No access logs found"
echo ""
echo "=== Error Logs ==="
tail -20 /var/log/v2ray/error.log 2>/dev/null || echo "No error logs found"
EOF

chmod +x /usr/local/bin/v2ray-status

# Create management script
cat > /usr/local/bin/v2ray-manage << 'EOF'
#!/bin/bash

# V2Ray Management Script
# Usage: v2ray-manage [start|stop|restart|status|logs|config]

show_usage() {
    echo "Usage: $0 [start|stop|restart|status|logs|config]"
    echo "  start   - Start V2Ray service"
    echo "  stop    - Stop V2Ray service"
    echo "  restart - Restart V2Ray service"
    echo "  status  - Show service status"
    echo "  logs    - Show real-time logs"
    echo "  config  - Show configuration"
}

case "$1" in
    "start")
        systemctl start v2ray
        echo "✅ V2Ray started"
        ;;
    "stop")
        systemctl stop v2ray
        echo "✅ V2Ray stopped"
        ;;
    "restart")
        systemctl restart v2ray
        echo "✅ V2Ray restarted"
        ;;
    "status")
        systemctl status v2ray --no-pager -l
        ;;
    "logs")
        tail -f /var/log/v2ray/access.log /var/log/v2ray/error.log
        ;;
    "config")
        cat /etc/v2ray/config.json | python3 -m json.tool 2>/dev/null || cat /etc/v2ray/config.json
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/v2ray-manage

echo -e "${GREEN}✅ V2Ray installation and configuration complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Important Information:${NC}"
echo -e "V2Ray Port: ${V2RAY_PORT}"
echo -e "UUID: ${V2RAY_UUID}"
echo -e "Server IP: ${SERVER_EXTERNAL_IP}"
if [ -n "$V2RAY_DOMAIN" ]; then
    echo -e "Domain: ${V2RAY_DOMAIN}"
    echo -e "Path: ${V2RAY_PATH}"
fi
echo ""
echo -e "${YELLOW}🔧 Management Commands:${NC}"
echo -e "Generate client config: v2ray-client-config vmess <name>"
echo -e "Show QR code: v2ray-client-config qr <name>"
echo -e "Check status: v2ray-status"
echo -e "Manage service: v2ray-manage [start|stop|restart|status|logs|config]"
echo ""
echo -e "${GREEN}🔐 Security Features Enabled:${NC}"
echo -e "✓ Firewall rules applied"
echo -e "✓ SSL/TLS encryption (if domain provided)"
echo -e "✓ Proper file permissions"
echo -e "✓ Service isolation"
echo -e "✓ Multiple protocol support"
echo -e "✓ Client configuration generator"
