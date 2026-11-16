.pragma library
.import "SettingsModel.js" as Model

var names = ['general', 'weather', 'appearance', 'placement', 'layout', 'spectrum', 'media', 'ambient',
             'advanced'];
function field(key, kind, min, max, step, options) {
  return {
    key: key,
    kind: kind,
    min: min || 0,
    max: max === undefined ? 1 : max,
    step: step || 1,
    options: options || []
  };
}
function fields(page) {
  if (page === 'general')
    return [field('clock24h', 'toggle'), field('live_preview', 'toggle')].concat(['weekday', 'clock', 'date', 'weather',
                                                                                  'spectrum', 'media'].map(
                                                                                   function (x) {
                                                                                     return field('show_' + x,
                                                                                                  'toggle');
                                                                                   }));
  if (page === 'weather')
    return [field('show_weather', 'toggle'), field('weather.units', 'select', 0, 0, 1, ['metric', 'imperial']), field(
              'weather.refresh_seconds', 'number', 60, 86400, 60)];
  if (page === 'appearance')
    return [field('opacity', 'slider', 0, 1, .01), field('scale', 'slider', .1, 3, .01), field('font_display',
                                                                                               'text'), field(
              'font_icon', 'text'), field('ink', 'text'), field('accent', 'text')];
  if (page === 'placement')
    return [field('anchor', 'select', 0, 0, 1, Model.anchors), field('margin_x', 'number', -4096, 8192), field(
              'margin_y', 'number', -4096, 8192), field('x', 'number', 0, 32768), field('y', 'number', 0,
                                                                                        32768)];
  if (page === 'spectrum')
    return [field('show_spectrum', 'toggle'), field('spectrum.bars', 'number', 8, 128), field('spectrum.fps', 'number', 10,
                                                                                              60), field(
              'spectrum.smoothing', 'number', 0, 100), field('spectrum.sensitivity', 'slider', .1, 10, .1)];
  if (page === 'media')
    return [field('show_media', 'toggle'), field('media.max_width', 'number', 20, 708)];
  return [];
}
