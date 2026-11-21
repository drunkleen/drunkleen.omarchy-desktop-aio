pragma ComponentBehavior: Bound
import QtQuick
import "SettingsModel.js" as Model

FocusScope {
  id: root
  activeFocusOnTab: true
  property string selected: "weather"
  readonly property var order: Model.order(Config.layout)
  readonly property string dragged: pointer.dragged
  readonly property point dragPosition: pointer.preview
  signal componentSelected(string componentId)

  function savePosition(id, before, after) {
    var changes = {};
    if (before.x !== after.x)
      changes["layout." + id + ".x"] = after.x;
    if (before.y !== after.y)
      changes["layout." + id + ".y"] = after.y;
    if (Object.keys(changes).length)
      Config.setValues(changes);
  }
  Keys.onPressed: event => {
    var dx = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : 0;
    var dy = event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0;
    if (dx || dy) {
      var p = Model.rect(selected, Config.layout), step = Config.layout.snap === false ? 1 : 8;
      root.savePosition(selected, p, Model.moveComponent(selected, p, dx * step, dy * step, false));
      event.accepted = true;
    }
  }

  Repeater {
    model: Model.components
    delegate: Rectangle {
      required property string modelData
      readonly property var geometry: Model.rect(modelData, Config.layout)
      x: root.dragged === modelData ? root.dragPosition.x : geometry.x
      y: root.dragged === modelData ? root.dragPosition.y : geometry.y
      width: geometry.w
      height: geometry.h
      color: root.selected === modelData ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) :
                                           "transparent"
      border.color: root.selected === modelData ? Theme.accent : Theme.inkFaint
      border.width: root.selected === modelData ? 2 : 1
      z: root.order.indexOf(modelData)
    }
  }

  MouseArea {
    id: pointer
    objectName: "componentPlacementInput"
    anchors.fill: parent
    z: root.order.length
    preventStealing: true
    cursorShape: Qt.SizeAllCursor
    property string candidate: ""
    property string dragged: ""
    property point origin
    property point sceneOrigin
    property point initial
    property point preview

    function updatePosition(x, y) {
      if (!candidate)
        return;
      var scene = mapToItem(null, x, y);
      if (!dragged && Math.hypot(scene.x - sceneOrigin.x, scene.y - sceneOrigin.y) < 4)
        return;
      preview = Model.moveComponent(candidate, initial, x - origin.x, y - origin.y, Config.layout.snap !== false);
      dragged = candidate;
      if (root.selected !== candidate)
        root.componentSelected(candidate);
    }
    onPressed: mouse => {
      candidate = Model.componentAt(root.order, Config.layout, root.selected, mouse.x, mouse.y);
      if (!candidate) {
        mouse.accepted = false;
        return;
      }
      root.forceActiveFocus();
      origin = Qt.point(mouse.x, mouse.y);
      sceneOrigin = mapToItem(null, mouse.x, mouse.y);
      var rect = Model.rect(candidate, Config.layout);
      initial = preview = Qt.point(rect.x, rect.y);
    }
    onPositionChanged: mouse => updatePosition(mouse.x, mouse.y)
    onReleased: mouse => {
      updatePosition(mouse.x, mouse.y);
      if (dragged)
        root.savePosition(dragged, initial, preview);
      else if (candidate && candidate === Model.componentAt(root.order, Config.layout, root.selected, mouse.x, mouse.y))
        root.componentSelected(candidate);
      candidate = dragged = "";
    }
    onCanceled: candidate = dragged = ""
  }
}
