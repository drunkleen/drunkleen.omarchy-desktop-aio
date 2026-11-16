pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "SettingsModel.js" as Model

QtObject {
  id: root
  property var positions: ({})
  property var sizes: ({})
  property var anchors: ({})
  property string error: ""
  property bool locked: true
  property bool stateReady: false
  readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME")
                                                                                  || "") + "/.local/state"))
                                           + "/drunkleen.desktop-aio"

  function saveState() {
    if (stateReady)
      stateFile.setText(JSON.stringify({
                                         version: 1,
                                         locked: locked,
                                         monitors: positions,
                                         sizes: sizes,
                                         anchors: anchors
                                       }) + "\n");
  }
  function remember(name, x, y, maxX, maxY) {
    var next = Object.assign({}, positions);
    next[name] = {
      x: maxX > 0 ? x / maxX : 0,
      y: maxY > 0 ? y / maxY : 0
    };
    positions = next;
    var a = Object.assign({}, anchors);
    a[name] = "free";
    anchors = a;
    saveState();
  }
  function sizeFor(name) {
    var value = sizes[name];
    return typeof value === "number" && isFinite(value) ? Math.max(0.1, Math.min(3, value)) : Config.scale;
  }
  function setSize(name, value) {
    var next = Object.assign({}, sizes);
    if (value === null)
      delete next[name];
    else
      next[name] = Math.max(0.1, Math.min(3, value));
    sizes = next;
  }
  function savedPosition(name) {
    var p = positions[name];
    return p && typeof p.x === "number" && isFinite(p.x) && typeof p.y === "number" && isFinite(p.y) ? p :
                                                                                                       null;
  }
  property FileView stateFile: FileView {
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(text());
        if (data.version !== 1)
          throw Error("Unsupported placement state version");
        if (data.version === 1) {
          root.positions = data.monitors && typeof data.monitors === "object" ? data.monitors : ({});
          root.locked = data.locked !== false;
          root.anchors = data.anchors && typeof data.anchors === "object" ? data.anchors : ({});
          root.sizes = data.sizes && typeof data.sizes === "object" ? data.sizes : ({});
        }
      } catch (e) {
        root.error = String(e);
        root.stateReady = false;
        return;
      }
      root.stateReady = true;
    }
    onLoadFailed: root.stateReady = true
    onSaveFailed: root.error = "Unable to save placement state"
  }
  property Process initialize: Process {
    command: ["mkdir", "-p", root.stateDirectory]
    running: true
    onExited: (code, status) => {
      if (code === 0)
        stateFile.path = root.stateDirectory + "/placement.json";
      else
        console.warn("Desktop AIO: could not create state directory");
    }
  }

  function anchorFor(name) {
    return anchors[name] || Config.anchor;
  }
  function selectAnchor(name, anchor) {
    var next = Object.assign({}, anchors);
    next[name] = anchor;
    anchors = next;
    resetPosition(name, true);
  }
  function resetPosition(name, keepAnchor) {
    var next = Object.assign({}, positions);
    delete next[name];
    positions = next;
    if (!keepAnchor) {
      var a = Object.assign({}, anchors);
      delete a[name];
      anchors = a;
    }
    saveState();
  }
  function resetSize(name) {
    setSize(name, null);
    saveState();
  }
  function resetMonitor(name) {
    var next = Object.assign({}, anchors);
    delete next[name];
    anchors = next;
    resetPosition(name);
    resetSize(name);
  }
  function resetAll() {
    error = "";
    stateReady = true;
    positions = ({});
    sizes = ({});
    anchors = ({});
    locked = true;
    saveState();
  }
  function point(name, maxX, maxY) {
    return Model.placement(name, {
                             monitors: positions,
                             anchors: anchors
                           }, Config.anchor, Config.freeX, Config.freeY, maxX, maxY, Config.marginX,
                           Config.marginY);
  }
}
