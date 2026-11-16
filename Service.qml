pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons as Commons

// Input is restricted to the card; normal application windows remain above it.
Item {
  id: root
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  property var positions: ({})
  property var sizes: ({})
  property bool locked: true
  property bool stateReady: false
  readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME") ||
    ((Quickshell.env("HOME") || "") + "/.local/state")) + "/drunkleen.desktop-aio"

  function saveState() {
    if (stateReady) stateFile.setText(JSON.stringify({version: 1, locked: locked, monitors: positions, sizes: sizes}) + "\n");
  }
  function remember(name, x, y, maxX, maxY) {
    var next = Object.assign({}, positions);
    next[name] = {x: maxX > 0 ? x / maxX : 0, y: maxY > 0 ? y / maxY : 0};
    positions = next;
    saveState();
  }
  function sizeFor(name) {
    var value = sizes[name];
    return typeof value === "number" && isFinite(value) ? Math.max(0.1, Math.min(3, value)) : Config.scale;
  }
  function setSize(name, value) {
    var next = Object.assign({}, sizes);
    if (value === null) delete next[name];
    else next[name] = Math.max(0.1, Math.min(3, value));
    sizes = next;
  }
  function savedPosition(name) {
    var p = positions[name];
    return p && typeof p.x === "number" && isFinite(p.x) &&
      typeof p.y === "number" && isFinite(p.y) ? p : null;
  }
  FileView {
    id: stateFile
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(text());
        if (data.version === 1) {
          root.positions = data.monitors && typeof data.monitors === "object" ? data.monitors : ({});
          root.locked = data.locked !== false;
          root.sizes = data.sizes && typeof data.sizes === "object" ? data.sizes : ({});
        }
      } catch (e) { console.warn("Desktop AIO: ignoring invalid placement state"); }
      root.stateReady = true;
    }
    onLoadFailed: root.stateReady = true
    onSaveFailed: console.warn("Desktop AIO: could not save placement state")
  }
  Process {
    command: ["mkdir", "-p", root.stateDirectory]
    running: true
    onExited: (code, status) => {
      if (code === 0) stateFile.path = root.stateDirectory + "/placement.json";
      else console.warn("Desktop AIO: could not create state directory");
    }
  }

  function placeX(anchor, w, total, m) {
    if (anchor.indexOf("left") >= 0) return m;
    if (anchor.indexOf("right") >= 0) return total - w - m;
    return Math.round((total - w) / 2);
  }
  function placeY(anchor, h, total, m) {
    if (anchor.indexOf("top") >= 0) return m;
    if (anchor.indexOf("bottom") >= 0) return total - h - m;
    return Math.round((total - h) / 2);
  }

  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      id: win
      required property var modelData

      screen: modelData
      visible: {
        var m = String(Config.monitor || "all");
        if (m === "all") return true;
        var list = m.split(",");
        for (var i = 0; i < list.length; i++)
          if (list[i].trim() === modelData.name) return true;
        return false;
      }

      color: "transparent"
      anchors { top: true; left: true; right: true; bottom: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "drunkleen.desktop-aio"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      property bool menuOpen: false
      property bool sizeMenuOpen: false
      function resizeTo(value) {
        if (root.locked) return;
        root.setSize(modelData.name, value);
        root.saveState();
      }
      property real menuX: 0
      property real menuY: 0
      property real dragX: 0
      property real dragY: 0
      readonly property real maxX: Math.max(0, width - widget.width)
      readonly property real maxY: Math.max(0, height - widget.height)
      readonly property var saved: root.savedPosition(modelData.name)
      mask: Region {
        item: win.menuOpen ? win.contentItem : widget
      }

      MouseArea {
        anchors.fill: parent
        enabled: win.menuOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: win.menuOpen = false
      }

      AioWidget {
        id: widget
        active: win.visible
        opacity: Config.opacity
        s: root.sizeFor(win.modelData.name)
        x: Math.max(0, Math.min(win.maxX, (moveArea.dragging || resizeArea.resizing) ? win.dragX : win.saved ? win.saved.x * win.maxX : Config.anchor === "free"
          ? Config.freeX
          : root.placeX(Config.anchor, widget.implicitWidth, win.width, Config.marginX)))
        y: Math.max(0, Math.min(win.maxY, (moveArea.dragging || resizeArea.resizing) ? win.dragY : win.saved ? win.saved.y * win.maxY : Config.anchor === "free"
          ? Config.freeY
          : root.placeY(Config.anchor, widget.implicitHeight, win.height, Config.marginY)))
        width: implicitWidth
        height: implicitHeight

        Rectangle {
          anchors.fill: parent
          visible: !root.locked
          color: "transparent"
          border.color: Theme.accent
          radius: 8
        }
        MouseArea {
          id: moveArea
          anchors.fill: parent
          enabled: root.stateReady
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: root.locked ? Qt.ArrowCursor : dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          property bool dragging: false
          property point origin
          property point initial
          onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
              var p = mapToItem(win.contentItem, mouse.x, mouse.y);
              win.menuX = Math.max(0, Math.min(win.width - contextMenu.width, p.x));
              win.menuY = Math.max(0, Math.min(win.height - contextMenu.height, p.y));
              win.sizeMenuOpen = false;
              win.menuOpen = true;
            } else if (!root.locked) {
              origin = mapToItem(win.contentItem, mouse.x, mouse.y);
              initial = Qt.point(widget.x, widget.y);
              win.dragX = widget.x;
              win.dragY = widget.y;
              dragging = true;
            }
          }
          onPositionChanged: mouse => {
            if (!dragging) return;
            var p = mapToItem(win.contentItem, mouse.x, mouse.y);
            win.dragX = Math.max(0, Math.min(win.maxX, initial.x + p.x - origin.x));
            win.dragY = Math.max(0, Math.min(win.maxY, initial.y + p.y - origin.y));
          }
          function finishDrag() {
            if (!dragging) return;
            root.remember(win.modelData.name, widget.x, widget.y, win.maxX, win.maxY);
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
          visible: !root.locked
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
            enabled: root.stateReady && !root.locked
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
              if (!resizing) return;
              var point = mapToItem(win.contentItem, mouse.x, mouse.y);
              // Project the pointer movement onto the card's aspect ratio.
              var delta = ((point.x - origin.x) * 708 + (point.y - origin.y) * 454) / (708 * 708 + 454 * 454);
              var limit = Math.min(3, (win.width - win.dragX) / 708, (win.height - win.dragY) / 454);
              root.setSize(win.modelData.name, Math.max(0.1, Math.min(limit, initialScale + delta)));
            }
            function finishResize() {
              if (!resizing) return;
              root.remember(win.modelData.name, widget.x, widget.y, win.maxX, win.maxY);
              resizing = false;
            }
            onReleased: finishResize()
            onCanceled: finishResize()
          }
        }
      }
      Rectangle {
        id: contextMenu
        x: Math.max(0, Math.min(win.menuX, win.width - width))
        y: Math.max(0, Math.min(win.menuY, win.height - height))
        width: 200
        height: menuItems.height + 8
        visible: win.menuOpen
        color: Theme.background
        border.color: Theme.accent
        radius: 8
        Column {
          id: menuItems
          x: 4
          y: 4
          width: parent.width - 8
          Rectangle {
            width: parent.width
            height: 38
            radius: 4
            color: lockMouse.containsMouse ? Theme.inkFaint : "transparent"
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              color: Theme.ink
              text: root.locked ? strings.t("position.unlock") : strings.t("position.lock")
            }
            MouseArea {
              id: lockMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                root.locked = !root.locked;
                root.saveState();
                win.menuOpen = false;
              }
            }
          }
          Rectangle {
            width: parent.width
            height: 38
            radius: 4
            opacity: root.locked ? 0.4 : 1
            color: sizeMouse.containsMouse ? Theme.inkFaint : "transparent"
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              color: Theme.ink
              text: strings.t("size.menu") + "  " + Math.round(widget.s * 100) + "%  ▾"
            }
            MouseArea {
              id: sizeMouse
              anchors.fill: parent
              hoverEnabled: true
              enabled: !root.locked
              onClicked: win.sizeMenuOpen = !win.sizeMenuOpen
            }
          }
          Repeater {
            model: win.sizeMenuOpen ? ["smaller", "larger", "25", "50", "75", "100", "configured"] : []
            delegate: Rectangle {
              required property string modelData
              width: menuItems.width
              height: 32
              radius: 4
              color: optionMouse.containsMouse ? Theme.inkFaint : "transparent"
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                color: Theme.ink
                text: /^[0-9]+$/.test(parent.modelData) ? parent.modelData + "%" : strings.t("size." + parent.modelData)
              }
              MouseArea {
                id: optionMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.locked
                onClicked: {
                  var option = parent.modelData;
                  var value = option === "configured" ? null : option === "smaller" ? widget.s - 0.05 : option === "larger" ? widget.s + 0.05 : Number(option) / 100;
                  win.resizeTo(value);
                }
              }
            }
          }
        }
      }
    }
  }
}
