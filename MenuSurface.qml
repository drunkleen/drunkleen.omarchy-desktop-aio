import QtQuick
import QtQuick.Controls as C
import qs.Commons as Commons

C.Menu {
  id: root
  property real screenHeight: 720
  width: 300
  margins: 8
  padding: 6
  height: Math.min(implicitHeight, Math.max(80, screenHeight - 16))
  closePolicy: C.Popup.CloseOnEscape | C.Popup.CloseOnPressOutside
  delegate: ContextMenuItem {}
  background: Rectangle {
    color: Commons.Color.background
    border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b,
                          0.25)
    radius: 8
  }
  contentItem: ListView {
    id: list
    implicitHeight: contentHeight
    model: root.contentModel
    currentIndex: root.currentIndex
    clip: true
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationWraps: true
    C.ScrollIndicator.vertical: C.ScrollIndicator {}
  }
}
