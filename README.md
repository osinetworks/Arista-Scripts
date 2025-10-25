# Arista EOS Firmware Upgrade Automation

Automated bash scripts for upgrading Arista EOS switches via HTTP with MD5 verification. Designed for environments with limited tools (WSL without Python libraries).

## ✨ Features

- 🔐 SSH key-based authentication setup
- 📦 Automated firmware upgrade via HTTP
- ✅ MD5 checksum verification (local and remote)
- 🔄 Bulk switch processing
- 🏥 Pre-flight connectivity checks
- 📝 Detailed logging per switch
- 🔍 Post-upgrade verification
- 💾 Configuration backup
- ⚙️ Configuration deployment
- 🧹 Automatic cleanup of old firmware images
- 🚫 **No dependencies** - Uses only native Linux commands

## 📋 Prerequisites

- **WSL** (Windows Subsystem for Linux) or Linux environment
- **SSH access** to Arista switches
- **Python 3** (for HTTP server only - pre-installed in most systems)
- **Network connectivity** between upgrade host and switches

## 📁 Files Description

| File | Purpose |
|------|---------|
| `1_scp-key-arista.sh` | Deploy SSH keys and create admin user on switches |
| `2_config-backup.sh` | Backup switch configurations before upgrade |
| `3_send-config.sh` | Deploy configuration changes to switches |
| `5_Arista_Firmware_Upgrade.sh` | Main firmware upgrade script |
| `6_post_upgrade.sh` | Verify upgrade status and firmware versions |
| `arista.env.sh` | Environment configuration (sensitive - not in repo) |
| `switch_list.txt` | List of switch IPs (sensitive - not in repo) |

## 🚀 Quick Start

### 1. Clone and Configure
```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/arista-firmware-upgrade.git
cd arista-firmware-upgrade

# Copy example files
cp arista.env.sh.example arista.env.sh
cp switch_list.txt.example switch_list.txt

# Edit configuration
nano arista.env.sh
nano switch_list.txt

# Make scripts executable
chmod +x *.sh
```

### 2. Initial Setup (One-time)
```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -f ~/.ssh/arista_key

# Deploy SSH key to switches and create admin user
./1_scp-key-arista.sh
```

### 3. Pre-Upgrade Tasks
```bash
# Backup current configurations
./2_config-backup.sh

# (Optional) Deploy any config changes
./3_send-config.sh
```

### 4. Firmware Upgrade
```bash
# Place firmware files in BASE_PATH directory
# - EOS-4.34.3M.swi
# - EOS64-4.34.3M.swi (for 64-bit switches like 7050)
# - EOS-4.34.3M.swi.md5

# Start HTTP server (in separate terminal)
cd /mnt/c/Users/user/Desktop/Network/Arista/Arista_scripts
python3 -m http.server -b 10.1.1.200 8080

# Run upgrade script
./5_Arista_Firmware_Upgrade.sh
```

### 5. Post-Upgrade Verification
```bash
# Wait 5-10 minutes for switches to reload
sleep 600

# Verify upgrade status
./6_post_upgrade.sh
```

## 📖 Detailed Usage

### Script 1: SSH Key Deployment

Deploys your SSH public key to switches and creates a privileged user.
```bash
./1_scp-key-arista.sh
```

**What it does:**
- Copies SSH public key to each switch
- Creates `admin2` user with privilege 15
- Configures SSH key authentication
- Verifies connectivity with new credentials

### Script 2: Configuration Backup

Creates timestamped backups of all switch configurations.
```bash
./2_config-backup.sh
```

**Output:** `config/10.1.1.10.20251023_14-30-45.cfg`

### Script 3: Configuration Deployment

Sends configuration commands to all switches.
```bash
./3_send-config.sh
```

**Edit the script to customize commands:**
```bash
# Example: Configure aliases, logging, IGMP settings
alias cc clear counters
logging buffered 65000
int vlan200
ip igmp static-group 224.0.1.129
```

### Script 5: Firmware Upgrade

Main upgrade script with comprehensive error handling.
```bash
./5_Arista_Firmware_Upgrade.sh
```

**Process:**
1. Verifies local MD5 checksum
2. Checks switch connectivity (ping + SSH)
3. Detects switch model (32-bit vs 64-bit)
4. Deletes old firmware images
5. Downloads new firmware via HTTP
6. Downloads MD5 file
7. Verifies remote MD5 checksum
8. Installs new boot image
9. Saves config and reloads switch

**Features:**
- Automatic model detection (EOS vs EOS64)
- Individual log files per switch
- Failed switches logged separately
- Graceful handling of SSH disconnects during reload

### Script 6: Post-Upgrade Verification

Verifies all switches are running expected firmware version.
```bash
./6_post_upgrade.sh
```

**Example Output:**
```
=========================================
Arista Switch Post-Upgrade Verification
Date: 2025-10-23 14:30:45
Expected Version: 4.34.3M
=========================================

[10.1.1.10]          OK - EOS-4.34.3M
[10.1.1.11]          OK - EOS64-4.34.3M
[10.1.1.12]          MISMATCH - EOS-4.32.3M (Expected: 4.34.3M)
[10.1.1.13]          UNREACHABLE

=========================================
Summary:
  Success:     2
  Failed:      1
  Unreachable: 1
=========================================
```

