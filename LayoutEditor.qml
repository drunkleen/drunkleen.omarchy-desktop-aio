pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
import "SettingsModel.js" as Model

Column {
  id: root
  property string selected: "weather"
  property string dragged: ""
  property real dragOffset: 0
  property var requestConfirmation: null
  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }
  spacing: 10
  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: Theme.foreground
    text: strings.t('layout.help')
  }
  SettingControl {
    width: parent.width
    setting: 'layout.snap'
    label: strings.t('layout.snap')
    kind: 'toggle'
  }
  Rectangle {
    width: parent.width
    height: Math.min(320, width * 454 / 708)
    color: Theme.background
    border.color: Theme.inkFaint
    radius: 8
    clip: true
    AioWidget {
      objectName: "layoutPreview"
      anchors.centerIn: parent
      s: Math.min(parent.width / 708, parent.height / 454)
      editing: true
      selectedComponent: root.selected
      onComponentSelected: componentId => root.selected = componentId
    }
  }
  Repeater {
    model: Model.order(Config.layout)
    delegate: Item {
      id: drop
      required property string modelData
      required property int index
      width: root.width
      height: 50
      z: root.dragged === modelData ? 1 : 0
      Rectangle {
        anchors.fill: parent
        color: root.selected === drop.modelData ? Theme.inkFaint : 'transparent'
        radius: 6
        transform: Translate {
          y: root.dragged === drop.modelData ? root.dragOffset : 0
        }
        Row {
          anchors.fill: parent
          spacing: 6
          Ui.Button {
            text: '☰'
            width: 38
            height: 46
            tooltipText: strings.t('layout.reorder')
          }
          Ui.Button {
            width: Math.max(70, drop.width - 200)
            height: 46
            text: strings.t('component.' + drop.modelData)
            selected: root.selected === drop.modelData
            focusable: true
            onClicked: root.selected = drop.modelData
          }
          Ui.Button {
            objectName: "visibility-" + drop.modelData
            text: Model.componentVisible(Config.data, drop.modelData) ? '✓' : '○'
            focusable: true
            onClicked: Config.setValue('show_' + drop.modelData, !Model.componentVisible(Config.data, drop.modelData))
          }
          Ui.Button {
            text: '↺'
            tooltipText: strings.t('layout.resetPart')
            focusable: true
            onClicked: root.requestConfirmation(function () {
              Config.resetSection('layout.' + drop.modelData);
            })
          }
        }
      }
      MouseArea {
        objectName: "reorder-" + drop.modelData
        width: 38
        height: 46
        preventStealing: true
        cursorShape: Qt.SizeVerCursor
        property real originY
        onPressed: mouse => originY = mapToItem(root, mouse.x, mouse.y).y
        onPositionChanged: mouse => {
          if (!pressed)
            return;
          var delta = mapToItem(root, mouse.x, mouse.y).y - originY;
          if (!root.dragged && Math.abs(delta) < 4)
            return;
          root.dragged = drop.modelData;
          root.dragOffset = delta;
        }
        onReleased: mouse => {
          var order = Model.order(Config.layout);
          var offset = Math.round((mapToItem(root, mouse.x, mouse.y).y - originY) / drop.height);
          var next = Model.offsetOrder(order, order.indexOf(drop.modelData), offset);
          root.dragged = "";
          root.dragOffset = 0;
          if (next !== order)
            Config.setSectionValue('layout', 'order', next);
        }
        onCanceled: {
          root.dragged = "";
          root.dragOffset = 0;
        }
      }
    }
  }
  Row {
    spacing: 8
    Ui.NumberField {
      label: 'X'
      from: 0
      to: Math.floor(708 - Model.geometry[root.selected][2])
      value: Math.round(Model.rect(root.selected, Config.layout).x)
      onModified: value => Config.setValue('layout.' + root.selected + '.x', value)
    }
    Ui.NumberField {
      label: 'Y'
      from: 0
      to: Math.floor(454 - Model.geometry[root.selected][3])
      value: Math.round(Model.rect(root.selected, Config.layout).y)
      onModified: value => Config.setValue('layout.' + root.selected + '.y', value)
    }
    Ui.Button {
      text: '↑'
      focusable: true
      tooltipText: strings.t('layout.back')
      onClicked: {
        var order = Model.order(Config.layout);
        var next = Model.offsetOrder(order, order.indexOf(root.selected), -1);
        if (next !== order)
          Config.setValue('layout.order', next);
      }
    }
    Ui.Button {
      text: '↓'
      focusable: true
      tooltipText: strings.t('layout.front')
      onClicked: {
        var order = Model.order(Config.layout);
        var next = Model.offsetOrder(order, order.indexOf(root.selected), 1);
        if (next !== order)
          Config.setValue('layout.order', next);
      }
    }
  }
  Ui.Button {
    text: strings.t('layout.reset')
    focusable: true
    onClicked: root.requestConfirmation(function () {
      Config.resetSection('layout');
    })
  }
}
