#!/usr/bin/env bash
# ============================================================================
#  Fedora 45 Beta Post-Install — Minimal Netinstall (Everything ISO, kein DE)
#  Usecase: Gaming + Browsing
#  DE: KDE Plasma (Wayland), minimal — Plasma Login Manager, Dolphin,
#      MTP/AFC/SMB fuer Dolphin, CUPS/Avahi-Drucken
#  Hardware: Ryzen 7 9800X3D | RX 9070 XT | MSI X870E Tomahawk Max WiFi
#
#  Start: als normaler User im tty (sudo-Rechte vorausgesetzt)
#  Aufruf: bash fedora45-beta-kde.sh
#
#  BETA-HINWEIS: RPM Fusion legt die "updates-released-45"-Metadaten
#  erst mit dem finalen Fedora-45-Release an. Bis dahin faengt Abschnitt 3a
#  das automatisch ab (Fallback auf Vorversion), damit dnf nicht mit
#  404-Spam auf den Metalinks haengen bleibt.
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
[[ "$FEDORA_VER" == "45" ]] || warn "Erwartet Fedora 45, gefunden: $FEDORA_VER — Script läuft trotzdem weiter."
info "Fedora $FEDORA_VER erkannt. Los geht's."

# ============================================================================
# 0. DNF-Metadaten frisch ziehen
# ============================================================================
info "Bereinige DNF-Metadaten-Cache und baue neu..."
sudo dnf clean metadata || true
sudo dnf makecache || warn "makecache fehlgeschlagen — Mirrors evtl. traege, Script laeuft trotzdem weiter."

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

# Locales — Minimal-Netinstall generiert kein en_US/de_DE, sonst pv-locale-gen-
# Fehler in der Steam Runtime beim ersten Proton-Start ("character map file
# 'UTF-8' nicht found").
info "Installiere Locales (en_US, de_DE)..."
sudo dnf install -y glibc-langpack-en glibc-langpack-de || warn "Locale-Pakete uebersprungen."

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

# --- BUGFIX: Verhindert versehentlich aktive Rawhide-Repos
info "Korrigiere RPM-Fusion-Repo-Status..."
for repo in rpmfusion-free rpmfusion-free-updates rpmfusion-nonfree rpmfusion-nonfree-updates; do
  sudo dnf config-manager setopt "${repo}.enabled=1" || warn "Konnte ${repo} nicht aktivieren."
done
for repo in rpmfusion-free-rawhide rpmfusion-nonfree-rawhide; do
  sudo dnf config-manager setopt "${repo}.enabled=0" 2>/dev/null || true
done

# AppStream-Metadaten + Cisco OpenH264
sudo dnf install -y rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted || warn "Tainted-Repos optional, uebersprungen."
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1 || warn "openh264-Repo nicht aktivierbar."
sudo dnf update -y @core || true
log "RPM Fusion eingerichtet und verifiziert."

# ============================================================================
# 3a. RPM-Fusion-Updates-Metadaten-Fallback (Beta-only)
# ============================================================================
info "Pruefe RPM-Fusion-Updates-Metadaten fuer Fedora ${FEDORA_VER}..."
PREV_VER=$((FEDORA_VER - 1))
for variant in free nonfree; do
  repo="rpmfusion-${variant}-updates"
  url="https://mirrors.rpmfusion.org/metalink?repo=${variant}-fedora-updates-released-${FEDORA_VER}&arch=x86_64"
  if curl -sf -o /dev/null "$url"; then
    log "${repo}: F${FEDORA_VER}-Metadaten bereits verfuegbar, kein Fallback noetig."
  else
    warn "${repo}: Noch keine F${FEDORA_VER}-Updates-Metadaten (Beta) — Fallback auf F${PREV_VER}."
    sudo dnf config-manager setopt "${repo}.metalink=" || true
    sudo dnf config-manager setopt "${repo}.baseurl=https://download1.rpmfusion.org/${variant}/fedora/updates/${PREV_VER}/x86_64/" || true
  fi
done
log "RPM-Fusion-Updates-Fallback geprueft."

# ============================================================================
# 3b. Terra (rolling-release Community-Repo, Fyra Labs)
# ============================================================================
info "Richte Terra-Repository ein..."
TERRA_AVAILABLE=0

# 1. terra-release direkt per RPM installieren (umgeht DNF5-repofrompath-Bugs)
TERRA_RPM_URL="https://repos.fyralabs.com/terra${FEDORA_VER}/terra-release.noarch.rpm"
if ! curl -sf -I "$TERRA_RPM_URL" >/dev/null 2>&1; then
  warn "Terra F${FEDORA_VER} RPM nicht erreichbar, versuche F${PREV_VER}-Release..."
  TERRA_RPM_URL="https://repos.fyralabs.com/terra${PREV_VER}/terra-release.noarch.rpm"
fi

