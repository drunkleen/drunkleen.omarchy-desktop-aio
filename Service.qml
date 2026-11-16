pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "SettingsModel.js" as Model

// Input is restricted to the card; normal application windows remain above it.
Item {
  id: root
  AmbientSurfaces {}
  ContextMenu {
    id: contextMenu
    onConfigureRequested: screen => settings.openFor(screen)
  }
  SettingsPanel {
    id: settings
  }
  IpcHandler {
    target: "desktopAio"
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
      property real dragX: 0
      property real dragY: 0
      readonly property real maxX: Math.max(0, width - widget.width)
      readonly property real maxY: Math.max(0, height - widget.height)
      readonly property var saved: Placement.point(modelData.name, maxX, maxY)
      mask: Region {
        item: widget
      }

      AioWidget {
        id: widget
        active: win.visible
        artOpacity: Config.opacity
        s: Math.min(Placement.sizeFor(win.modelData.name), win.width / 708, win.height / 454)
        x: Math.max(0, Math.min(win.maxX, (moveArea.dragging || resizeArea.resizing) ? win.dragX :
                                                                                       win.saved.x))
        y: Math.max(0, Math.min(win.maxY, (moveArea.dragging || resizeArea.resizing) ? win.dragY :
                                                                                       win.saved.y))
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
        MouseArea {
          id: moveArea
          anchors.fill: parent
          enabled: Placement.stateReady
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Placement.locked ? Qt.ArrowCursor : dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          property bool dragging: false
          property point origin
          property point initial
          onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
              var p = mapToItem(win.contentItem, mouse.x, mouse.y);
              contextMenu.openAt(win.modelData, p.x, p.y);
            } else if (!Placement.locked) {
              origin = mapToItem(win.contentItem, mouse.x, mouse.y);
              initial = Qt.point(widget.x, widget.y);
              win.dragX = widget.x;
              win.dragY = widget.y;
              dragging = true;
            }
          }
          onPositionChanged: mouse => {
            if (!dragging)
              return;
            var p = mapToItem(win.contentItem, mouse.x, mouse.y);
            var next = Model.dragPoint(initial, origin, p, win.maxX, win.maxY);
            win.dragX = next.x;
            win.dragY = next.y;
          }
          function finishDrag() {
            if (!dragging)
              return;
            Placement.remember(win.modelData.name, widget.x, widget.y, win.maxX, win.maxY);
            dragging = false;
          }
          onReleased: finishDrag()
          onCanceled: finishDrag()
        }
        Rectangle {
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
          MouseArea {
            id: resizeArea
            anchors.fill: parent
            enabled: Placement.stateReady && !Placement.locked
            cursorShape: Qt.SizeFDiagCursor
            property bool resizing: false
            property point origin
            property real initialScale
            onPressed: mouse => {
              origin = mapToItem(win.contentItem, mouse.x, mouse.y);
              initialScale = widget.s;
              win.dragX = widget.x;
              win.dragY = widget.y;
              resizing = true;
            }
            onPositionChanged: mouse => {
              if (!resizing)
                return;
              var point = mapToItem(win.contentItem, mouse.x, mouse.y);
              Placement.setSize(win.modelData.name, Model.resizeScale(initialScale, point.x - origin.x, point.y
                                                                      - origin.y, win.width, win.height,
                                                                      win.dragX, win.dragY));
            }
            function finishResize() {
              if (!resizing)
                return;
              Placement.remember(win.modelData.name, widget.x, widget.y, win.maxX, win.maxY);
              resizing = false;
            }
            onReleased: finishResize()
            onCanceled: finishResize()
          }
        }
      }
    }
  }
}
