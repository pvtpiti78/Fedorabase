#!/bin/bash
# =============================================================================
# fedora-setup.sh — Fedora 44 Base Setup
# =============================================================================
# Ausgangslage: Minimale Fedora 44 TTY-Installation
# Umfang: DNF5-Tuning, RPM Fusion, akmod-nvidia, Fish, Kitty, Starship,
#         Fastfetch, Firefox, Steam, ProtonPlus, Faugus, LACT, nvidia.conf, gaming.conf
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

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
echo "  ███████╗███████╗██████╗  ██████╗ ██████╗  █████╗ "
echo "  ██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗"
echo "  █████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║"
echo "  ██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║"
echo "  ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║"
echo "  ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "  ${BOLD}Fedora 44 — Base Setup${NC}"
echo -e "  akmod-nvidia · Fish · Kitty · Starship · Gaming ENV"
echo ""
echo -e "  ${YELLOW}Dieses Script richtet das System neu ein.${NC}"
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

# ── Flatpak deaktivieren ──────────────────────────────────────────────────────
info "Flatpak deaktivieren und entfernen..."
dnf remove -y flatpak flatpak-libs 2>/dev/null || true
rm -rf /var/lib/flatpak
rm -rf ~/.local/share/flatpak
log "Flatpak entfernt"

# ── Basis-Pakete ──────────────────────────────────────────────────────────────
info "Basis-Pakete installieren..."
dnf install -y \
    git \
    curl \
    wget \
    unzip \
    p7zip \
    p7zip-plugins \
    btop \
    fastfetch \
    bash-completion \
    pciutils \
    usbutils \
    lshw \
    rsync \
    vim \
    nano \
    man-db \
    xdg-utils \
    xdg-user-dirs \
    pipewire \
    pipewire-pulseaudio \
    wireplumber \
    power-profiles-daemon \
    hunspell \
    hunspell-de \
    hunspell-en
log "Basis-Pakete installiert"

# ── power-profiles-daemon ─────────────────────────────────────────────────────
info "power-profiles-daemon aktivieren..."
systemctl enable --now power-profiles-daemon
log "power-profiles-daemon aktiv"

# ── Nvidia akmod-nvidia ───────────────────────────────────────────────────────
info "Nvidia-Treiber (akmod-nvidia) installieren..."
dnf install -y \
    akmod-nvidia \
    xorg-x11-drv-nvidia-cuda \
    xorg-x11-drv-nvidia-libs.i686 \
    libva-nvidia-driver \
    libva-utils \
    kernel-devel \
    kernel-headers
log "Nvidia-Treiber installiert (akmods baut beim nächsten Boot)"

# ── Terra Repo ────────────────────────────────────────────────────────────────
info "Terra Repo aktivieren (nach Nvidia — verhindert Treiber-Überschreibung)..."
dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
log "Terra Repo aktiviert"

# ── NTSYNC explizit laden ─────────────────────────────────────────────────────
info "NTSYNC konfigurieren..."
echo "ntsync" > /etc/modules-load.d/ntsync.conf
log "NTSYNC aktiviert"

# ── Fish Shell ────────────────────────────────────────────────────────────────
info "Fish Shell installieren..."
dnf install -y fish

CURRENT_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$CURRENT_USER")

chsh -s /usr/bin/fish "$CURRENT_USER"

mkdir -p "$USER_HOME/.config/fish"
cat > "$USER_HOME/.config/fish/config.fish" << 'EOF'
# Fish Config — Fedora 44
if status is-interactive
    # Starship prompt
    starship init fish | source

    # Fastfetch beim Start
    fastfetch

    # Aliase
    alias ls='ls --color=auto'
    alias ll='ls -lah --color=auto'
    alias grep='grep --color=auto'
    alias df='df -h'
    alias free='free -h'
    alias ..='cd ..'
    alias ...='cd ../..'

    # DNF-Shortcuts
    alias update='sudo dnf upgrade -y --refresh'
    alias install='sudo dnf install -y'
    alias remove='sudo dnf remove -y'
    alias search='dnf search'

    # Cache leeren
    alias clean='sudo dnf clean all'

    # Systemd
    alias ss='sudo systemctl status'
    alias sr='sudo systemctl restart'
    alias se='sudo systemctl enable'

    # Git
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
conflicted = "⚡"
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
untracked = "?"
modified = "!"
staged = "+"
deleted = "✘"

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
# =============================================================================
# Kitty Terminal Configuration
# Theme: Tokyo Night
# =============================================================================

# Font
font_family      JetBrainsMono Nerd Font
bold_font        JetBrainsMono Nerd Font Bold
italic_font      JetBrainsMono Nerd Font Italic
bold_italic_font JetBrainsMono Nerd Font Bold Italic
font_size        13.0