## ⚙️ Configuration

### arista.env.sh
```bash
# SSH Users
SSH_USER="admin"           # Initial admin user (for key deployment)
SSH_USER2="admin2"         # Privileged user created by script

# Paths
BASE_PATH="/mnt/c/Users/user/Desktop/Network/Arista/Arista_scripts"
SWITCH_LIST="$BASE_PATH/switch_list.txt"
KEY_HOME="/home/user/.ssh"
ARISTA_KEY="arista_key"

# HTTP Server (for firmware distribution)
HTTP_PORT=8080
HTTP_SERVER_IP="10.1.1.200"  # Must be reachable by all switches

# Firmware Files
EOS_IMAGE="EOS-4.34.3M.swi"       # 32-bit switches
EOS64_IMAGE="EOS64-4.34.3M.swi"   # 64-bit switches (7050, etc.)
EOS64_SWITCH_TYPE="7050"          # Model pattern for 64-bit detection
```

### switch_list.txt
```
# Core Switches
10.1.1.10
10.1.1.11

# Access Switches
10.1.1.20
10.1.1.21
10.1.1.22

# Lines starting with # are ignored
# Blank lines are ignored
```

## 🔒 Security Best Practices

1. **SSH Key Permissions:**
```bash
   chmod 600 ~/.ssh/arista_key
   chmod 644 ~/.ssh/arista_key.pub
```

2. **Never commit sensitive files:**
   - `arista.env.sh` (contains paths and usernames)
   - `switch_list.txt` (contains IP addresses)
   - SSH keys
   - Log files
   - Configuration backups

3. **Cleanup after upgrade:**
```bash
   # Remove temporary admin user (optional)
   ssh admin@10.1.1.10
   conf t
   no username admin2
   write mem
```

## 🐛 Troubleshooting

### Switch Unreachable
```bash
# Check connectivity
ping -c 3 10.1.1.10

# Check SSH port
nc -zv 10.1.1.10 22

# Verify switch is powered on
# Check firewall rules
```

### SSH Authentication Failed
```bash
# Check key permissions
ls -la ~/.ssh/arista_key

# Test SSH manually
ssh -i ~/.ssh/arista_key admin2@10.1.1.10 "show version"

# Verify key was deployed
ssh admin@10.1.1.10 "show users"
```

### MD5 Verification Failed
```bash
# Re-download firmware from Arista
# Verify MD5 locally
md5sum EOS-4.34.3M.swi
cat EOS-4.34.3M.swi.md5

# Check for network corruption
# Verify HTTP server is serving correct files
```

### HTTP Server Not Reachable
```bash
# Verify server is running
curl http://10.1.1.200:8080/EOS-4.34.3M.swi -I

# Check from switch
ssh admin2@10.1.1.10
bash curl http://10.1.1.200:8080/EOS-4.34.3M.swi -I

# Verify firewall allows port 8080
```

### Switch Stuck in Boot Loop
```bash
# Connect via console
# Boot from previous image:
boot flash:EOS-4.32.3M.swi

# Or configure boot preferences
zerotouch cancel
reload
```

## 📊 Logs

All logs are stored in `$BASE_PATH/logs/`:

- `10.1.1.10.log` - Individual switch upgrade log
- `10.1.1.11.log` - Individual switch upgrade log
- `failed_switches.log` - List of failed switches
- `10.1.1.10_config_output.log` - Configuration deployment output

## 🎯 Design Philosophy

**Why Bash and not Python?**
- ✅ No external dependencies required
- ✅ Works in minimal WSL environments
- ✅ Native Linux commands only
- ✅ Easy to audit and modify
- ✅ Portable across all Linux systems
- ✅ No pip install or library management

## 📝 Upgrade Workflow Diagram
```
┌─────────────────────────┐
│ 1. Initial Setup        │
│ - Generate SSH key      │
│ - Deploy to switches    │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│ 2. Pre-Upgrade          │
│ - Backup configs        │
│ - Deploy changes        │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│ 3. Start HTTP Server    │
│ python3 -m http.server  │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│ 4. Run Upgrade          │
│ - Verify MD5            │
│ - Check connectivity    │
│ - Delete old images     │
│ - Copy new firmware     │
│ - Verify remote MD5     │
│ - Install & reload      │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│ 5. Wait 5-10 minutes    │
│ (Switches reloading)    │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│ 6. Verify Upgrade       │
│ - Check versions        │
│ - Generate report       │
└─────────────────────────┘
```

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly on lab environment
4. Submit pull request with detailed description

## 📄 License

MIT License - See LICENSE file for details

## ⚠️ Disclaimer

- **Test in lab environment first**
- **Always backup configurations before upgrade**
- **Verify change windows and maintenance schedules**
- **Have console access available**
- **Plan rollback procedure**

This tool is provided as-is. Always follow your organization's change management procedures.

## 👥 Author

Ozden Sicim - Network Engineer

## 🔗 Related Resources

- [Arista EOS Software Upgrade Guide](https://www.arista.com/en/um-eos/eos-upgrades-and-downgrades)
- [Arista EOS Manual](https://www.arista.com/en/um-eos)
- [SSH Key Authentication Guide](https://arista.my.site.com/AristaCommunity/s/article/ssh-login-without-password)

