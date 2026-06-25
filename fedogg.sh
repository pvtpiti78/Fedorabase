#!/bin/bash
# =============================================================================
# fedora-setup.sh — Fedora 44 Base Setup (AMD Edition)
# =============================================================================
# Ausgangslage: Minimale Fedora 44 TTY-Installation
# =============================================================================

set -euo pipefail

# ── Farben ────────────────────────────────────────────────────────────────────
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

# ── Root-Check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Bitte als root ausführen: sudo bash fedora-setup.sh"

CURRENT_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$CURRENT_USER")

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${RED}"
echo "  ███████╗███████╗██████╗  ██████╗ ██████╗  █████╗ "
echo "  ██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗"
echo "  █████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║"
echo "  ██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║"
echo "  ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║"
echo "  ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "  ${BOLD}Fedora 44 — Base Setup (Team Red)${NC}"
echo -e "  Mesa/AMDGPU · Fish · Kitty · Starship · Gaming ENV"
echo ""
echo -e "  ${YELLOW}Drücke ENTER zum Starten oder CTRL+C zum Abbrechen.${NC}"
read -r

# ── DNF5 konfigurieren ────────────────────────────────────────────────────────
info "DNF5 konfigurieren..."
cat > /etc/dnf/dnf.conf << 'EOF'
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
best=False
skip_if_unavailable=True
max_parallel_downloads=10
fastestmirror=True
deltarpm=False
EOF
log "DNF5 konfiguriert"

# ── System aktualisieren ──────────────────────────────────────────────────────
info "System aktualisieren..."
dnf upgrade -y --refresh
log "System aktuell"

# ── RPM Fusion aktivieren ─────────────────────────────────────────────────────
info "RPM Fusion Free + Non-Free aktivieren..."
dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf config-manager setopt fedora-cisco-openh264.enabled=1
log "RPM Fusion aktiviert"

# ── ffmpeg-free → ffmpeg (RPM Fusion) ────────────────────────────────────────
info "ffmpeg-free gegen vollwertiges ffmpeg tauschen..."
dnf swap -y ffmpeg-free ffmpeg --allowerasing
log "ffmpeg getauscht"

# ── Flatpak deaktivieren ──────────────────────────────────────────────────────
info "Flatpak deaktivieren und entfernen..."
dnf remove -y flatpak flatpak-libs 2>/dev/null || true
rm -rf /var/lib/flatpak
rm -rf "$USER_HOME/.local/share/flatpak"
log "Flatpak entfernt"

# ── Basis-Pakete & AMD Treiber ────────────────────────────────────────────────
info "Basis-Pakete und Mesa (AMD Vulkan/VA-API) installieren..."
dnf install -y \
    git tar curl wget unzip p7zip p7zip-plugins btop fastfetch bash-completion \
    pciutils usbutils lshw rsync vim nano man-db xdg-utils xdg-user-dirs \
    pipewire pipewire-pulseaudio wireplumber power-profiles-daemon \
    hunspell hunspell-de hunspell-en-US \
    mesa-vulkan-drivers mesa-vulkan-drivers.i686 \
    vulkan-loader vulkan-loader.i686 \
    mesa-va-drivers

info "Erweiterte VA-API Codecs für AMD installieren..."
dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld --allowerasing || true
log "Basis-Pakete und AMD-Treiber installiert"

# ── power-profiles-daemon ─────────────────────────────────────────────────────
info "power-profiles-daemon aktivieren..."
systemctl enable --now power-profiles-daemon
log "power-profiles-daemon aktiv"

# ── Terra Repo ────────────────────────────────────────────────────────────────
info "Terra Repo aktivieren..."
dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
log "Terra Repo aktiviert"

# ── NTSYNC explizit laden ─────────────────────────────────────────────────────
info "NTSYNC konfigurieren..."
echo "ntsync" > /etc/modules-load.d/ntsync.conf
log "NTSYNC aktiviert"

# ── Fish Shell ────────────────────────────────────────────────────────────────
info "Fish Shell installieren..."
dnf install -y fish
chsh -s /usr/bin/fish "$CURRENT_USER"

mkdir -p "$USER_HOME/.config/fish"
cat > "$USER_HOME/.config/fish/config.fish" << 'EOF'
if status is-interactive
    starship init fish | source
    fastfetch
    alias ls='ls --color=auto'
    alias ll='ls -lah --color=auto'
    alias grep='grep --color=auto'
    alias df='df -h'
    alias free='free -h'
    alias ..='cd ..'
    alias ...='cd ../..'
    alias update='sudo dnf upgrade -y --refresh'
    alias install='sudo dnf install -y'
    alias remove='sudo dnf remove -y'
    alias search='dnf search'
    alias clean='sudo dnf clean all'
    alias ss='sudo systemctl status'
    alias sr='sudo systemctl restart'
    alias se='sudo systemctl enable'
    alias gs='git status'
    alias ga='git add .'
    alias gc='git commit -m'
    alias gp='git push'
