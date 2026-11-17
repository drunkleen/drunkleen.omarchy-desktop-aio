pragma Singleton
import QtQuick
import qs.Commons as Commons

// Ink and accent for the widget, following the current Omarchy theme
// (~/.local/state/omarchy/current/theme/colors.toml). Overridable from config.
QtObject {
  id: root

  // Omarchy pushes theme transitions into its shared palette; file watches
  // alone can miss a replaced current-theme symlink.
  readonly property color primary: Commons.Color.accent
  readonly property color accent: Config.accent !== "" ? Config.accent : primary
  readonly property color foreground: Commons.Color.foreground
  readonly property color background: Commons.Color.background

  readonly property color ink: Config.ink !== "" ? Config.ink : foreground
  readonly property color inkDim: Qt.rgba(ink.r, ink.g, ink.b, 0.62)
  readonly property color inkFaint: Qt.rgba(ink.r, ink.g, ink.b, 0.35)

  readonly property string font: Config.fontDisplay
  readonly property string display: Config.fontDisplay
  readonly property string icon: Config.fontIcon
}
