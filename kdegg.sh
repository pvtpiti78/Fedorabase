#!/bin/bash
# =============================================================================
# kde-setup.sh — Fedora 44 KDE Plasma 6.6 Setup (AMD Edition)
# =============================================================================
# Voraussetzung: fedora-setup.sh wurde ausgeführt
# Umfang: Minimales KDE Plasma 6.6, Plasma Login Manager, MTP-Support
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${CYAN}[→]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash kde-setup.sh"

CURRENT_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$CURRENT_USER")

clear
echo -e "${BOLD}${RED}"
echo "  ██╗  ██╗██████╗ ███████╗"
echo "  ██║ ██╔╝██╔══██╗██╔════╝"
echo "  █████╔╝ ██║  ██║█████╗  "
echo "  ██╔═██╗ ██║  ██║██╔══╝  "
echo "  ██║  ██╗██████╔╝███████╗"
echo "  ╚═╝  ╚═╝╚═════╝ ╚══════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Fedora 44 — KDE Plasma 6.6 Setup${NC}"
echo -e "  Minimal · Plasma Login Manager · Wayland (AMD)"
echo ""
echo -e "  ${YELLOW}ENTER zum Starten, CTRL+C zum Abbrechen.${NC}"
read -r

info "Writing fastfetch config..."
mkdir -p "$USER_HOME/.config/fastfetch"
cat > "$USER_HOME/.config/fastfetch/config.jsonc" <<'EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "builtin",
        "source": "debian"
    },
    "display": {
        "separator": "  "
    },
    "modules": [
        "title",
        "separator",
        {
            "type": "os",
            "key": "OS"
        },
        {
            "type": "kernel",
            "key": "Kernel"
        },
        {
            "type": "uptime",
            "key": "Uptime"
        },
        {
            "type": "packages",
            "key": "Packages"
        },
        "separator",
        {
            "type": "shell",
            "key": "Shell"
        },
        {
            "type": "terminal",
            "key": "Terminal"
        },
        {
            "type": "de",
            "key": "DE/WM"
        },
        "separator",
        {
            "type": "display",
            "key": "Resolution"
        },
        "separator",
        {
            "type": "cpu",
            "key": "CPU"
        },
        {
            "type": "gpu",
            "key": "GPU",
            "driverSpecific": true,
            "format": "{name} [{driver}]"
        },
        {
            "type": "memory",
            "key": "RAM"
        },
        {
            "type": "disk",
            "key": "Disk",
            "folders": "/"
        },
        "separator",
        {
            "type": "localip",
            "key": "Local IP"
        }
    ]
}
EOF
chown "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/fastfetch/config.jsonc"

# ── KDE Plasma 6.6 — minimale Pakete + MTP ───────────────────────────────────
info "KDE Plasma 6.6 (minimal) installieren..."
dnf install -y \
    plasma-desktop \
    plasma-workspace \
    plasma-nm \
    plasma-pa \
    plasma-systemsettings \
    kscreen \
    dolphin \
    kio-extras \
    kate \
    ark \
    xdg-desktop-portal-kde \
    polkit-kde \
    pam-kwallet \
    bluedevil \
    powerdevil

log "KDE Plasma 6.6 und kio-extras (MTP-Support) installiert"

# ── Plasma Login Manager ──────────────────────────────────────────────────────
info "Plasma Login Manager aktivieren (F44 Standard für KDE)..."
dnf install -y plasma-login-manager kcm-plasmalogin
systemctl enable --force plasmalogin.service
systemctl set-default graphical.target
log "Plasma Login Manager aktiviert"

# ── Abschluss ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  KDE Plasma 6.6 Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}System neu starten:${NC}  ${BOLD}sudo reboot${NC}"
echo ""
