#!/usr/bin/env bash
# ============================================================================
#  Fedora 45 Post-Install — Minimal Netinstall (Everything ISO, kein DE)
#  Usecase: Gaming + Browsing
#  DE: KDE Plasma (Wayland), minimal — Plasma Login Manager, Dolphin,
#      MTP/AFC/SMB fuer Dolphin, CUPS/Avahi-Drucken
#  Hardware: Ryzen 7 9800X3D | RX 9070 XT | MSI X870E Tomahawk Max WiFi
#
#  Start: als normaler User im tty (sudo-Rechte vorausgesetzt)
#  Aufruf: bash fedorabeta45.sh
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
[[ "$FEDORA_VER" == "44" || "$FEDORA_VER" == "45" ]] || warn "Erwartet Fedora 44/45, gefunden: $FEDORA_VER — Script laeuft trotzdem weiter."
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
# 'UTF-8' not found").
info "Installiere Locales (en_US, de_DE)..."
sudo dnf install -y glibc-langpack-en glibc-langpack-de || warn "Locale-Pakete uebersprungen."

# ============================================================================
# 2. System-Update
# ============================================================================
info "Vollstaendiges System-Update..."
sudo dnf upgrade -y --refresh
log "System aktuell."

# ============================================================================
# 3. RPM Fusion (free + nonfree) — Ohne Testing & Ohne Tainted
# ============================================================================
info "Installiere RPM Fusion..."
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

info "Konfiguriere RPM-Fusion-Repos..."
# 1. Basis-Repos aktivieren
for repo in rpmfusion-free rpmfusion-nonfree; do
  sudo dnf config-manager setopt "${repo}.enabled=1" || warn "Konnte ${repo} nicht aktivieren."
done

# 2. Testing-Repos explizit deaktiviert lassen (verhindert Mesa-Versionskonflikte im Pre-Release Freeze)
for repo in rpmfusion-free-updates-testing rpmfusion-nonfree-updates-testing; do
  sudo dnf config-manager setopt "${repo}.enabled=0" 2>/dev/null || true
done

# 3. Updates-Repos nur aktivieren, wenn 'updates-released' auf den Mirrors schon existiert:
if curl -fsI "https://mirrors.rpmfusion.org/metalink?repo=free-fedora-updates-released-${FEDORA_VER}&arch=x86_64" >/dev/null 2>&1; then
  info "RPM-Fusion Updates-Repo vorhanden: Aktiviere regulaeere Updates-Repos..."
  for repo in rpmfusion-free-updates rpmfusion-nonfree-updates; do
    sudo dnf config-manager setopt "${repo}.enabled=1" || true
  done
else
  info "Pre-Release/Freeze erkannt (updates-released-${FEDORA_VER} noch nicht da): Deaktiviere Updates-Repo vorerst..."
  for repo in rpmfusion-free-updates rpmfusion-nonfree-updates; do
    sudo dnf config-manager setopt "${repo}.enabled=0" || true
  done
fi

# AppStream-Metadaten + Cisco OpenH264
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1 || warn "openh264-Repo nicht aktivierbar."
sudo dnf update -y @core || true
log "RPM Fusion eingerichtet."

# ============================================================================
# 3b. Terra (rolling-release Community-Repo, Fyra Labs)
# ============================================================================
# Liefert Heroic, ProtonPlus, Faugus Launcher und LACT direkt und aktuell.
info "Installiere Terra-Repo..."
sudo dnf install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_VER}" terra-release || \
  sudo dnf install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra44" terra-release || \
  warn "Terra-Repo-Setup fehlgeschlagen."
log "Terra aktiv."

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

# Fonts + Hardware-Support (DNF5 @group-Syntax)
sudo dnf install -y @fonts || warn "Font-Gruppe nicht installierbar — pruefe manuell."
sudo dnf install -y @hardware-support || warn "hardware-support-Gruppe uebersprungen."

