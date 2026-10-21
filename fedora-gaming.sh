#!/usr/bin/env bash
# ============================================================================
#  Fedora 44 / 45 Post-Install — Minimal Netinstall (Everything ISO, kein DE)
#  Usecase: Gaming + Browsing
#  DE: KDE Plasma (Wayland), minimal — Plasma Login Manager, Dolphin,
#      MTP/AFC/SMB fuer Dolphin, CUPS/Avahi-Drucken
#  Hardware: Ryzen 7 9800X3D | RX 9070 XT | MSI X870E Tomahawk Max WiFi
#
#  Start: als normaler User im tty (sudo-Rechte vorausgesetzt)
#  Aufruf: bash fedora-gaming.sh
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
[[ "$FEDORA_VER" == "44" || "$FEDORA_VER" == "45" ]] || warn "Erwartet Fedora 44/45, gefunden: $FEDORA_VER — Script läuft trotzdem weiter."
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
EOF
log "dnf.conf geschrieben."

# dnf5-plugins liefert config-manager (wird fuer Chrome gebraucht) — auf
# Minimal-Installs oft NICHT dabei.
sudo dnf install -y dnf5-plugins || warn "dnf5-plugins konnte nicht installiert werden."

# Locales — Minimal-Netinstall generiert kein en_US/de_DE, sonst pv-locale-gen-
# Fehler in der Steam Runtime beim ersten Proton-Start ("character map file
# 'UTF-8' not found").
info "Installiere Locales (en_US, de_DE)..."
sudo dnf install -y glibc-langpack-en glibc-langpack-de || warn "Locale-Pakete uebersprungen."

# ============================================================================
# 2. System-Update
# ============================================================================
info "Vollständiges System-Update..."
sudo dnf upgrade -y --refresh
log "System aktuell."

# ============================================================================
# 3. RPM Fusion (free + nonfree)
# ============================================================================
# Die Release-RPMs bringen die Repos mit Standard-Einstellungen mit:
# free/nonfree + updates an, updates-testing aus. Nichts davon muss von Hand
# umgeschaltet werden. Tainted wird nicht gebraucht (nichts daraus installiert).
info "Installiere RPM Fusion..."
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
log "RPM Fusion eingerichtet."

# ============================================================================
# 3b. Terra (rolling-release Community-Repo, Fyra Labs)
# ============================================================================
# Liefert: Heroic, ProtonPlus, Faugus Launcher, LACT. Kein COPR mehr noetig.
info "Installiere Terra-Repo..."
sudo dnf install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_VER}" terra-release || \
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

# Fonts + Hardware-Support (Firmware etc.) — Gruppen, mit Fallback
sudo dnf group install -y fonts || warn "Font-Gruppe nicht installierbar — pruefe manuell."
sudo dnf group install -y hardware-support || warn "hardware-support-Gruppe uebersprungen."

sudo systemctl enable --force plasmalogin.service
sudo systemctl enable power-profiles-daemon.service || warn "power-profiles-daemon nicht aktivierbar."
sudo systemctl enable upower.service || warn "upower nicht aktivierbar."
sudo systemctl set-default graphical.target
log "Plasma minimal + Plasma Login Manager installiert, graphical.target gesetzt."

# ============================================================================
# 5. Archiv-Backends + CLI-Basics (fehlen in @core der Minimal-Install)
# ============================================================================
info "Installiere Archiv-Tools + CLI-Basics..."
sudo dnf install -y \
  unzip \
  zip \
  p7zip \
  p7zip-plugins \
  bzip2 \
  wget \
  btop || warn "Einzelne Utility-Pakete fehlgeschlagen."
# unrar kommt aus RPM Fusion nonfree (proprietaer):
sudo dnf install -y unrar || warn "unrar uebersprungen — RPM-Fusion-Status pruefen."
log "Archiv-Backends bereit."

# ============================================================================
# 6. MTP/Netzwerk-Freigaben fuer Dolphin (kio-extras Backends)
# ============================================================================
# libmtp/libimobiledevice sind nur weiche Abhaengigkeiten (dlopen zur
# Laufzeit) — bei install_weak_deps=False werden sie NICHT automatisch
# mitgezogen, dann bleibt "mtp:/" in Dolphin leer.
info "Installiere MTP/AFC/SMB-Laufzeitbibliotheken fuer kio-extras..."
sudo dnf install -y \
  libmtp \
  libimobiledevice \
  samba-client-libs || warn "Einzelne MTP/Netzwerk-Bibliotheken fehlgeschlagen."
