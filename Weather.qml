pragma Singleton
import QtQuick
import "Wmo.js" as Wmo
import "WeatherModel.js" as Model

QtObject {
  id: root
  property int failures: 0
  property bool available: false
  property string status: "idle"
  property string errorText: ""
  property string locationCity: ""
  property var locationLatitude: null
  property var utcOffsetSeconds: null
  property string placeName: ""
  property var current: null
  property var daily: []
  property var request: null
  property var searchRequest: null
  property int generation: 0
  property int searchGeneration: 0
  property var suggestions: []
  property string searchStatus: "idle"
  property string searchQuery: ""
  readonly property string city: placeName || Config.city
  readonly property bool isDay: current ? Number(current.is_day) === 1 : true
  readonly property int code: current ? Number(current.weather_code) : 0
  readonly property int tempNow: current ? Math.round(Number(current.temperature_2m)) : 0
  readonly property string condition: Wmo.conditionFor(code)
  readonly property string glyph: Wmo.symbolFor(code, isDay)
  readonly property string requestKey: JSON.stringify([Config.ready, Config.showWeather, Config.city, Config.units,
                                                       Config.weatherSec.latitude,
                                                       Config.weatherSec.longitude])
  onRequestKeyChanged: {
    available = false;
    cancel();
    failures = 0;
    if (Config.ready && Config.showWeather)
      changeTimer.restart();
    else {
      status = "idle";
      available = false;
    }
  }
  function cancel() {
    recovery.stop();
    generation++;
    if (request) {
      request.destroy();
      request = null;
    }
  }
  function send(url, callback) {
    var token = generation;
    var obj = transport.createObject(root, {
                                       url: url
                                     });
    request = obj;
    obj.finished.connect(function (ok, body) {
      if (Model.current(token, generation, Config.showWeather)) {
        request = null;
        callback(ok, body);
      }
      obj.destroy();
    });
  }
  function failed() {
    status = "error";
    errorText = "weather.networkError";
    failures = Math.min(failures + 1, 6);
    if (Config.ready && Config.showWeather)
      recovery.restart();
  }
  function retry() {
    cancel();
    if (!Config.ready || !Config.showWeather)
      return;
    status = "loading";
    errorText = "";
    var w = Config.weatherSec;
    if (typeof w.latitude === 'number' && typeof w.longitude === 'number' && (!w.location_city || w.location_city
                                                                              === Config.city))
      forecast(w.latitude, w.longitude, w.label || Config.city);
    else
      send("https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name="
           + encodeURIComponent(Config.city), function (ok, body) {
             try {
               if (!ok)
                 throw Error();
               var cities = Model.locations(body);
               if (!cities.length) {
                 status = "error";
                 errorText = "weather.notFound";
                 return;
               }
               forecast(cities[0].latitude, cities[0].longitude, cities[0].label);
             } catch (e) {
               root.failed();
             }
           });
  }
  function forecast(lat, lon, label) {
    send("https://api.open-meteo.com/v1/forecast?timezone=auto&forecast_days=3&latitude=" + lat
         + "&longitude=" + lon
         + "&current=temperature_2m,is_day,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min"
         + (Config.units === 'imperial' ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : ""), function (
           ok, body) {
           try {
             if (!ok)
               throw Error();
             var data = Model.forecast(body);
             locationCity = Config.city;
             locationLatitude = lat;
             utcOffsetSeconds = data.utcOffset;
             current = data.current;
             daily = data.daily;
             placeName = label;
             failures = 0;
             recovery.stop();
             available = true;
             status = "ready";
             errorText = "";
           } catch (e) {
             root.failed();
           }
         });
  }
  function cancelSearch() {
    searchTimer.stop();
    searchGeneration++;
    if (searchRequest) {
      searchRequest.destroy();
      searchRequest = null;
    }
    searchStatus = "idle";
  }
  function search(query) {
    searchTimer.stop();
    searchQuery = query;
    searchGeneration++;
    if (searchRequest) {
      searchRequest.destroy();
      searchRequest = null;
    }
    suggestions = [];
    if (query.trim().length < 2) {
      searchStatus = "idle";
      return;
    }
    searchStatus = "loading";
    searchTimer.restart();
  }
  function searchNow() {
    var token = searchGeneration;
    var obj = transport.createObject(root, {
                                       url: "https://geocoding-api.open-meteo.com/v1/search?count=8&language=en&format=json&name="
                                            + encodeURIComponent(searchQuery.slice(0, 200))
                                     });
    searchRequest = obj;
    obj.finished.connect(function (ok, body) {
      if (token === searchGeneration) {
        searchRequest = null;
        try {
          if (!ok)
            throw Error();
          suggestions = Model.locations(body);
          searchStatus = suggestions.length ? 'ready' : 'notFound';
        } catch (e) {
          searchStatus = 'networkError';
        }
      }
      obj.destroy();
    });
  }
  function choose(location) {
    var changes = {
      'weather.city': location.city,
      'weather.label': location.label,
      'weather.latitude': location.latitude,
      'weather.longitude': location.longitude,
      'weather.location_city': location.city
    };
    if (Config.setValues(changes)) {
      suggestions = [];
      searchStatus = 'selected';
    }
  }
  property Component transport: Component {
    HttpRequest {}
  }
  property Timer recovery: Timer {
    interval: Math.min(300, 15 * Math.pow(2, Math.max(0, root.failures - 1))) * 1000
    onTriggered: root.retry()
  }
  property Timer changeTimer: Timer {
    interval: 250
    onTriggered: root.retry()
  }
  property Timer searchTimer: Timer {
    interval: 350
    onTriggered: root.searchNow()
  }
  property Timer refresh: Timer {
    interval: Math.max(60, Config.refreshSeconds) * 1000
    repeat: true
    running: Config.ready && Config.showWeather
    onTriggered: root.retry()
  }
  Component.onCompleted: if (Config.ready && Config.showWeather)
                           changeTimer.restart()
}
