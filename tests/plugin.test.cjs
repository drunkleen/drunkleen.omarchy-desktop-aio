const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');

test('TOML overrides preserve literal markup and independent weather settings', () => {
  const context = vm.createContext({});
  vm.runInContext(fs.readFileSync(path.join(root, 'Toml.js'), 'utf8').replace(/^\.pragma library\s*/, ''), context);
  const data = context.parse('scale = 0.55\nshow_weather = false\n[weather]\ncity = "<img src=https://example.invalid>"\nrefresh_seconds = 900\n');
  assert.equal(data.scale, 0.55);
  assert.equal(data.show_weather, false);
  assert.equal(data.weather.city, '<img src=https://example.invalid>');
  assert.equal(data.weather.refresh_seconds, 900);
});

test('Cava helper passes config to Cava, cleans temporary file, and rejects shell input', () => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'aio-cava-test-'));
  try {
    const capture = path.join(temp, 'captured');
    fs.writeFileSync(path.join(temp, 'cava'), '#!/bin/sh\ncp "$2" "$CAPTURE"\nprintf "%s" "$2" > "$CAPTURE.path"\n', {mode: 0o755});
    const env = {...process.env, PATH: temp + ':' + process.env.PATH, TMPDIR: temp, CAPTURE: capture};
    const run = args => spawnSync('bash', [path.join(root, 'scripts/cava-stream'), ...args], {env});
    assert.equal(run(['30', '40', '45']).status, 0);
    assert.match(fs.readFileSync(capture, 'utf8'), /framerate = 30\nbars = 40/);
    assert.match(fs.readFileSync(capture, 'utf8'), /method = pipewire/);
    assert.equal(fs.existsSync(fs.readFileSync(capture + '.path', 'utf8')), false);
    assert.equal(run(['30; touch /tmp/aio-injection', '40', '45']).status, 2);
  } finally { fs.rmSync(temp, {recursive: true, force: true}); }
});

test('size changes preserve old placement and persist per monitor outside configuration', () => {
  const source = fs.readFileSync(path.join(root, 'Placement.qml'), 'utf8');
  const methods = source.slice(source.indexOf('  function saveState()'), source.indexOf('  property FileView'));
  let saved;
  const context = vm.createContext({
    positions: {'DP-2': {x: 0.3, y: 1}}, sizes: {}, anchors: {}, locked: true, stateReady: true,
    Config: {scale: 0.55}, stateFile: {setText: text => saved = JSON.parse(text)}
  });
  context.root = context;
  vm.runInContext(methods, context);
  assert.equal(context.sizeFor('DP-2'), 0.55); // Existing state has no size field.
  context.setSize('DP-2', 0.75);
  context.saveState();
  assert.equal(saved.sizes['DP-2'], 0.75);
  assert.equal(saved.monitors['DP-2'].x, 0.3);
  assert.equal(saved.locked, true);
  assert.equal(context.sizeFor('eDP-1'), 0.55);
  context.setSize('DP-2', 9);
  assert.equal(context.sizeFor('DP-2'), 3);
  context.setSize('DP-2', null);
  assert.equal(context.sizeFor('DP-2'), 0.55);
});