if sudo dnf install -y --nogpgcheck "$TERRA_RPM_URL"; then
  # 2. Checksum-Fix: Metalink deaktivieren und direkt auf Baseurl pinnen.
  # Verhindert Desync-Fehler von tetsudou-Mirrors während der Beta.
  info "Konfiguriere Terra-Repo-Pfade (Bypass fuer Metalink-Sync-Fehler)..."
  sudo dnf config-manager setopt terra.metalink="" 2>/dev/null || true
  
  if curl -sf -o /dev/null "https://repos.fyralabs.com/terra${FEDORA_VER}/repodata/repomd.xml"; then
    sudo dnf config-manager setopt "terra.baseurl=https://repos.fyralabs.com/terra${FEDORA_VER}" || true
    log "Terra F${FEDORA_VER} via Direktanbindung aktiv."
  else
    warn "Terra F${FEDORA_VER} noch leer/unvollständig — Fallback auf F${PREV_VER} Baseurl."
    sudo dnf config-manager setopt "terra.baseurl=https://repos.fyralabs.com/terra${PREV_VER}" || true
  fi

  # Metadaten-Cache für Terra frisch erzwingen
  sudo dnf clean metadata --repo=terra || true
  if sudo dnf makecache --repo=terra; then
    TERRA_AVAILABLE=1
    log "Terra erfolgreich synchronisiert."
  else
    warn "Terra makecache fehlgeschlagen — wird vorerst deaktiviert."
    sudo dnf config-manager setopt terra.enabled=0 || true
  fi
else
  warn "terra-release konnte nicht installiert werden. Fallbacks greifen automatisch."
fi

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

# Fonts + Hardware-Support
sudo dnf group install -y fonts || warn "Font-Gruppe nicht installierbar — pruefe manuell."
sudo dnf group install -y hardware-support || warn "hardware-support-Gruppe uebersprungen."

sudo systemctl enable --force plasmalogin.service
sudo systemctl enable power-profiles-daemon.service || warn "power-profiles-daemon nicht aktivierbar."
sudo systemctl enable upower.service || warn "upower nicht aktivierbar."
sudo systemctl set-default graphical.target
log "Plasma minimal + Plasma Login Manager installiert, graphical.target gesetzt."

# ============================================================================
# 4b. Archiv-Backends + CLI-Basics
# ============================================================================
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
sudo dnf install -y unrar || warn "unrar uebersprungen — RPM-Fusion-Status pruefen."
log "Archiv-Backends bereit."

# ============================================================================
# 4c. MTP/Netzwerk-Freigaben fuer Dolphin (kio-extras Backends)
# ============================================================================
info "Installiere MTP/AFC/SMB-Laufzeitbibliotheken fuer kio-extras..."
sudo dnf install -y \
  libmtp \
  libimobiledevice \
  samba-client-libs || warn "Einzelne MTP/Netzwerk-Bibliotheken fehlgeschlagen."
log "mtp:/, afc:/ und smb:/ in Dolphin einsatzbereit."

# ============================================================================
# 4d. Drucken (CUPS + Netzwerk-Discovery fuer Brother etc.)
# ============================================================================
info "Installiere CUPS + Netzwerk-Druckerkennung..."
sudo dnf install -y \
  cups \
  cups-filters \
  cups-pk-helper \
  kde-print-manager \
  avahi \
  nss-mdns \
  system-config-printer || warn "Einzelne Druck-Pakete fehlgeschlagen."

sudo systemctl enable --now cups.socket || warn "cups.socket nicht aktivierbar."
sudo systemctl enable --now avahi-daemon.service || warn "avahi-daemon nicht aktivierbar."
log "CUPS + Avahi aktiv."

# ============================================================================
# 5. Multimedia: Full ffmpeg + GStreamer + VA-API (AMD Freeworld)
# ============================================================================
info "Wechsle auf volles ffmpeg (RPM Fusion)..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || \
  sudo dnf install -y ffmpeg --allowerasing

info "Installiere GStreamer-Codecs..."
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
  || warn "Einzelne GStreamer-Pakete fehlgeschlagen."

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
sudo dnf install -y mesa-va-drivers-freeworld.i686 || warn "32-bit VA-API uebersprungen."
sudo dnf install -y libva-utils
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
log "RADV 64/32-bit bereit."

# ============================================================================
# 8. Gaming-Software: Steam, Protontricks, ProtonPlus, Tools
# ============================================================================
info "Installiere Steam + Gaming-Tools..."
sudo dnf install -y \
  steam \
  steam-devices \
  protontricks || warn "Einzelne Gaming-Pakete fehlgeschlagen."

info "Installiere ProtonPlus..."
if [[ "$TERRA_AVAILABLE" == "1" ]]; then
  sudo dnf install -y protonplus || warn "ProtonPlus (Terra) fehlgeschlagen."
else
  warn "ProtonPlus uebersprungen (Terra nicht aktiv) — spaeter via Flatpak nachinstallieren."
fi
log "Steam, Protontricks, ProtonPlus verarbeitet."

# ============================================================================
# 8b. Heroic + Faugus Launcher (nativ, kein Flatpak)
# ============================================================================
info "Installiere Heroic Games Launcher..."
if sudo dnf install -y heroic-games-launcher; then
  log "Heroic installiert."
