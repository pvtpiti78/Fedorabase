#!/bin/bash
# =============================================================================
# kde-setup.sh — Fedora 44 KDE Plasma 6.6 Setup
# =============================================================================
# Voraussetzung: fedora-setup.sh wurde ausgeführt
# Umfang: Minimales KDE Plasma 6.6, Plasma Login Manager (kein SDDM),
#         kio-extras (MTP/SMB/SFTP), KWallet, GTK-Theming-Konsistenz
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
echo -e "${BOLD}${CYAN}"
echo "  ██╗  ██╗██████╗ ███████╗"
echo "  ██║ ██╔╝██╔══██╗██╔════╝"
echo "  █████╔╝ ██║  ██║█████╗  "
echo "  ██╔═██╗ ██║  ██║██╔══╝  "
echo "  ██║  ██╗██████╔╝███████╗"
echo "  ╚═╝  ╚═╝╚═════╝ ╚══════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Fedora 44 — KDE Plasma 6.6 Setup${NC}"
echo -e "  Minimal · Plasma Login Manager · Wayland"
echo ""
echo -e "  ${YELLOW}ENTER zum Starten, CTRL+C zum Abbrechen.${NC}"
read -r

# ── KDE Plasma 6.6 — minimale Pakete ─────────────────────────────────────────
info "KDE Plasma 6.6 (minimal) installieren..."
dnf install -y \
    plasma-desktop \
    plasma-workspace \
    plasma-nm \
    plasma-pa \
    plasma-systemsettings \
    kscreen \
    dolphin \
    kate \
    ark \
    xdg-desktop-portal-kde \
    polkit-kde \
    bluedevil \
    bluez \
    powerdevil

log "KDE Plasma 6.6 installiert"

# ── kio-extras (Netzwerk-/Protokoll-Handler für Dolphin) ─────────────────────
info "kio-extras installieren (SMB, SFTP, MTP, Archive-Browsing etc.)..."
dnf install -y kio-extras
log "kio-extras installiert"

# ── KWallet (Passwort-Speicher für Netzwerk/WLAN/Browser-Integration) ────────
info "KWallet installieren..."
dnf install -y kwalletmanager5 kwallet-pam || dnf install -y kwalletmanager kwallet-pam
log "KWallet installiert"

# ── GTK-Theming-Konsistenz (Firefox & Co. passend zu Breeze) ─────────────────
info "GTK-Theming-Konsistenz installieren..."
dnf install -y kde-gtk-config breeze-gtk
log "GTK-Theming installiert"

# ── Plasma Login Manager ──────────────────────────────────────────────────────
info "Plasma Login Manager aktivieren (F44 Standard für KDE)..."
dnf install -y plasma-login-manager kcm-plasmalogin
systemctl enable --force plasmalogin.service
systemctl set-default graphical.target
log "Plasma Login Manager aktiviert"

# ── Wayland-Session als Standard ─────────────────────────────────────────────
info "KDE Wayland-Session als Standard setzen..."
# Plasma 6.6 hat Wayland als Default — kein X11 nötig
mkdir -p /etc/environment.d
cat >> /etc/environment.d/gaming.conf << 'EOF'

# KDE Plasma 6.6 Wayland
KWIN_DRM_USE_MODIFIERS=1
EOF
log "KDE Wayland konfiguriert"


# ── Abschluss ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  KDE Plasma 6.6 Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}System neu starten:${NC}  ${BOLD}sudo reboot${NC}"
echo ""
