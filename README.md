# Fedorabase

A modular post-install script collection for **Fedora 44** — minimal TTY base to fully configured desktop in one run.

Built for AMD Ryzen + NVIDIA setups on Wayland. No Flatpak, no bloat, no compromises.

---

## Structure

```
fedorabase/
├── fedora-setup.sh     # Base setup — run this first
├── install-de.sh       # Interactive desktop selector
├── gnome-setup.sh      # GNOME 50
├── kde-setup.sh        # KDE Plasma 6.6
└── cosmic-setup.sh     # COSMIC Desktop
```

---

## Requirements

- Fedora 44 minimal install (Everything ISO, TTY)
- NVIDIA GPU (akmod-nvidia via RPM Fusion)
- Wired network connection
- Run as your user with sudo access

---

## Usage

```bash
sudo dnf install -y git
git clone https://github.com/pvtpiti78/fedorabase
cd fedorabase
sudo bash fedora-setup.sh
```

After base setup completes, reboot once to let akmods build the NVIDIA kernel module:

```bash
sudo reboot
```

Then install your desktop:

```bash
sudo bash install-de.sh
```

Or directly:

```bash
sudo bash gnome-setup.sh
sudo bash kde-setup.sh
sudo bash cosmic-setup.sh
```

---

## What fedora-setup.sh does

| Section | Details |
|---|---|
| **DNF5** | Parallel downloads (10), fastestmirror, deltarpm off |
| **RPM Fusion** | Free + Non-Free, OpenH264 enabled |
| **Flatpak** | Removed completely |
| **NVIDIA** | akmod-nvidia, cuda, vaapi, kernel-devel/headers |
| **Terra Repo** | Added after NVIDIA (prevents driver override) |
| **NTSYNC** | Enabled via modules-load.d (mainline since 6.14) |
| **Fish** | Default shell, DNF aliases, Git aliases |
| **Starship** | Tokyo Night prompt |
| **Kitty** | Tokyo Night theme, JetBrainsMono Nerd Font |
| **Fonts** | Noto (CJK, Emoji, Color), Liberation, DejaVu, JetBrainsMono NF |
| **GStreamer** | Full codec stack + ffmpeg |
| **Steam** | + Protontricks |
| **LACT** | NVIDIA undervolting/overclocking via COPR ilyaz/LACT |
| **ProtonPlus** | GE-Proton manager via COPR wehagy/protonplus |
| **Faugus Launcher** | Game launcher via COPR faugus/faugus-launcher |
| **dnf-app-center** | App store + extension manager via Nobara COPR |
| **Firefox** | + langpacks, no telemetry, no Pocket, hardware decoding, German UI |
| **nvidia.conf** | modprobe options (PAT, PCIe Gen3) |
| **gaming.conf** | Full DXVK/DLSS/MFG/NTSYNC/HDR/VRR environment |
| **nvidia ENV** | GBM_BACKEND, GLX, LIBVA, NVD_BACKEND, MOZ_DISABLE_RDD_SANDBOX |
| **sysctl** | vm.max_map_count=2147483642 |
| **Locale** | de_DE.UTF-8, keyboard layout de |
| **Permissions** | Full chown of $HOME at the end |

---

## Gaming Environment

The `gaming.conf` is identical to [Archbase](https://github.com/pvtpiti78/Archbase) and tuned for RTX 5080 + 240Hz OLED:

```
DLSS Preset M        — best quality/sharpness preset
50% scaling          — DLSS SR render ratio
Dynamic MFG          — up to 5x frame generation, target 240 FPS
237 FPS cap          — prevents VRR dropout below 240Hz ceiling
NTSYNC               — native kernel NT sync (no esync/fsync)
HDR                  — DXVK + Proton HDR enabled
VRR                  — fullscreen only (prevents gamma flicker on OLED)
```

---

## Desktop Environments

### GNOME 50
- Wayland-only (X11 removed upstream)
- GDM display manager
- Minimal package set — no GNOME Games, no GNOME Maps etc.
- Resources (system monitor) via COPR atim/resources
- Dash to Panel extension
- AppIndicator extension
- NVIDIA cursor bug workaround pre-configured (disabled by default)

> If cursor disappears or freezes under GNOME 50 + NVIDIA:
> Uncomment `MUTTER_DEBUG_DISABLE_HW_CURSORS=1` in `/etc/environment.d/gaming.conf`

### KDE Plasma 6.6
- Wayland
- Plasma Login Manager (replaces SDDM in F44)
- Minimal: plasma-desktop, dolphin, kate, ark, kscreen, bluedevil, powerdevil

### COSMIC
- Wayland
- cosmic-greeter display manager
- No cosmic-store, no cosmic-term
- `@cosmic-desktop-environment` group from Fedora repos (no COPR needed)

---

## Firefox Policies

Configured via `/usr/lib64/firefox/distribution/policies.json`:

- No telemetry (locked)
- No Pocket
- No sponsored content
- No onboarding
- Hardware video decoding (vaapi, dmabuf, webrender)
- German UI (`RequestedLocales: ["de", "en-US"]`)
- XDG portal file picker

---

## Related

- [Archbase](https://github.com/pvtpiti78/Archbase) — same philosophy for Arch Linux

---

## License

MIT
