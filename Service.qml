pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "SettingsModel.js" as Model

// Input is restricted to the card; normal application windows remain above it.
Item {
  id: root
  AmbientSurfaces {
    id: ambientSurfaces
  }
  ContextMenu {
    id: contextMenu
    onConfigureRequested: screen => settings.openFor(screen)
  }
  SettingsHost {
    id: settings
  }
  IpcHandler {
    target: "desktopAio"
    function weatherStatus(): string {
      return JSON.stringify({
                              city: Config.city,
                              location: Config.weatherSec.label || Config.city,
                              status: Weather.status,
                              available: Weather.available,
                              error: Weather.errorText,
                              loadedCity: Weather.locationCity,
                              retrying: Weather.recovery.running
                            });
    }
    function audioStatus(): string {
      return JSON.stringify({
                              active: AudioBars.active,
                              source: AudioBars.source,
                              running: AudioBars.cava.running,
                              energy: AudioBars.energy,
                              color: String(Theme.primary)
                            });
    }
    function ambientStatus(): string {
      return JSON.stringify(ambientSurfaces.status());
    }
    function configure(): void {
      settings.openFor(Quickshell.screens[0]);
    }
  }
  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      id: win
      required property var modelData

      screen: modelData
      visible: {
        var m = String(Config.monitor || "all");
        if (m === "all")
          return true;
        var list = m.split(",");
        for (var i = 0; i < list.length; i++)
          if (list[i].trim() === modelData.name)
            return true;
        return false;
      }

      color: "transparent"
      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "drunkleen.desktop-aio"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      readonly property real maxX: Math.max(0, width - widget.width)
      readonly property real maxY: Math.max(0, height - widget.height)
      readonly property var saved: Placement.point(modelData.name, maxX, maxY)
      mask: Region {
        // Keep the Wayland input region fixed until release or cancellation.
        item: pointer.gesture ? win.contentItem : widget
      }

      AioWidget {
        id: widget
        objectName: "desktopWidget"
        active: win.visible
        artOpacity: Config.opacity
        s: Math.min(pointer.gesture === "resize" ? pointer.previewScale : Placement.sizeFor(win.modelData.name),
                    win.width / 708, win.height / 454)
        x: pointer.gesture ? Math.min(win.maxX, pointer.previewPosition.x) : win.saved.x
        y: pointer.gesture ? Math.min(win.maxY, pointer.previewPosition.y) : win.saved.y
        width: implicitWidth
        height: implicitHeight

        Rectangle {
          anchors.fill: parent
          visible: !Placement.locked || Config.opacity < 0.15 || Config.error !== "" || Placement.error !== ""
          color: "transparent"
          border.color: Theme.accent
          radius: 8
        }
        Text {
          visible: Config.error !== '' || Placement.error !== ''
          text: '!'
          textFormat: Text.PlainText
          color: Theme.accent
          font.bold: true
          font.pixelSize: 20
        }
        Rectangle {
          id: grip
          width: 22
          height: 22
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          visible: !Placement.locked
          color: Theme.background
          border.color: Theme.accent
          radius: 4
          Text {
            anchors.centerIn: parent
            text: "◢"
            textFormat: Text.PlainText
            color: Theme.accent
          }
        }
      }

      // Keep the grab owner and its coordinate space stationary. The surface
      // input region follows the card for hit testing before the press.
      MouseArea {
        id: pointer
        objectName: "widgetPlacementInput-" + win.modelData.name
        anchors.fill: parent
        enabled: Placement.stateReady
        acceptedButtons: Placement.locked ? Qt.RightButton : Qt.LeftButton | Qt.RightButton
        hoverEnabled: !Placement.locked
        preventStealing: true
        cursorShape: Placement.locked ? Qt.ArrowCursor :
                     gesture === "resize" || (!gesture && overGrip(mouseX, mouseY)) ? Qt.SizeFDiagCursor :
                     gesture === "move" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property string gesture: ""
        property point origin
        property point initialPosition
        property real initialScale
        property point previewPosition
        property real previewScale

        function overGrip(x, y) {
          return grip.contains(grip.mapFromItem(pointer, x, y));
        }
        function updatePosition(x, y) {
          if (gesture === "move")
            previewPosition = Model.dragPoint(initialPosition, origin, Qt.point(x, y), win.maxX, win.maxY);
          else if (gesture === "resize")
            previewScale = Model.resizeScale(initialScale, x - origin.x, y - origin.y, win.width,
                                             win.height, initialPosition.x, initialPosition.y);
        }
        onPressed: mouse => {
          if (!widget.contains(widget.mapFromItem(pointer, mouse.x, mouse.y))) {
            mouse.accepted = false;
            return;
          }
          if (mouse.button !== Qt.LeftButton || Placement.locked || gesture)
            return;
          origin = Qt.point(mouse.x, mouse.y);
          initialPosition = previewPosition = Qt.point(widget.x, widget.y);
          initialScale = previewScale = widget.s;
          gesture = overGrip(mouse.x, mouse.y) ? "resize" : "move";
        }
        onPositionChanged: mouse => updatePosition(mouse.x, mouse.y)
        onReleased: mouse => {
          if (mouse.button !== Qt.LeftButton || !gesture)
            return;
          updatePosition(mouse.x, mouse.y);
          if (previewScale !== initialScale || previewPosition.x !== initialPosition.x ||
              previewPosition.y !== initialPosition.y) {
            if (gesture === "resize")
              Placement.setSize(win.modelData.name, previewScale);
            Placement.remember(win.modelData.name, widget.x, widget.y, win.maxX, win.maxY);
          }
          gesture = "";
        }
        onCanceled: gesture = ""
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton && !gesture &&
              widget.contains(widget.mapFromItem(pointer, mouse.x, mouse.y)))
            contextMenu.openAt(win.modelData, mouse.x, mouse.y);
        }
        Connections {
          target: Placement
          function onLockedChanged() {
            if (Placement.locked)
              pointer.gesture = "";
          }
        }
      }
    }
  }
}
