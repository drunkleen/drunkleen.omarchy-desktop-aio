import QtQuick
import Quickshell
import "plugin" as Aio

ShellRoot {
  property bool initialized: Aio.Config.ready
  property string weatherStatus: Aio.Weather.status
  property int step: 0
  function check(ok, message) {
    if (!ok) {
      console.log('AIO_RUNTIME_FAIL ' + message);
      Qt.quit();
    }
  }
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      step++;
      if (step === 2) {
        check(Aio.Config.city === 'Dresden' && Aio.Config.weatherSec.latitude === 51.05089,
              'saved city and coordinates must load at startup');
        check(Aio.Weather.status === 'error' && Aio.Weather.recovery.running,
              'initial network failure must schedule recovery');
        check(Aio.Weather.recovery.interval === 15000, 'first recovery delay');
      }
      if (step === 19) {
        check(Aio.Weather.status === 'ready' && Aio.Weather.available, 'network recovery without user input');
        check(Aio.Weather.locationCity === 'Dresden' && !Aio.Weather.recovery.running,
              'saved location recovered');
        Aio.Weather.failed();
        Aio.Weather.failed();
        check(Aio.Weather.recovery.interval === 30000, 'bounded exponential retry');
        Aio.Config.setValue('show_weather', false);
      }
      if (step === 20) {
        check(!Aio.Weather.recovery.running && Aio.Weather.request === null, 'disable cancels recovery');
        console.log('AIO_RUNTIME_PASS');
        Qt.quit();
      }
    }
  }
}
