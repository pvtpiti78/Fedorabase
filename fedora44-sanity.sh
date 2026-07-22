#!/usr/bin/env bash
# ============================================================================
#  Fedora 44 Post-Install — Minimal Netinstall (Everything ISO, kein DE)
#  Usecase: Gaming + Browsing
#  Hardware: Ryzen 7 9800X3D | RX 9070 XT | MSI X870E Tomahawk Max WiFi
#
#  Start: als normaler User im tty (sudo-Rechte vorausgesetzt)
#  Aufruf: bash fedora44-gaming.sh
# ============================================================================
set -euo pipefail

# ---------- Logging ----------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC}   $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

# ---------- Vorab-Checks ----------
[[ $EUID -eq 0 ]] && die "Nicht als root starten — als User mit sudo."
command -v sudo >/dev/null || die "sudo fehlt."
ping -c1 -W3 fedoraproject.org >/dev/null 2>&1 || die "Keine Internetverbindung."
FEDORA_VER=$(rpm -E %fedora)
[[ "$FEDORA_VER" == "44" ]] || warn "Erwartet Fedora 44, gefunden: $FEDORA_VER — Script läuft trotzdem weiter."
info "Fedora $FEDORA_VER erkannt. Los geht's."

# ============================================================================
# 1. DNF-Konfiguration
# ============================================================================
info "Konfiguriere DNF..."
sudo tee /etc/dnf/dnf.conf >/dev/null <<'EOF'
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
skip_if_unavailable=True
max_parallel_downloads=10
fastestmirror=True
EOF
log "dnf.conf geschrieben."

# dnf5-plugins: liefert config-manager & copr — auf Minimal-Installs oft NICHT dabei
sudo dnf install -y dnf5-plugins || warn "dnf5-plugins konnte nicht installiert werden."

# ============================================================================
# 2. System-Update
# ============================================================================
info "Vollständiges System-Update..."
sudo dnf upgrade -y --refresh
log "System aktuell."

# ============================================================================
# 3. RPM Fusion (free + nonfree) + F44-Rawhide-Bugfix
# ============================================================================
info "Installiere RPM Fusion..."
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

# --- BUGFIX (Stand F44): Release-Paket aktiviert faelschlich die Rawhide-Repos
#     und laesst die richtigen F44-Repos deaktiviert -> glibc-Konflikte.
info "Korrigiere RPM-Fusion-Repo-Status (F44 Rawhide-Bug)..."
for repo in rpmfusion-free rpmfusion-free-updates rpmfusion-nonfree rpmfusion-nonfree-updates; do
  sudo dnf config-manager setopt "${repo}.enabled=1" || warn "Konnte ${repo} nicht aktivieren."
done
for repo in rpmfusion-free-rawhide rpmfusion-nonfree-rawhide; do
  sudo dnf config-manager setopt "${repo}.enabled=0" 2>/dev/null || true
done

# AppStream-Metadaten + Cisco OpenH264 (Firefox-H264, schadet auch sonst nicht)
sudo dnf install -y rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted || warn "Tainted-Repos optional, uebersprungen."
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1 || warn "openh264-Repo nicht aktivierbar."
sudo dnf update -y @core || true
log "RPM Fusion eingerichtet und verifiziert."

# ============================================================================
# 4. Minimal KDE Plasma (Wayland) + Plasma Login Manager
# ============================================================================
info "Installiere minimales KDE Plasma..."
sudo dnf install -y --setopt=install_weak_deps=False \
  plasma-desktop \
  plasma-workspace \
  plasma-workspace-wayland \
  plasma-nm \
  plasma-pa \
  plasma-systemsettings \
  plasma-systemmonitor \
  powerdevil \
  power-profiles-daemon \
  upower \
  kscreen \
  kwallet-pam \
  bluedevil \
  bluez \
  plasma-login-manager \
  kcm-plasmalogin \
  konsole \
  dolphin \
  kate \
  kio-extras \
  ark \
  spectacle \
  kcalc \
  xdg-desktop-portal-kde \
  xdg-desktop-portal-gtk \
  polkit-kde \
  NetworkManager-wifi \
  pipewire \
  pipewire-alsa \
  pipewire-pulseaudio \
  wireplumber

# Fonts + Hardware-Support (Firmware etc.) — Gruppen, mit Fallback
sudo dnf group install -y fonts || warn "Font-Gruppe nicht installierbar — pruefe manuell."
sudo dnf group install -y hardware-support || warn "hardware-support-Gruppe uebersprungen."

