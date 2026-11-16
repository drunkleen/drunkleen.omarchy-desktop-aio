.pragma library

// Pure selection policy, shared by settings, menu, surfaces and tests.
var modes = ['auto', 'sakura', 'green_leaves', 'yellow_leaves', 'orange_leaves', 'rain', 'snow'];
var snowCodes = [71, 73, 75, 77, 85, 86];
var rainCodes = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99];
var defaults = {
  enabled: true,
  preview: true,
  mode: 'sakura',
  density: 0.4,
  speed: 0.5,
  opacity: 0.75,
  size: 1,
  wind: 0.3
};
var limits = {
  density: [0, 1],
  speed: [0.1, 2],
  opacity: [0, 1],
  size: [0.25, 3],
  wind: [0, 3]
};
function bounded(value, range, fallback) {
  return typeof value === 'number' && isFinite(value) ? Math.max(range[0], Math.min(range[1], value)) :
                                                        fallback;
}
function normalize(input) {
  input = input || {};
  var cfg = {
    enabled: typeof input.enabled === 'boolean' ? input.enabled : defaults.enabled,
    preview: typeof input.preview === 'boolean' ? input.preview : defaults.preview,
    mode: modes.indexOf(input.mode) >= 0 ? input.mode : defaults.mode
  };
  Object.keys(limits).forEach(function (key) {
    cfg[key] = bounded(input[key], limits[key], defaults[key]);
  });
  return cfg;
}
function validate(key, value) {
  if (value === undefined)
    return;
  if ((key === 'enabled' || key === 'preview') && typeof value !== 'boolean')
    throw Error('ambient.enabled must be boolean');
  if (key === 'mode' && modes.indexOf(value) < 0)
    throw Error('Unknown ambient mode');
  if (limits[key] && (typeof value !== 'number' || !isFinite(value) || value < limits[key][0] || value
                      > limits[key][1]))
    throw Error('Invalid ambient.' + key);
}
function validLatitude(lat) {
  return typeof lat === 'number' && isFinite(lat) && Math.abs(lat) <= 90;
}
function season(month, latitude) {
  // month is 1..12, meteorological seasons. Equator/unknown latitude uses north.
  if (validLatitude(latitude) && latitude < 0)
    month = (month + 5) % 12 + 1;
  return month >= 3 && month <= 5 ? 'spring' : month >= 6 && month <= 8 ? 'summer' : month >= 9 && month <= 11
                                                                          ? 'autumn' : 'winter';
}
function localMonth(now, offset) {
  if (typeof offset === 'number' && isFinite(offset) && offset >= -43200 && offset <= 50400)
    return new Date(now.getTime() + offset * 1000).getUTCMonth() + 1;
  return now.getMonth() + 1;
}
function resolve(input, weather, now) {
  return resolveAtMonth(input, weather, localMonth(now || new Date(), (weather || {}).utcOffset));
}
function resolveAtMonth(input, weather, month) {
  var cfg = normalize(input);
  weather = weather || {};
  if (!cfg.enabled)
    return {
      effect: 'none',
      reason: 'disabled'
    };
  if (cfg.mode !== 'auto')
    return {
      effect: cfg.mode,
      reason: 'manual'
    };
  if (weather.available) {
    if (snowCodes.indexOf(weather.code) >= 0)
      return {
        effect: 'snow',
        reason: 'weather'
      };
    if (rainCodes.indexOf(weather.code) >= 0)
      return {
        effect: 'rain',
        reason: 'weather'
      };
  }
  var s = season(month, weather.latitude);
  return {
    effect: s === 'spring' ? 'sakura' : s === 'summer' ? 'green_leaves' : s === 'autumn' ? 'orange_leaves' :
                                                                                           'none',
    reason: s
  };
}
var palettes = {
  sakura: {
    petals: [
      {
        base: '#5C1020',
        tip: '#A63A50'
      },
      {
        base: '#8B1E2D',
        tip: '#A63A50'
      },
      {
        base: '#722F37',
        tip: '#8B1E2D'
      },
      {
        base: '#5C1020',
        tip: '#722F37'
      }
    ],
    accent: {
      base: '#C98E9A',
      tip: '#EBCFD6'
    },
    accent_chance: 0.1
  },
  green_leaves: {
    petals: [
      {
        base: '#31582A',
        tip: '#8CAB54'
      },
      {
        base: '#426C39',
        tip: '#BAD67B'
      },
      {
        base: '#245342',
        tip: '#6F9D65'
      },
      {
        base: '#647239',
        tip: '#AFC267'
      }
    ],
    accent: {
      base: '#80934D',
      tip: '#D3DA93'
    },
    accent_chance: 0.12
  },
  yellow_leaves: {
    petals: [
      {
        base: '#9F762C',
        tip: '#E8C86A'
      },
      {
        base: '#B49136',
        tip: '#F6DE8C'
      },
      {
        base: '#8B7130',
        tip: '#DAB650'
      },
      {
        base: '#BE994E',
        tip: '#EEDAA2'
      }
    ],
    accent: {
      base: '#D7B662',
      tip: '#FBE7A2'
    },
    accent_chance: 0.15
  },
  orange_leaves: {
    petals: [
      {
        base: '#8B482F',
        tip: '#DA9254'
      },
      {
        base: '#A35D31',
        tip: '#EDB966'
      },
      {
        base: '#704737',
        tip: '#B67846'
      },
      {
        base: '#B26B39',
        tip: '#E8A153'
      }
    ],
    accent: {
      base: '#B89045',
      tip: '#F0CF81'
    },
    accent_chance: 0.15
  },
  rain: {
    petals: [
      {
        base: '#547786',
        tip: '#A3C5D4'
      },
      {
        base: '#6B8D9A',
        tip: '#BDD6DE'
      }
    ],
    accent: null,
    accent_chance: 0
  },
  snow: {
    petals: [
      {
        base: '#D1E1E8',
        tip: '#F4F9FC'
      },
      {
        base: '#B7CCD8',
        tip: '#E7F0F6'
      }
    ],
    accent: null,
    accent_chance: 0
  }
};
function settings(input, effect) {
  var cfg = normalize(input);
  return {
    petal_count: Math.min(128, Math.round(cfg.density * (effect === 'rain' ? 125 : 62.5))),
    spawn_rate: cfg.density * (effect === 'rain' ? 60 : effect === 'snow' ? 8 : 1.25),
    fall_px: effect === 'rain' ? 900 : effect === 'snow' ? 34 : 60,
    speed_factor: cfg.speed / 0.5,
    wind_strength: cfg.wind / 2,
    depth_spread: 0.6,
    spin: effect === 'rain' ? 0 : effect === 'snow' ? 0.12 : 0.5,
    opacity: cfg.opacity,
    size_min: effect === 'rain' ? 16 : effect === 'snow' ? 4 : 12,
    size_max: effect === 'rain' ? 34 : effect === 'snow' ? 10 : 28,
    size_factor: cfg.size,
    fps: 30,
    palette: palettes[effect] || palettes.sakura
  };
}
function ownsSurface(enabled, checked, legacy) {
  return enabled && checked && !legacy;
}
