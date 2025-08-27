# 🚀 VPN Server Installation Guide

This guide provides step-by-step instructions for setting up a secure VPN server with WireGuard and OpenVPN support.

## 📋 Prerequisites

- Ubuntu 18.04+ or Debian 10+ server
- Root access (sudo privileges)
- Internet connection
- Static IP address (recommended)
- Ports 51820 (WireGuard) and 1194 (OpenVPN) open on firewall

## 🔧 Installation Steps

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd server-setup
chmod +x setup.sh modules/*.sh test-vpn.sh
```

### 2. Run Setup Menu

```bash
sudo ./setup.sh
```

Select option 1 for WireGuard or option 2 for OpenVPN.

### 3. Manual Installation (Alternative)

If you prefer manual installation:

#### WireGuard Installation
```bash
sudo bash modules/wireguard.sh
```

#### OpenVPN Installation
```bash
sudo bash modules/openvpn.sh
```

## 🛡️ WireGuard Setup

### Features
- **Port**: 51820 (UDP)
- **Network**: 10.0.0.0/24
- **Encryption**: 256-bit
- **Protocol**: Modern, fast, secure

### Management Commands

```bash
# Add new client
wg-manage-client add <client_name>

# Remove client
wg-manage-client remove <client_name>

# List all clients
wg-manage-client list

# Check status
wg-status

# Get client configuration
wg-client-config <client_name>
```

### Client Configuration

After adding a client, the configuration file will be created at:
```
/etc/wireguard/<client_name>.conf
```

Copy this file to your client device and import it into the WireGuard app.

## 🔐 OpenVPN Setup

### Features
- **Port**: 1194 (UDP)
- **Network**: 10.8.0.0/24
- **Encryption**: 4096-bit RSA + AES-256-GCM
- **Protocol**: Traditional, widely supported

### Management Commands

```bash
# Add new client
openvpn-manage-client add <client_name>

# Remove client
openvpn-manage-client remove <client_name>

# Revoke client certificate
openvpn-manage-client revoke <client_name>

# List all clients
openvpn-manage-client list

# Check status
openvpn-status

# Get client configuration
openvpn-client-config <client_name>
```

### Client Configuration

After adding a client, the configuration file will be created at:
```
/etc/openvpn/clients/<client_name>.ovpn
```

Copy this file to your client device and import it into any OpenVPN client.

## 🧪 Testing Installation

Run the test script to verify everything is working:

```bash
sudo ./test-vpn.sh
```

This will test:
- Service status
- Firewall configuration
- Certificate validity
- Multi-user support
- Management scripts

## 📱 Client Setup

### WireGuard Clients

#### Android/iOS
1. Install WireGuard app from app store
2. Import configuration file
3. Enable connection

#### Windows
1. Download WireGuard from wireguard.com
2. Import configuration file
3. Connect

#### Linux/macOS
1. Install WireGuard package
2. Copy configuration to `/etc/wireguard/`
3. Run `wg-quick up <interface_name>`

### OpenVPN Clients

#### Android/iOS
1. Install OpenVPN Connect app
2. Import .ovpn file
3. Connect

#### Windows
1. Download OpenVPN client
2. Import .ovpn file
3. Connect

#### Linux/macOS
1. Install OpenVPN package
2. Run `sudo openvpn --config <file>.ovpn`

## 🔒 Security Features

### Implemented Security
- ✅ Strong encryption (256-bit+)
- ✅ Proper file permissions (600 for keys)
- ✅ Firewall rules (UFW)
- ✅ Network isolation
- ✅ Certificate-based authentication (OpenVPN)
- ✅ Key-based authentication (WireGuard)
- ✅ IP forwarding protection
- ✅ Client isolation

### Additional Recommendations
- Change default SSH port
- Use SSH keys instead of passwords
- Regular security updates
- Monitor logs regularly
- Backup configurations
- Use strong passwords for management

## 🌐 Network Configuration

### WireGuard Network
- Server IP: 10.0.0.1
- Client IPs: 10.0.0.2-254
- DNS: 1.1.1.1, 8.8.8.8

### OpenVPN Network
- Server IP: 10.8.0.1
- Client IPs: 10.8.0.2-254
- DNS: 1.1.1.1, 8.8.8.8

## 🔧 Troubleshooting

### Common Issues

#### Service Not Starting
```bash
# Check logs
journalctl -u wg-quick@wg0 -f
journalctl -u openvpn@server -f

# Check configuration
wg-quick strip wg0
openvpn --config /etc/openvpn/server.conf --test-crypto
```

#### Connection Issues
```bash
# Check firewall
ufw status

# Check ports
ss -tuln | grep -E "(51820|1194)"

# Check routing
ip route show
```

#### Certificate Issues
```bash
# Check certificate validity
openssl x509 -in /etc/openvpn/server.crt -text -noout

# Regenerate certificates if needed
cd ~/easy-rsa
./easyrsa build-server-full server nopass
```

### Performance Optimization

#### WireGuard
- MTU optimization (already configured)
- Use UDP protocol
- Enable compression if needed

#### OpenVPN
- Use UDP protocol
- Optimize cipher settings
- Monitor connection limits

## 📊 Monitoring

### Log Files
- WireGuard: `journalctl -u wg-quick@wg0 -f`
- OpenVPN: `tail -f /var/log/openvpn.log`
- System: `tail -f /var/log/syslog`

### Status Commands
```bash
# WireGuard
wg show wg0
wg-status

# OpenVPN
openvpn-status
systemctl status openvpn@server

# General
ufw status
ip addr show
```

## 🔄 Maintenance

### Regular Tasks
1. **Weekly**: Check service status
2. **Monthly**: Review logs for errors
3. **Quarterly**: Update system packages
4. **Annually**: Rotate certificates (OpenVPN)

### Backup
```bash
# Backup configurations
tar -czf vpn-backup-$(date +%Y%m%d).tar.gz /etc/wireguard /etc/openvpn

# Backup certificates
cp -r ~/easy-rsa /backup/easy-rsa-$(date +%Y%m%d)
```

## 🆘 Support

### Getting Help
1. Check logs for error messages
2. Run test script: `./test-vpn.sh`
3. Verify firewall rules: `ufw status`
4. Check service status: `systemctl status`

### Useful Commands
```bash
# Quick health check
wg show wg0 && systemctl status openvpn@server && ufw status

# Restart services
systemctl restart wg-quick@wg0
systemctl restart openvpn@server

# View all VPN connections
ss -tuln | grep -E "(51820|1194)"
```

---

**⚠️ Security Notice**: This setup provides enterprise-grade security. Keep your server updated and monitor for any suspicious activity.
