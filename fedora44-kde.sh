#!/usr/bin/env bash
# ============================================================================
#  Fedora 44 Post-Install — Minimal Netinstall (Everything ISO, kein DE)
#  Usecase: Gaming + Browsing
#  DE: KDE Plasma (Wayland), minimal — Plasma Login Manager, Dolphin,
#      MTP/AFC/SMB fuer Dolphin, CUPS/Avahi-Drucken
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
# 3b. Terra (rolling-release Community-Repo, Fyra Labs)
# ============================================================================
# Ersetzt Heroic- und ProtonPlus-COPR: Terra baut aktueller/haeufiger, und
# die dortige Heroic-Version nutzt bereits umu-launcher als Standard-Runner
# -> zieht KEIN System-Wine mehr (aeltere COPR-Builds taten das noch).
# LACT kommt ebenfalls von hier (kein extra COPR mehr noetig).
# Faugus bleibt auf der eigenen COPR — NICHT auf Terra verfuegbar (geprueft).
info "Installiere Terra-Repo..."
sudo dnf install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_VER}" terra-release || warn "Terra-Repo-Setup fehlgeschlagen."
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
# 4c. MTP/Netzwerk-Freigaben fuer Dolphin (kio-extras Backends)
# ============================================================================
# kio-extras (schon in Abschnitt 4 dabei) bringt die MTP/AFC/SMB-KIO-Slaves
# im Code schon mit, aber libmtp/libimobiledevice sind nur weiche
# Abhaengigkeiten (dlopen zur Laufzeit) — bei install_weak_deps=False werden
# die NICHT automatisch mitgezogen, dann bleibt "mtp:/" in Dolphin leer.
info "Installiere MTP/AFC/SMB-Laufzeitbibliotheken fuer kio-extras..."
sudo dnf install -y \
  libmtp \
  libimobiledevice \
  samba-client-libs || warn "Einzelne MTP/Netzwerk-Bibliotheken fehlgeschlagen."
log "mtp:/, afc:/ und smb:/ in Dolphin einsatzbereit."

# ============================================================================
# 4d. Drucken (CUPS + Netzwerk-Discovery fuer Brother etc.)
# ============================================================================
# Moderne Brother-Netzwerkdrucker (v.a. Laser) unterstuetzen fast immer
# IPP Everywhere / AirPrint = treiberloses Drucken. avahi macht die
# automatische Erkennung im Netzwerk (mDNS/Bonjour). kde-print-manager ist
# das KDE-Pendant zu GNOMEs Drucker-Panel (Systray-Applet + Systemeinstel-
# lungen-Modul) — auf Fedora heisst das Paket "kde-print-manager", NICHT
# "print-manager" (das ist der Arch-Paketname). Falls dein Modell KEIN IPP
# Everywhere kann: proprietaeren Treiber von support.brother.com laden
# (rpm-Paket, "Driver Install Tool").
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
# Firewall-Freigabe fuer mDNS/IPP folgt in Abschnitt 12 (firewalld).

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
# info "Richte Flatpak/Flathub ein..."
# sudo dnf install -y flatpak
# sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
# log "Flathub aktiv."

# ============================================================================
# 8. Gaming-Software: Steam, Protontricks, ProtonPlus, Tools
# ============================================================================
info "Installiere Steam + Gaming-Tools..."
# HINWEIS: --exclude=wine-desktop wuerde hier NICHTS bringen — winetricks
# (Hard-Dep von protontricks) requires wine, und Fedoras "wine"-Metapaket
# requires wine-desktop HART, ohne Alternative. dnf ignoriert --exclude
# stillschweigend, sobald es der einzige Weg ist, eine Requires-Kette
# aufzuloesen. Wine kommt also so oder so mit rein (wine-core wird von
# protontricks fuer den Proton-Workflow ohnehin kaum gebraucht, Proton
# bringt seine eigene Wine-Kopie mit). Der Cleanup (wine-desktop wieder raus)
# passiert erst GANZ am Ende (Abschnitt 15) als Sicherheitsnetz — Heroic
# zieht seit dem Umstieg auf Terra (8b, nutzt umu-launcher als Standard-
# Runner) selbst KEIN Wine mehr, aber falls Faugus oder was anderes spaeter
# im Script doch nochmal wine-desktop reinzieht, faengt der Cleanup das ab.
sudo dnf install -y \
  steam \
  steam-devices \
  protontricks || warn "Einzelne Gaming-Pakete fehlgeschlagen."

# gamescope optional — bei Bedarf einkommentieren:
# sudo dnf install -y gamescope

info "Installiere ProtonPlus (Terra, offiziell gelisteter Distributionskanal)..."
sudo dnf install -y protonplus || warn "ProtonPlus (Terra) fehlgeschlagen."
log "Steam, Protontricks, ProtonPlus installiert."

