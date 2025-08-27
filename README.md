# Server Setup 🚀

A comprehensive server setup automation script with enhanced security configurations for various services.

## 🛡️ VPN Services

### WireGuard VPN
- **Port**: 51820 (UDP)
- **Network**: 10.0.0.0/24
- **Security**: 
  - 256-bit encryption
  - Automatic key generation
  - Firewall rules
  - Network isolation
- **Features**:
  - Fast and modern protocol
  - Built-in status monitoring
  - Client configuration generation
  - Persistent connections

### OpenVPN
- **Port**: 1194 (UDP)
- **Network**: 10.8.0.0/24
- **Security**:
  - 2048-bit RSA encryption
  - AES-256-CBC cipher
  - SHA256 authentication
  - TLS 1.2+ required
  - HMAC key protection
- **Features**:
  - Certificate-based authentication
  - Advanced security options
  - Comprehensive logging
  - Client certificate management

## 🔧 Available Modules

- WireGuard VPN
- OpenVPN
- Laravel
- WordPress
- Golang (Gin)
- Node.js (Express)

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/itKhaleghi/server-setup.git
cd server-setup

# Make scripts executable
chmod +x setup.sh
chmod +x modules/*.sh

# Run the setup menu
sudo ./setup.sh
```

## 🔐 Security Features

### VPN Security
- ✅ IP forwarding configured
- ✅ Firewall rules applied
- ✅ Proper file permissions (600 for keys)
- ✅ Network isolation
- ✅ Persistent configuration
- ✅ Automatic service management

### System Security
- ✅ UFW firewall enabled
- ✅ Default deny incoming
- ✅ SSH access maintained
- ✅ Service isolation
- ✅ Logging enabled

## 📋 Management Commands

### WireGuard
```bash
# Check status
wg-status

# Get client configuration
wg-client-config

# Restart service
systemctl restart wg-quick@wg0

# View logs
journalctl -u wg-quick@wg0 -f
```

### OpenVPN
```bash
# Check status
openvpn-status

# Get client configuration
openvpn-client-config

# Manage certificates
openvpn-manage-certs

# Restart service
systemctl restart openvpn@server

# View logs
tail -f /var/log/openvpn.log
```

## 🌐 Network Configuration

### WireGuard
- Server IP: 10.0.0.1
- Client IPs: 10.0.0.2/32
- DNS: 1.1.1.1, 8.8.8.8

### OpenVPN
- Server IP: 10.8.0.1
- Client Pool: 10.8.0.2-254
- DNS: 1.1.1.1, 8.8.8.8

## ⚠️ Important Notes

1. **Run as root**: Scripts require sudo privileges
2. **Firewall**: UFW will be reset and reconfigured
3. **Ports**: Ensure ports 51820 (WireGuard) and 1194 (OpenVPN) are open
4. **Backup**: Backup existing configurations before running
5. **Internet**: Server needs internet access for package installation

## 🔧 Customization

### WireGuard
- Edit `/etc/wireguard/wg0.conf` for server settings
- Modify client IP ranges in the configuration
- Change port in configuration and firewall rules

### OpenVPN
- Edit `/etc/openvpn/server.conf` for server settings
- Modify certificate details in `~/easy-rsa/vars`
- Change port in configuration and firewall rules

## 📞 Support

For issues or questions:
1. Check service status with provided commands
2. Review logs for error messages
3. Verify firewall rules with `ufw status`
4. Ensure proper file permissions

## 🚀 Next Steps

After VPN setup:
1. Configure client devices
2. Test connectivity
3. Set up additional services (Laravel, WordPress, etc.)
4. Configure monitoring and alerts
5. Regular security updates

---

**⚠️ Security Notice**: This setup provides enterprise-grade security but should be regularly updated and monitored in production environments.
