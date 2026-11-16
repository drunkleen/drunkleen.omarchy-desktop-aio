pragma ComponentBehavior: Bound
import QtQuick

// Owns the petal pool for one monitor and advances it from a single timer.
// Dormant particles are neither stepped nor drawn. The same motion clock
// also releases new particles at settings.spawn_rate per second.
Item {
  id: field

  required property var settings
  // False while the surface is hidden (fullscreen, pause): the timer stops, so
  // nothing wakes up or redraws.
  property bool running: true
  property bool effectsEnabled: true
  property string effect: "sakura"
  readonly property int poolSize: 128
  readonly property bool animating: ticker.running
  property int liveCount: 0
  property bool transitionPending: false
  property int frameCount: 0
  onEffectsEnabledChanged: if (!effectsEnabled)
                             clearPool()
  onEffectChanged: transition()
  onSettingsChanged: reconcileDensity()
  // Window rectangles to keep petals out from under, in this field's coordinates.
  property var obstacles: []

  readonly property int count: Math.min(poolSize, Math.max(0, settings.petal_count))
  // Motion is tuned at 1440 px of height and scaled to each monitor.
  readonly property real scaleY: height / 1440

  property real clock: 0
  property real spawnCooldown: 0
  property real lastMs: 0
  property bool seeded: false

  onWidthChanged: seedOnce()
  onHeightChanged: seedOnce()

  // Start with most of the pool already in flight so the first frame isn't empty.
  function seedOnce() {
    if (seeded || petals.count < poolSize || !petals.itemAt(poolSize - 1) || width <= 0 || height <= 0)
      return;
    if (!effectsEnabled || effect === "none" || count === 0)
      return;
    seeded = true;
    const initial = Math.max(1, Math.round(count * 0.8));
    for (var i = 0; i < initial; i++) {
      const petal = petals.itemAt(i);
      if (petal) {
        petal.spawn(true);
        liveCount++;
      }
    }
  }

  function spawnOne(anywhere) {
    for (var i = 0; i < poolSize; i++) {
      const petal = petals.itemAt(i);
      if (petal && !petal.alive) {
        petal.spawn(anywhere === true);
        liveCount++;
        return true;
      }
    }
    return false;
  }

  function clearPool() {
    for (var i = 0; i < poolSize; i++) {
      const p = petals.itemAt(i);
      if (p)
        p.alive = false;
    }
    liveCount = 0;
    seeded = false;
    lastMs = 0;
    spawnCooldown = 0;
  }
  function transition() {
    transitionPending = effect !== "none";
    for (var i = 0; i < poolSize; i++) {
      const p = petals.itemAt(i);
      if (p && p.alive)
        p.retiring = true;
    }
    spawnCooldown = 0;
    seedOnce();
  }
  function reconcileDensity() {
    transitionPending = true;
    var kept = 0;
    for (var i = 0; i < poolSize; i++) {
      const p = petals.itemAt(i);
      if (p && p.alive && !p.retiring && p.kind === effect) {
        if (kept >= count)
          p.retiring = true;
        else
          kept++;
      }
    }
  }
  function step() {
    frameCount++;
    const now = Date.now();
    // Measured dt keeps motion true if the timer fires late; clamped so a
    // stall never teleports petals.
    const dt = lastMs === 0 ? 1 / settings.fps : Math.min((now - lastMs) / 1000, 0.1);
    lastMs = now;
    clock += dt;

    // Wind swells slowly; two incommensurate sines keep it from looking periodic.
    const wind = settings.wind_strength * (0.7 + 0.2 * Math.sin(clock * 0.09) + 0.1 * Math.sin(clock * 0.23
                                                                                               + 1.3));

    var living = 0, current = 0;
    for (var i = 0; i < poolSize; i++) {
      const petal = petals.itemAt(i);
      if (petal && petal.alive) {
        petal.advance(dt, wind, width, height, obstacles);
        if (petal.alive) {
          living++;
          if (!petal.retiring && petal.kind === effect)
            current++;
        }
      }
    }
    liveCount = living;
    if (transitionPending && effect !== "none" && effectsEnabled) {
      const target = count;
      while (current < target) {
        if (!spawnOne(true))
          break;
        current++;
      }
      if (current >= target)
        transitionPending = false;
    }

    if (effect !== "none" && effectsEnabled && current < count && settings.spawn_rate > 0) {
      spawnCooldown -= dt;
      if (spawnCooldown <= 0) {
        spawnOne();
        // Jittered interval so releases never fall into a visible rhythm.
        spawnCooldown = (1 / settings.spawn_rate) * (0.5 + Math.random());
      }
    }
  }

  Timer {
    id: ticker
    interval: Math.round(1000 / field.settings.fps)
    repeat: true
    running: field.running && field.effectsEnabled && field.settings.opacity > 0 && field.width > 0 && field.height
             > 0 && ((field.effect !== "none" && field.count > 0) || field.liveCount > 0)
    onRunningChanged: {
      field.lastMs = 0;
      if (running)
        field.seedOnce();
    }
    onTriggered: field.step()
  }

  Repeater {
    id: petals
    model: field.poolSize
    onItemAdded: field.seedOnce()

    Petal {
      owner: field
    }
  }
}