end
EOF
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/fish"
log "Fish Shell konfiguriert"

# ── Starship Prompt ───────────────────────────────────────────────────────────
info "Starship installieren..."
curl -sS https://starship.rs/install.sh | sh -s -- --yes

mkdir -p "$USER_HOME/.config"
cat > "$USER_HOME/.config/starship.toml" << 'EOF'
format = """
$directory\
$git_branch\
$git_status\
$cmd_duration\
$line_break\
$character"""

[directory]
style = "bold #7aa2f7"
truncation_length = 3
truncate_to_repo = true
format = "[$path]($style) "

[git_branch]
symbol = " "
style = "bold #bb9af7"
format = "[$symbol$branch]($style) "

[git_status]
style = "bold #f7768e"
format = "[$all_status$ahead_behind]($style) "

[cmd_duration]
min_time = 3_000
style = "bold #e0af68"
format = "[ $duration]($style) "

[character]
success_symbol = "[❯](bold #9ece6a)"
error_symbol = "[❯](bold #f7768e)"

[package]
disabled = true
[python]
disabled = true
[nodejs]
disabled = true
[rust]
disabled = true
EOF
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/starship.toml"
log "Starship konfiguriert"

# ── Kitty Terminal ────────────────────────────────────────────────────────────
info "Kitty installieren..."
dnf install -y kitty

mkdir -p "$USER_HOME/.config/kitty"
cat > "$USER_HOME/.config/kitty/kitty.conf" << 'EOF'
font_family      JetBrainsMono Nerd Font
bold_font        JetBrainsMono Nerd Font Bold
italic_font      JetBrainsMono Nerd Font Italic
bold_italic_font JetBrainsMono Nerd Font Bold Italic
font_size        13.0

foreground              #c0caf5
background              #1a1b26
selection_foreground    #1a1b26
selection_background    #c0caf5
cursor                  #c0caf5
cursor_text_color       #1a1b26
url_color               #73daca

color0  #15161e
color8  #414868
color1  #f7768e
color9  #f7768e
color2  #9ece6a
color10 #9ece6a
color3  #e0af68
color11 #e0af68
color4  #7aa2f7
color12 #7aa2f7
color5  #bb9af7
color13 #bb9af7
color6  #7dcfff
color14 #7dcfff
color7  #a9b1d6
color15 #c0caf5

window_padding_width    12
background_opacity      0.95
hide_window_decorations no
remember_window_size    yes
cursor_shape            block
cursor_blink_interval   0
sync_to_monitor         yes
confirm_os_window_close 0
tab_bar_style           powerline
tab_powerline_style     slanted
EOF
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/kitty"
log "Kitty konfiguriert"

# ── Fonts ─────────────────────────────────────────────────────────────────────
info "System-Fonts installieren..."
dnf install -y \
    google-noto-fonts-common google-noto-sans-fonts google-noto-serif-fonts \
    google-noto-mono-fonts google-noto-emoji-fonts google-noto-emoji-color-fonts \
    google-noto-cjk-fonts liberation-fonts dejavu-fonts-all jetbrains-mono-fonts
log "System-Fonts installiert"

info "JetBrainsMono Nerd Font installieren..."
FONT_DIR="/usr/share/fonts/JetBrainsMonoNF"
mkdir -p "$FONT_DIR"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
TMP_FONT=$(mktemp -d)
curl -fsSL "$FONT_URL" -o "$TMP_FONT/JetBrainsMono.zip"
unzip -q "$TMP_FONT/JetBrainsMono.zip" -d "$FONT_DIR"
rm -rf "$TMP_FONT"
fc-cache -fv > /dev/null
log "JetBrainsMono Nerd Font installiert"

# ── GStreamer + Codecs ────────────────────────────────────────────────────────
info "GStreamer-Stack und Codecs installieren..."
dnf install -y \
    gstreamer1 gstreamer1-plugins-base gstreamer1-plugins-good \
    gstreamer1-plugins-good-extras gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-free-extras gstreamer1-plugins-ugly \
    gstreamer1-plugin-libav ffmpeg ffmpeg-libs libva libva-utils || true
log "GStreamer + Codecs installiert"

# ── Gaming-Tools ──────────────────────────────────────────────────────────────
info "Gaming-Tools installieren (Steam, Protontricks)..."
dnf install -y steam protontricks
log "Gaming-Tools installiert"

