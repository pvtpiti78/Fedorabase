#!/bin/bash
# =============================================================================
# cosmic-setup.sh — Fedora 44 COSMIC Desktop Setup
# =============================================================================
# Voraussetzung: fedora-setup.sh wurde ausgeführt
# Umfang: COSMIC Desktop, cosmic-greeter, kein Shop, kein Terminal
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

[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash cosmic-setup.sh"

CURRENT_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$CURRENT_USER")

clear
echo -e "${BOLD}${CYAN}"
echo "   ██████╗ ██████╗ ███████╗███╗   ███╗██╗ ██████╗"
echo "  ██╔════╝██╔═══██╗██╔════╝████╗ ████║██║██╔════╝"
echo "  ██║     ██║   ██║███████╗██╔████╔██║██║██║     "
echo "  ██║     ██║   ██║╚════██║██║╚██╔╝██║██║██║     "
echo "  ╚██████╗╚██████╔╝███████║██║ ╚═╝ ██║██║╚██████╗"
echo "   ╚═════╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝╚═╝ ╚═════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Fedora 44 — COSMIC Desktop Setup${NC}"
echo -e "  cosmic-greeter · Wayland · Nvidia"
echo ""
echo -e "  ${YELLOW}ENTER zum Starten, CTRL+C zum Abbrechen.${NC}"
read -r

# ── COSMIC Desktop installieren ───────────────────────────────────────────────
info "COSMIC Desktop installieren..."
dnf install -y @cosmic-desktop-environment || \
    dnf install -y cosmic-desktop
log "COSMIC installiert"

# ── Unerwünschte Pakete entfernen ─────────────────────────────────────────────
info "cosmic-store und cosmic-term entfernen..."
dnf remove -y cosmic-store cosmic-term 2>/dev/null || true
log "Unnötige Pakete entfernt"

# ── cosmic-greeter aktivieren ─────────────────────────────────────────────────
info "cosmic-greeter aktivieren..."
systemctl enable cosmic-greeter
systemctl set-default graphical.target

# GDM deaktivieren falls vorhanden
systemctl disable gdm 2>/dev/null || true
systemctl disable sddm 2>/dev/null || true
systemctl disable plasma-login-manager 2>/dev/null || true
log "cosmic-greeter aktiviert"

# ── Wayland + Nvidia für COSMIC ───────────────────────────────────────────────
info "COSMIC Wayland/Nvidia ENV konfigurieren..."
cat >> /etc/environment.d/nvidia.conf << 'EOF'

# COSMIC Wayland
COSMIC_DATA_CONTROL_ENABLED=1
EOF
log "COSMIC ENV konfiguriert"


# ── Abschluss ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  COSMIC Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}System neu starten:${NC}  ${BOLD}sudo reboot${NC}"
echo ""
echo -e "  ${YELLOW}Hinweis: COSMIC + Nvidia — bei Problemen${NC}"
echo -e "  ${YELLOW}cosmic-greeter Status prüfen:${NC}"
echo -e "  ${BOLD}systemctl status cosmic-greeter${NC}"
echo ""
