pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C
import qs.Ui as Ui
import qs.Commons as Commons
import "Toml.js" as Toml

Column {
  id: root
  property string setting: ""
  property string label: ""
  property string kind: "text"
  property var options: []
  property real minimum: 0
  property real maximum: 1
  property real step: 0.01
  property var current: Toml.get(Config.data, setting.split('.'))
  signal committed(var value)
  function apply(value) {
    if (Config.setValue(setting, value))
      committed(value);
  }
  spacing: 6
  Text {
    visible: root.kind !== 'toggle'
    textFormat: Text.PlainText
    text: root.label + (root.kind === 'slider' ? '   ' + Number(root.current).toFixed(2) : '')
    color: Theme.foreground
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.body
  }
  Ui.Toggle {
    objectName: "toggle-" + root.setting
    activeFocusOnTab: true
    Keys.onSpacePressed: root.apply(!checked)
    visible: root.kind === 'toggle'
    width: parent.width
    label: root.label
    checked: root.current === true
    onClicked: root.apply(!checked)
  }
  Ui.TextField {
    id: field
    objectName: "text-" + root.setting
    visible: root.kind === 'text'
    width: parent.width
    text: String(root.current === undefined ? '' : root.current)
    onEditingFinished: if (text !== String(root.current === undefined ? '' : root.current))
                         root.apply(text)
    onAccepted: root.apply(text)
  }
  Ui.NumberField {
    visible: root.kind === 'number'
    width: parent.width
    from: root.minimum
    to: root.maximum
    stepSize: root.step
    value: Number(root.current || 0)
    onModified: value => root.apply(value)
  }
  SelectControl {
    objectName: 'select-' + root.setting
    visible: root.kind === 'select'
    width: parent.width
    value: String(root.current)
    options: root.options
    onChanged: value => root.apply(value)
  }
  C.Slider {
    objectName: "slider-" + root.setting
    visible: root.kind === 'slider'
    width: parent.width
    from: root.minimum
    to: root.maximum
    stepSize: root.step
    value: Number(root.current || 0)
    palette.highlight: Theme.accent
    palette.button: Theme.background
    palette.window: Theme.background
    palette.text: Theme.foreground
    onMoved: root.apply(Number(value.toFixed(6)))
  }
}
