// Copied into an isolated config directory by scripts/check-runtime.
import QtQuick
import Quickshell
import Quickshell.Io
import "plugin" as Aio
import "plugin/ambient" as Particles

ShellRoot {
  id: root
  property Component serviceType: Component {Aio.Service {}}
  Aio.SettingsPanel {
    id: panel
  }
  Aio.ContextMenu {
    id: menu
  }
  Item {
    width: 640
    height: 360
    Particles.PetalField {
      id: particles
      width: 640
      height: 360
      effect: Aio.Ambient.effect
      settings: Aio.Ambient.settings
      effectsEnabled: Aio.Ambient.enabled
      running: true
    }
  }
  property int frozenFrames: 0
  property int weatherGeneration: 0
  property int step: 0
  property FileView disk: FileView {
    path: Aio.Config.path
    blockAllReads: true
    blockWrites: true
  }
  function require(ok, message) {
    if (!ok)
      throw Error(message + ': ' + Aio.Config.error);
  }
  Timer {
    interval: 700
    repeat: true
    running: true
    onTriggered: {
      try {
        root.step++;
        if (root.step === 1) {
          root.require(Aio.Config.ready, 'not ready');
          Aio.Config.setValue('opacity', .7);
          Aio.Config.flush();
        }
        if (root.step === 2) {
          root.disk.reload();
          root.require(root.disk.text().includes('0.7'), 'save');
          panel.openFor(Quickshell.screens[0]);
        }
        if (root.step >= 3 && root.step < 11)
          panel.category = ['general', 'weather', 'appearance', 'placement', 'layout', 'spectrum', 'media',
                            'advanced'][root.step - 3];
        if (root.step === 11) {
          Aio.Config.setValue('clock24h', false);
          root.disk.reload();
          root.disk.setText(root.disk.text() + '\n[external]\nunknown="preserve"\n');
          Aio.Config.flush();
        }
        if (root.step === 12) {
          root.disk.reload();
          root.require(root.disk.text().includes('preserve') && root.disk.text().includes('false'),
                       'external merge');
          Aio.Weather.search('Paris');
        }
        if (root.step === 14) {
          root.require(Aio.Weather.suggestions.length === 2, 'city suggestions');
          Aio.Weather.choose(Aio.Weather.suggestions[1]);
          Aio.Config.setValue('show_weather', true);
        }
        if (root.step === 16) {
          root.require(Aio.Weather.tempNow === 20 && Aio.Weather.available, 'metric forecast');
          Aio.Ambient.setMode('auto');
          Aio.Weather.current = {
            temperature_2m: 20,
            is_day: 1,
            weather_code: 71
          };
          root.require(Aio.Ambient.effect === 'snow', 'live WMO ambient selection');
          Aio.Weather.status = 'error';
          root.require(Aio.Ambient.effect !== 'snow', 'weather error uses seasonal fallback');
          Aio.Weather.status = 'ready';
          Aio.Config.setSectionValue('weather', 'units', 'imperial');
        }
        if (root.step === 18) {
          root.require(Aio.Weather.tempNow === 68 && Aio.Weather.available, 'live unit change');
          Aio.Weather.search('invalid');
        }
        if (root.step === 20) {
          root.require(Aio.Weather.suggestions.length === 0 && Aio.Config.city === 'Paris',
                       'invalid city preservation');
          Aio.Config.setValue('show_weather', false);
          panel.visible = false;
          menu.openAt(Quickshell.screens[0], 99999, 99999);
        }
        if (root.step === 21) {
          menu.submenu = 'anchor';
        }
        if (root.step === 22) {
          menu.close();
          Aio.Config.flush();
          root.require(Aio.Weather.request === null, 'weather cancellation');
          panel.category = 'ambient';
          panel.visible = true;
          Aio.Ambient.setMode('snow');
        }
        if (root.step === 23) {
          root.require(particles.animating && particles.liveCount > 0 && particles.liveCount <= 128,
                       'pooled snow renderer');
          Aio.Ambient.setMode('disabled');
          root.frozenFrames = particles.frameCount;
        }
        if (root.step === 24) {
          root.require(!particles.animating && particles.liveCount === 0 && particles.frameCount
                       === root.frozenFrames, 'disabled stops all particle processing');
          Aio.Ambient.setMode('yellow_leaves');
          particles.running = false;
          root.frozenFrames = particles.frameCount;
        }
        if (root.step === 25) {
          root.require(!particles.animating && particles.frameCount === root.frozenFrames,
                       'hidden surface pauses particles');
          particles.running = true;
        }
        if (root.step === 26) {
          root.require(particles.animating && particles.liveCount <= 128,
                       'resume retains single bounded pool');
          root.weatherGeneration = Aio.Weather.generation;
          Aio.Ambient.setMode('auto');
        }
        if (root.step === 27) {
          root.require(Aio.Weather.request === null && Aio.Weather.generation === root.weatherGeneration,
                       'automatic respects disabled weather');
          Aio.Ambient.setMode('rain');
        }
        if (root.step === 28) {
          root.require(Aio.Ambient.effect === 'rain' && particles.liveCount <= 128,
                       'manual effect transition');
          Aio.Config.setSectionValue('ambient', 'density', 0);
        }
        if (root.step === 30) {
          root.require(particles.liveCount === 0 && !particles.animating,
                       'zero density drains and stops the engine');
          root.frozenFrames = particles.frameCount;
        }
        if (root.step === 31) {
          root.require(particles.frameCount === root.frozenFrames, 'zero density has no frame wakeups');
          Aio.Ambient.setMode('disabled');
          Aio.Config.flush();
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
