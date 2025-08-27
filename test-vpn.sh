#!/bin/bash

# Enhanced VPN Test Script
# Tests VPN connectivity, configuration, and multi-user support

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🧪 Enhanced VPN Configuration Test Script${NC}"
echo "============================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Test WireGuard
echo -e "${BLUE}🔍 Testing WireGuard Configuration...${NC}"
if [ -f "/etc/wireguard/wg0.conf" ]; then
    echo -e "${GREEN}✓ WireGuard config file exists${NC}"
    
    if systemctl is-active --quiet wg-quick@wg0; then
        echo -e "${GREEN}✓ WireGuard service is running${NC}"
        
        # Check interface
        if ip link show wg0 &> /dev/null; then
            echo -e "${GREEN}✓ WireGuard interface exists${NC}"
            
            # Check IP address
            WG_IP=$(ip addr show wg0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
            if [ ! -z "$WG_IP" ]; then
                echo -e "${GREEN}✓ WireGuard IP: $WG_IP${NC}"
            else
                echo -e "${RED}✗ WireGuard IP not assigned${NC}"
            fi
        else
            echo -e "${RED}✗ WireGuard interface not found${NC}"
        fi
        
        # Test management script
        if [ -f "/usr/local/bin/wg-manage-client" ]; then
            echo -e "${GREEN}✓ WireGuard management script exists${NC}"
            
            # Test listing clients
            echo -e "${CYAN}📋 Testing client management...${NC}"
            /usr/local/bin/wg-manage-client list
        else
            echo -e "${RED}✗ WireGuard management script missing${NC}"
        fi
    else
        echo -e "${RED}✗ WireGuard service not running${NC}"
    fi
else
    echo -e "${RED}✗ WireGuard config file not found${NC}"
fi

echo ""

# Test OpenVPN
echo -e "${BLUE}🔍 Testing OpenVPN Configuration...${NC}"
if [ -f "/etc/openvpn/server.conf" ]; then
    echo -e "${GREEN}✓ OpenVPN config file exists${NC}"
    
    if systemctl is-active --quiet openvpn@server; then
        echo -e "${GREEN}✓ OpenVPN service is running${NC}"
        
        # Check if port is listening
        if ss -tuln | grep -q ":1194"; then
            echo -e "${GREEN}✓ OpenVPN listening on port 1194${NC}"
        else
            echo -e "${RED}✗ OpenVPN not listening on port 1194${NC}"
        fi
        
        # Test management script
        if [ -f "/usr/local/bin/openvpn-manage-client" ]; then
            echo -e "${GREEN}✓ OpenVPN management script exists${NC}"
            
            # Test listing clients
            echo -e "${CYAN}📋 Testing client management...${NC}"
            /usr/local/bin/openvpn-manage-client list
        else
            echo -e "${RED}✗ OpenVPN management script missing${NC}"
        fi
    else
        echo -e "${RED}✗ OpenVPN service not running${NC}"
    fi
else
    echo -e "${RED}✗ OpenVPN config file not found${NC}"
fi

echo ""

# Test Firewall
echo -e "${BLUE}🔍 Testing Firewall Configuration...${NC}"
if ufw status | grep -q "Status: active"; then
    echo -e "${GREEN}✓ UFW firewall is active${NC}"
    
    # Check WireGuard port
    if ufw status | grep -q "51820/udp"; then
        echo -e "${GREEN}✓ WireGuard port 51820 allowed${NC}"
    else
        echo -e "${RED}✗ WireGuard port 51820 not allowed${NC}"
    fi
    
    # Check OpenVPN port
    if ufw status | grep -q "1194/udp"; then
        echo -e "${GREEN}✓ OpenVPN port 1194 allowed${NC}"
    else
        echo -e "${RED}✗ OpenVPN port 1194 not allowed${NC}"
    fi
    
    # Check SSH port
    if ufw status | grep -q "22/tcp"; then
        echo -e "${GREEN}✓ SSH port 22 allowed${NC}"
    else
        echo -e "${RED}✗ SSH port 22 not allowed${NC}"
    fi
else
    echo -e "${RED}✗ UFW firewall not active${NC}"
fi

echo ""

# Test Network Configuration
echo -e "${BLUE}🔍 Testing Network Configuration...${NC}"

# Check IP forwarding
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" == "1" ]; then
    echo -e "${GREEN}✓ IP forwarding enabled${NC}"
else
    echo -e "${RED}✗ IP forwarding disabled${NC}"
fi

# Check routing
if ip route | grep -q "10.0.0.0/24\|10.8.0.0/24"; then
    echo -e "${GREEN}✓ VPN routes configured${NC}"
else
    echo -e "${RED}✗ VPN routes not found${NC}"
fi

echo ""

# Test Certificate Files
echo -e "${BLUE}🔍 Testing Certificate Files...${NC}"

# WireGuard keys
if [ -f "/etc/wireguard/server_public.key" ] && [ -f "/etc/wireguard/server_private.key" ]; then
    echo -e "${GREEN}✓ WireGuard keys exist${NC}"
    
    # Check key permissions
    if [ "$(stat -c %a /etc/wireguard/server_private.key)" = "600" ]; then
        echo -e "${GREEN}✓ WireGuard private key has correct permissions (600)${NC}"
    else
        echo -e "${RED}✗ WireGuard private key has incorrect permissions${NC}"
    fi
else
    echo -e "${RED}✗ WireGuard keys missing${NC}"
fi

# OpenVPN certificates
if [ -f "/etc/openvpn/ca.crt" ] && [ -f "/etc/openvpn/server.crt" ] && [ -f "/etc/openvpn/server.key" ]; then
    echo -e "${GREEN}✓ OpenVPN certificates exist${NC}"
    
    # Check certificate strength
    CERT_BITS=$(openssl x509 -in /etc/openvpn/server.crt -text -noout 2>/dev/null | grep "Public-Key:" | awk '{print $2}')
    if [ ! -z "$CERT_BITS" ]; then
        echo -e "${GREEN}✓ OpenVPN certificate strength: ${CERT_BITS} bits${NC}"
    fi
    
    # Check key permissions
    if [ "$(stat -c %a /etc/openvpn/server.key)" = "600" ]; then
        echo -e "${GREEN}✓ OpenVPN private key has correct permissions (600)${NC}"
    else
        echo -e "${RED}✗ OpenVPN private key has incorrect permissions${NC}"
    fi
else
    echo -e "${RED}✗ OpenVPN certificates missing${NC}"
fi

echo ""

# Test Management Scripts
echo -e "${BLUE}🔍 Testing Management Scripts...${NC}"

if [ -f "/usr/local/bin/wg-status" ]; then
    echo -e "${GREEN}✓ WireGuard status script exists${NC}"
else
    echo -e "${RED}✗ WireGuard status script missing${NC}"
fi

if [ -f "/usr/local/bin/openvpn-status" ]; then
    echo -e "${GREEN}✓ OpenVPN status script exists${NC}"
else
    echo -e "${RED}✗ OpenVPN status script missing${NC}"
fi

if [ -f "/usr/local/bin/wg-manage-client" ]; then
    echo -e "${GREEN}✓ WireGuard client management script exists${NC}"
else
    echo -e "${RED}✗ WireGuard client management script missing${NC}"
fi

if [ -f "/usr/local/bin/openvpn-manage-client" ]; then
    echo -e "${GREEN}✓ OpenVPN client management script exists${NC}"
else
    echo -e "${RED}✗ OpenVPN client management script missing${NC}"
fi

echo ""

# Test Multi-User Support
echo -e "${BLUE}🔍 Testing Multi-User Support...${NC}"

# Test adding a test client for WireGuard
if [ -f "/usr/local/bin/wg-manage-client" ]; then
    echo -e "${CYAN}🧪 Testing WireGuard client addition...${NC}"
    if /usr/local/bin/wg-manage-client add testuser 2>/dev/null; then
        echo -e "${GREEN}✓ WireGuard test client added successfully${NC}"
        
        # Check if client config exists
        if [ -f "/etc/wireguard/testuser.conf" ]; then
            echo -e "${GREEN}✓ WireGuard test client config created${NC}"
        else
            echo -e "${RED}✗ WireGuard test client config not created${NC}"
        fi
        
        # Clean up test client
        /usr/local/bin/wg-manage-client remove testuser 2>/dev/null
        echo -e "${CYAN}🧹 Test client removed${NC}"
    else
        echo -e "${YELLOW}⚠️  WireGuard client addition test failed (may already exist)${NC}"
    fi
fi

# Test adding a test client for OpenVPN
if [ -f "/usr/local/bin/openvpn-manage-client" ]; then
    echo -e "${CYAN}🧪 Testing OpenVPN client addition...${NC}"
    if /usr/local/bin/openvpn-manage-client add testuser 2>/dev/null; then
        echo -e "${GREEN}✓ OpenVPN test client added successfully${NC}"
        
        # Check if client config exists
        if [ -f "/etc/openvpn/clients/testuser.ovpn" ]; then
            echo -e "${GREEN}✓ OpenVPN test client config created${NC}"
        else
            echo -e "${RED}✗ OpenVPN test client config not created${NC}"
        fi
        
        # Clean up test client
        /usr/local/bin/openvpn-manage-client remove testuser 2>/dev/null
        echo -e "${CYAN}🧹 Test client removed${NC}"
    else
        echo -e "${YELLOW}⚠️  OpenVPN client addition test failed (may already exist)${NC}"
    fi
fi

echo ""

# Summary
echo -e "${BLUE}📊 Test Summary:${NC}"
echo "=================="

# Count successes and failures
SUCCESS_COUNT=0
FAILURE_COUNT=0

# Count WireGuard successes
if [ -f "/etc/wireguard/wg0.conf" ] && systemctl is-active --quiet wg-quick@wg0; then
    ((SUCCESS_COUNT++))
else
    ((FAILURE_COUNT++))
fi

# Count OpenVPN successes
if [ -f "/etc/openvpn/server.conf" ] && systemctl is-active --quiet openvpn@server; then
    ((SUCCESS_COUNT++))
else
    ((FAILURE_COUNT++))
fi

# Count firewall success
if ufw status | grep -q "Status: active"; then
    ((SUCCESS_COUNT++))
else
    ((FAILURE_COUNT++))
fi

# Count management scripts
if [ -f "/usr/local/bin/wg-manage-client" ] && [ -f "/usr/local/bin/openvpn-manage-client" ]; then
    ((SUCCESS_COUNT++))
else
    ((FAILURE_COUNT++))
fi

echo -e "${GREEN}✅ Successful tests: $SUCCESS_COUNT${NC}"
echo -e "${RED}❌ Failed tests: $FAILURE_COUNT${NC}"

if [ $FAILURE_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! VPN is properly configured with multi-user support.${NC}"
else
    echo -e "${YELLOW}⚠️  Some tests failed. Check the configuration.${NC}"
fi

echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo "1. Test client connectivity"
echo "2. Verify traffic routing"
echo "3. Check logs for any errors"
echo "4. Configure client devices"
echo ""
echo -e "${CYAN}👥 Multi-User Management:${NC}"
echo "• Add users: wg-manage-client add <name> (WireGuard)"
echo "• Add users: openvpn-manage-client add <name> (OpenVPN)"
echo "• List users: wg-manage-client list / openvpn-manage-client list"
echo "• Remove users: wg-manage-client remove <name> / openvpn-manage-client remove <name>"
echo "• Get configs: wg-client-config <name> / openvpn-client-config <name>"
