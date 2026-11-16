pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C
import Quickshell
import qs.Ui as Ui
import qs.Commons as Commons
import "SettingsPages.js" as Pages

FloatingWindow {
  id: root
  property string category: "general"
  onCategoryChanged: Qt.callLater(function () {
    if (scroll.contentItem)
      scroll.contentItem.contentY = 0;
  })
  property string monitorName: ""
  property string confirmationMessage: tr("confirm.message")
  property var confirmAction: null
  function tr(key) {
    return strings.t(key);
  }
  function openFor(target) {
    screen = target || Quickshell.screens[0];
    monitorName = screen ? screen.name : '';
    visible = true;
    Qt.callLater(function () {
      focusRoot.forceActiveFocus();
    });
  }
  function confirm(action, message) {
    confirmationMessage = message || tr("confirm.message");
    confirmAction = action;
    confirmation.opened = true;
  }
  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (Quickshell.screens.indexOf(root.screen) < 0)
        root.screen = Quickshell.screens[0] || null;
      if (!Quickshell.screens.some(function (s) {
        return s.name === root.monitorName;
      }))
        root.monitorName = root.screen ? root.screen.name : '';
    }
  }
  onVisibleChanged: if (!visible) {
                      Weather.cancelSearch();
                      Config.flush();
                    }
  visible: false
  title: tr('settings.title')
  implicitWidth: Math.min(980, screen ? screen.width - 32 : 980)
  implicitHeight: Math.min(820, screen ? screen.height - 64 : 820)
  minimumSize: Qt.size(360, 360)
  color: Theme.background
  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }
  FocusScope {
    id: focusRoot
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: event => {
      if (confirmation.opened)
        confirmation.opened = false;
      else {
        Config.flush();
        root.visible = false;
      }
      event.accepted = true;
    }
    Keys.onPressed: event => {
      if (confirmation.opened)
        confirmation.handleKey(event);
    }
    Column {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 10
      Row {
        width: parent.width
        spacing: 8
        Text {
          width: parent.width - 110
          textFormat: Text.PlainText
          text: root.tr('settings.title')
          color: Theme.foreground
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.title
          font.bold: true
        }
        Ui.Button {
          text: root.tr('close')
          focusable: true
          onClicked: {
            Config.flush();
            root.visible = false;
          }
        }
      }
      Text {
        width: parent.width
        visible: Config.error !== '' || Placement.error !== ''
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.accent
        text: root.tr("config.error") + " " + (Config.error || Placement.error)
      }
      Text {
        width: parent.width
        textFormat: Text.PlainText
        color: Theme.inkDim
        text: root.tr(Config.dirty ? 'config.pending' : 'config.saved')
      }
      C.ScrollView {
        width: parent.width
        height: 48
        clip: true
        Row {
          spacing: 4
          Repeater {
            model: Pages.names
            delegate: Ui.Button {
              required property string modelData
              text: root.tr('page.' + modelData)
              focusable: true
              selected: root.category === modelData
              onClicked: root.category = modelData
            }
          }
        }
      }
      C.ScrollView {
        id: scroll
        width: parent.width
        height: Math.max(100, parent.height - y - 8)
        clip: true
        contentWidth: availableWidth
        Column {
          width: scroll.availableWidth
          spacing: 16
          Item {
            visible: Config.livePreview && root.category !== 'layout' && root.category !== 'ambient'
            width: parent.width
            height: visible ? Math.min(180, width * 454 / 708) : 0
            AioWidget {
              anchors.centerIn: parent
              s: Math.min(parent.width / 708, parent.height / 454)
              artOpacity: Config.opacity
            }
          }
          CitySearch {
            width: parent.width
            visible: root.category === 'weather'
            height: visible ? implicitHeight : 0
          }
          Column {
            width: parent.width
            spacing: 10
            visible: root.category === 'placement'
            height: visible ? implicitHeight : 0
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              color: Theme.inkDim
              text: root.tr('placement.help')
            }
            SelectControl {
              activeFocusOnTab: true
              width: parent.width
              label: root.tr('placement.target')
              value: root.monitorName
              options: Quickshell.screens.map(function (s) {
                return {
                  value: s.name,
                  label: s.name
                };
              })
              onChanged: value => root.monitorName = value
            }
            SelectControl {
              activeFocusOnTab: true
              width: parent.width
              label: root.tr('monitor')
              value: Config.monitor
              options: [
                {
                  value: 'all',
                  label: root.tr('placement.all')
                }
              ].concat(Quickshell.screens.map(function (s) {
                return {
                  value: s.name,
                  label: s.name
                };
              }))
              onChanged: value => Config.setValue('monitor', value)
            }
            AnchorSelector {
              monitorName: root.monitorName
            }
            Ui.Toggle {
              activeFocusOnTab: true
              Keys.onSpacePressed: {
                Placement.locked = !Placement.locked;
                Placement.saveState();
              }
              width: parent.width
              label: root.tr('placement.lock')
              checked: Placement.locked
              onClicked: {
                Placement.locked = !Placement.locked;
                Placement.saveState();
              }
            }
            Ui.Button {
              text: root.tr('placement.resetPosition')
              focusable: true
              onClicked: root.confirm(function () {
                Placement.resetPosition(root.monitorName);
              })
            }
            Ui.Button {
              text: root.tr('placement.resetSize')
              focusable: true
              onClicked: root.confirm(function () {
                Placement.resetSize(root.monitorName);
              })
            }
          }
          Repeater {
            model: Pages.fields(root.category)
            delegate: SettingControl {
              required property var modelData
              width: parent.width
              setting: modelData.key
              label: root.tr(modelData.key)
              kind: modelData.kind
              minimum: modelData.min
              maximum: modelData.max
              step: modelData.step
              options: modelData.options.map(function (o) {
                return {
                  value: o,
                  label: root.tr((setting === 'anchor' ? 'anchor.' : 'units.') + o)
                };
              })
              onCommitted: value => {
                if (root.category === 'placement') {
                  if (setting === 'x' || setting === 'y')
                    Placement.selectAnchor(root.monitorName, 'free');
                  else if (setting === "anchor")
                    Placement.resetPosition(root.monitorName);
                  else
                    Placement.resetPosition(root.monitorName, true);
                }
                if (setting === 'scale')
                  Placement.resetSize(root.monitorName);
              }
            }
          }
          Ui.Button {
            visible: root.category === 'appearance'
            text: root.tr('appearance.follow')
            focusable: true
            onClicked: Config.setValues({
                                          ink: '',
                                          accent: ''
                                        })
          }
          LayoutEditor {
            width: parent.width
            visible: root.category === 'layout'
            height: visible ? implicitHeight : 0
            requestConfirmation: root.confirm
          }
          AmbientSettings {
            width: parent.width
            visible: root.category === 'ambient'
            height: visible ? implicitHeight : 0
            confirm: root.confirm
          }
          AdvancedSettings {
            width: parent.width
            visible: root.category === 'advanced'
            height: visible ? implicitHeight : 0
            confirm: root.confirm
          }
          Ui.Button {
            visible: ['general', 'weather', 'appearance', 'spectrum', 'media'].indexOf(root.category) >= 0
            text: root.tr('category.reset')
            focusable: true
            onClicked: root.confirm(function () {
              if (['weather', 'spectrum', 'media'].indexOf(root.category) >= 0) {
                Config.resetSection(root.category);
                Config.resetValue('show_' + root.category);
              } else
                Config.resetKeys(Pages.fields(root.category).map(function (f) {
                  return f.key;
                }));
            })
          }
        }
      }
    }
    Ui.ConfirmDialog {
      id: confirmation
      anchors.fill: parent
      z: 10000
      message: root.confirmationMessage
      cancelText: root.tr('cancel')
      confirmText: root.tr('confirm')
      onCanceled: opened = false
      onConfirmed: {
        opened = false;
        if (root.confirmAction)
          root.confirmAction();
        root.confirmAction = null;
      }
    }
  }
}
