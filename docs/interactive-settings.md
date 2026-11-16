# Interactive settings implementation report

Local feature branch: `feat/interactive-settings`; plugin version: `1.2.0`.
No release, push, merge, or installed-plugin replacement is part of this change.

## Architecture

`Config` is the single source of truth for personal TOML overrides. All controls
use its validated setters and share its effective defaults/overrides/pending
view. Writes are debounced, atomic, and patch the latest document rather than
regenerating it. Unrelated external changes are retained; same-key conflicts
stop persistence with an error. Invalid input leaves the existing file intact.

`Placement` owns version-1 runtime JSON, preserving monitor positions, sizes and
lock state while adding optional per-monitor anchors. Explicit anchor changes
clear only the selected monitor's drag position. User configuration and runtime
state remain in their existing XDG locations outside the checkout.

`Service` retains the desktop drag/resize surfaces and owns one menu and one
settings window. The desktop never requests keyboard focus. The bounded menu
uses a temporary overlay; the configuration panel is a managed native window.
Omarchy buttons, toggles, dropdowns, text fields, number fields, separators and
confirmation UI are reused. No web stack or GUI helper runtime was added.

The layout model retains the original design coordinates. Order determines
stacking; free coordinates remain independent. The preview edits that exact
model. Decoration follows component visibility/customization. All component
visibility is independent, and the rendered spectrum follows the configured
bar count. Cava restarts only for process-affecting settings; sensitivity is
applied to samples without restarting.

Weather uses cancelable bounded requests and generation guards, separate
suggestion/forecast channels, validated location selections and immediate
configuration-change refreshes. Requests stop on weather disable; closing the
panel also cancels city search.

## Added files

- `AdvancedSettings.qml`, `AnchorSelector.qml`, `CitySearch.qml`
- `ComponentEditor.qml`, `ContextMenu.qml`, `HttpRequest.qml`
- `LayoutEditor.qml`, `Placement.qml`, `SettingControl.qml`
- `SettingsPanel.qml`, `SettingsModel.js`, `SettingsPages.js`, `WeatherModel.js`
- `scripts/check-runtime`
- `tests/config.test.cjs`, `tests/runtime/shell.qml`, `tests/runtime/curl`
- `docs/interactive-settings.md`

## Modified files

- `Config.qml`, `Toml.js`: validated read/write document infrastructure
- `Service.qml`: shared placement integration, menu/panel host, recovery IPC
- `AioWidget.qml`: independent components, real layout positions/order, editor,
  opacity isolation and configured spectrum count
- `Weather.qml`, `AudioBars.qml`, `scripts/cava-stream`: request/process lifecycle
- `Theme.qml`: XDG-aware theme loading and invalid-theme protection
- `config.toml`, `qmldir`, `manifest.json`, `i18n/en.json`: defaults, types,
  version and localization resources
- `README.md`, `tests/plugin.test.cjs`: documentation and regression coverage

## Configuration additions

- `show_weekday`, `live_preview`
- `weather.label`, `weather.location_city`, `weather.latitude`,
  `weather.longitude` for validated city choices
- `layout.order`, `layout.snap`, `layout.<component>.x/y`
- Optional `anchors` map in placement JSON (schema version remains 1)

The existing options remain supported. Bundled defaults are never edited by the
settings UI. The default rendered spectrum count is 34, preserving the original
composition; existing explicit personal counts are now rendered faithfully.

## Verification

- Omarchy plugin manifest validation passed.
- 17 individual Node test cases passed (14 configuration/model cases plus
  3 existing/helper cases); the requested `node --test tests/*.test.cjs` also
  passed.
- `bash -n` and ShellCheck passed for the Cava helper, runtime runner and fixture.
- QML formatting and linting completed. Lint retains dynamic Omarchy Style/type
  metadata and uncreatable-PanelWindow metadata warnings; no syntax, unresolved
  import, or read-only-assignment failures remain. The actual Quickshell engine
  successfully creates these types.
- Isolated Wayland runtime suite passed: all categories, persisted writes,
  external-edit merging, validated city suggestions, live unit changes,
  invalid-city preservation, cancellation, and edge-of-screen menus.
- Settings/layout window visually inspected. Runtime testing used temporary XDG
  directories and fixture weather; personal configuration and the installed
  plugin were not changed.

## Limits and release checks

The TOML implementation supports the plugin's types and common scalar/array/
inline-table/nested-section syntax, not every TOML feature. Arrays of tables are
reported as unsupported and are never silently rewritten. New UI strings ship
in English and use Omarchy's existing locale/fallback mechanism.

Before release, manually verify pointer drag/resize and component reordering,
keyboard traversal, real PipeWire/Cava behavior, physical monitor reconnection,
fractional scaling, and light/dark theme transitions on the target desktop.
The automated suite does not emulate physical display changes or audio hardware.