sudo systemctl enable --force plasmalogin.service
sudo systemctl enable power-profiles-daemon.service || warn "power-profiles-daemon nicht aktivierbar."
sudo systemctl enable upower.service || warn "upower nicht aktivierbar."
sudo systemctl set-default graphical.target
log "Plasma minimal + Plasma Login Manager installiert, graphical.target gesetzt."

# ============================================================================
# 4b. Archiv-Backends + CLI-Basics (fehlen in @core der Minimal-Install)
# ============================================================================
info "Installiere Archiv-Tools + CLI-Basics..."
sudo dnf install -y \
  unzip \
  zip \
  7zip \
  p7zip \
  p7zip-plugins \
  tar \
  bzip2 \
  wget \
  btop || warn "Einzelne Utility-Pakete fehlgeschlagen."
# unrar kommt aus RPM Fusion nonfree:
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
log "CUPS + Avahi aktiv — Drucker sollte automatisch in Systemeinstellungen -> Drucker auftauchen."

# ============================================================================
# 5. Multimedia: Full ffmpeg + GStreamer + VA-API (AMD Freeworld)
# ============================================================================
info "Wechsle auf volles ffmpeg (RPM Fusion)..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || \
  sudo dnf install -y ffmpeg --allowerasing || \
  warn "ffmpeg-Swap aktuell wegen Freeze/Abhaengigkeiten nicht moeglich — spaeter nachholen."

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

info "VA-API Freeworld-Swap (H.264/H.265 Hardware-Decode fuer RDNA4)..."
# Mit || warn abgesichert, da Fedora im Freeze (z.B. Mesa 26.2.3) und RPM Fusion (z.B. 26.5.2)
# kurz vor Release auseinanderlaufen — verhindert Script-Abbruch!
if rpm -q mesa-va-drivers >/dev/null 2>&1; then
  sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld || warn "Mesa VA-Swap wegen Versionskonflikt (Freeze) uebersprungen — nach Release via 'mesafix' nachholen."
else
  sudo dnf install -y mesa-va-drivers-freeworld || warn "mesa-va-drivers-freeworld aktuell nicht installierbar (Freeze)."
fi

# 32-bit fuer Steam/Proton
sudo dnf install -y mesa-va-drivers-freeworld.i686 || warn "32-bit VA-API Freeworld uebersprungen."
sudo dnf install -y libva-utils || true  # vainfo zum Verifizieren
log "Codecs + Hardware-Decode abgearbeitet."

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
log "RADV 64/32-bit bereit. (RX 9070 XT laeuft out-of-the-box ueber Mesa.)"

# ============================================================================
# 7. Flatpak + Flathub (optional, auskommentiert)
# ============================================================================
# info "Richte Flatpak/Flathub ein..."
# sudo dnf install -y flatpak
# sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
# log "Flathub aktiv."

# ============================================================================
# 8. Gaming-Software: Steam & ProtonPlus (ohne protontricks -> kein System-Wine!)
# ============================================================================
info "Installiere Steam..."
sudo dnf install -y \
  steam \
  steam-devices || warn "Steam-Installation fehlgeschlagen."

# gamescope optional — bei Bedarf einkommentieren:
# sudo dnf install -y gamescope

info "Installiere ProtonPlus (Terra, mit F44-Fallback)..."
if sudo dnf install -y protonplus; then
  log "ProtonPlus (Terra F${FEDORA_VER}) installiert."
elif sudo dnf install -y --releasever=44 protonplus; then
  log "ProtonPlus aus Terra F44 installiert (releasever=44 Fallback)."
else
  warn "ProtonPlus (Terra) fehlgeschlagen."
fi
log "Steam & ProtonPlus abgeschlossen."

# ============================================================================
# 8b. Heroic + Faugus Launcher (beide via Terra, nutzen umu-launcher)
# ============================================================================
info "Installiere Heroic Games Launcher (Terra, mit F44-Fallback)..."
if sudo dnf install -y heroic-games-launcher; then
  log "Heroic (Terra F${FEDORA_VER}) installiert — Updates laufen ueber dnf mit."
elif sudo dnf install -y --releasever=44 heroic-games-launcher; then
  log "Heroic aus Terra F44 installiert (releasever=44 Fallback)."
