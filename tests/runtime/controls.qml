import QtQuick
import QtTest
import Quickshell
import "plugin" as Aio
import "plugin/ambient" as Particles

ShellRoot {
  id: root
  Aio.ContextMenu {
    id: menu
  }
  TestCase {
    id: menuDriver
    when: false
    parent: menu.contentItem
  }
  property int step: 0
  property int beforeCount: 0
  function require(ok, message) {
    if (!ok)
      throw Error(message + ' ' + Aio.Config.error);
  }
  FloatingWindow {
    id: window
    title: 'Desktop AIO · Control regression test'
    visible: true
    implicitWidth: 720
    implicitHeight: 700
    color: '#0b1113'
    Column {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 12
      Aio.SettingControl {
        id: mode
        width: parent.width
        setting: 'ambient.mode'
        kind: 'select'
        options: [
          {
            value: 'sakura',
            label: 'Sakura'
          },
          {
            value: 'snow',
            label: 'Snow'
          },
          {
            value: 'green_leaves',
            label: 'Green'
          }
        ]
      }
      Aio.SettingControl {
        id: density
        width: parent.width
        setting: 'ambient.density'
        kind: 'slider'
        minimum: 0
        maximum: 1
        step: .01
      }
      Aio.SettingControl {
        id: size
        width: parent.width
        setting: 'ambient.size'
        kind: 'slider'
        minimum: .25
        maximum: 3
        step: .05
      }
      Aio.SettingControl {
        id: enabled
        width: parent.width
        setting: 'ambient.enabled'
        kind: 'toggle'
      }
      Particles.PetalField {
        id: particles
        width: 640
        height: 240
        effect: Aio.Ambient.effect
        settings: Aio.Ambient.settings
        effectsEnabled: Aio.Ambient.enabled
        running: true
      }
    }
    TestCase {
      id: driver
      when: false
    }
  }
  property var choice: null
  property var slider: null
  Timer {
    interval: 500
    running: true
    repeat: true
    onTriggered: {
      try {
        root.step++;
        if (root.step === 1) {
          root.require(Aio.Config.ready, 'config not ready');
          root.choice = driver.findChild(mode, 'select-ambient.mode-combo');
          root.slider = driver.findChild(density, 'slider-ambient.density');
          root.require(!!root.choice && !!root.slider, 'controls missing');
        }
        if (root.step === 2)
          driver.mouseClick(root.choice, 30, root.choice.height / 2);
        if (root.step === 3) {
          var option = root.choice.popup.contentItem.itemAtIndex(2);
          root.require(!!option, 'popup option missing');
          driver.mouseClick(option, option.width / 2, option.height / 2);
        }
        if (root.step === 4) {
          root.require(Aio.Ambient.config.mode === 'green_leaves',
                       'click without prior hover selects wrong mode');
          Aio.Config.setSectionValue('ambient', 'mode', 'snow');
        }
        if (root.step === 5) {
          root.require(root.choice.currentValue === 'snow', 'selector lost external binding');
          root.beforeCount = particles.liveCount;
          driver.mouseClick(root.slider, root.slider.width * .9, root.slider.height / 2);
        }
        if (root.step === 6) {
          root.require(Aio.Ambient.config.density > .8, 'density slider did not apply');
          root.require(particles.liveCount >= Math.round(Aio.Ambient.settings.petal_count * .8),
                       'density increase not reflected promptly');
          root.require(particles.liveCount > root.beforeCount, 'particle count did not increase');
        }
        if (root.step === 7) {
          var s = driver.findChild(size, 'slider-ambient.size');
          driver.mouseClick(s, s.width * .6, s.height / 2);
        }
        if (root.step === 8) {
          root.require(Aio.Ambient.config.size > 1.5, 'size slider not applied');
          var alive = Array.from(particles.children).find(function (p) {
            return p.alive === true;
          });
          root.require(!!alive && Math.abs(alive.screenSize / (alive.size * alive.proj) - Aio.Ambient.config.size)
                       < 0.001, 'rendered particle size did not change');
          var toggle = driver.findChild(enabled, 'toggle-ambient.enabled');
          driver.mouseClick(toggle, toggle.width / 2, toggle.height / 2);
        }
        if (root.step === 9) {
          root.require(!Aio.Ambient.enabled && !particles.animating && particles.liveCount === 0,
                       'toggle did not disable particles');
          menu.openAt(Quickshell.screens[0], 99999, 99999);
        }
        if (root.step === 10) {
          root.require(menu.menu.visible && menu.menu.width >= 250 && menu.menu.height > 200,
                       'menu missing or collapsed');
          root.require(menu.menu.x >= 0 && menu.menu.y >= 0 && menu.menu.x + menu.menu.width <= menu.width
                       && menu.menu.y + menu.menu.height <= menu.height, 'menu outside screen');
          menu.menu.contentItem.grabToImage(function (result) {
            result.saveToFile('/tmp/aio-fixed-menu.png');
          });
          var entry = menu.menu.itemAt(7);
          driver.mouseClick(entry, entry.width / 2, entry.height / 2);
        }
        if (root.step === 11) {
          var ambientMenu = menu.menu.itemAt(7).subMenu;
          root.require(ambientMenu.visible, 'ambient submenu did not open');
          var rain = ambientMenu.itemAt(5);
          driver.mouseClick(rain, rain.width / 2, rain.height / 2);
        }
        if (root.step === 12) {
          root.require(Aio.Ambient.effect === 'rain', 'submenu did not apply rain');
          root.require(!menu.opened && !menu.visible, 'menu retained keyboard grab after selecting');
          Aio.Config.flush();
          menu.openAt(Quickshell.screens[0], 8, 8);
        }
        if (root.step === 13)
          menuDriver.keyClick(Qt.Key_Escape);
        if (root.step === 14) {
          root.require(!menu.opened && !menu.visible, 'Escape did not close menu and release focus');
          console.log('AIO_RUNTIME_PASS');
          Qt.quit();
        }
      } catch (e) {
        console.error('AIO_RUNTIME_FAIL ' + e);
        Qt.quit();
      }
    }
  }
}
