import QtQuick
import Quickshell
import "plugin" as Aio
import "plugin/ambient" as Particles

ShellRoot {
  Item {
    width: 2150
    height: 900
    Particles.PetalField {
      id: rain
      anchors.fill: parent
      effect: 'rain'
      settings: Aio.Ambient.settings
    }
  }
  property int step: 0
  property int frozenFrames: 0
  Timer {
    interval: 500
    repeat: true
    running: true
    onTriggered: {
      step++;
      if (step === 1) {
        Aio.Config.setValues({
                               'ambient.mode': 'rain',
                               'ambient.enabled': true,
                               'ambient.density': 1,
                               'ambient.speed': 1.81,
                               'ambient.size': 0.65,
                               'ambient.opacity': 1
                             });
      }
      if (step >= 5 && step <= 12) {
        var current = 0, bright = 0;
        for (var i = 0; i < rain.children.length; i++) {
          var p = rain.children[i];
          if (p.alive === true && p.kind === 'rain' && !p.retiring) {
            current++;
            if (p.opacity > 0.3)
              bright++;
          }
        }
        if (current !== 125 || bright < 15) {
          console.log('AIO_RUNTIME_FAIL rain density/visibility: ' + current + '/' + bright);
          Qt.quit();
        }
        console.log('RAIN_VISIBLE count=' + current + ' bright=' + bright);
      }
      if (step === 13) {
        rain.effectsEnabled = false;
        frozenFrames = rain.frameCount;
      }
      if (step === 14) {
        console.log(rain.liveCount === 0 && rain.frameCount === frozenFrames ? 'AIO_RUNTIME_PASS' :
                                                                               'AIO_RUNTIME_FAIL disabled rain processing');
        Qt.quit();
      }
    }
  }
}