else
  warn "Terra-Install fehlgeschlagen — Fallback: RPM direkt vom GitHub-Release."
  HEROIC_URL=$(curl -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest \
    | grep -oP '"browser_download_url":\s*"\K[^"]*x86_64\.rpm' | head -n1)
  if [[ -n "${HEROIC_URL:-}" ]]; then
    sudo dnf install -y "$HEROIC_URL" && log "Heroic via GitHub-RPM installiert."
  else
    warn "Heroic-RPM nicht gefunden — manuell nachinstallieren."
  fi
fi

info "Installiere GLES-Support (Faugus/GTK-Abhaengigkeit)..."
sudo dnf install -y libglvnd-gles.x86_64 libglvnd-gles.i686 || warn "libglvnd-gles uebersprungen."

info "Installiere Faugus Launcher (Terra, mit F44-Fallback)..."
if sudo dnf install -y faugus-launcher; then
  log "Faugus Launcher (Terra F${FEDORA_VER}) installiert."
elif sudo dnf install -y --releasever=44 faugus-launcher; then
  log "Faugus Launcher aus Terra F44 installiert (releasever=44 Fallback)."
else
  warn "Faugus Launcher Installation ueber Terra fehlgeschlagen."
fi
log "Launcher-Sektion abgeschlossen."

# ============================================================================
# 9. Google Chrome + Debloat-Policy + VA-API/Wayland-Flags
# ============================================================================
info "Installiere Google Chrome..."
sudo dnf install -y fedora-workstation-repositories
sudo dnf config-manager setopt google-chrome.enabled=1
sudo dnf install -y google-chrome-stable

info "Setze Chrome Enterprise Policy (Telemetrie/Bloat aus) & VA-API Flags..."
sudo mkdir -p /etc/opt/chrome/policies/managed
sudo tee /etc/opt/chrome/policies/managed/99-gaming-clean.json >/dev/null <<'EOF'
{
  "BackgroundModeEnabled": false,
  "DefaultBrowserSettingEnabled": false,
  "MetricsReportingEnabled": false,
  "PromotionsEnabled": false,
  "PrivacySandboxPromptEnabled": false,
  "PrivacySandboxAdMeasurementEnabled": false,
  "PrivacySandboxAdTopicsEnabled": false,
  "PrivacySandboxSiteEnabledAdsEnabled": false
}
EOF

mkdir -p "$HOME/.config"
tee "$HOME/.config/chrome-flags.conf" >/dev/null <<'EOF'
--ozone-platform-hint=auto
--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,VaapiOnNvidiaGPUs,VaapiIgnoreDriverChecks
EOF
log "Chrome installiert und konfiguriert."

# ============================================================================
# 10. LACT (GPU-Kontrolle: Undervolt/Powerlimit fuer die 9070 XT)
# ============================================================================
info "Installiere LACT (Terra, mit F44-Fallback)..."
if sudo dnf install -y lact; then
  log "LACT (Terra F${FEDORA_VER}) installiert."
elif sudo dnf install -y --releasever=44 lact; then
  log "LACT aus Terra F44 installiert (releasever=44 Fallback)."
else
  warn "Terra-Install fehlgeschlagen — Fallback: COPR ilyaz/LACT..."
  if sudo dnf copr enable -y ilyaz/LACT || sudo dnf copr enable -y ilyaz/LACT fedora-44-x86_64; then
    sudo dnf install -y lact || warn "LACT manuell nachinstallieren."
  fi
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

# ZRAM: 15% RAM, zstd
sudo dnf install -y zram-generator || warn "zram-generator uebersprungen — ZRAM-Config wirkungslos."
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram * 0.15
compression-algorithm = zstd
EOF