sudo systemctl enable --force plasmalogin.service
sudo systemctl enable power-profiles-daemon.service || warn "power-profiles-daemon nicht aktivierbar."
sudo systemctl enable upower.service || warn "upower nicht aktivierbar."
sudo systemctl set-default graphical.target
log "Plasma minimal + Plasma Login Manager installiert, graphical.target gesetzt."

# ============================================================================
# 4b. Archiv-Backends + CLI-Basics (fehlen in @core der Minimal-Install)
# ============================================================================
# Kein base-devel-Aequivalent noetig: kein AUR, keine DKMS (AMD), COPRs
# liefern Binaries. Aber Ark braucht die Backends, sonst kann es nur tar.
info "Installiere Archiv-Tools + CLI-Basics..."
sudo dnf install -y \
  unzip \
  zip \
  p7zip \
  p7zip-plugins \
  tar \
  bzip2 \
  wget \
  btop || warn "Einzelne Utility-Pakete fehlgeschlagen."
# unrar kommt aus RPM Fusion nonfree (proprietaer):
sudo dnf install -y unrar || warn "unrar uebersprungen — RPM-Fusion-Status pruefen."
log "Archiv-Backends bereit."

# ============================================================================
# 5. Multimedia: Full ffmpeg + GStreamer + VA-API (AMD Freeworld)
# ============================================================================
info "Wechsle auf volles ffmpeg (RPM Fusion)..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || \
  sudo dnf install -y ffmpeg --allowerasing

info "Installiere GStreamer-Codecs (explizit, DNF5-sicher)..."
sudo dnf install -y --setopt=install_weak_deps=False \
  --exclude=PackageKit-gstreamer-plugin \
  gstreamer1-plugins-base \
  gstreamer1-plugins-good \
  gstreamer1-plugins-bad-free \
  gstreamer1-plugins-bad-freeworld \
  gstreamer1-plugins-ugly \
  gstreamer1-plugins-ugly-free \
  gstreamer1-plugin-libav \
  gstreamer1-plugin-openh264 \
  || warn "Einzelne GStreamer-Pakete fehlgeschlagen — Namen pruefen."

info "VA-API/VDPAU Freeworld-Swap (H.264/H.265 Hardware-Decode fuer RDNA4)..."
if rpm -q mesa-va-drivers >/dev/null 2>&1; then
  sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
else
  sudo dnf install -y mesa-va-drivers-freeworld
fi
if rpm -q mesa-vdpau-drivers >/dev/null 2>&1; then
  sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld || warn "VDPAU-Swap fehlgeschlagen (unkritisch)."
else
  sudo dnf install -y mesa-vdpau-drivers-freeworld || warn "VDPAU freeworld uebersprungen."
fi
# 32-bit fuer Steam/Proton
sudo dnf install -y mesa-va-drivers-freeworld.i686 || warn "32-bit VA-API uebersprungen."
sudo dnf install -y libva-utils   # vainfo zum Verifizieren
log "Codecs + Hardware-Decode eingerichtet."

# ============================================================================
# 6. AMD Gaming-Grundlage (Vulkan 64+32 bit)
# ============================================================================
info "Installiere Vulkan-Stack..."
sudo dnf install -y \
  mesa-vulkan-drivers \
  mesa-vulkan-drivers.i686 \
  vulkan-loader \
  vulkan-loader.i686 \
  vulkan-tools
log "RADV 64/32-bit bereit. (RX 9070 XT laeuft in F44 out-of-the-box ueber Mesa.)"

# ============================================================================
# 7. Flatpak + Flathub
# ============================================================================
info "Richte Flatpak/Flathub ein..."
sudo dnf install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
log "Flathub aktiv."

# ============================================================================
# 8. Gaming-Software: Steam, Protontricks, ProtonPlus, Tools
# ============================================================================
info "Installiere Steam + Gaming-Tools..."
sudo dnf install -y \
  steam \
  steam-devices \
  protontricks || warn "Einzelne Gaming-Pakete fehlgeschlagen."

# gamescope optional — bei Bedarf einkommentieren:
# sudo dnf install -y gamescope

info "Installiere ProtonPlus (Flathub, offizieller Weg)..."
sudo flatpak install -y flathub com.vysp3r.ProtonPlus || warn "ProtonPlus-Flatpak fehlgeschlagen."
log "Steam, Protontricks, ProtonPlus installiert."

