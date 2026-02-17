# VPN User Guide

## What is VPN and Why You Need It

VPN (Virtual Private Network) provides:
- 🔒 **Secure access** to internal company resources
- 🌐 **Remote work** — access office network from anywhere
- 🛡️ **Encrypted traffic** — protection on public Wi-Fi

## How to Get VPN Access

### Step 1: Request a Certificate

Send an email to: **iamroypchel@gmail**

Include:
- Your full name
- Department
- Reason for VPN access

You will receive a `.ovpn` configuration file within 1 business day.

### Step 2: Install VPN Client

#### Windows
1. Download OpenVPN GUI: https://openvpn.net/community-downloads/
2. Run installer, accept defaults
3. Restart computer if prompted

#### macOS
1. Download Tunnelblick: https://tunnelblick.net/downloads.html
2. Open `.dmg` file, drag to Applications
3. Or use Homebrew: `brew install --cask tunnelblick`

#### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install openvpn
```

#### Android
1. Open Google Play Store
2. Search "OpenVPN Connect"
3. Install official app by OpenVPN Inc.

#### iOS
1. Open App Store
2. Search "OpenVPN Connect"
3. Install official app

### Step 3: Import Configuration

#### Windows (OpenVPN GUI)
1. Copy `.ovpn` file to `C:\Users\<YourName>\OpenVPN\config\`
2. Right-click OpenVPN icon in system tray → Connect

#### macOS (Tunnelblick)
1. Double-click `.ovpn` file
2. Click "Only Me" when prompted
3. Click Tunnelblick icon → Connect

#### Linux
```bash
sudo openvpn --config your-config.ovpn
```

#### Mobile (Android/iOS)
1. Transfer `.ovpn` file to your device (email, cloud, etc.)
2. Open OpenVPN Connect app
3. Tap "+" → "Import" → select file
4. Tap "Connect"

### Step 4: Verify Connection

After connecting, you should see:

- ✅ "Connected" status in VPN client
- ✅ New IP address (10.8.0.x)
- ✅ Access to internal resources

Test connection:
```bash
# On any OS with terminal
ping 10.10.0.6
```

## Troubleshooting

#### "Connection timed out"
- Check your internet connection
- Try different network (mobile hotspot)
- Contact admin if persists

#### "Certificate expired"
- Request a new certificate from admin
- Old certificates are valid for 1 year

#### "TLS handshake failed"
- Ensure system time is correct
- Re-download your `.ovpn` file

## Getting Help

**Email:** iamroypchel@gmail.com

When reporting issues, please include:

- Operating system and version
- VPN client version
- Error message (screenshot if possible)
- When the problem started
Response time: within 1 business day