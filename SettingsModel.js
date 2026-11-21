.pragma library
.import "AmbientModel.js" as Ambient

var legacyComponents = ['weather', 'weekday', 'clock', 'date', 'media', 'spectrum'];
var components = ['divider'].concat(legacyComponents);
var anchors = ['top-left', 'top-center', 'top-right', 'center-left', 'center', 'center-right', 'bottom-left',
               'bottom-center', 'bottom-right', 'free'];
var geometry = {
  divider: [312, 18, 50, 134],
  weather: [44, 34, 340, 130],
  weekday: [34, 150, 350, 240],
  clock: [392, 74, 316.72, 74],
  date: [392, 168, 316, 24],
  media: [392, 198, 316, 24],
  spectrum: [330, 300, 302, 120]
};
var numbers = {
  opacity: [0, 1],
  scale: [0.1, 3],
  margin_x: [-4096, 8192],
  margin_y: [-4096, 8192],
  x: [0, 32768],
  y: [0, 32768],
  'weather.refresh_seconds': [60, 86400],
  'weather.latitude': [-90, 90],
  'weather.longitude': [-180, 180],
  'spectrum.bars': [8, 128],
  'spectrum.fps': [10, 60],
  'spectrum.smoothing': [0, 100],
  'spectrum.sensitivity': [0.1, 10],
  'media.max_width': [20, 708]
};
var integers = ['margin_x', 'margin_y', 'x', 'y', 'weather.refresh_seconds', 'spectrum.bars', 'spectrum.fps',
                'spectrum.smoothing', 'media.max_width'];