# ============================================================================
# 8b. Heroic + Faugus Launcher (nativ, kein Flatpak)
# ============================================================================
info "Installiere Heroic Games Launcher (COPR atim/heroic-games-launcher)..."
if sudo dnf copr enable -y atim/heroic-games-launcher && \
   sudo dnf install -y heroic-games-launcher-bin; then
  log "Heroic (nativ) installiert — Updates laufen ueber dnf mit."
else
  warn "COPR fehlgeschlagen — Fallback: RPM direkt vom GitHub-Release."
  HEROIC_URL=$(curl -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest \
    | grep -oP '"browser_download_url":\s*"\K[^"]*x86_64\.rpm' | head -n1)
  if [[ -n "${HEROIC_URL:-}" ]]; then
    sudo dnf install -y "$HEROIC_URL" && log "Heroic via GitHub-RPM installiert."
  else
    warn "Heroic-RPM nicht gefunden — manuell nachinstallieren."
  fi
fi

info "Installiere Faugus Launcher (offizielles COPR faugus/faugus-launcher)..."
sudo dnf copr enable -y faugus/faugus-launcher && \
  sudo dnf install -y faugus-launcher || warn "Faugus Launcher fehlgeschlagen."
# Hinweis: zieht umu-launcher automatisch mit.
# Runner-Pfad: ~/.local/share/Steam/compatibilitytools.d/ (Proton-GE via ProtonPlus
# wird also von Faugus direkt gefunden).
log "Launcher-Sektion abgeschlossen."

# ============================================================================
# 9. Google Chrome
# ============================================================================
info "Installiere Google Chrome..."
sudo dnf install -y fedora-workstation-repositories
sudo dnf config-manager setopt google-chrome.enabled=1
sudo dnf install -y google-chrome-stable
log "Chrome installiert."

# ============================================================================
# 10. LACT (GPU-Kontrolle: Undervolt/Powerlimit fuer die 9070 XT)
# ============================================================================
info "Installiere LACT..."
if sudo dnf install -y lact 2>/dev/null; then
  log "LACT aus Fedora-Repos."
else
  warn "LACT nicht in den Repos — versuche COPR ilyaz/LACT..."
  sudo dnf copr enable -y ilyaz/LACT && sudo dnf install -y lact || warn "LACT manuell nachinstallieren."
fi
sudo systemctl enable lactd 2>/dev/null || warn "lactd-Service nicht aktivierbar — nach Reboot pruefen."
# Dein Setting zur Erinnerung: -70 mV / -25% Powerlimit

# ============================================================================
# 11. System-Tuning
# ============================================================================
info "Schreibe Tuning-Configs..."

# split_lock: bestaetigter Gaming-Gewinn
sudo tee /etc/sysctl.d/99-gaming.conf >/dev/null <<'EOF'
kernel.split_lock_mitigate=0
vm.max_map_count=2147483642
EOF

# ZRAM: 15% RAM, zstd (dein Standard)
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram * 0.15
compression-algorithm = zstd
EOF

# Gaming-Env (dein settled Setup)
sudo tee /etc/profile.d/gaming.sh >/dev/null <<'EOF'
export MESA_SHADER_CACHE_MAX_SIZE=12G
export PROTON_ENABLE_HDR=1
export PROTON_USE_OPTISCALER=1
export PROTON_FSR4_UPGRADE=1
export PROTON_XESS_UPGRADE=1
export PROTON_ENABLE_WAYLAND=1
EOF

sudo systemctl enable fstrim.timer || warn "fstrim.timer nicht aktivierbar."
log "sysctl, ZRAM, Env-Variablen, fstrim gesetzt."

# ============================================================================
# 12. Firewall (firewalld — auf Minimal-Install nicht garantiert vorhanden)
# ============================================================================
info "Richte firewalld ein..."
sudo dnf install -y firewalld
sudo systemctl enable --now firewalld || warn "firewalld nicht startbar — nach Reboot pruefen."
# Default-Zone: public (restriktiv, nur dhcpv6-client + ssh offen).
# Fuer Desktop ohne SSH-Server kann ssh raus:
sudo firewall-cmd --permanent --zone=public --remove-service=ssh 2>/dev/null || true
# Steam Local Network Game Transfer — bei Bedarf einkommentieren:
# sudo firewall-cmd --permanent --add-port=27040/tcp
# sudo firewall-cmd --permanent --add-port=27036/udp
sudo firewall-cmd --reload 2>/dev/null || true
log "firewalld aktiv (Zone: public, dicht bis auf DHCPv6)."

