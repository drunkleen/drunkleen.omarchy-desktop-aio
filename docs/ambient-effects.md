# Ambient effects implementation

This is a local extension of `feat/interactive-settings`, version 1.3.0. It does
not push, merge, release, or replace the installed plugin or standalone service.
The existing uncommitted interactive-settings implementation is preserved.

## Files and decisions

- `ambient/Petal.qml`, `ambient/PetalField.qml`: adapted directly from the existing
  miyamoto.sakura-rain source. One fixed pool, one clock, original leaf silhouette,
  gradient shading, depth and obstacle easing; rain/snow share that lifecycle.
- `AmbientModel.js`: pure deterministic WMO/season/date/hemisphere selection,
  defaults, validation, limits, palettes and rendering settings.
- `Ambient.qml`: one shared selection/controller using existing weather and clock;
  mode setters and explicit legacy-overlay ownership handoff.
- `AmbientSurfaces.qml`: original background-layer/window-avoidance behavior,
  per-monitor pooling, fullscreen pause and no input/focus acquisition.
- `AmbientSettings.qml`: native settings, synchronized controls, resolved reason,
  preview, reset and confirmed handoff. Existing reusable controls are reused.
- `Service.qml`, `SettingsPages.js`, `SettingsPanel.qml`, `ContextMenu.qml`: host,
  category and submenu integration.
- `SettingsModel.js`, `config.toml`: validated `[ambient]` settings, Sakura defaults.
- `Weather.qml`, `WeatherModel.js`: retain accepted location latitude/city and
  Open-Meteo UTC offset for selection. No additional requests or provider.
- `qmldir`, `manifest.json`, `i18n/en.json`, `NOTICE`: types, version, translation
  catalog and source attribution.
- `tests/ambient.test.cjs`, `tests/config.test.cjs`, `tests/runtime/shell.qml`,
  `scripts/check-runtime`: policy, persistence and native lifecycle regression tests.
- `README.md`, `assets/ambient-effects.png`, this report: configuration, behavior
  and an actual isolated render of all six manual effects at increased size/density.

The original standalone Sakura source is a separate dotfiles package. It is not
modified or launched by this change. AIO suppresses its own desktop surfaces
while that legacy service is active/enabled (or the legacy config is running).
Switching ownership is an explicit confirmed UI action, preserving source/config.
Preview pools exist only inside settings and use the same engine, not a competing
full-desktop overlay. Future manual starts of the legacy overlay should be
followed by the panel's recheck action; do not intentionally run both owners.

## Default and fallback policy

The sole enable flag is `ambient.enabled`; disabling retains `ambient.mode`.
Sakura is the backward-compatible default. Automatic never creates winter snow
without a snowfall code, never enables weather requests and ignores unavailable
or mismatched forecasts. Southern latitudes reverse the four meteorological
seasons. Unavailable latitude uses north; unavailable UTC offset uses local time.
The shared existing clock handles season changes and resume-time jumps.

Effect changes fade inside one 128-item pool. Disable clears immediately and
stops the timer; hidden/fullscreen surfaces pause, and zero-density fields stop
after draining. Fixed retained vector objects avoid frame-by-frame QML object
creation. Per-frame motion uses scalar state and cached obstacle rectangles.

## Verification and remaining checks

Run all existing validation plus `node --test tests/*.test.cjs` and the optional
`./scripts/check-runtime` under an unlocked Wayland session. The runner uses
isolated XDG settings and fixture forecasts and does not execute ownership
handoff or modify the real standalone service.

The graphical preview covers Sakura, each leaf palette, rain and snow. Runtime
checks exercise the Ambient Effects category, manual/automatic mode changes,
weather privacy, a bounded pool and frozen frame counters when disabled/hidden.
Release verification should additionally include real monitor disconnects,
fullscreen transitions, long-running CPU/GPU/power measurements, light wallpaper
contrast and the actual confirmed legacy-service handoff on the target machine.

Completed checks: 29 individual Node test cases (12 ambient, 14 configuration,
3 existing/helper), requested Node test-runner command, Omarchy manifest
validation, shell syntax and ShellCheck passed. The isolated native runtime
suite passed and all six vector effects were visually inspected. QML lint
retains existing dynamic-type/Style metadata warnings and dynamic Repeater
item-type warnings; no syntax/unresolved-import/read-only-assignment errors
were found. The standalone Sakura service was not stopped or disabled.
