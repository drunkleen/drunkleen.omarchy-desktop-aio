.pragma library

function locations(body) {
  var o = JSON.parse(body), results = Array.isArray(o.results) ? o.results : [];
  return results.slice(0, 8).filter(function (r) {
    return typeof r.name === 'string' && Number.isFinite(r.latitude) && Math.abs(r.latitude) <= 90 && Number.isFinite(
          r.longitude) && Math.abs(r.longitude) <= 180;
  }).map(function (r) {
    return {
      city: r.name.slice(0, 200),
      label: [r.name, r.admin1, r.country].filter(function (x) {
        return typeof x === 'string' && x.length;
      }).join(', ').slice(0, 256),
      latitude: r.latitude,
      longitude: r.longitude
    };
  });
}
function forecast(body) {
  var o = JSON.parse(body);
  if (!o.current || !Number.isFinite(o.current.temperature_2m))
    throw Error('Invalid forecast');
  var daily = [];
  if (o.daily && Array.isArray(o.daily.time))
    for (var i = 0; i < Math.min(3, o.daily.time.length); i++) {
      if (Number.isFinite(o.daily.temperature_2m_max[i]) && Number.isFinite(o.daily.temperature_2m_min[i]))
        daily.push({
                     day: o.daily.time[i],
                     hi: Math.round(o.daily.temperature_2m_max[i]),
                     lo: Math.round(o.daily.temperature_2m_min[i]),
                     code: o.daily.weather_code[i]
                   });
    }
  return {
    utcOffset: typeof o.utc_offset_seconds === "number" && o.utc_offset_seconds >= -43200
               && o.utc_offset_seconds <= 50400 ? o.utc_offset_seconds : null,
    current: o.current,
    daily: daily
  };
}
function current(request, generation, enabled) {
  return request === generation && enabled;
}
