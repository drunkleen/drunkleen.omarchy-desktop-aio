pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C
import qs.Commons as Commons

Column {
  id: root
  property string label: ""
  property string value: ""
  property var options: []
  property alias combo: choice
  signal changed(string value)
  spacing: 6
  Text {
    visible: root.label !== ''
    text: root.label
    textFormat: Text.PlainText
    color: Theme.foreground
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.body
  }
  C.ComboBox {
    id: choice
    objectName: root.objectName + '-combo'
    width: parent.width
    model: root.options
    textRole: 'label'
    valueRole: 'value'
    currentIndex: root.options.findIndex(function (o) {
      return String(typeof o === 'object' ? o.value : o) === String(root.value);
    })
    onActivated: index => root.changed(typeof root.options[index] === 'object' ? root.options[index].value :
                                                                                 root.options[index])
    displayText: currentIndex < 0 ? root.value : currentText
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.body
    palette.text: Theme.foreground
    palette.button: Theme.background
    palette.base: Theme.background
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.background
    delegate: C.ItemDelegate {
      required property int index
      width: choice.width
      highlighted: choice.highlightedIndex === index
      contentItem: Text {
        textFormat: Text.PlainText
        text: typeof root.options[parent.index] === 'object' ? root.options[parent.index].label : String(
                                                                 root.options[parent.index])
        font: choice.font
        color: Theme.foreground
        elide: Text.ElideRight
      }
      background: Rectangle {
        color: parent.highlighted ? Theme.inkFaint : Theme.background
      }
    }
  }
}