function validate(key, v) {
  if (key.indexOf("ambient.") === 0) {
    Ambient.validate(key.slice(8), v);
    return;
  }
  if (v === undefined)
    return;
  if (numbers[key]) {
    if (typeof v !== 'number' || !isFinite(v) || v < numbers[key][0] || v > numbers[key][1] || (
          integers.indexOf(key) >= 0 && Math.floor(v) !== v))
      throw Error('Invalid ' + key);
    return;
  }
  if (/^(?:show_(?:divider|weather|weekday|clock|date|media|spectrum)|clock24h|layout\.snap|live_preview)$/.test(
        key)) {
    if (typeof v !== 'boolean')
      throw Error('Expected boolean: ' + key);
    return;
  }
  if (key === 'anchor' && anchors.indexOf(v) < 0)
    throw Error('Invalid anchor');
  if (key === 'weather.units' && ['metric', 'imperial'].indexOf(v) < 0)
    throw Error('Invalid units');
  if (['ink', 'accent'].indexOf(key) >= 0 && v !== '' && !/^#[\da-fA-F]{6}(?:[\da-fA-F]{2})?$/.test(v))
    throw Error('Use #RRGGBB or #RRGGBBAA');
  if (['monitor', 'anchor', 'font_display', 'font_icon', 'ink', 'accent', 'weather.city', 'weather.label',
       'weather.location_city'].indexOf(key) >= 0) {
    if (typeof v !== 'string' || v.length > 256 || /[\x00-\x1f]/.test(v))
      throw Error('Invalid text: ' + key);
    if (['weather.city', 'font_display', 'font_icon'].indexOf(key) >= 0 && !v.trim())
      throw Error('Empty ' + key);
  }
  if (key === 'layout.order' && !matchesOrder(v, components) && !matchesOrder(v, legacyComponents))
    throw Error('Layout order must contain each component once');
  if (/^layout\.(divider|weather|weekday|clock|date|media|spectrum)\.[xy]$/.test(key)) {
    var part = key.split('.'), g = geometry[part[1]], limit = part[2] === 'x' ? 708 - g[2] : 454 - g[3];
    if (typeof v !== 'number' || !isFinite(v) || v < 0 || v > limit)
      throw Error('Invalid component position');
  }
}
function matchesOrder(value, ids) {
  return Array.isArray(value) && value.length === ids.length && ids.every(function (id) {
    return value.indexOf(id) >= 0;
  });
}
function order(layout) {
  var v = layout && layout.order;
  if (matchesOrder(v, legacyComponents))
    return ['divider'].concat(v);
  return matchesOrder(v, components) ? v : components;
}
function componentVisible(data, id) {
  return data['show_' + id] !== false;
}
function rect(id, layout) {
  var g = geometry[id], p = layout && layout[id] || {};
  return {
    x: p.x === undefined ? g[0] : p.x,
    y: p.y === undefined ? g[1] : p.y,
    w: g[2],
    h: g[3]
  };
}
function bounded(id, x, y, snap) {
  var g = geometry[id];
  function bound(v, m) {
    v = snap ? Math.round(v / 8) * 8 : v;
    return Math.max(0, Math.min(m, v));
  }
  return {
    x: bound(x, 708 - g[2]),
    y: bound(y, 454 - g[3])
  };
}
function moveComponent(id, start, dx, dy, snap) {
  var next = bounded(id, start.x + dx, start.y + dy, snap);
  var deadZone = snap ? 4 : 0;
  return {
    x: Math.abs(dx) > deadZone ? next.x : start.x,
    y: Math.abs(dy) > deadZone ? next.y : start.y
  };
}
function componentAt(order, layout, selected, x, y) {
  function contains(id) {
    var g = rect(id, layout);
    return x >= g.x && x <= g.x + g.w && y >= g.y && y <= g.y + g.h;
  }
  // Selecting a row makes an obscured component reachable without restacking it.
  if (order.indexOf(selected) >= 0 && contains(selected))
    return selected;
  for (var i = order.length - 1; i >= 0; i--)
    if (contains(order[i]))
      return order[i];
  return '';
}
function offsetOrder(order, index, offset) {
  var to = Math.max(0, Math.min(order.length - 1, index + offset));
  if (index < 0 || index === to)
    return order;
  var next = order.slice();
  next.splice(to, 0, next.splice(index, 1)[0]);
  return next;
}
function reorder(order, id, before) {
  var a = order.filter(function (x) {
    return x !== id;
  }), i = a.indexOf(before);
  a.splice(i < 0 ? a.length : i, 0, id);
  return a;
}
function state(data) {
  if (!data || data.version !== 1)
    throw Error('Unsupported placement state');
  return {
    version: 1,
    locked: data.locked !== false,
    monitors: data.monitors || {},
    sizes: data.sizes || {},
    anchors: data.anchors || {}
  };
}
function placement(name, state, anchor, x, y, maxX, maxY, mx, my) {
  var p = state.monitors[name], a = state.anchors[name] || anchor;
  if (p && typeof p.x === 'number' && isFinite(p.x) && typeof p.y === 'number' && isFinite(p.y))
    return {
      x: Math.max(0, Math.min(1, p.x)) * maxX,
      y: Math.max(0, Math.min(1, p.y)) * maxY
    };
  return {
    x: Math.max(0, Math.min(maxX, a === 'free' ? x : a.indexOf('left') >= 0 ? mx : a.indexOf('right') >= 0
                                                                              ? maxX - mx : maxX / 2)),
    y: Math.max(0, Math.min(maxY, a === 'free' ? y : a.indexOf('top') >= 0 ? my : a.indexOf('bottom') >= 0
                                                                             ? maxY - my : maxY / 2))
  };
}
function selectAnchor(state, name, anchor) {
  var s = JSON.parse(JSON.stringify(state));
  delete s.monitors[name];
  s.anchors[name] = anchor;
  return s;
}

function dragPoint(initial, origin, pointer, maxX, maxY) {
  return {
    x: Math.max(0, Math.min(maxX, initial.x + pointer.x - origin.x)),
    y: Math.max(0, Math.min(maxY, initial.y + pointer.y - origin.y))
  };
}
function resizeScale(initial, dx, dy, width, height, x, y) {
  var delta = (dx * 708 + dy * 454) / (708 * 708 + 454 * 454), limit = Math.min(3, (width - x) / 708, (height
                                                                                                       - y) / 454);
  return Math.max(0.1, Math.min(limit, initial + delta));
}
