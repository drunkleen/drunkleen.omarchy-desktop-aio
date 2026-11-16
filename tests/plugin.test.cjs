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