# Tokyo Night Colors
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

# Window
window_padding_width    12
background_opacity      0.95
hide_window_decorations no
remember_window_size    yes

# Cursor
cursor_shape            block
cursor_blink_interval   0

# Performance
sync_to_monitor         yes
confirm_os_window_close 0

# Tab bar
tab_bar_style           powerline
tab_powerline_style     slanted
EOF

chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/kitty"
log "Kitty konfiguriert"

# ── Fonts ─────────────────────────────────────────────────────────────────────
info "System-Fonts installieren (Noto, Liberation, DejaVu, Emoji)..."
dnf install -y \
    google-noto-fonts-common \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    google-noto-mono-fonts \
    google-noto-emoji-fonts \
    google-noto-emoji-color-fonts \
    google-noto-cjk-fonts \
    liberation-fonts \
    dejavu-fonts-all \
    jetbrains-mono-fonts
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
    gstreamer1 \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good \
    gstreamer1-plugins-good-extras \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-ugly \
    gstreamer1-plugin-libav \
    ffmpeg \
    ffmpeg-libs \
    libva \
    libva-utils || true
log "GStreamer + Codecs installiert"

# ── Gaming-Tools ──────────────────────────────────────────────────────────────
info "Gaming-Tools installieren (Steam, Protontricks)..."
dnf install -y \
    steam \
    protontricks
log "Gaming-Tools installiert"

# ── LACT (Nvidia Undervolting) ────────────────────────────────────────────────
info "LACT installieren..."
dnf copr enable -y ilyaz/LACT
dnf install -y lact
systemctl enable --now lactd
log "LACT installiert"

# ── Gaming Launcher ───────────────────────────────────────────────────────────
info "Gaming Launcher installieren (ProtonPlus, Faugus)..."
# ProtonPlus (https://copr.fedorainfracloud.org/coprs/wehagy/protonplus/)
dnf copr enable -y wehagy/protonplus
dnf install -y protonplus
log "Gaming Launcher installiert (soweit verfügbar)"

# ── Firefox ───────────────────────────────────────────────────────────────────
info "Firefox installieren..."
dnf install -y firefox firefox-langpacks

info "Firefox policies.json konfigurieren (kein Telemetry, kein Pocket)..."
FIREFOX_POLICIES_DIR="/usr/lib64/firefox/distribution"
mkdir -p "$FIREFOX_POLICIES_DIR"
cat > "$FIREFOX_POLICIES_DIR/policies.json" << 'EOF'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisableFirefoxAccounts": false,
    "DisablePocket": true,
    "DisableFormHistory": false,
    "DontCheckDefaultBrowser": true,
    "NoDefaultBookmarks": true,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",

    "FirefoxHome": {
      "Search": true,
      "TopSites": false,
      "SponsoredTopSites": false,
      "Highlights": false,
      "Pocket": false,
      "SponsoredPocket": false,
      "Snippets": false,
      "Locked": false
    },

    "UserMessaging": {
      "WhatsNew": false,
      "ExtensionRecommendations": false,
      "FeatureRecommendations": false,
      "UrlbarInterventions": false,
      "SkipOnboarding": true,
      "MoreFromMozilla": false,
      "Locked": false
    },

    "Preferences": {
      "media.ffmpeg.vaapi.enabled":                      { "Value": true,  "Status": "default" },
      "media.rdd-ffmpeg.enabled":                        { "Value": true,  "Status": "default" },
      "media.hardware-video-decoding.force-enabled":     { "Value": true,  "Status": "default" },
      "widget.dmabuf.force-enabled":                     { "Value": true,  "Status": "default" },
      "media.av1.enabled":                               { "Value": true,  "Status": "default" },
      "media.ffvpx.enabled":                             { "Value": false, "Status": "default" },
      "gfx.webrender.all":                               { "Value": true,  "Status": "default" },
      "widget.use-xdg-desktop-portal.file-picker":       { "Value": 1,     "Status": "default" },
      "widget.wayland.opaque-region.enabled":            { "Value": false, "Status": "default" },
      "apz.gtk.kinetic_scroll.enabled":                  { "Value": false, "Status": "default" },
      "intl.locale.requested":                              { "Value": "de,en-US", "Status": "default" },
      "browser.newtabpage.activity-stream.feeds.telemetry": { "Value": false, "Status": "locked" },
      "browser.newtabpage.activity-stream.telemetry":    { "Value": false, "Status": "locked" },
      "browser.ping-centre.telemetry":                   { "Value": false, "Status": "locked" },
      "toolkit.telemetry.unified":                       { "Value": false, "Status": "locked" },
      "toolkit.telemetry.enabled":                       { "Value": false, "Status": "locked" },
      "datareporting.healthreport.uploadEnabled":        { "Value": false, "Status": "locked" },
      "datareporting.policy.dataSubmissionEnabled":      { "Value": false, "Status": "locked" },
      "browser.crashReports.unsubmittedCheck.autoSubmit2": { "Value": false, "Status": "locked" },
      "browser.tabs.crashReporting.sendReport":          { "Value": false, "Status": "locked" }
    }
  }
}
EOF