# ── LACT (AMD GPU Controller) ─────────────────────────────────────────────────
info "LACT installieren (ideal für Radeon Undervolting/Fan Control)..."
dnf copr enable -y ilyaz/LACT
dnf install -y lact || true
systemctl enable --now lactd
log "LACT installiert"

# ── Gaming Launcher ───────────────────────────────────────────────────────────
info "Gaming Launcher installieren (ProtonPlus, Faugus)..."
dnf copr enable -y wehagy/protonplus
dnf install -y protonplus || true

dnf copr enable -y faugus/faugus-launcher
dnf install -y faugus-launcher || true
log "Gaming Launcher installiert"

# ── dnf-app-center ────────────────────────────────────────────────────────────
info "dnf-app-center aus Nobara 44 installieren..."
dnf copr enable -y gloriouseggroll/nobara-44 fedora-44-x86_64
dnf config-manager setopt copr:copr.fedorainfracloud.org:gloriouseggroll:nobara-44.enabled=0
dnf install -y dnf-app-center --enablerepo=copr:copr.fedorainfracloud.org:gloriouseggroll:nobara-44 || \
    warn "dnf-app-center konnte nicht installiert werden"
log "dnf-app-center installiert"

# ── Systemsprache & Google Chrome ─────────────────────────────────────────────
info "Systemsprache auf Deutsch setzen..."
dnf install -y glibc-langpack-de
localectl set-locale LANG=de_DE.UTF-8
log "Systemsprache gesetzt"

info "Google Chrome installieren..."
dnf install -y fedora-workstation-repositories
dnf config-manager setopt google-chrome.enabled=1
dnf install -y google-chrome-stable
log "Google Chrome installiert"

# ── gaming.conf (Environment Variables) ──────────────────────────────────────
info "gaming.conf (Systemd Environment) erstellen..."
mkdir -p /etc/environment.d
cat > /etc/environment.d/gaming.conf << 'EOF'
### Proton / Wayland
PROTON_ENABLE_WAYLAND=1
PROTON_VKD3D_HEAP=1
PROTON_USE_NTSYNC=1

### NTSYNC — kein esync/fsync
WINEFSYNC=0
WINEESYNC=0

### Optiscaler FSR4 Override Prep & Upgrade
PROTON_FSR4_UPGRADE=1

### Mesa Shader Cache
MESA_SHADER_CACHE_MAX_SIZE=12G

### Frame Rate Cap — 237 FPS (VRR-Dropout-Schutz bei 240Hz)
DXVK_FRAME_RATE=237
VKD3D_FRAME_RATE=237

### HDR (Für Wayland Compositor)
DXVK_HDR=1
PROTON_ENABLE_HDR=1
ENABLE_HDR_WSI=1
EOF
log "gaming.conf erstellt"

# ── sysctl tweaks ─────────────────────────────────────────────────────────────
info "sysctl vm.max_map_count setzen (Steam/Wine)..."
cat > /etc/sysctl.d/99-gaming.conf << 'EOF'
vm.max_map_count=2147483642
EOF
sysctl --system > /dev/null
log "sysctl konfiguriert"

# ── Vorlagen ──────────────────────────────────────────────────────────────────
info "Vorlagen-Verzeichnis anlegen..."
TEMPLATES_DIR="$USER_HOME/Vorlagen"
mkdir -p "$TEMPLATES_DIR"
touch "$TEMPLATES_DIR/Leere Textdatei.txt"
touch "$TEMPLATES_DIR/Dokument.md"
touch "$TEMPLATES_DIR/Skript.sh"
cat > "$TEMPLATES_DIR/Webseite.html" << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Titel</title>
</head>
<body>
</body>
</html>
EOF
chown -R "$CURRENT_USER:$CURRENT_USER" "$TEMPLATES_DIR"
log "Vorlagen angelegt"

# ── Tastatur & Berechtigungen ─────────────────────────────────────────────────
info "Tastaturlayout auf Deutsch setzen..."
localectl set-keymap de
localectl set-x11-keymap de

info "Berechtigungen Home-Verzeichnis setzen..."
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME"
log "Berechtigungen gesetzt"

# ── Abschluss ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Base-Setup abgeschlossen! (Team Red)${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Nächste Schritte:${NC}"
echo -e "  • Desktop-Umgebung wählen:  ${BOLD}bash install-de.sh${NC}"
echo -e "  • Oder direkt:              ${BOLD}bash gnome-setup.sh${NC} / ${BOLD}bash kde-setup.sh${NC}"
echo ""
