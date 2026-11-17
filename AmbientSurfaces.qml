pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "ambient"

// The existing Sakura overlay's background scope and obstacle projection,
// hosted inside AIO. One pooled field per screen; no particle-owned windows.
Item {
  id: root
  function status() {
    var fields = [];
    for (var i = 0; i < surfaces.instances.length; i++) {
      var w = surfaces.instances[i];
      fields.push(w.diagnostics());
    }
    return {
      mode: Ambient.config.mode,
      effect: Ambient.effect,
      reason: Ambient.reason,
      ownsDesktop: Ambient.ownsDesktop,
      legacyOwned: Ambient.legacyOwned,
      fields: fields
    };
  }
  property var windowRects: []
  function refreshWindowRects() {
    if (!Ambient.ownsDesktop)
      return;
    var out = [], list = Hyprland.toplevels.values;
    for (var i = 0; i < list.length; i++) {
      var o = list[i].lastIpcObject;
      if (!o || !o.at || !o.size || o.hidden || !o.mapped)
        continue;
      out.push({
                 x: o.at[0],
                 y: o.at[1],
                 w: o.size[0],
                 h: o.size[1],
                 ws: o.workspace ? o.workspace.id : -1
               });
    }
    windowRects = out;
  }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      root.refreshWindowRects();
    }
  }
  Connections {
    target: Ambient
    function onOwnsDesktopChanged() {
      if (Ambient.ownsDesktop)
        root.refreshWindowRects();
      else
        root.windowRects = [];
    }
  }
  Component.onCompleted: refreshWindowRects()
  Variants {
    id: surfaces
    model: Quickshell.screens
    delegate: PanelWindow {
      id: win
      required property var modelData
      function diagnostics() {
        var samples = [];
        for (var i = 0; i < field.children.length; i++) {
          var p = field.children[i];
          if (p.alive === true && samples.length < 3)
            samples.push({
                           x: p.x,
                           y: p.y,
                           opacity: p.opacity,
                           visible: p.visible,
                           fallRate: p.fallRate
                         });
        }
        return {
          screen: screen.name,
          visible: visible,
          width: width,
          height: height,
          fullscreen: fullscreen,
          obstacles: obstacles,
          frames: field.frameCount,
          live: field.liveCount,
          running: field.animating,
          samples: samples
        };
      }
      screen: modelData
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      color: 'transparent'
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: 'drunkleen.desktop-aio.ambient'
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}
      readonly property var monitor: Hyprland.monitorFor(screen)
      readonly property bool fullscreen: !!(monitor && monitor.activeWorkspace
                                            && monitor.activeWorkspace.hasFullscreen)
      visible: Ambient.ownsDesktop && !fullscreen && Ambient.config.opacity > 0 && ((Ambient.effect !== 'none'
                                                                                     && Ambient.settings.petal_count
                                                                                     > 0) || field.liveCount
                                                                                    > 0)
      readonly property int workspace: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
      readonly property var obstacles: {
        var out = [], rects = root.windowRects;
        for (var i = 0; i < rects.length; i++) {
          var r = rects[i];
          if (r.ws === workspace)
            out.push({
                       x: r.x - screen.x,
                       y: r.y - screen.y,
                       w: r.w,
                       h: r.h
                     });
        }
        return out;
      }
      PetalField {
        id: field
        objectName: 'aioAmbientField'
        anchors.fill: parent
        effect: Ambient.effect
        settings: Ambient.settings
        effectsEnabled: Ambient.enabled && Ambient.ownsDesktop
        running: win.visible
        obstacles: win.obstacles
      }
    }
  }
}