# Gaming-Env (systemd environment.d fuer volle Wayland/GUI-Session-Abdeckung)
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
# 12. Firewall (firewalld — auf Minimal-Install nicht garantiert vorhanden)
# ============================================================================
info "Richte firewalld ein..."
sudo dnf install -y firewalld
sudo systemctl enable --now firewalld || warn "firewalld nicht startbar — nach Reboot pruefen."
sudo firewall-cmd --permanent --zone=public --remove-service=ssh 2>/dev/null || true
sudo firewall-cmd --permanent --zone=public --add-service=mdns 2>/dev/null || true
sudo firewall-cmd --permanent --zone=public --add-service=ipp-client 2>/dev/null || true
# Steam Local Network Game Transfer — bei Bedarf einkommentieren:
# sudo firewall-cmd --permanent --add-port=27040/tcp
# sudo firewall-cmd --permanent --add-port=27036/udp
sudo firewall-cmd --reload 2>/dev/null || true
log "firewalld aktiv (Zone: public, dicht bis auf DHCPv6 + mDNS/IPP)."

# ============================================================================
# 13. Fish Shell + Abbreviations (DNF + Flatpak + Post-Freeze-Helfer)
# ============================================================================
info "Installiere Fish Shell..."
sudo dnf install -y fish
sudo chsh -s /usr/bin/fish "$USER" || warn "Default-Shell nicht gesetzt — manuell: chsh -s /usr/bin/fish"

mkdir -p "$HOME/.config/fish"
tee "$HOME/.config/fish/config.fish" >/dev/null <<'EOF'
# ---------------------------------------------------------------
# Fish-Konfiguration — Fedora Gaming
# ---------------------------------------------------------------
if status is-interactive
    set -g fish_greeting  # Begruessung aus

    # --- Update: DNF ---
    abbr -a up   'sudo dnf upgrade --refresh'

    # --- DNF-Basics ---
    abbr -a in   'sudo dnf install'
    abbr -a rem  'sudo dnf remove'
    abbr -a se   'dnf search'
    abbr -a inf  'dnf info'
    abbr -a li   'dnf list --installed'
    abbr -a hist 'dnf history'
    abbr -a wp   'dnf provides'          # welches Paket liefert Datei X

    # --- Post-Freeze Helfer (Mesa Freeworld & RPM Fusion Updates aktivieren) ---
    abbr -a mesafix 'sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld; and sudo dnf install mesa-va-drivers-freeworld.i686'
    abbr -a rpmup   'sudo dnf config-manager setopt rpmfusion-free-updates.enabled=1 rpmfusion-nonfree-updates.enabled=1'

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
log "Fish installiert, als Default-Shell gesetzt, Abbreviations geschrieben."

# ============================================================================
# 14. Optional: scx-Scheduler (auskommentiert — bei Bedarf aktivieren)
# ============================================================================
# sudo dnf copr enable -y bieszczaders/kernel-cachyos-addons || \
#   sudo dnf copr enable -y bieszczaders/kernel-cachyos-addons fedora-44-x86_64
# sudo dnf install -y scx-scheds

# ============================================================================
# 15. Aufraeumen + Abschluss
# ============================================================================
info "Pruefe auf eventuellen Wine-Desktop-Menuemuell..."
# Da protontricks raus ist und Heroic/Faugus ueber Terra 'umu-launcher' nutzen,
# sollte wine-desktop gar nicht erst installiert sein — falls doch, fliegt es hier raus:
if rpm -q wine-desktop >/dev/null 2>&1; then
  sudo dnf remove -y wine-desktop || true
fi

sudo dnf autoremove -y || true
sudo dnf clean packages || true

echo
log "============================================="
log " Fertig (Fedora ${FEDORA_VER}). Naechste Schritte:"
log "   1. reboot   -> Plasma Login Manager / Plasma (Wayland)"
log "   2. vainfo   -> H264/HEVC unter VAEntrypointVLD pruefen"
log "                  (Nach Release-Unfreeze: 'rpmup' & 'mesafix' in Fish tippen)"
log "   3. Drucker  -> Systemeinstellungen -> Drucker (Brother via Avahi/IPP)"
log "   4. Steam    -> Starten, Proton-GE via ProtonPlus ziehen"
log "   5. LACT     -> -70 mV / PL -25% setzen"
log "   6. Terminal -> Fish aktiv ('up' = Update)"
log "============================================="