log "mtp:/, afc:/ und smb:/ in Dolphin einsatzbereit."

# ============================================================================
# 7. Drucken (CUPS + Netzwerk-Discovery fuer Brother)
# ============================================================================
# Brother-Netzwerkdrucker koennen fast immer IPP Everywhere / AirPrint
# (treiberlos). avahi macht die Erkennung im Netzwerk (mDNS).
# kde-print-manager = Drucker-Modul in den Systemeinstellungen (auf Fedora
# "kde-print-manager", NICHT "print-manager").
# Falls das Modell KEIN IPP Everywhere kann: Treiber von support.brother.com.
info "Installiere CUPS + Netzwerk-Druckerkennung..."
sudo dnf install -y \
  cups \
  cups-filters \
  cups-pk-helper \
  kde-print-manager \
  avahi \
  nss-mdns || warn "Einzelne Druck-Pakete fehlgeschlagen."

sudo systemctl enable --now cups.socket || warn "cups.socket nicht aktivierbar."
sudo systemctl enable --now avahi-daemon.service || warn "avahi-daemon nicht aktivierbar."
log "CUPS + Avahi aktiv — Firewall-Freigabe folgt in Abschnitt 14."

# ============================================================================
# 8. Multimedia: Full ffmpeg + GStreamer + VA-API (AMD Freeworld)
# ============================================================================
info "Wechsle auf volles ffmpeg (RPM Fusion)..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || \
  sudo dnf install -y ffmpeg --allowerasing

info "Installiere GStreamer-Codecs..."
sudo dnf install -y --setopt=install_weak_deps=False \
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
if rpm -q mesa-va-drivers >/dev/null 2>&1; then
  sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
else
  sudo dnf install -y mesa-va-drivers-freeworld
fi
# 32-bit fuer Steam/Proton
sudo dnf install -y mesa-va-drivers-freeworld.i686 || warn "32-bit VA-API uebersprungen."
sudo dnf install -y libva-utils   # vainfo zum Verifizieren
log "Codecs + Hardware-Decode eingerichtet."

# ============================================================================
# 9. AMD Gaming-Grundlage (Vulkan 64+32 bit)
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
# 10. Steam
# ============================================================================
# Kein protontricks: GE-Proton/umu-protonfixes wenden Winetricks-Verbs
# pro Spiel selbst an. Manuell nachschieben per Startoption -pf_tricks=<verb>.
info "Installiere Steam..."
sudo dnf install -y \
  steam \
  steam-devices || warn "Einzelne Gaming-Pakete fehlgeschlagen."
log "Steam abgeschlossen."

# ============================================================================
# 11. Launcher + Tools aus Terra (ProtonPlus, Heroic, Faugus, LACT)
# ============================================================================
# Ohne libglvnd-gles crasht Faugus beim GUI-Start mit "Couldn't open
# libGLESv2.so.2" (SIGABRT). Paketname ist libglvnd-gles, NICHT mesa-libGLES.
info "Installiere GLES-Support (Faugus/GTK-Abhaengigkeit)..."
sudo dnf install -y libglvnd-gles.x86_64 libglvnd-gles.i686 || warn "libglvnd-gles uebersprungen."

info "Installiere ProtonPlus, Heroic, Faugus Launcher, LACT (Terra)..."
for pkg in protonplus heroic-games-launcher faugus-launcher lact; do
  sudo dnf install -y "$pkg" || warn "$pkg (Terra) fehlgeschlagen — manuell nachinstallieren."
done
# Faugus zieht umu-launcher mit. Runner-Pfad: ~/.local/share/Steam/compatibilitytools.d/
# (Proton-GE via ProtonPlus wird von Faugus direkt gefunden).

sudo systemctl enable lactd 2>/dev/null || warn "lactd-Service nicht aktivierbar — nach Reboot pruefen."
# LACT-Setting zur Erinnerung: -70 mV / -25% Powerlimit
log "Launcher + LACT abgeschlossen."

# ============================================================================
# 12. Google Chrome
# ============================================================================
info "Installiere Google Chrome..."
sudo dnf install -y fedora-workstation-repositories
sudo dnf config-manager setopt google-chrome.enabled=1
sudo dnf install -y google-chrome-stable
log "Chrome installiert."

