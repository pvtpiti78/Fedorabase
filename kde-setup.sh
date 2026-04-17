#!/bin/bash
# =============================================================================
# kde-setup.sh — Fedora 44 KDE Plasma 6.6 Setup
# =============================================================================
# Voraussetzung: fedora-setup.sh wurde ausgeführt
# Umfang: Minimales KDE Plasma 6.6, Plasma Login Manager (kein SDDM)
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
    powerdevil

log "KDE Plasma 6.6 installiert"

# ── Plasma Login Manager (kein SDDM) ─────────────────────────────────────────
info "Plasma Login Manager aktivieren (F44 Standard für KDE)..."
dnf install -y plasma-login-manager 2>/dev/null || {
    # Fallback: SDDM falls plasma-login-manager noch nicht im Repo
    warn "plasma-login-manager nicht gefunden — SDDM als Fallback"
    dnf install -y sddm
    systemctl enable sddm
    systemctl set-default graphical.target
    log "SDDM aktiviert (Fallback)"
    return
}
systemctl enable plasmalogin 2>/dev/null || systemctl enable sddm
systemctl set-default graphical.target
log "Plasma Login Manager aktiviert"

# ── Wayland-Session als Standard ─────────────────────────────────────────────
info "KDE Wayland-Session als Standard setzen..."
# Plasma 6.6 hat Wayland als Default — kein X11 nötig
# KWIN Wayland + Nvidia
mkdir -p /etc/environment.d
cat >> /etc/environment.d/gaming.conf << 'EOF'

# KDE Plasma 6.6 Wayland
KWIN_DRM_USE_MODIFIERS=1
KWIN_FORCE_SW_CURSOR=0
EOF
log "KDE Wayland konfiguriert"

# ── Fastfetch KDE-Variante ────────────────────────────────────────────────────
info "Fastfetch für KDE konfigurieren..."
mkdir -p "$USER_HOME/.config/fastfetch"
cat > "$USER_HOME/.config/fastfetch/config.jsonc" << 'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "fedora",
    "padding": { "right": 2 }
  },
  "modules": [
    "title", "separator",
    { "type": "os",      "key": "OS      " },
    { "type": "kernel",  "key": "Kernel  " },
    { "type": "de",      "key": "DE      " },
    { "type": "wm",      "key": "WM      " },
    { "type": "shell",   "key": "Shell   " },
    { "type": "cpu",     "key": "CPU     " },
    { "type": "gpu",     "key": "GPU     " },
    { "type": "memory",  "key": "RAM     " },
    { "type": "disk",    "key": "Disk    " },
    { "type": "uptime",  "key": "Uptime  " }
  ]
}
EOF
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/fastfetch"
log "Fastfetch konfiguriert"

# ── Abschluss ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  KDE Plasma 6.6 Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}System neu starten:${NC}  ${BOLD}sudo reboot${NC}"
echo ""
