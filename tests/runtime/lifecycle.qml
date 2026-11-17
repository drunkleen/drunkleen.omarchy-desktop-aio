import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "plugin" as Aio
import "plugin/ambient" as Particles
import "plugin/AmbientModel.js" as Model

ShellRoot {
  id: root
  property int step: 0
  property int failures: 0
  property int closeExit: -1
  property var sample: null
  property real beforeY: 0
  property var firstPanel: null
  function openPanel(screen) {
    panel.openFor(screen);
    panel.panel.title = 'Desktop AIO · Lifecycle test';
  }
  function check(ok, message) {
    console.log((ok ? 'CHECK_PASS ' : 'CHECK_FAIL ') + message);
    if (!ok)
      failures++;
  }
  Item {
    id: host
    width: 1
    height: 1
    Particles.PetalField {
      id: rain
      anchors.fill: parent
      settings: Model.settings({
                                 density: .8
                               }, 'rain')
      effect: 'rain'
      running: false
    }
  }
  Aio.SettingsHost {
    id: panel
  }
  property Process closeTest: Process {
    command: ["bash", decodeURIComponent(String(Qt.resolvedUrl("close-window")).replace(/^file:\/\//, ""))]
    onExited: code => {
      root.closeExit = code;
      console.log('COMPOSITOR_CLOSE_EXIT ' + code);
    }
  }
  Aio.ContextMenu {
    id: menu
    onConfigureRequested: screen => root.openPanel(screen)
  }
  TestCase {
    id: driver
    when: false
    parent: menu.contentItem
  }
  Timer {
    interval: 500
    repeat: true
    running: true
    onTriggered: {
      try {
        root.step++;
        if (root.step === 1) {
          root.openPanel(Quickshell.screens[0]);
        }
        if (root.step === 1)
          console.log('INITIAL_POOL ' + rain.liveCount + ' extent ' + rain.width + 'x' + rain.height);
        if (root.step === 2) {
          host.width = 640;
          host.height = 360;
          rain.running = true;
        }
        if (root.step === 3) {
          root.sample = Array.from(rain.children).find(function (p) {
            return p.alive === true && p.screenY >= 0 && p.screenY < rain.height / 2;
          });
          if (root.sample)
            root.beforeY = root.sample.screenY;
        }
        if (root.step === 4) {
          root.check(!!root.sample && root.sample.screenY - root.beforeY > 10,
                     'rain moves down after initial 1px surface is configured');
          if (root.sample)
            console.log('RAIN_DELTA ' + (root.sample.screenY - root.beforeY) + ' rate ' + root.sample.fallRate
                        + ' frames ' + rain.frameCount + ' retiring ' + root.sample.retiring);
          root.openPanel(Quickshell.screens[0]);
        }
        if (root.step === 5) {
          root.check((panel.panel && panel.panel.backingWindowVisible), 'settings initially opens');
          root.firstPanel = panel.panel;
          panel.panel.category = 'ambient';
          Qt.callLater(function () {
            var choice = driver.findChild(panel.panel.contentItem, 'select-ambient.mode-combo');
            if (choice)
              choice.popup.open();
            closeTest.running = true;
          });
        }
        if (root.step === 6) {
          root.check(root.closeExit === 0, 'compositor close command completed');
          root.check(!panel.panel, 'closed settings window resources released');
          root.openPanel(Quickshell.screens[0]);
        }
        if (root.step === 7) {
          root.check((panel.panel && panel.panel.backingWindowVisible),
                     'settings reopens after compositor close');
          root.check(panel.panel !== root.firstPanel, 'settings gets fresh window resources after close');
          panel.panel.visible = false;
        }
        if (root.step === 8)
          root.openPanel(Quickshell.screens[0]);
        if (root.step === 9) {
          root.check((panel.panel && panel.panel.backingWindowVisible),
                     'settings reopens after in-app close');
          panel.panel.visible = false;
        }
        if (root.step === 10)
          menu.openAt(Quickshell.screens[0], 140, 160);
        if (root.step === 11) {
          root.check(menu.menu.visible && Math.abs(menu.menu.x - 140) <= 1 && Math.abs(menu.menu.y - 160) <= 1,
                     'first menu opens at requested widget coordinates');
          console.log('MENU_POSITION ' + menu.menu.x + ',' + menu.menu.y);
          menu.close();
        }
        if (root.step === 12)
          menu.openAt(Quickshell.screens[Quickshell.screens.length - 1], 180, 200);
        if (root.step === 13) {
          root.check(menu.menu.visible && Math.abs(menu.menu.x - 180) <= 1 && Math.abs(menu.menu.y - 200) <= 1,
                     'menu reopens at coordinates on selected monitor');
          menu.close();
        }
        if (root.step === 14)
          menu.openAt(Quickshell.screens[0], 140, 160);
        if (root.step === 15) {
          var configure = menu.menu.itemAt(9);
          driver.mouseClick(configure, configure.width / 2, configure.height / 2);
        }
        if (root.step === 16) {
          root.check(panel.panel && panel.panel.backingWindowVisible && !menu.visible,
                     'configure action opens settings and releases menu grab');
          panel.panel.visible = false;
        }
        if (root.step === 17)
          menu.openAt(Quickshell.screens[0], 140, 160);
        if (root.step === 18) {
          var configure = menu.menu.itemAt(9);
          driver.mouseClick(configure, configure.width / 2, configure.height / 2);
        }
        if (root.step === 19)
          root.check(panel.panel && panel.panel.backingWindowVisible && !menu.visible,
                     'configure action reopens settings after close');
        if (root.step === 20) {
          console.log(root.failures ? 'AIO_RUNTIME_FAIL lifecycle ' + root.failures : 'AIO_RUNTIME_PASS');
          Qt.quit();
        }
      } catch (e) {
        console.error('AIO_RUNTIME_FAIL ' + e);
        Qt.quit();
      }
    }
  }
}