else
  warn "Heroic fehlgeschlagen — Fallback: RPM direkt vom GitHub-Release."
  HEROIC_URL=$(curl -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest \
    | grep -oP '"browser_download_url":\s*"\K[^"]*x86_64\.rpm' | head -n1)
  if [[ -n "${HEROIC_URL:-}" ]]; then
    sudo dnf install -y "$HEROIC_URL" && log "Heroic via GitHub-RPM installiert."
  else
    warn "Heroic-RPM nicht gefunden — manuell nachinstallieren."
  fi
fi

info "Installiere GLES-Support..."
sudo dnf install -y libglvnd-gles.x86_64 libglvnd-gles.i686 || warn "libglvnd-gles uebersprungen."

info "Installiere Faugus Launcher (COPR faugus/faugus-launcher)..."
sudo dnf copr enable -y faugus/faugus-launcher && \
  sudo dnf install -y faugus-launcher || warn "Faugus Launcher fehlgeschlagen."
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
# 10. LACT (GPU-Kontrolle: Undervolt/Powerlimit)
# ============================================================================
info "Installiere LACT..."
if sudo dnf install -y lact; then
  log "LACT (Terra) installiert."
else
  warn "Terra-Install fehlgeschlagen — Fallback: COPR ilyaz/LACT..."
  sudo dnf copr enable -y ilyaz/LACT && sudo dnf install -y lact || warn "LACT manuell nachinstallieren."
fi
sudo systemctl enable lactd 2>/dev/null || warn "lactd-Service nicht aktivierbar — nach Reboot pruefen."

# ============================================================================
# 11. System-Tuning
# ============================================================================
info "Schreibe Tuning-Configs..."
sudo tee /etc/sysctl.d/99-gaming.conf >/dev/null <<'EOF'
kernel.split_lock_mitigate=0
vm.max_map_count=2147483642
EOF

sudo dnf install -y zram-generator || warn "zram-generator uebersprungen."
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram * 0.15
compression-algorithm = zstd
EOF

sudo mkdir -p /etc/environment.d
sudo tee /etc/environment.d/90-gaming.conf >/dev/null <<'EOF'
MESA_SHADER_CACHE_MAX_SIZE=12G
PROTON_ENABLE_HDR=1
PROTON_USE_OPTISCALER=1
PROTON_FSR4_UPGRADE=1
PROTON_XESS_UPGRADE=1
PROTON_ENABLE_WAYLAND=1
EOF

sudo systemctl enable fstrim.timer || warn "fstrim.timer nicht aktivierbar."
log "sysctl, ZRAM, Env-Variablen, fstrim gesetzt."

# ============================================================================
# 12. Firewall
# ============================================================================
info "Richte firewalld ein..."
sudo dnf install -y firewalld
sudo systemctl enable --now firewalld || warn "firewalld nicht startbar."
sudo firewall-cmd --permanent --zone=public --remove-service=ssh 2>/dev/null || true
sudo firewall-cmd --permanent --zone=public --add-service=mdns 2>/dev/null || true
sudo firewall-cmd --permanent --zone=public --add-service=ipp-client 2>/dev/null || true
sudo firewall-cmd --reload 2>/dev/null || true
log "firewalld aktiv."

# ============================================================================
# 13. Fish Shell + Abbreviations
# ============================================================================
info "Installiere Fish Shell..."
sudo dnf install -y fish
sudo chsh -s /usr/bin/fish "$USER" || warn "Default-Shell nicht gesetzt."

mkdir -p "$HOME/.config/fish"
tee "$HOME/.config/fish/config.fish" >/dev/null <<'EOF'
if status is-interactive
    set -g fish_greeting

    # --- Update ---
    abbr -a up   'sudo dnf upgrade --refresh'

    # --- DNF-Basics ---
    abbr -a in   'sudo dnf install'
    abbr -a rem  'sudo dnf remove'
    abbr -a se   'dnf search'
    abbr -a inf  'dnf info'
    abbr -a li   'dnf list --installed'
    abbr -a hist 'dnf history'
    abbr -a wp   'dnf provides'

    # --- Aufraeumen ---
    abbr -a clean 'sudo dnf autoremove -y; and sudo dnf clean packages'

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
log "Fish eingerichtet."

# ============================================================================
# 15. Aufraeumen + Abschluss
# ============================================================================
info "Entferne Wine-Desktop-Menuemuell..."
sudo dnf remove -y wine-desktop || warn "wine-desktop nicht vorhanden oder Entfernen fehlgeschlagen."

sudo dnf autoremove -y || true
sudo dnf clean packages || true

echo
log "============================================="
log " Fertig. Naechste Schritte:"
log "   1. reboot  ->  Plasma Login Manager / Plasma (Wayland)"
log "   2. vainfo  ->  H264/HEVC unter VAEntrypointVLD pruefen"
log "   3. Systemeinstellungen -> Drucker: Brother pruefen"
log "   4. Steam starten, Proton-GE via ProtonPlus ziehen"
log "   5. LACT: Settings setzen (-70 mV / -25% PL)"
log "   6. Neues Terminal = Fish ('up' zum Updaten)"
log "============================================="
