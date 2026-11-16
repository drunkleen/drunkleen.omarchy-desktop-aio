pragma ComponentBehavior: Bound
import QtQuick
import "SettingsModel.js" as Model

FocusScope {
  id: root
  activeFocusOnTab: true
  Keys.onPressed: event => {
    var dx = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : 0, dy = event.key === Qt.Key_Up
                                                                                  ? -1 : event.key
                                                                                    === Qt.Key_Down ? 1 : 0;
    if (dx || dy) {
      var p = Model.rect(selected, Config.layout), step = Config.layout.snap === false ? 1 : 8, v
                                                                                                = Model.bounded(
                                                                                                  selected, p.x
                                                                                                  + dx * step,
                                                                                                  p.y + dy
                                                                                                  * step, false),
      c = {};
      c["layout." + selected + ".x"] = v.x;
      c["layout." + selected + ".y"] = v.y;
      Config.setValues(c);
      event.accepted = true;
    }
  }
  property string selected: "weather"
  Repeater {
    model: Model.order(Config.layout)
    delegate: Rectangle {
      id: part
      required property string modelData
      readonly property var geometry: Model.rect(modelData, Config.layout)
      x: geometry.x
      y: geometry.y
      width: geometry.w
      height: geometry.h
      color: root.selected === modelData ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) :
                                           "transparent"

      border.color: root.selected === modelData ? Theme.accent : Theme.inkFaint
      border.width: root.selected === modelData ? 2 : 1
      z: Model.order(Config.layout).indexOf(modelData)
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeAllCursor
        property point origin
        property point initial
        onPressed: mouse => {
          root.forceActiveFocus();
          root.selected = part.modelData;
          origin = mapToItem(root, mouse.x, mouse.y);
          initial = Qt.point(part.x, part.y);
        }
        onPositionChanged: mouse => {
          if (!pressed)
            return;
          var p = mapToItem(root, mouse.x, mouse.y), v = Model.bounded(part.modelData, initial.x + p.x
                                                                       - origin.x, initial.y + p.y - origin.y,
                                                                       Config.layout.snap !== false);
          var changes = {};
          changes['layout.' + part.modelData + '.x'] = v.x;
          changes['layout.' + part.modelData + '.y'] = v.y;
          Config.setValues(changes);
        }
      }
    }
  }
}
