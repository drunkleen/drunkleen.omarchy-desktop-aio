# Drunkleen Desktop AIO

**A little rhythm for your Omarchy desktop.**

Weather, a bold weekday, a clock and date, a live audio spectrum, and your
now-playing track — together in a compact card that follows your Omarchy theme.

![Desktop AIO layout illustration](preview.png)

*Layout illustration with sample data. Colors follow your active theme.*

## Make it yours

- **Move it once.** Right-click → **Unlock position**, drag with the left mouse
  button, then right-click → **Lock position**. An accent outline marks edit mode.
- **Keep it where it belongs.** Position is remembered per monitor, outside the
  plugin checkout. It survives shell restarts and plugin updates.
- **Stay out of the way.** A bottom-layer Wayland surface sits above the wallpaper
  and below application windows. Only the card accepts pointer input; it never
  takes keyboard focus.
- **Match your desktop.** Text and spectrum colors follow the current Omarchy
  theme. Override colors, fonts, scale, components, or monitor selection.
- **See the music.** Cava visualizes PipeWire playback; MPRIS provides track and
  artist information from compatible players.

## Install

Requires **Omarchy Quattro** with its Quickshell plugin system. This is an
Omarchy plugin, not a standalone Quickshell configuration.

Install the runtime dependencies:

```bash
omarchy pkg add cava inter-font ttf-material-symbols-variable curl
```

Add and enable the plugin:

```bash
omarchy plugin add https://github.com/drunkleen/drunkleen.omarchy-desktop-aio --enable
omarchy restart shell
```

For unattended setup, append `--yes` to the `plugin add` command.
Plugin ID: `drunkleen.desktop-aio`. Omarchy supplies Quickshell, Qt SVG, Bash,
and PipeWire; Inter and Material Symbols provide the intended typography.

## Configure

Personal settings live outside the Git checkout. Copy the defaults once:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/drunkleen.desktop-aio"
cp ~/.config/omarchy/plugins/drunkleen.desktop-aio/config.toml \
  "${XDG_CONFIG_HOME:-$HOME/.config}/drunkleen.desktop-aio/config.toml"
```

Edit that personal file. Changes reload live; plugin updates leave it alone.
You can also create a smaller file containing only your overrides:

```toml
monitor = "all"       # or comma-separated names, e.g. "DP-2,eDP-1"
anchor = "bottom-right"
margin_x = 56
margin_y = 56
scale = 0.55
opacity = 1.0
clock24h = true
show_weather = true
show_spectrum = true
show_media = true

[weather]
city = "London"
units = "metric"     # or "imperial"
refresh_seconds = 900
```

See [config.toml](config.toml) for every option, including component visibility,
fonts, ink/accent overrides and spectrum settings. Anchors accept `top-left`,
`top-center`, `top-right`, `center-left`, `center`, `center-right`, `bottom-left`,
`bottom-center`, `bottom-right`, and `free`. With `free`, set `x` and `y`.
Saved drag positions take precedence over configured anchors for that monitor.
`scale` is relative to the 708 × 454 design box.

### Saved placement

The lock state and normalized per-monitor positions are stored at:

```text
${XDG_STATE_HOME:-~/.local/state}/drunkleen.desktop-aio/placement.json
```

The file is written when you release a drag or toggle the lock, never into your
plugin checkout or dotfiles. Positions stay within the screen when its size
changes. Dragging is within a monitor; `monitor` controls which displays show a
card. The lock toggle applies to all cards.

To return to configured anchors, disable the plugin, move `placement.json` to a
backup, then enable it and restart the shell.

## Network and local access

With `show_weather = true`, the configured city is sent to Open-Meteo's HTTPS
geocoding API and its coordinates to the forecast API. Forecasts refresh every
15 minutes by default (minimum one minute); no API key or automatic location
lookup is used. Set `show_weather = false` to stop weather requests. Requests
have time and size limits. [Open-Meteo](https://open-meteo.com/) supplies weather
under [CC BY 4.0](https://open-meteo.com/en/licence).

Cava reads the PipeWire playback monitor for visualization. MPRIS track metadata
is read locally over the session bus. The plugin invokes `curl`, `mkdir`, and
its bundled Cava helper. It needs no root access and runs inside Omarchy's shell.

## Update, disable, remove

```bash
omarchy plugin update drunkleen.desktop-aio --yes
omarchy restart shell

omarchy plugin disable drunkleen.desktop-aio
omarchy plugin remove drunkleen.desktop-aio
```

Personal config and saved placement are intentionally retained. Remove those
separately if you want a completely fresh start.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Card is missing | Enable `drunkleen.desktop-aio`, restart the shell, and check `monitor` against `hyprctl monitors`. |
| Card will not move | Right-click and choose **Unlock position** first. Application windows must not cover the card. |
| Spectrum is flat | Play audio, check `cava` is installed, and ensure PipeWire playback is available. |
| Weather is unavailable | Check the configured city, internet access, and `show_weather`. The clock works without weather. |
| Icons look wrong | Install `ttf-material-symbols-variable` and restart the shell. |

## Development

```bash
git clone https://github.com/drunkleen/drunkleen.omarchy-desktop-aio
cd drunkleen.omarchy-desktop-aio
omarchy plugin validate .
node --test tests/*.test.cjs
bash -n scripts/cava-stream
```

The root `manifest.json` declares a `service` entry point in `Service.qml`.
`Config.qml` watches personal overrides; `Theme.qml` follows Omarchy colors;
`Weather.qml`, `AudioBars.qml`, and `Media.qml` supply the card's data.
Please include your Omarchy version and relevant shell log when reporting bugs.

## Credits and license

Created by [drunkleen](https://github.com/drunkleen). Adapted from
[Ryoku](https://github.com/Ryoku-dev/ryoku)'s desktop AIO design, audio bars and
weather code mapping. See [NOTICE](NOTICE) for attribution and source paths.

Distributed under [GPL-3.0-only](LICENSE). No Ryoku daemon or theme-generation
runtime is required. This is a community plugin and is not affiliated with the
Omarchy project.
