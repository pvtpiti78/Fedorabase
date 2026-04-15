#!/bin/bash
# =============================================================================
# install-de.sh — Fedora 44 Desktop Environment Selector
# =============================================================================
# Interaktiver Installer: wählt zwischen GNOME 50 und KDE Plasma 6.6
# Voraussetzung: fedora-setup.sh wurde ausgeführt
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${CYAN}[→]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash install-de.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Prüfen ob fedora-setup.sh gelaufen ist ────────────────────────────────────
if ! command -v fish &>/dev/null; then
    warn "Fish nicht gefunden — fedora-setup.sh wurde möglicherweise nicht ausgeführt."
    echo -e "  ${YELLOW}Zuerst ausführen:${NC} ${BOLD}sudo bash fedora-setup.sh${NC}"
    echo ""
    read -rp "Trotzdem fortfahren? [j/N] " CONFIRM
    [[ "${CONFIRM,,}" != "j" ]] && exit 0
fi

clear
echo -e "${BOLD}${CYAN}"
echo "  ███████╗███████╗██████╗  ██████╗ ██████╗  █████╗ "
echo "  ██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗"
echo "  █████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║"
echo "  ██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║"
echo "  ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║"
echo "  ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "  ${BOLD}Fedora 44 — Desktop Environment Selector${NC}"
echo ""
echo -e "  ┌─────────────────────────────────────────────────┐"
echo -e "  │                                                 │"
echo -e "  │  ${BOLD}[1]${NC}  🟣  ${BOLD}GNOME 50${NC}                              │"
echo -e "  │       Wayland-only · GDM · Adwaita              │"
echo -e "  │       + Nvidia Cursor-Workaround (präventiv)    │"
echo -e "  │                                                 │"
echo -e "  │  ${BOLD}[2]${NC}  🔵  ${BOLD}KDE Plasma 6.6${NC}                        │"
echo -e "  │       Wayland · Plasma Login Manager            │"
echo -e "  │       Minimal (14 Pakete)                       │"
echo -e "  │                                                 │"
echo -e "  │  ${BOLD}[q]${NC}  Abbrechen                                  │"
echo -e "  │                                                 │"
echo -e "  └─────────────────────────────────────────────────┘"
echo ""

while true; do
    read -rp "  Auswahl [1/2/q]: " CHOICE
    case "$CHOICE" in
        1)
            echo ""
            info "GNOME 50 gewählt"
            echo ""
            if [[ -f "$SCRIPT_DIR/gnome-setup.sh" ]]; then
                bash "$SCRIPT_DIR/gnome-setup.sh"
            else
                err "gnome-setup.sh nicht gefunden in $SCRIPT_DIR"
            fi
            break
            ;;
        2)
            echo ""
            info "KDE Plasma 6.6 gewählt"
            echo ""
            if [[ -f "$SCRIPT_DIR/kde-setup.sh" ]]; then
                bash "$SCRIPT_DIR/kde-setup.sh"
            else
                err "kde-setup.sh nicht gefunden in $SCRIPT_DIR"
            fi
            break
            ;;
        q|Q)
            echo ""
            info "Abgebrochen."
            exit 0
            ;;
        *)
            warn "Ungültige Eingabe. Bitte 1, 2 oder q eingeben."
            ;;
    esac
done
