pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Toml.js" as Toml

// User configuration, read from
// ~/.config/drunkleen.desktop-aio/config.toml, over bundled defaults.
// The file is watched, so edits apply live.
QtObject {
  id: root

  readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")) + "/drunkleen.desktop-aio/config.toml"

  property var defaults: Toml.parse(defaultFile.text())
  property var overrides: ({})
  readonly property var data: Object.assign({}, defaults, overrides)
  property FileView defaultFile: FileView {
    path: Qt.resolvedUrl("config.toml")
    blockLoading: true
    watchChanges: true
    onFileChanged: reload()
  }

  function get(key, fallback) {
    var v = root.data ? root.data[key] : undefined;
    return (v === undefined || v === null || v === "") ? fallback : v;
  }

  function section(name) {
    return Object.assign({}, root.defaults[name] || {}, root.overrides[name] || {});
  }

  property FileView file: FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    onLoaded: root.overrides = Toml.parse(text())
    onLoadFailed: root.overrides = ({})
    onFileChanged: reload()
  }

  // placement
  readonly property string monitor: get("monitor", "all")
  readonly property string anchor: get("anchor", "top-right")
  readonly property int marginX: get("margin_x", 56)
  readonly property int marginY: get("margin_y", 56)
  readonly property int freeX: get("x", 0)
  readonly property int freeY: get("y", 0)
  readonly property real scale: Math.max(0.1, Math.min(3, get("scale", 0.55)))
  readonly property real opacity: Math.max(0, Math.min(1, get("opacity", 1.0)))

  // components
  readonly property bool showClock: get("show_clock", true)
  readonly property bool showDate: get("show_date", true)
  readonly property bool showWeather: get("show_weather", true)
  readonly property bool showSpectrum: get("show_spectrum", true)
  readonly property bool showMedia: get("show_media", true)

  // clock
  readonly property bool clock24h: get("clock24h", true)

  // fonts
  readonly property string fontDisplay: get("font_display", "Inter Display")
  readonly property string fontIcon: get("font_icon", "Material Symbols Rounded")

  // colour overrides ("" = follow the Omarchy theme)
  readonly property string ink: get("ink", "")
  readonly property string accent: get("accent", "")

  // weather
  readonly property var weatherSec: section("weather")
  readonly property string city: weatherSec.city !== undefined ? weatherSec.city : "Tehran"
  readonly property int refreshSeconds: weatherSec.refresh_seconds !== undefined ? weatherSec.refresh_seconds : 900
  readonly property string units: weatherSec.units !== undefined ? weatherSec.units : "metric"

  // spectrum
  readonly property var spectrumSec: section("spectrum")
  readonly property int bars: spectrumSec.bars !== undefined ? spectrumSec.bars : 40
  readonly property int fps: spectrumSec.fps !== undefined ? spectrumSec.fps : 30
  readonly property int smoothing: spectrumSec.smoothing !== undefined ? spectrumSec.smoothing : 45
  readonly property real sensitivity: spectrumSec.sensitivity !== undefined ? spectrumSec.sensitivity : 1.0

  // media
  readonly property var mediaSec: section("media")
  readonly property int mediaMaxWidth: mediaSec.max_width !== undefined ? mediaSec.max_width : 320
}
