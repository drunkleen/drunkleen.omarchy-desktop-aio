import QtQuick
import QtQuick.Controls as C
import QtTest
import Quickshell
import "plugin" as Aio
import "plugin/SettingsModel.js" as Model

ShellRoot {
  id: root
  readonly property var screen: Quickshell.screens[0]
  property int step: 0

  Aio.Service {
    id: service
  }
  FloatingWindow {
    id: window
    title: "Desktop AIO · placement regression"
    implicitWidth: 740
    implicitHeight: 790
    visible: root.step >= 2
    C.ScrollView {
      id: scroll
      anchors.fill: parent
      contentWidth: availableWidth
      Aio.LayoutEditor {
        id: layout
        width: scroll.availableWidth
      }
    }
  }
  TestCase {
    id: driver
    when: false
  }

  function require(ok, message) {
    if (!ok)
      throw Error(message + ' ' + Aio.Config.error + ' ' + Aio.Placement.error);
  }
  function near(actual, expected, message) {
    root.require(Math.abs(actual - expected) < 2, message + ' (' + actual + ' vs ' + expected + ')');
  }
  function checkDesktop() {
    var input = driver.findChild(service, 'widgetPlacementInput-' + root.screen.name);
    root.require(!!input, 'desktop input missing');
    var widget = driver.findChild(input.parent, 'desktopWidget');
    root.require(!!widget && widget.width > 150, 'desktop widget missing or too small');
    var x = widget.x, y = widget.y, scale = widget.s, w = widget.width, h = widget.height;
    var px = Math.round(x + w / 2), py = Math.round(y + h / 2);
    var dx = Math.round(w * .75), dy = Math.round(h * .8);
    driver.mousePress(input, px, py, Qt.LeftButton);
    driver.mouseMove(input, px + dx, py + dy, 0);
    root.near(widget.x, x + dx, 'fast desktop drag left the original hit box');
    root.near(widget.y, y + dy, 'desktop drag Y');
    root.require(!Aio.Placement.savedPosition(root.screen.name), 'move persisted before release');
    driver.mouseMove(input, px + dx + 18, py + dy + 12, 0);
    root.near(widget.x, x + dx + 18, 'desktop move used an unstable origin');
    driver.mouseRelease(input, px + dx + 18, py + dy + 12, Qt.LeftButton);
    root.require(input.gesture === '' && !!Aio.Placement.savedPosition(root.screen.name), 'move release lost');
    root.near(widget.x, x + dx + 18, 'desktop jumped on release');

    x = widget.x;
    y = widget.y;
    px = Math.floor(x + w - 7);
    py = Math.floor(y + h - 7);
    dx = 100;
    dy = 88;
    var expected = Model.resizeScale(scale, dx, dy, input.width, input.height, x, y);
    driver.mousePress(input, px, py, Qt.LeftButton);
    root.require(input.gesture === 'resize', 'grip started a move');
    driver.mouseMove(input, px + dx, py + dy, 0);
    root.near(widget.width, 708 * expected, 'fast resize left the original hit box');
    root.near(widget.height, 454 * expected, 'aspect ratio changed');
    root.near(widget.x, x, 'resize moved the left edge');
    root.near(widget.y, y, 'resize moved the top edge');
    root.near(Aio.Placement.sizeFor(root.screen.name) * 708, scale * 708, 'resize persisted before release');
    driver.mouseRelease(input, px + dx, py + dy, Qt.LeftButton);
    root.require(input.gesture === '', 'resize release lost');
    root.near(Aio.Placement.sizeFor(root.screen.name) * 708, 708 * expected, 'new size not saved');
    root.require(Aio.Placement.sizeFor('other-monitor') === 0.82 &&
                 Aio.Placement.savedPosition('other-monitor').x === .25, 'other monitor placement changed');

    driver.mousePress(input, Math.round(x + 20), Math.round(y + 20), Qt.LeftButton);
    driver.mouseMove(input, Math.round(x + 80), Math.round(y + 70), 0);
    Aio.Placement.locked = true;
    driver.mouseRelease(input, Math.round(x + 80), Math.round(y + 70), Qt.LeftButton);
    root.require(input.gesture === '', 'locking retained active gesture');
    root.near(widget.x, x, 'cancel wrote a new desktop position');
  }

  function checkComponents() {
    var preview = driver.findChild(layout, 'layoutPreview');
    var otherDivider = driver.findChild(service, 'diagonalDivider');
    var input = driver.findChild(preview, 'componentPlacementInput');
    var divider = driver.findChild(preview, 'diagonalDivider');
    root.require(!!input && !!divider && divider.visible && !!otherDivider, 'divider missing');
    var before = Model.rect('weather', Aio.Config.layout);
    driver.mousePress(input, 90, 53, Qt.LeftButton);
    driver.mouseMove(input, 91, 53, 0);
    driver.mouseRelease(input, 91, 53, Qt.LeftButton);
    root.require(!Aio.Config.layout.weather, 'click or small motion wrote a position');
    driver.mousePress(input, 90, 53, Qt.LeftButton);
    driver.mouseMove(input, 470, 220, 0);
    root.require(!Aio.Config.layout.weather && input.dragged === 'weather', 'preview drag lost its grab or saved early');
    driver.mouseMove(input, 250, 189, 0);
    driver.mouseRelease(input, 250, 189, Qt.LeftButton);
    root.near(Aio.Config.layout.weather.x, before.x + 160, 'weather X drifted');
    root.near(Aio.Config.layout.weather.y, before.y + 136, 'weather Y drifted');
    root.require(divider.visible && divider.x === 312 && Aio.Config.get('show_divider') === true,
                 'moving Weather affected the divider');

    layout.selected = 'divider';
    driver.mousePress(input, 340, 72, Qt.LeftButton);
    driver.mouseMove(input, 188, 161, 0);
    driver.mouseRelease(input, 188, 161, Qt.LeftButton);
    root.near(divider.x, 160, 'divider X did not move independently');
    root.near(divider.y, 107, 'divider Y did not move independently');
    root.near(otherDivider.x, divider.x, 'desktop and editor did not share layout');
    var toggle = driver.findChild(layout, 'visibility-divider');
    driver.mouseClick(toggle, toggle.width / 2, toggle.height / 2);
    root.require(!divider.visible && Aio.Config.showWeather, 'divider toggle affected Weather or did not hide');
    driver.mouseClick(toggle, toggle.width / 2, toggle.height / 2);
    root.require(divider.visible, 'divider toggle did not restore rendering');

    var handle = driver.findChild(layout, 'reorder-divider');
    driver.mousePress(handle, 18, 20, Qt.LeftButton);
    driver.mouseMove(handle, 18, 170, 0);
    driver.mouseRelease(handle, 18, 170, Qt.LeftButton);
    root.require(Model.order(Aio.Config.layout)[3] === 'divider', 'stacking drag did not reorder');
    root.require(layout.dragged === '' && layout.dragOffset === 0, 'reorder retained a drag');
    Aio.Config.flush();
    Aio.Config.reload();
    root.require(Model.order(Aio.Config.layout)[3] === 'divider' && divider.visible, 'reload lost stacking or visibility');
    root.near(divider.x, 160, 'reload lost divider position');
  }

  Timer {
    interval: 500
    repeat: true
    running: true
    onTriggered: {
      if (!Aio.Config.ready || !Aio.Placement.stateReady)
        return;
      try {
        root.step++;
        if (root.step === 1) {
          Aio.Config.setValues({monitor: root.screen.name, anchor: 'top-left', margin_x: 56, margin_y: 56,
                                 scale: .36, show_weather: true, 'layout.snap': false});
          Aio.Config.resetValue('show_divider');
          Aio.Placement.setSize('other-monitor', .82);
          Aio.Placement.remember('other-monitor', 25, 40, 100, 100);
          Aio.Placement.locked = false;
        } else if (root.step === 2) {
          root.checkDesktop();
        } else if (root.step === 3) {
          root.checkComponents();
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
