import QtQuick
import QtQuick.Shapes

// One sakura petal, drawn as a vector path with a gradient from stem to tip and
// a faint highlight. Each petal lives in a 3D world: x and y are world
// coordinates on the z = 0 plane, and z is its distance from the screen. A
// perspective projection maps the world to the screen, so near petals are
// larger, faster and brighter, and far petals are smaller, slower and dimmer.
// State is plain properties and advance() does no allocation.
Item {
  id: petal

  required property var owner
  property bool alive: false
  property string kind: "sakura"
  property bool retiring: false
  property real transitionOpacity: 0
  property real opacityVariation: 1

  // World state, in px on the z = 0 plane.
  property real size: 14        // petal size at z = 0
  property real driftX: 0       // world x before sway
  property real fallY: 0        // world y
  property real fallRate: 20    // world px/s
  property real driftRate: 0    // world px/s at full wind
  property real swayAmp: 20     // world px
  property real swayRate: 0.5   // rad/s
  property real swayPhase: 0

  // Depth: z is distance from the screen plane; proj = 1 / (1 + z) scales it.
  property real zDist: 0
  property real proj: 1

  property real angle: 0        // deg
  property real spin: 0         // deg/s
  property real flipPhase: 0
  property real flipRate: 0     // rad/s
  property real flip: 1         // horizontal squash that reads as a 3D tumble
  property real fade: 1
  // 1 on open wallpaper, eases to 0 under an app window.
  property real clear: 1
  property var colors: null

  // Projected screen position and size.
  readonly property real screenSize: size * proj * owner.settings.size_factor
  readonly property real screenX: owner.width / 2 + (driftX + swayAmp * Math.sin(swayPhase) - owner.width
                                                     / 2) * proj
  readonly property real screenY: owner.height / 2 + (fallY - owner.height / 2) * proj

  visible: alive
  width: screenSize
  height: screenSize
  x: screenX - width / 2
  y: screenY - height / 2
  rotation: kind === "rain" ? -Math.atan(owner.settings.wind_strength * 0.12) * 180 / Math.PI : angle
  transformOrigin: Item.Center
  // Far petals dim and fade into the air; near petals stay close to full strength.
  opacity: transitionOpacity * opacityVariation * fade * clear * owner.settings.opacity * Math.min(1, 0.3
                                                                                                   + 0.7 * proj)

  // Brings a petal in from above the top edge, or anywhere when seeding the field.
  function spawn(anywhere) {
    const s = owner.settings;
    kind = owner.effect;
    retiring = false;
    transitionOpacity = 0;
    opacityVariation = 0.65 + 0.35 * Math.random();
    const k = owner.height / 1440;
    const cx = owner.width / 2;
    const cy = owner.height / 2;

    // Random depth, scaled by depth_spread: 0 puts every petal on one plane, 1
    // spreads them from just in front of the screen to well behind it.
    zDist = s.depth_spread * (-0.3 + 2.5 * Math.random());
    proj = 1 / (1 + zDist);
    size = s.size_min + (s.size_max - s.size_min) * Math.random();

    // Pick a screen position, then convert it to world coordinates.
    driftX = cx + (Math.random() * owner.width - cx) / proj;
    fallY = anywhere ? cy + (Math.random() * owner.height - cy) / proj : cy - (cy + size * proj
                                                                               * s.size_factor) / proj;

    fallRate = s.fall_px * (0.85 + 0.3 * Math.random());
    driftRate = 55 * (0.8 + 0.4 * Math.random());
    swayAmp = (kind === "rain" ? 0 : kind === "snow" ? 20 + 35 * Math.random() : 14 + 26 * Math.random()) * k;
    swayRate = kind === "snow" ? 0.2 + 0.3 * Math.random() : 0.35 + 0.45 * Math.random();
    swayPhase = Math.random() * 2 * Math.PI;
    angle = Math.random() * 360;
    spin = (Math.random() < 0.5 ? -1 : 1) * (4 + 12 * Math.random()) * s.spin;
    flipPhase = Math.random() * 2 * Math.PI;
    flipRate = (0.6 + 0.8 * Math.random()) * s.spin;
    colors = pickColors(s.palette);
    clear = 1;
    fade = 0;
    alive = true;
  }

  function pickColors(palette) {
    if (palette.accent && Math.random() < palette.accent_chance)
      return palette.accent;
    return palette.petals[Math.floor(Math.random() * palette.petals.length)];
  }

  // True when the petal's center sits inside a window, padded by half its size
  // so it starts fading before its edge reaches the window.
  function underWindow(px, py, obstacles) {
    const pad = screenSize / 2;
    for (var i = 0; i < obstacles.length; i++) {
      const r = obstacles[i];
      if (px >= r.x - pad && px <= r.x + r.w + pad && py >= r.y - pad && py <= r.y + r.h + pad)
        return true;
    }
    return false;
  }

  // Steps the petal. Sets alive = false once it has fully fallen out of view.
  function advance(dt, wind, width, height, obstacles) {
    const cx = width / 2;
    const margin = 2 * size * owner.settings.size_factor + swayAmp;

    if (retiring) {
      transitionOpacity = Math.max(0, transitionOpacity - dt / 0.65);
      if (transitionOpacity <= 0) {
        alive = false;
        return;
      }
    } else
      transitionOpacity = Math.min(1, transitionOpacity + dt / 0.65);
    const speed = owner.settings.speed_factor;
    driftX += driftRate * (owner.height / 1440) * wind * dt * speed * (kind === "rain" ? 2.5 : 1);
    // Wrap sideways just outside the visible area. Near the screen plane the
    // visible world width is narrower, far away it is wider; use the wider bound.
    const half = cx / proj + margin;
    const span = 2 * half;
    driftX = ((driftX - cx + half) % span + span) % span - half + cx;

    fallY += fallRate * (owner.height / 1440) * dt * speed;
    swayPhase += swayRate * dt * speed;
    angle += spin * dt * speed;
    flipPhase += flipRate * dt * speed;
    flip = flipRate > 0 ? 0.35 + 0.65 * Math.abs(Math.cos(flipPhase)) : 1;

    // Fade in as it enters from the top, fade out over the bottom fifth.
    const sy = height / 2 + (fallY - height / 2) * proj;
    const ss = screenSize;
    const fadeIn = Math.min(1, Math.max(0, (sy + ss) / (0.1 * height)));
    const fadeOut = Math.min(1, Math.max(0, (height - sy) / (0.22 * height)));
    fade = Math.min(fadeIn, fadeOut);

    // Ease toward the target so petals slide out from under windows, never pop.
    const sx = cx + (driftX + swayAmp * Math.sin(swayPhase) - cx) * proj;
    const target = underWindow(sx, sy, obstacles) ? 0 : 1;
    clear += (target - clear) * Math.min(1, dt * 6);

    if (sy - ss / 2 > height)
      alive = false;
  }

  Shape {
    visible: petal.kind !== "rain" && petal.kind !== "snow"
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    transform: Scale {
      origin.x: petal.width / 2
      origin.y: petal.height / 2
      xScale: petal.flip
    }

    ShapePath {
      strokeColor: "transparent"
      fillGradient: LinearGradient {
        x1: petal.width / 2
        y1: petal.height
        x2: petal.width / 2
        y2: 0
        GradientStop {
          position: 0.0
          color: petal.colors ? petal.colors.base : "#8B1E2D"
        }
        GradientStop {
          position: 1.0
          color: petal.colors ? petal.colors.tip : "#A63A50"
        }
      }

      // Obcordate sakura petal: broad rounded lobes, shallow notch at the tip,
      // narrow claw at the stem.
      startX: petal.width * 0.5
      startY: petal.height
      PathCubic {
        x: petal.width * 0.02
        y: petal.height * 0.38
        control1X: petal.width * 0.12
        control1Y: petal.height * 0.98
        control2X: petal.width * 0.0
        control2Y: petal.height * 0.62
      }
      PathCubic {
        x: petal.width * 0.42
        y: petal.height * 0.04
        control1X: petal.width * 0.04
        control1Y: petal.height * 0.14
        control2X: petal.width * 0.30
        control2Y: petal.height * 0.02
      }
      PathCubic {
        x: petal.width * 0.5
        y: petal.height * 0.2
        control1X: petal.width * 0.46
        control1Y: petal.height * 0.05
        control2X: petal.width * 0.48
        control2Y: petal.height * 0.12
      }
      PathCubic {
        x: petal.width * 0.58
        y: petal.height * 0.04
        control1X: petal.width * 0.52
        control1Y: petal.height * 0.12
        control2X: petal.width * 0.54
        control2Y: petal.height * 0.05
      }
      PathCubic {
        x: petal.width * 0.98
        y: petal.height * 0.38
        control1X: petal.width * 0.70
        control1Y: petal.height * 0.02
        control2X: petal.width * 0.96
        control2Y: petal.height * 0.14
      }
      PathCubic {
        x: petal.width * 0.5
        y: petal.height
        control1X: petal.width * 1.0
        control1Y: petal.height * 0.62
        control2X: petal.width * 0.88
        control2Y: petal.height * 0.98
      }
    }

    // Soft light along the left lobe, the one visible shading cue on a flat petal.
    ShapePath {
      strokeColor: "transparent"
      fillColor: Qt.rgba(1, 1, 1, 0.14)
      startX: petal.width * 0.5
      startY: petal.height * 0.95
      PathCubic {
        x: petal.width * 0.14
        y: petal.height * 0.42
        control1X: petal.width * 0.36
        control1Y: petal.height * 0.9
        control2X: petal.width * 0.12
        control2Y: petal.height * 0.7
      }
      PathCubic {
        x: petal.width * 0.44
        y: petal.height * 0.14
        control1X: petal.width * 0.18
        control1Y: petal.height * 0.2
        control2X: petal.width * 0.36
        control2Y: petal.height * 0.1
      }
      PathCubic {
        x: petal.width * 0.5
        y: petal.height * 0.95
        control1X: petal.width * 0.5
        control1Y: petal.height * 0.4
        control2X: petal.width * 0.52
        control2Y: petal.height * 0.8
      }
    }
  }
  // Rain and snow share the same pool, clock, depth and lifetime as the petals.
  // Only their vector geometry and motion parameters differ.
  Rectangle {
    visible: petal.kind === "rain"
    anchors.centerIn: parent
    width: Math.max(1, petal.screenSize * 0.055)
    height: petal.screenSize
    radius: width / 2
    gradient: Gradient {
      GradientStop {
        position: 0
        color: "transparent"
      }
      GradientStop {
        position: 1
        color: petal.colors ? petal.colors.tip : "#A3C5D4"
      }
    }
  }
  Shape {
    visible: petal.kind === "snow"
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: petal.colors ? petal.colors.tip : "#E7F0F6"
      strokeWidth: Math.max(0.8, petal.width * 0.07)
      fillColor: "transparent"
      startX: petal.width * 0.5
      startY: 0
      PathLine {
        x: petal.width * 0.5
        y: petal.height
      }
      PathMove {
        x: petal.width * 0.07
        y: petal.height * 0.25
      }
      PathLine {
        x: petal.width * 0.93
        y: petal.height * 0.75
      }
      PathMove {
        x: petal.width * 0.07
        y: petal.height * 0.75
      }
      PathLine {
        x: petal.width * 0.93
        y: petal.height * 0.25
      }
    }
  }
}
