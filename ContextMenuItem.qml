import QtQuick
import QtQuick.Controls as C
import qs.Commons as Commons

C.MenuItem {
  id: root
  property string glyph: ""
  implicitHeight: 36
  implicitWidth: 290
  leftPadding: 32
  rightPadding: subMenu ? 28 : 12
  opacity: enabled ? 1 : 0.4
  font.family: Commons.Style.font.family
  font.pixelSize: Commons.Style.font.body
  contentItem: Text {
    textFormat: Text.PlainText
    text: root.text
    font: root.font
    color: root.highlighted ? Commons.Color.accent : Commons.Color.foreground
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }
  indicator: Text {
    x: 9
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.checkable ? (root.checked ? '✓' : '') : root.glyph
    color: Commons.Color.accent
    font: root.font
  }
  arrow: Text {
    x: root.width - width - 10
    anchors.verticalCenter: parent.verticalCenter
    visible: !!root.subMenu
    textFormat: Text.PlainText
    text: '›'
    color: Commons.Color.foreground
    font: root.font
  }
  background: Rectangle {
    radius: 5
    color: root.highlighted ? Commons.Style.hoverFillFor(Commons.Color.foreground, Commons.Color.accent) :
                              'transparent'
    border.width: root.activeFocus ? 1 : 0
    border.color: Commons.Color.accent
  }
}