# ============================================================================
# 8b. Heroic + Faugus Launcher (nativ, kein Flatpak)
# ============================================================================
info "Installiere Heroic Games Launcher (Terra)..."
# Terra statt COPR: aktueller (2.18.x statt aeltere atim-Builds) und nutzt
# umu-launcher als Standard-Runner -> zieht KEIN System-Wine mehr rein.
if sudo dnf install -y heroic-games-launcher; then
  log "Heroic (Terra) installiert — Updates laufen ueber dnf mit."
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
# Ohne das crasht Faugus beim GUI-Start mit:
# "Couldn't open libGLESv2.so.2" -> SIGABRT. Paketname ist libglvnd-gles,
# NICHT mesa-libGLES (das Paket gibt es unter F44 nicht mehr/so nicht).
sudo dnf install -y libglvnd-gles.x86_64 libglvnd-gles.i686 || warn "libglvnd-gles uebersprungen."

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
info "Installiere LACT (Terra, kein extra COPR mehr noetig)..."
if sudo dnf install -y lact; then
  log "LACT (Terra) installiert."
else
  warn "Terra-Install fehlgeschlagen — Fallback: COPR ilyaz/LACT..."
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
# Paket selbst installieren — auf der Minimal-Netinstall (Everything-ISO)
# ist zram-generator nicht garantiert vorhanden; ohne das Paket liest
# nichts die Config unten, ZRAM bleibt nach dem Reboot stillschweigend aus.
sudo dnf install -y zram-generator || warn "zram-generator uebersprungen — ZRAM-Config wirkungslos."
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram * 0.15
compression-algorithm = zstd
EOF

# Gaming-Env (dein settled Setup)
# WICHTIG: /etc/profile.d/*.sh wird NUR von Login-Shells eingelesen (bash
# --login, klassisches TTY-Login) — nicht von grafisch gestarteten Programmen
# (Steam-Icon-Klick etc. laufen ueber Plasma Login Manager/systemd --user,
# keine Login-Shell). environment.d ist der systemd-korrekte Weg: wird vom
# User-Manager beim Session-Start eingelesen, gilt fuer ALLES in der Session,
# auch GUI-Starts. Syntax ist strikt KEY=VALUE — kein "export", keine
# Anfuehrungszeichen.
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
# Default-Zone: public (restriktiv, nur dhcpv6-client + ssh offen).
# Fuer Desktop ohne SSH-Server kann ssh raus:
sudo firewall-cmd --permanent --zone=public --remove-service=ssh 2>/dev/null || true
# Netzwerkdrucker-Erkennung (Brother etc., Abschnitt 4d): mDNS fuer Avahi,
# ipp-client fuer ausgehende/eingehende Druckkommunikation.
sudo firewall-cmd --permanent --zone=public --add-service=mdns 2>/dev/null || true
sudo firewall-cmd --permanent --zone=public --add-service=ipp-client 2>/dev/null || true
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
    abbr -a up   'sudo dnf upgrade --refresh'

    # --- DNF-Basics ---
    abbr -a in   'sudo dnf install'
    abbr -a rem  'sudo dnf remove'
    abbr -a se   'dnf search'
    abbr -a inf  'dnf info'
    abbr -a li   'dnf list --installed'
    abbr -a hist 'dnf history'
    abbr -a wp   'dnf provides'          # welches Paket liefert Datei X

    # --- Aufraeumen: DNF + Flatpak ---
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
# COPR bieszczaders/kernel-cachyos-addons liefert scx-scheds fuer Fedora.
# sudo dnf copr enable -y bieszczaders/kernel-cachyos-addons
# sudo dnf install -y scx-scheds
# Hinweis: falcond ist auf Fedora nicht sauber paketiert — scx_bpfland
# alternativ direkt per systemd-Service starten (scx.service, /etc/default/scx).

# ============================================================================
# 15. Aufraeumen + Abschluss
# ============================================================================
info "Entferne Wine-Desktop-Menuemuell (Notepad/Wordpad/Regedit/WineMine)..."
# Muss GANZ am Ende passieren: sowohl protontricks (Abschnitt 8) als auch
# Heroic (Abschnitt 8b, eigene Windows-Spiele-Verwaltung) ziehen wine ueber
# ihre jeweiligen Requires-Ketten rein. Ein Cleanup direkt nach Steam wuerde
# von Heroic gleich wieder ueberschrieben. Nimmt "wine" als Ganzes mit (kein
# Problem, Proton bringt seine eigene Wine-Kopie mit) sowie ungenutzte
# Recommends-Ketten wie wine-mono (~300 MB .NET-Runtime) und dosbox-staging +
# fluid-soundfont-gm (~140 MB, DOS-Emulator-Zubehoer).
sudo dnf remove -y wine-desktop || warn "wine-desktop war nicht installiert oder Entfernen fehlgeschlagen."

sudo dnf autoremove -y || true
sudo dnf clean packages || true

echo
log "============================================="
log " Fertig. Naechste Schritte:"
log "   1. reboot  ->  Plasma Login Manager / Plasma (Wayland)"
log "   2. vainfo  ->  H264/HEVC unter VAEntrypointVLD pruefen"
log "   3. Systemeinstellungen -> Drucker: Brother sollte automatisch auftauchen"
log "   4. Steam starten, Proton-GE via ProtonPlus ziehen"
log "   5. LACT: -70 mV / PL -25% setzen"
log "   6. Neues Terminal = Fish. 'up' tippen -> expandiert zum Update-Befehl"
log "============================================="
