import QtQuick
import Quickshell
import qs.Commons as Commons
import "plugin" as Aio

ShellRoot {
  id: root
  property bool configReady: Aio.Config.ready
  property color primary: Aio.Theme.primary
  property int step: 0
  QtObject {
    id: owner
  }
  Timer {
    interval: 700
    repeat: true
    running: true
    onTriggered: {
      if (!root.configReady)
        return;
      step++;
      if (step === 1) {
        Aio.Config.setValue('show_spectrum', true);
        Aio.Config.setValue('accent', '#abcdef');
        Aio.AudioBars.setActive(owner, true);
        Commons.Color.loadColors('accent = "#123456"\nforeground = "#eeeeee"\nbackground = "#111111"');
      }
      if (step === 5) {
        if (String(Aio.Theme.primary) !== '#123456' || String(Aio.Theme.accent) !== '#abcdef' ||
            !Aio.AudioBars.source.endsWith('.monitor') || !Aio.AudioBars.cava.running) {
          console.log('AIO_RUNTIME_FAIL theme or playback capture: ' + Aio.AudioBars.source + ' primary='
                      + Aio.Theme.primary + ' accent=' + Aio.Theme.accent + ' cava='
                      + Aio.AudioBars.cava.running);
          Qt.quit();
          return;
        }
        Commons.Color.loadColors('accent = "#654321"');
      }
      if (step === 6) {
        if (String(Aio.Theme.primary) !== '#654321') {
          console.log('AIO_RUNTIME_FAIL live theme palette');
          Qt.quit();
          return;
        }
        console.log('AUDIO_SOURCE ' + Aio.AudioBars.source);
        Aio.AudioBars.setActive(owner, false);
      }
      if (step === 8) {
        console.log(!Aio.AudioBars.cava.running && !Aio.AudioBars.routingEvents.running &&
                    !Aio.AudioBars.sourceLookup.running && Aio.AudioBars.source === '' ? 'AIO_RUNTIME_PASS' :
                                                                                         'AIO_RUNTIME_FAIL capture cleanup');
        Qt.quit();
      }
    }
  }
}
