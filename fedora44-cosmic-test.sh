#!/usr/bin/env bash
# ============================================================================
#  Fedora 44 — COSMIC 1.5.0 zum Testen dazuinstallieren
#  Laeuft PARALLEL zu GNOME (fedora44-gnome.sh) ueber GDM-Sessionwahl —
#  keine Neuinstallation noetig, einfach rueckbaubar.
#
#  Quelle: offizielle Fedora-Repos (seit F41), KEIN COPR — 1.5.0 ist der
#  aktuelle stabile Release-Zweig, Fedora zieht die Pakete regulaer per
#  dnf upgrade nach. Falls die Repo-Version noch hinterherhaengt, steht
#  unten der Bleeding-Edge-COPR-Fallback (ryanabx/cosmic-epoch) drin.
#
#  Aufruf: bash fedora44-cosmic-test.sh
# ============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC}   $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] && die "Nicht als root starten — als User mit sudo."
command -v gdm >/dev/null 2>&1 || command -v gdm3 >/dev/null 2>&1 || \
  rpm -q gdm >/dev/null 2>&1 || warn "GDM nicht gefunden — Sessionwahl beim Login braucht GDM (siehe fedora44-gnome.sh)."

# ============================================================================
# 1. COSMIC Desktop Environment (Gruppe, offizielle Fedora-Repos)
# ============================================================================
info "Installiere COSMIC 1.5.x aus den Fedora-Hauptrepos..."
sudo dnf install -y @cosmic-desktop-environment

# Version verifizieren — falls die Repo-Pakete hinter 1.5.0 liegen, Hinweis
# auf den Nightly-COPR geben, statt automatisch draufzuballern.
INSTALLED_VER=$(rpm -q --qf '%{VERSION}' cosmic-session 2>/dev/null || echo "unbekannt")
info "Installierte cosmic-session-Version: ${INSTALLED_VER}"
if [[ "$INSTALLED_VER" != "1.5"* ]]; then
  warn "Repo-Version ist noch nicht 1.5.x. Fuer Bleeding-Edge (weniger QA):"
  warn "  sudo dnf copr enable ryanabx/cosmic-epoch"
  warn "  sudo dnf install cosmic-desktop"
  warn "  (Migration zurueck auf stabil: dnf remove cosmic-desktop; dnf copr disable ryanabx/cosmic-epoch; dnf install @cosmic-desktop-environment)"
fi

# ============================================================================
# 2. Fedora-COSMIC-Branding (optional, Hintergruende/Theming passend zu F44)
# ============================================================================
info "Installiere COSMIC-Branding-Paket..."
sudo dnf install -y fedora-release-cosmic || warn "fedora-release-cosmic uebersprungen (optional)."

# ============================================================================
# 3. Sanity-Check: Wayland-Session-Datei vorhanden?
# ============================================================================
if ls /usr/share/wayland-sessions/ 2>/dev/null | grep -qi cosmic; then
  log "COSMIC-Session-Eintrag gefunden — taucht im GDM-Zahnrad-Menue auf."
else
  warn "Keine COSMIC-Session-Datei unter /usr/share/wayland-sessions gefunden — nach Reboot pruefen."
fi

echo
log "============================================="
log " Fertig. Naechste Schritte:"
log "   1. reboot"
log "   2. Auf dem GDM-Login-Screen: Username anklicken,"
log "      unten rechts das Zahnrad -> 'COSMIC' waehlen"
log "   3. Testen. Zurueck zu GNOME jederzeit ueber dasselbe Zahnrad."
log "   4. Zum Entfernen: sudo dnf group remove cosmic-desktop-environment"
log "============================================="
echo
info "Ressourcen:"
info "  Release Notes 1.5.0: https://github.com/pop-os/cosmic-epoch/releases"
info "  Fedora COSMIC SIG:   https://fedoraproject.org/wiki/SIGs/COSMIC"
info "  Upstream Repo:       https://github.com/pop-os/cosmic-epoch"
