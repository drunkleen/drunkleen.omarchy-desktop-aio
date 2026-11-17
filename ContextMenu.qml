pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import QtQuick.Controls as C
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import "SettingsModel.js" as Model
import "AmbientModel.js" as Effects

PanelWindow {
  id: root
  signal configureRequested(var screen)
  property real pointerX: 0
  property real pointerY: 0
  property var targetScreen: null
  property bool opened: false
  property bool popupPending: false
  readonly property bool surfaceReady: !!targetScreen && backingWindowVisible && width === targetScreen.width
                                       && height === targetScreen.height
  onSurfaceReadyChanged: if (surfaceReady)
                           Qt.callLater(showPopup)
  function showPopup() {
    if (!opened || !popupPending || !surfaceReady)
      return;
    popupPending = false;
    mainMenu.currentIndex = -1;
    var x = Math.max(8, Math.min(pointerX, width - mainMenu.width - 8));
    var y = Math.max(8, Math.min(pointerY, height - mainMenu.height - 8));
    mainMenu.popup(root.contentItem, x, y);
  }
  function configure() {
    var target = targetScreen;
    close();
    Qt.callLater(function () {
      root.configureRequested(target);
    });
  }
  // Retained for integration tests and callers; native menus own submenu layout.
  property string submenu: ""
  readonly property string monitorName: targetScreen ? targetScreen.name : ''
  property alias menu: mainMenu
  function tr(key) {
    return strings.t(key);
  }
  function openAt(target, x, y) {
    close();
    targetScreen = target;
    pointerX = x;
    pointerY = y;
    popupPending = true;
    opened = true;
    Qt.callLater(showPopup);
  }
  function close() {
    popupPending = false;
    mainMenu.close();
    opened = false;
    submenu = '';
  }
  onSubmenuChanged: {
    if (submenu === 'anchor')
      anchorsMenu.open();
    else if (submenu === 'ambient')
      ambientMenu.open();
  }
  visible: opened && !!targetScreen && Quickshell.screens.indexOf(targetScreen) >= 0
  onVisibleChanged: if (!visible)
                      close()
  screen: targetScreen
  color: 'transparent'
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
    directory: Qt.resolvedUrl('i18n')
  }
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: root.close()
  }
  MenuSurface {
    id: mainMenu
    objectName: 'aioContextMenu'
    screenHeight: root.height
    onClosed: {
      root.opened = false;
      root.submenu = '';
    }
    ContextMenuItem {
      objectName: 'menu-lock'
      text: root.tr(Placement.locked ? 'position.unlock' : 'position.lock')
      glyph: Placement.locked ? '◇' : '◆'
      onTriggered: {
        Placement.locked = !Placement.locked;
        Placement.saveState();
      }
    }
    MenuSurface {
      id: sizeMenu
      title: root.tr('size.menu') + '  ' + Math.round(Placement.sizeFor(root.monitorName) * 100) + '%'
      screenHeight: root.height
      enabled: !Placement.locked
      Instantiator {
        model: ['smaller', 'larger', '25', '50', '55', '75', '100', 'configured']
        delegate: ContextMenuItem {
          required property string modelData
          text: /^\d+$/.test(modelData) ? modelData + '%' : root.tr('size.' + modelData)
          onTriggered: {
            Placement.setSize(root.monitorName, modelData === 'configured' ? null : modelData === 'smaller'
                                                                             ? Placement.sizeFor(
                                                                                 root.monitorName) - 0.05 :
                                                                               modelData === 'larger'
                                                                               ? Placement.sizeFor(
                                                                                   root.monitorName) + 0.05 :
                                                                                 Number(modelData) / 100);
            Placement.saveState();
          }
        }
        onObjectAdded: (index, object) => sizeMenu.insertItem(index, object)
        onObjectRemoved: (index, object) => sizeMenu.removeItem(object)
      }
    }
    MenuSurface {
      id: anchorsMenu
      title: root.tr('anchor.title')
      screenHeight: root.height
      Instantiator {
        model: Model.anchors
        delegate: ContextMenuItem {
          required property string modelData
          text: root.tr('anchor.' + modelData)
          checkable: true
          checked: Placement.anchorFor(root.monitorName) === modelData
          onTriggered: Placement.selectAnchor(root.monitorName, modelData)
        }
        onObjectAdded: (index, object) => anchorsMenu.insertItem(index, object)
        onObjectRemoved: (index, object) => anchorsMenu.removeItem(object)
      }
    }
    C.MenuSeparator {}
    ContextMenuItem {
      text: root.tr('show_weather')
      checkable: true
      checked: Config.showWeather
      onTriggered: Config.setValue('show_weather', !Config.showWeather)
    }
    MenuSurface {
      title: root.tr('weather.units') + '  ' + root.tr('units.' + Config.units + '.short')
      screenHeight: root.height
      ContextMenuItem {
        text: root.tr('units.metric')
        checkable: true
        checked: Config.units === 'metric'
        onTriggered: Config.setSectionValue('weather', 'units', 'metric')
      }
      ContextMenuItem {
        text: root.tr('units.imperial')
        checkable: true
        checked: Config.units === 'imperial'
        onTriggered: Config.setSectionValue('weather', 'units', 'imperial')
      }
    }
    ContextMenuItem {
      text: root.tr('clock24h')
      checkable: true
      checked: Config.clock24h
      onTriggered: Config.setValue('clock24h', !Config.clock24h)
    }
    MenuSurface {
      id: ambientMenu
      title: root.tr('page.ambient')
      screenHeight: root.height
      Instantiator {
        model: Effects.modes.concat(['disabled'])
        delegate: ContextMenuItem {
          required property string modelData
          objectName: 'menu-ambient-' + modelData
          text: root.tr('ambient.mode.' + modelData)
          checkable: true
          checked: (Ambient.enabled ? Ambient.config.mode : 'disabled') === modelData
          onTriggered: Ambient.setMode(modelData)
        }
        onObjectAdded: (index, object) => ambientMenu.insertItem(index, object)
        onObjectRemoved: (index, object) => ambientMenu.removeItem(object)
      }
    }
    C.MenuSeparator {}
    ContextMenuItem {
      text: root.tr('configure')
      glyph: '⚙'
      onTriggered: root.configure()
    }
    ContextMenuItem {
      text: root.tr('editConfig')
      glyph: '✎'
      onTriggered: Config.edit()
    }
  }
}
