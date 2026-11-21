import QtQuick
import QtTest
import Quickshell
import "plugin" as Aio

ShellRoot {
  id: root
  property bool ready: Aio.Config.ready
  property int step: 0
  readonly property string draftPath: Aio.Config.directory + '/missing/draft.toml'
  Aio.SettingsPanel {
    id: panel
  }
  Aio.SettingControl {
    id: probe
    parent: panel.contentItem
    width: 100
    x: -1000
    kind: 'slider'
    setting: 'opacity'
  }
  TestCase {
    id: driver
    when: false
    parent: panel.contentItem
  }
  function page(name) {
    return driver.findChild(panel.contentItem, name + 'PageLoader');
  }
  function require(ok, message) {
    if (!ok)
      throw Error(message);
  }
  Timer {
    interval: 500
    repeat: true
    running: true
    onTriggered: {
      if (!root.ready)
        return;
      try {
        root.step++;
        switch (root.step) {
        case 1:
          panel.openFor(Quickshell.screens[0]);
          break;
        case 2:
          root.require(root.page('weather').item === null, 'search exists on General');
          root.require(driver.findChild(probe, 'textInputLoader').item === null && driver.findChild(probe,
                                                                                                    'numberInputLoader').item
                       === null, 'slider contains hidden input');
          panel.category = 'weather';
          break;
        case 3:
          var field = driver.findChild(root.page('weather').item, 'citySearchInput');
          root.require(!!field && root.page('weather').height > 0, 'Weather search or sizing missing');
          field.text = 'Paris';
          field.textEdited();
          break;
        case 4:
          root.require(Aio.Weather.suggestions.length === 2, 'city search no longer works');
          panel.category = 'general';
          break;
        case 5:
          root.require(root.page('weather').item === null, 'Weather not unloaded');
          root.require(!driver.findChild(panel.contentItem, 'citySearchInput'), 'hidden city input remains');
          root.require(Aio.Weather.searchRequest === null && Aio.Weather.searchStatus === 'idle',
                       'search not cancelled');
          panel.category = 'weather';
          break;
        case 6:
          var reopened = driver.findChild(root.page('weather').item, 'citySearchInput');
          root.require(!!reopened && reopened.text === '', 'return to Weather failed');
          root.require(Aio.Weather.suggestions.length === 0, 'stale city suggestions on return');
          reopened.text = 'Paris';
          reopened.textEdited();
          break;
        case 7:
          root.require(Aio.Weather.suggestions.length === 2, 'city search failed after reopening');
          Aio.Weather.choose(Aio.Weather.suggestions[1]);
          Aio.Config.flush();
          root.require(Aio.Config.city === 'Paris' && Aio.Config.weatherSec.latitude === 48,
                       'city not saved');
          Aio.Config.reload();
          panel.category = 'advanced';
          break;
        case 8:
          root.require(Aio.Config.city === 'Paris' && Aio.Config.weatherSec.latitude === 48,
                       'selection did not persist after reload');
          root.require(root.page('weather').item === null && !!root.page('advanced').item,
                       'Advanced lifecycle');
          var pathInput = driver.findChild(root.page('advanced').item, 'transferPathInput');
          root.require(pathInput.text === Aio.Config.directory + '/desktop-aio-export.toml',
                       'default transfer path missing');
          pathInput.forceActiveFocus();
          pathInput.text = root.draftPath;
          pathInput.textEdited();
          panel.category = 'layout';
          break;
        case 9:
          root.require(root.page('advanced').item === null && !!root.page('layout').item, 'Layout lifecycle');
          panel.category = 'advanced';
          break;
        case 10:
          var restoredPath = driver.findChild(root.page('advanced').item, 'transferPathInput');
          root.require(restoredPath.text === root.draftPath, 'unsaved transfer path lost');
          root.require(Aio.Config.error === '' && panel.confirmAction === null,
                       'navigation triggered an import or export');
          panel.category = 'appearance';
          break;
        case 11:
          root.require(root.page('layout').item === null, 'hidden layout editors remain');
          root.require(!!driver.findChild(panel.contentItem, 'text-font_display'),
                       'appearance editor missing');
          panel.category = 'weather';
          probe.kind = 'number';
          break;
        case 12:
          root.require(!!driver.findChild(probe, 'numberInputLoader').item && driver.findChild(probe,
                                                                                               'textInputLoader').item
                       === null, 'number input lifecycle');
          probe.kind = 'text';
          break;
        case 13:
          root.require(!!driver.findChild(probe, 'textInputLoader').item && driver.findChild(probe,
                                                                                             'numberInputLoader').item
                       === null, 'text input lifecycle');
          probe.visible = false;
          panel.visible = false;
          break;
        case 14:
          root.require(driver.findChild(probe, 'textInputLoader').item === null,
                       'hidden setting editor remains');
          root.require(root.page('weather').item === null, 'search remains after closing window');
          console.log('AIO_RUNTIME_PASS');
          Qt.quit();
          break;
        }
      } catch (e) {
        console.log('AIO_RUNTIME_FAIL ' + e);
        Qt.quit();
      }
    }
  }
}