# ============================================================================
# 13. System-Tuning
# ============================================================================
info "Schreibe Tuning-Configs..."

# split_lock: bestaetigter Gaming-Gewinn
sudo tee /etc/sysctl.d/99-gaming.conf >/dev/null <<'EOF'
kernel.split_lock_mitigate=0
vm.max_map_count=2147483642
EOF

# ZRAM: 15% RAM, zstd. Paket selbst installieren — auf der Minimal-Netinstall
# ist zram-generator nicht garantiert vorhanden, ohne es bleibt ZRAM still aus.
sudo dnf install -y zram-generator || warn "zram-generator uebersprungen — ZRAM-Config wirkungslos."
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram * 0.15
compression-algorithm = zstd
EOF

# Gaming-Env: environment.d statt /etc/profile.d, weil profile.d nur von
# Login-Shells gelesen wird, nicht von grafisch gestarteten Programmen.
# Syntax strikt KEY=VALUE — kein "export", keine Anfuehrungszeichen.
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
# 14. Firewall (firewalld — auf Minimal-Install nicht garantiert vorhanden)
# ============================================================================
info "Richte firewalld ein..."
sudo dnf install -y firewalld
sudo systemctl enable --now firewalld || warn "firewalld nicht startbar — nach Reboot pruefen."
# Zone public: nur dhcpv6-client + ssh offen. Desktop ohne SSH-Server -> ssh raus.
sudo firewall-cmd --permanent --zone=public --remove-service=ssh 2>/dev/null || true
# Netzwerkdrucker-Erkennung (Abschnitt 7): mDNS fuer Avahi, ipp-client fuer IPP.
sudo firewall-cmd --permanent --zone=public --add-service=mdns 2>/dev/null || true
sudo firewall-cmd --permanent --zone=public --add-service=ipp-client 2>/dev/null || true
sudo firewall-cmd --reload 2>/dev/null || true
log "firewalld aktiv (Zone: public, dicht bis auf DHCPv6)."

# ============================================================================
# 15. Fish Shell + Abbreviations
# ============================================================================
info "Installiere Fish Shell..."
sudo dnf install -y fish
sudo chsh -s /usr/bin/fish "$USER" || warn "Default-Shell nicht gesetzt — manuell: chsh -s /usr/bin/fish"

mkdir -p "$HOME/.config/fish"
tee "$HOME/.config/fish/config.fish" >/dev/null <<'EOF'
# ---------------------------------------------------------------
# Fish-Konfiguration — Fedora Gaming
# Abbreviations statt Aliase: expandieren sichtbar in der Zeile,
# bleiben editierbar und landen sauber in der History.
# ---------------------------------------------------------------
if status is-interactive
    set -g fish_greeting  # Begruessung aus

    # --- Update ---
    abbr -a up   'sudo dnf upgrade --refresh'

    # --- DNF-Basics ---
    abbr -a in   'sudo dnf install'
    abbr -a rem  'sudo dnf remove'
    abbr -a se   'dnf search'
    abbr -a inf  'dnf info'
    abbr -a li   'dnf list --installed'
    abbr -a hist 'dnf history'
    abbr -a wp   'dnf provides'          # welches Paket liefert Datei X

    # --- Aufraeumen ---
    abbr -a clean 'sudo dnf autoremove -y; and sudo dnf clean packages'
end
EOF
log "Fish installiert, als Default-Shell gesetzt, Abbreviations geschrieben."

# ============================================================================
# 16. Aufraeumen + Abschluss
# ============================================================================
sudo dnf autoremove -y || true
sudo dnf clean packages || true

echo
log "============================================="
log " Fertig (Fedora ${FEDORA_VER}). Naechste Schritte:"
log "   1. reboot  ->  Plasma Login Manager / Plasma (Wayland)"
log "   2. vainfo  ->  H264/HEVC unter VAEntrypointVLD pruefen"
log "   3. Systemeinstellungen -> Drucker: Brother sollte automatisch auftauchen"
log "   4. Steam starten, Proton-GE via ProtonPlus ziehen"
log "   5. LACT: -70 mV / PL -25% setzen"
log "   6. Neues Terminal = Fish. 'up' tippen -> expandiert zum Update-Befehl"
log "============================================="
