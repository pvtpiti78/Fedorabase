#!/bin/bash
# =============================================================================
# gnome-setup.sh — Fedora 44 GNOME 50 Setup
# =============================================================================
# Voraussetzung: fedora-setup.sh wurde ausgeführt
# Umfang: Minimales GNOME 50, GDM, Wayland-only
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

[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash gnome-setup.sh"

CURRENT_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$CURRENT_USER")

clear
echo -e "${BOLD}${CYAN}"
echo "  ██████╗ ███╗   ██╗ ██████╗ ███╗   ███╗███████╗"
echo "  ██╔════╝████╗  ██║██╔═══██╗████╗ ████║██╔════╝"
echo "  ██║  ███╗██╔██╗ ██║██║   ██║██╔████╔██║█████╗  "
echo "  ██║   ██║██║╚██╗██║██║   ██║██║╚██╔╝██║██╔══╝  "
echo "  ╚██████╔╝██║ ╚████║╚██████╔╝██║ ╚═╝ ██║███████╗"
echo "   ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Fedora 44 — GNOME 50 Setup${NC}"
echo -e "  Minimal · GDM · Wayland-only"
echo ""
warn "Hinweis: GNOME 50 + Nvidia 595 — bekannter Mutter/Cursor-Bug möglich."
warn "Workaround falls nötig: MUTTER_DEBUG_DISABLE_HW_CURSORS=1 in gaming.conf"
echo ""
echo -e "  ${YELLOW}ENTER zum Starten, CTRL+C zum Abbrechen.${NC}"
read -r

# ── GNOME 50 — minimale Pakete ────────────────────────────────────────────────
info "GNOME 50 (minimal) installieren..."
dnf install -y \
    gnome-shell \
    gnome-session \
    gnome-control-center \
    gnome-text-editor \
    gnome-disk-utility \
    gnome-tweaks \
    gnome-extensions-app \
    nautilus \
    gdm \
    xdg-desktop-portal-gnome \
    gvfs \
    gvfs-mtp \
    gvfs-smb \
    adwaita-icon-theme \
    adwaita-cursor-theme \
    gnome-backgrounds

log "GNOME 50 installiert"

# ── GDM aktivieren ────────────────────────────────────────────────────────────
info "GDM als Display Manager aktivieren..."
systemctl enable gdm
systemctl set-default graphical.target
log "GDM aktiviert"

# ── Wayland erzwingen (kein X11 Fallback in GNOME 50) ────────────────────────
info "Wayland-only sicherstellen..."
# GNOME 50 hat X11 komplett entfernt — keine weitere Konfiguration nötig
# Nvidia modeset bereits in fedora-setup.sh gesetzt
mkdir -p /etc/udev/rules.d
# GDM Wayland für Nvidia explizit erlauben
sed -i 's/#WaylandEnable=false/WaylandEnable=true/' /etc/gdm/custom.conf 2>/dev/null || true
log "Wayland konfiguriert"

# ── Nvidia Cursor-Bug Workaround (präventiv, auskommentiert) ──────────────────
info "Nvidia Cursor-Workaround vorbereiten (deaktiviert)..."
cat >> /etc/environment.d/gaming.conf << 'EOF'

# GNOME 50 + Nvidia: Cursor/Mouse-Bug Workaround
# Bei Problemen (Cursor verschwindet, freezes) diese Zeile aktivieren:
# MUTTER_DEBUG_DISABLE_HW_CURSORS=1
EOF
log "Cursor-Workaround dokumentiert (inaktiv)"

# ── GNOME Shell Extensions ───────────────────────────────────────────────────
info "Extensions installieren..."

# AppIndicator + Dash to Panel — DNF
dnf install -y \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-dash-to-panel 2>/dev/null || \
    warn "Dash to Panel nicht im Repo — nach GNOME-Start via gnome-extensions-app installieren"

# Resources (System Monitor)
dnf copr enable -y atim/resources
dnf install -y resources

log "Extensions installiert"


# ── Fastfetch GNOME-Variante ──────────────────────────────────────────────────
info "Fastfetch für GNOME konfigurieren..."
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
echo -e "${BOLD}${GREEN}  GNOME 50 Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}System neu starten:${NC}  ${BOLD}sudo reboot${NC}"
echo ""
echo -e "  ${YELLOW}Falls Cursor-Bug auftritt:${NC}"
echo -e "  /etc/environment.d/gaming.conf → MUTTER_DEBUG_DISABLE_HW_CURSORS=1 einkommentieren"
echo ""
