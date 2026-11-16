pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C
import Quickshell
import Quickshell.Wayland
import qs.Ui as Ui
import qs.Commons as Commons
import "SettingsModel.js" as Model

PanelWindow {
  id: root
  signal configureRequested(var screen)
  property real pointerX: 0
  property real pointerY: 0
  property string submenu: ""
  property var targetScreen: null
  property bool opened: false
  readonly property string monitorName: targetScreen ? targetScreen.name : ""
  function tr(key) {
    return strings.t(key);
  }
  function openAt(target, x, y) {
    targetScreen = target;
    pointerX = x;
    pointerY = y;
    submenu = "";
    opened = true;
    Qt.callLater(function () {
      menuFocus.forceActiveFocus();
    });
  }
  function close() {
    opened = false;
    submenu = "";
  }
  visible: opened && !!targetScreen && Quickshell.screens.indexOf(targetScreen) >= 0
  onVisibleChanged: if (!visible)
                      opened = false
  screen: targetScreen
  color: "transparent"
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: root.close()
  }
  FocusScope {
    id: menuFocus
    anchors.fill: parent
    Keys.onEscapePressed: event => {
      if (root.submenu)
        root.submenu = "";
      else
        root.close();
      event.accepted = true;
    }
    Rectangle {
      id: card
      x: Math.max(0, Math.min(root.pointerX, root.width - width))
      y: Math.max(0, Math.min(root.pointerY, root.height - height))
      width: Math.min(root.width, root.submenu ? 540 : 282)
      height: Math.min(root.height - 8, Math.max(mainColumn.implicitHeight, subColumn.implicitHeight) + 16)
      color: Theme.background
      border.color: Theme.inkFaint
      radius: Commons.Style.cornerRadius
      Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8
        C.ScrollView {
          width: root.submenu ? Math.min(260, (card.width - 24) / 2) : card.width - 16
          height: parent.height
          clip: true
          Column {
            id: mainColumn
            width: parent.width
            spacing: 2
            Text {
              width: parent.width
              visible: Config.error !== '' || Placement.error !== ''
              textFormat: Text.PlainText
              wrapMode: Text.WordWrap
              color: Theme.accent
              text: root.tr('config.error') + ' ' + (Config.error || Placement.error)
            }
            Ui.Button {
              width: parent.width
              leftAlign: true
              focusable: true
              text: root.tr(Placement.locked ? 'position.unlock' : 'position.lock')
              iconText: Placement.locked ? '◇' : '◆'
              onClicked: {
                Placement.locked = !Placement.locked;
                Placement.saveState();
                root.close();
              }
            }
            Ui.Button {
              width: parent.width
              leftAlign: true
              focusable: true
              enabled: !Placement.locked
              text: root.tr('size.menu') + '    ' + Math.round(Placement.sizeFor(root.monitorName) * 100)
                    + '%  ›'

              onClicked: root.submenu = 'size'
            }
            Ui.Button {
              width: parent.width
              leftAlign: true
              focusable: true
              text: root.tr('anchor.title') + '  ›'
              iconText: '⌖'
              onClicked: root.submenu = 'anchor'
            }
            Ui.PanelSeparator {
              width: parent.width
            }
            Ui.Button {
              width: parent.width
              leftAlign: true
              focusable: true
              text: root.tr('show_weather') + (Config.showWeather ? '  ✓' : '')
              onClicked: Config.setValue('show_weather', !Config.showWeather)
            }
            Ui.Button {
              width: parent.width
              leftAlign: true
              focusable: true
              text: root.tr('weather.units') + '  ' + root.tr('units.' + Config.units) + '  ›'
              onClicked: root.submenu = 'units'
            }
            Ui.Button {
              width: parent.width
              leftAlign: true
              focusable: true
              text: root.tr('clock24h') + (Config.clock24h ? '  ✓' : '')
              onClicked: Config.setValue('clock24h', !Config.clock24h)
            }
            Ui.Button {
              width: parent.width
              leftAlign: true
              focusable: true
              text: root.tr('page.ambient') + '  ›'
              iconText: '✧'
              onClicked: root.submenu = 'ambient'
            }
            Ui.PanelSeparator {
              width: parent.width
            }
            Ui.Button {
              width: parent.width
              leftAlign: true
              focusable: true
              text: root.tr('configure')
              iconText: '⚙'
              onClicked: {
                var screen = root.targetScreen;
                root.close();
                root.configureRequested(screen);
              }
            }
            Ui.Button {
              width: parent.width
              leftAlign: true
              focusable: true
              text: root.tr('editConfig')
              iconText: '✎'
              onClicked: {
                Config.edit();
                root.close();
              }
            }
          }
        }
        C.ScrollView {
          visible: root.submenu !== ''
          width: Math.max(0, card.width / 2 - 16)
          height: parent.height
          clip: true
          Column {
            id: subColumn
            width: parent.width
            spacing: 2
            Repeater {
              model: root.submenu === 'ambient' ? ['auto', 'sakura', 'green_leaves', 'yellow_leaves', 'orange_leaves',
                                                   'rain', 'snow', 'disabled'] : root.submenu === 'anchor'
                                                  ? Model.anchors : root.submenu === 'size' ? ['smaller',
                                                                                               'larger', '25',
                                                                                               '50', '55',
                                                                                               '75', '100',
                                                                                               'configured'] :
                                                                                              root.submenu
                                                                                              === 'units'
                                                                                              ? ['metric',
                                                                                                 'imperial'] :
                                                                                                []
              delegate: Ui.Button {
                required property string modelData
                width: parent.width
                leftAlign: true
                focusable: true
                selected: root.submenu === 'ambient' ? (Ambient.enabled ? Ambient.config.mode : 'disabled')
                                                       === modelData : root.submenu === 'anchor'
                                                       ? Placement.anchorFor(root.monitorName) === modelData :
                                                         root.submenu === 'units' ? Config.units
                                                                                    === modelData : false
                text: root.submenu === 'ambient' ? root.tr('ambient.mode.' + modelData) : root.submenu
                                                   === 'anchor' ? root.tr('anchor.' + modelData) :
                                                                  root.submenu === 'units' ? root.tr('units.'
                                                                                                     + modelData) :
                                                                                             /^\d+$/.test(
                                                                                               modelData)
                                                                                             ? modelData
                                                                                               + '%' : root.tr(
                                                                                                 'size.' + modelData)
                onClicked: {
                  if (root.submenu === 'ambient')
                    Ambient.setMode(modelData);
                  else if (root.submenu === 'anchor')
                    Placement.selectAnchor(root.monitorName, modelData);
                  else if (root.submenu === 'units')
                    Config.setSectionValue('weather', 'units', modelData);
                  else {
                    Placement.setSize(root.monitorName, modelData === 'configured' ? null : modelData
                                                                                     === 'smaller'
                                                                                     ? Placement.sizeFor(
                                                                                         root.monitorName)
                                                                                       - 0.05 : modelData
                                                                                       === 'larger'
                                                                                       ? Placement.sizeFor(
                                                                                           root.monitorName)
                                                                                         + 0.05 : Number(
                                                                                           modelData) / 100);
                    Placement.saveState();
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
