pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared cava spectrum feed (PipeWire playback monitor). Owner-refcounted, so
// the analyser runs only while a visible surface claims it. Settles flat when
// frames stop arriving. Adapted from Ryoku's AudioBars.qml (GPL-3.0).
QtObject {
  id: root

  property var activeOwners: []
  readonly property bool active: Config.showSpectrum && activeOwners.length > 0
  property bool restarting: false
  readonly property string processKey: JSON.stringify([bars, fps, Config.smoothing])
  onProcessKeyChanged: {
    if (cavaProc.running) {
      restarting = true;
    }
    restartTimer.restart();
  }

  function setActive(owner, enabled) {
    var next = activeOwners.slice();
    var i = next.indexOf(owner);
    if (enabled && i < 0)
      next.push(owner);
    else if (!enabled && i >= 0)
      next.splice(i, 1);
    root.activeOwners = next;
  }

  readonly property int bars: Math.max(8, Math.min(128, Config.bars))
  readonly property int fps: Math.max(10, Math.min(60, Config.fps))
  readonly property real sensitivity: Config.sensitivity

  property var levels: root.flat()
  property real energy: 0
  property real lastReadMs: 0

  function flat() {
    var a = [];
    for (var i = 0; i < root.bars; i++)
      a.push(0);
    return a;
  }

  property Process cava: Process {
    id: cavaProc
    running: root.active && !cavaProc.backoff && !root.restarting
    property bool backoff: false
    command: ["bash", decodeURIComponent(String(Qt.resolvedUrl("scripts/cava-stream")).replace(/^file:\/\//,
                                                                                               "")), String(
        root.fps), String(root.bars), String(Math.max(0, Math.min(100, Config.smoothing)))]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => root.readBars(line)
    }
    onExited: if (root.active) {
                cavaProc.backoff = true;
                root.restartTimer.restart();
              }
  }

  property Timer restartTimer: Timer {
    interval: 1200
    onTriggered: {
      root.restarting = false;
      cavaProc.backoff = false;
    }
  }

  // cava stops emitting while playback idles; fall back to flat.
  property Timer settle: Timer {
    interval: 140
    running: root.active
    repeat: true
    onTriggered: if (Date.now() - root.lastReadMs > 280) {
                   root.levels = root.flat();
                   root.energy = 0;
                 }
  }

  function norm(v) {
    var n = parseInt(v);
    if (isNaN(n))
      return 0;
    var x = (n / 100) * root.sensitivity;
    return Math.max(0, Math.min(1, x));
  }

  function readBars(line) {
    var t = String(line || "").trim();
    if (!t)
      return;
    var parts = t.split(/[;\s]+/);
    if (parts.length < root.bars)
      return;
    var out = [];
    var sum = 0;
    for (var i = 0; i < root.bars; i++) {
      var v = root.norm(parts[i]);
      out.push(v);
      sum += v;
    }
    root.levels = out;
    root.energy = sum / root.bars;
    root.lastReadMs = Date.now();
  }

  onActiveChanged: {
    root.levels = root.flat();
    root.energy = 0;
    if (root.active)
      root.lastReadMs = 0;
  }
}
