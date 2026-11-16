pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "AmbientModel.js" as Model

QtObject {
  id: root
  readonly property var config: Model.normalize(Config.section("ambient"))
  readonly property bool enabled: config.enabled
  readonly property bool weatherMatches: Weather.locationCity === Config.city
  readonly property var latitude: {
    var w = Config.weatherSec;
    if (Model.validLatitude(w.latitude) && (!w.location_city || w.location_city === Config.city))
      return w.latitude;
    return weatherMatches ? Weather.locationLatitude : null;
  }
  readonly property var utcOffset: weatherMatches ? Weather.utcOffsetSeconds : null
  // Shared clock detects month/date boundaries and time jumps after resume.
  // Only a changed month invalidates the seasonal selection.
  readonly property int month: Model.localMonth(Now.now, utcOffset)
  property int resumeRevision: 0
  property real previousTick: 0
  property Connections clockWatch: Connections {
    target: Now
    function onNowChanged() {
      var ms = Now.now.getTime();
      if (root.previousTick > 0 && (ms - root.previousTick > 5000 || ms < root.previousTick)) {
        root.resumeRevision++;
        root.checkLegacy();
      }
      root.previousTick = ms;
    }
  }
  readonly property var resolution: {
    var revision = resumeRevision;
    return Model.resolveAtMonth(config, {
                                  available: Config.showWeather && Weather.available && Weather.status
                                             !== "error" && weatherMatches,
                                  code: Weather.code,
                                  latitude: latitude
                                }, month);
  }
  readonly property string effect: resolution.effect
  readonly property string reason: resolution.reason
  readonly property var settings: Model.settings(config, effect)
  property bool legacyChecked: false
  property bool legacyOwned: false
  property string error: ""
  readonly property bool ownsDesktop: Model.ownsSurface(enabled, legacyChecked, legacyOwned)

  function setMode(mode) {
    if (mode === 'disabled')
      Config.setSectionValue('ambient', 'enabled', false);
    else
      Config.setValues({
                         'ambient.enabled': true,
                         'ambient.mode': mode
                       });
  }
  function checkLegacy() {
    if (!check.running)
      check.running = true;
  }
  function takeOwnership() {
    if (!takeover.running) {
      error = '';
      takeover.running = true;
    }
  }
  property Process check: Process {
    // Treat an enabled legacy unit as an owner even before it starts, avoiding
    // a startup race between two full-desktop overlays. No polling timer.
    command: ["bash", "-c",
      "systemctl --user is-active --quiet sakura-rain.service 2>/dev/null || systemctl --user is-enabled --quiet sakura-rain.service 2>/dev/null || qs list -j | jq -e 'any(.[]; .config_path | contains(\"/quickshell/sakura-rain/\"))' >/dev/null"]
    running: true
    onExited: code => {
      root.legacyOwned = code === 0;
      root.legacyChecked = true;
    }
  }
  property Process takeover: Process {
    // Explicit, confirmed migration only. Preserve all legacy config/source.
    command: ["bash", "-c",
      "if systemctl --user cat sakura-rain.service >/dev/null 2>&1; then systemctl --user disable --now sakura-rain.service || exit 1; fi; qs kill -p \"$HOME/.config/quickshell/sakura-rain\" --any-display >/dev/null 2>&1 || true"]
    onExited: code => {
      if (code !== 0)
        root.error = 'ambient.takeoverError';
      root.checkLegacy();
    }
  }
}