log "Firefox installiert und konfiguriert"

# ── nvidia.conf ───────────────────────────────────────────────────────────────
info "nvidia.conf (Gaming-ENV) erstellen..."
cat > /etc/modprobe.d/nvidia.conf << 'EOF'
# Nvidia — Fedora 44
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_EnablePCIeGen3=1
options nvidia NVreg_RegistryDwords="PerfLevelSrc=0x2222"
EOF

# ── gaming.conf (Environment Variables) ──────────────────────────────────────
info "gaming.conf (Systemd Environment) erstellen..."
mkdir -p /etc/environment.d
cat > /etc/environment.d/gaming.conf << 'EOF'
### OpenGL
__GL_SYNC_TO_VBLANK=0
__GL_MaxFramesAllowed=1
__GL_GSYNC_ALLOWED=1
__GL_VRR_ALLOWED=1
__GL_SHADER_DISK_CACHE_SIZE=12000000000

### Proton / Wayland
PROTON_ENABLE_NGX_UPDATER=1
PROTON_ENABLE_WAYLAND=1
PROTON_ENABLE_NVAPI=1
PROTON_VKD3D_HEAP=1
PROTON_USE_NTSYNC=1

### NTSYNC — kein esync/fsync
WINEFSYNC=0
WINEESYNC=0

### DLSS SR — Preset M, 50% Skalierung
DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE=on
DXVK_NVAPI_DRS_NGX_DLSS_SR_MODE=custom
DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_SCALING_RATIO=50
DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest

### DLSS RR
DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE=on
DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest

### Frame Generation — Dynamic MFG
DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE=on
DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest
DXVK_NVAPI_DRS_NGX_DLSSG_MODE=dynamic
DXVK_NVAPI_DRS_NGX_DLSSG_DYNAMIC_TARGET_FRAME_RATE=240
DXVK_NVAPI_DRS_NGX_DLSSG_DYNAMIC_MULTI_FRAME_COUNT_MAX=5

### Frame Rate Cap — 237 FPS (VRR-Dropout-Schutz bei 240Hz)
DXVK_FRAME_RATE=237
VKD3D_FRAME_RATE=237

### HDR
DXVK_HDR=1
PROTON_ENABLE_HDR=1
ENABLE_HDR_WSI=1

### Debug (DLSS + DLSSG Indicator)
DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS="DLSSIndicator=1024,DLSSGIndicator=2"
EOF

log "nvidia.conf und gaming.conf erstellt"

# ── nvidia.conf ENV (Wayland/Vulkan) ─────────────────────────────────────────
info "nvidia.conf ENV erstellen..."
cat > /etc/environment.d/nvidia.conf << 'EOF'
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
ELECTRON_OZONE_PLATFORM_HINT=auto

# Hardware-Decoding Firefox
MOZ_DISABLE_RDD_SANDBOX=1
EOF
log "nvidia.conf ENV erstellt"

# ── sysctl tweaks ─────────────────────────────────────────────────────────────
info "sysctl vm.max_map_count setzen (Steam/Wine)..."
cat > /etc/sysctl.d/99-gaming.conf << 'EOF'
vm.max_map_count=2147483642
EOF
sysctl --system > /dev/null
log "sysctl konfiguriert"

# ── Vorlagen (Rechtsklick → Neu erstellen) ────────────────────────────────────
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

# ── Tastatur auf Deutsch ─────────────────────────────────────────────────────
info "Tastaturlayout auf Deutsch setzen..."
localectl set-keymap de
localectl set-x11-keymap de
log "Tastaturlayout gesetzt"

# ── Berechtigungen Home-Verzeichnis ──────────────────────────────────────────
info "Berechtigungen Home-Verzeichnis setzen..."
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME"
log "Berechtigungen gesetzt"

# ── Abschluss ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Base-Setup abgeschlossen!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Nächste Schritte:${NC}"
echo -e "  • Desktop-Umgebung wählen:  ${BOLD}bash install-de.sh${NC}"
echo -e "  • Oder direkt:              ${BOLD}bash gnome-setup.sh${NC} / ${BOLD}bash kde-setup.sh${NC}"
echo ""
echo -e "  ${YELLOW}Neustart empfohlen vor DE-Installation (Nvidia-Module laden)${NC}"
echo ""