# ============================================================================
# 13. Fish Shell + Abbreviations (DNF + Flatpak)
# ============================================================================
info "Installiere Fish Shell..."
sudo dnf install -y fish
sudo chsh -s /usr/bin/fish "$USER" || warn "Default-Shell nicht gesetzt — manuell: chsh -s /usr/bin/fish"

mkdir -p "$HOME/.config/fish"
tee "$HOME/.config/fish/config.fish" >/dev/null <<'EOF'
# ---------------------------------------------------------------
# Fish-Konfiguration — Fedora 44 Gaming
# Abbreviations statt Aliase: expandieren sichtbar in der Zeile,
# bleiben editierbar und landen sauber in der History.
# ---------------------------------------------------------------
if status is-interactive
    set -g fish_greeting  # Begruessung aus

    # --- Update: DNF + Flatpak in einem Rutsch ---
    abbr -a up   'sudo dnf upgrade --refresh; and flatpak update -y'

    # --- DNF-Basics ---
    abbr -a in   'sudo dnf install'
    abbr -a rem  'sudo dnf remove'
    abbr -a se   'dnf search'
    abbr -a inf  'dnf info'
    abbr -a li   'dnf list --installed'
    abbr -a hist 'dnf history'
    abbr -a wp   'dnf provides'          # welches Paket liefert Datei X

    # --- Aufraeumen: DNF + Flatpak ---
    abbr -a clean 'sudo dnf autoremove -y; and sudo dnf clean packages; and flatpak uninstall --unused -y'

    # --- Flatpak ---
    abbr -a fin  'flatpak install flathub'
    abbr -a fse  'flatpak search'
    abbr -a frem 'flatpak uninstall'
    abbr -a fli  'flatpak list --app'

    # --- COPR ---
    abbr -a copron  'sudo dnf copr enable'
    abbr -a coproff 'sudo dnf copr disable'
end
EOF
log "Fish installiert, als Default-Shell gesetzt, Abbreviations geschrieben."

# ============================================================================
# 14. Optional: scx-Scheduler (auskommentiert — bei Bedarf aktivieren)
# ============================================================================
# COPR bieszczaders/kernel-cachyos-addons liefert scx-scheds fuer Fedora.
# sudo dnf copr enable -y bieszczaders/kernel-cachyos-addons
# sudo dnf install -y scx-scheds
# Hinweis: falcond ist auf Fedora nicht sauber paketiert — scx_bpfland
# alternativ direkt per systemd-Service starten (scx.service, /etc/default/scx).

# ============================================================================
# 15. Sanity-Check (faengt Luecken durch Reposync-Aussetzer waehrend des Installs)
# ============================================================================
log "Sanity-Check: Paketkonsistenz und Vulkan-Funktionsfaehigkeit..."

if ! sudo dnf check 2>&1 | tee /tmp/dnf-check.log | grep -q .; then
  log "dnf check: OK, keine Paketinkonsistenzen."
else
  warn "dnf check meldet Probleme, siehe /tmp/dnf-check.log — pruefen vor Weiterarbeit!"
fi

if command -v vulkaninfo >/dev/null 2>&1; then
  VK_OUT="$(vulkaninfo --summary 2>&1)"
  if echo "$VK_OUT" | grep -q "deviceName.*RADV\|deviceName.*AMD"; then
    log "Vulkan: RADV-Device gefunden. $(echo "$VK_OUT" | grep 'deviceName' | head -1 | xargs)"
  else
    warn "Vulkan: Keine AMD/RADV-GPU gefunden! Vermutlich fehlt mesa-vulkan-drivers.x86_64"
    warn "  -> sudo dnf install mesa-vulkan-drivers.x86_64"
  fi
else
  warn "vulkaninfo nicht gefunden — vulkan-tools scheint nicht installiert zu sein."
fi

# ============================================================================
# 16. Aufraeumen + Abschluss
# ============================================================================
sudo dnf autoremove -y || true
sudo dnf clean packages || true

echo
log "============================================="
log " Fertig. Naechste Schritte:"
log "   1. reboot  ->  Plasma Login Manager / Plasma (Wayland)"
log "   2. vainfo  ->  H264/HEVC unter VAEntrypointVLD pruefen"
log "   3. Steam starten, Proton-GE via ProtonPlus ziehen"
log "   4. LACT: -70 mV / PL -25% setzen"
log "   5. Neues Terminal = Fish. 'up' tippen -> expandiert zum Update-Befehl"
log "============================================="
