pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Toml.js" as Toml
import "SettingsModel.js" as Model

QtObject {
  id: root
  readonly property string directory: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "")
                                                                             + "/.config"))
                                      + "/drunkleen.desktop-aio"
  readonly property string path: directory + "/config.toml"
  property var defaults: Toml.parse(defaultFile.text())
  property var overrides: ({})
  property var pending: ({})
  property var baseline: ({})
  property string diskText: ""
  property string error: ""
  property string notice: ""
  property bool ready: false
  property bool writing: false
  property bool exists: false
  property bool invalid: false
  readonly property bool dirty: Object.keys(pending).length > 0
  readonly property var data: {
    var flat = Object.assign({}, Toml.flatten(overrides), pending), out = {};
    Object.keys(flat).forEach(function (k) {
      if (flat[k] !== undefined)
        Toml.put(out, Toml.keyPath(k), flat[k]);
    });
    return Toml.merge(defaults, out);
  }
  function get(key, fallback) {
    var v = data[key];
    return v === undefined ? fallback : v;
  }
  function section(name) {
    return data[name] || {};
  }
  function setValue(key, value) {
    var values = {};
    values[key] = value;
    return setValues(values);
  }
  function setSectionValue(section, key, value) {
    return setValue(section + "." + key, value);
  }
  function setValues(values) {
    try {
      if (invalid || !ready)
        throw Error("Repair or reload the personal configuration before saving");
      var next = Object.assign({}, pending), base = Object.assign({}, baseline), flat = Toml.flatten(
                                                                                   overrides);


      if (Object.prototype.hasOwnProperty.call(values, 'weather.city') &&
          !Object.prototype.hasOwnProperty.call(values, 'weather.latitude')) {
        values = Object.assign({}, values, {
                                 'weather.latitude': undefined,
                                 'weather.longitude': undefined,
                                 'weather.label': undefined
                               });
      }
      Object.keys(values).forEach(function (k) {
        Model.validate(k, values[k]);
        if (!Object.prototype.hasOwnProperty.call(next, k))
          base[k] = JSON.stringify(flat[k]);
        next[k] = values[k];
      });
      baseline = base;
      pending = next;
      error = "";
      debounce.restart();
      return true;
    } catch (e) {
      error = String(e);
      return false;
    }
  }
  function resetValue(key) {
    return setValue(key, undefined);
  }
  function resetSection(section) {
    var changes = {}, flat = Object.assign({}, Toml.flatten(overrides), pending);
    Object.keys(flat).forEach(function (k) {
      if (k === section || k.indexOf(section + ".") === 0)
        changes[k] = undefined;
    });
    return setValues(changes);
  }
  function resetKeys(keys) {
    var c = {};
    keys.forEach(function (k) {
      c[k] = undefined;
    });
    return setValues(c);
  }
  function resetAll() {
    var c = {};
    Object.keys(Object.assign({}, Toml.flatten(overrides), pending)).forEach(function (k) {
      c[k] = undefined;
    });
    return setValues(c);
  }
  function validateText(text) {
    var parsed = Toml.parse(text), flat = Toml.flatten(parsed);
    Object.keys(flat).forEach(function (k) {
      Model.validate(k, flat[k]);
    });
    return parsed;
  }
  function accept(text) {
    if (writing)
      return;
    try {
      var parsed = validateText(text);
      diskText = text;
      overrides = parsed;
      invalid = false;
      if (!dirty)
        error = "";
    } catch (e) {
      invalid = true;
      error = String(e);
    }
  }
  function flush() {
    if (!dirty || writing || !ready || invalid)
      return;
    try {
      // Synchronous reread immediately before patching: merge unrelated editor changes.
      file.reload();
      var latest = exists ? file.text() : "";
      if (invalid)
        throw Error(error);
      var parsed = validateText(latest), flat = Toml.flatten(parsed);
      Object.keys(pending).forEach(function (k) {
        if (JSON.stringify(flat[k]) !== baseline[k] && JSON.stringify(flat[k]) !== JSON.stringify(pending[k]))
          throw Error("External edit conflicts with " + k + ". Reload before retrying.");
      });
      var output = Toml.patch(latest, pending);
      validateText(output);
      writing = true;
      file.setText(output);
      file.waitForJob();
      writing = false;
      // onSaved completes the transaction; failed writes retain pending values.
    } catch (e) {
      writing = false;
      error = String(e);
    }
  }
  function reload() {
    pending = ({});
    baseline = ({});
    invalid = false;
    file.reload();
    file.text();
  }
  function ensureFile() {
    if (exists)
      return true;
    if (invalid)
      return false;
    if (!exists) {
      file.setText("# Desktop AIO personal overrides\n");
      file.waitForJob();
    }
    return exists;
  }
  function edit() {
    if (ensureFile())
      Quickshell.execDetached(["omarchy", "launch", "editor", path]);
  }
  function openDirectory() {
    Quickshell.execDetached(["xdg-open", directory]);
  }
  function exportTo(path) {
    try {
      flush();
      if (error)
        throw Error(error);
      if (!path.startsWith("/"))
        throw Error("Use an absolute file path");
      transfer.path = path;
      var values = Toml.flatten(data);
      values['layout.order'] = Model.order(layout);
      transfer.setText(Toml.patch("# Desktop AIO export\n", values));
      transfer.waitForJob();
    } catch (e) {
      error = String(e);
    }
  }
  function readImport(path) {
    error = "";
    if (!path.startsWith("/"))
      throw Error("Use an absolute file path");
    transfer.path = path;
    transfer.reload();
    var text = transfer.text();
    if (error)
      throw Error(error);
    validateText(text);
    return text;
  }
  function importText(text) {
    return setValues(Toml.flatten(validateText(text)));
  }
  property FileView defaultFile: FileView {
    path: Qt.resolvedUrl("config.toml")
    blockLoading: true
  }
  property FileView file: FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    blockAllReads: true
    blockWrites: true
    onLoaded: {
      root.exists = true;
      root.accept(text());
    }
    onFileChanged: if (!root.writing)
                     reload()
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound) {
        root.exists = false;
        root.accept("");
      } else {
        root.invalid = true;
        root.error = "Unable to read personal configuration (" + error + ")";
      }
    }
    onSaved: {
      root.exists = true;
      root.pending = ({});
      root.baseline = ({});
      root.diskText = text();
      root.writing = false;
      root.accept(text());
      root.notice = "saved";
    }
    onSaveFailed: error => {
      root.writing = false;
      root.error = "Unable to save configuration (" + error + ")";
    }
  }
  property FileView transfer: FileView {
    blockAllReads: true
    blockWrites: true
    printErrors: false
    onSaveFailed: error => root.error = "Export failed (" + error + ")"
    onLoadFailed: error => root.error = "Import failed (" + error + ")"
  }
  property Timer debounce: Timer {
    interval: 300
    onTriggered: root.flush()
  }
  property Process initialize: Process {
    command: ["mkdir", "-p", root.directory]
    running: true
    onExited: code => {
      root.ready = code === 0;
      if (code !== 0)
        root.error = "Cannot create configuration directory";
    }
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
  readonly property bool showWeekday: get("show_weekday", true)
  readonly property bool livePreview: get("live_preview", true)
  readonly property var layout: section("layout")
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
  readonly property int refreshSeconds: weatherSec.refresh_seconds !== undefined ? weatherSec.refresh_seconds :
                                                                                   900
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
