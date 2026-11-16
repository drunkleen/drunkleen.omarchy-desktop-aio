pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
import "SettingsModel.js" as Model

Column {
  id: root
  property string monitorName: ""
  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }
  spacing: 4
  Grid {
    columns: 3
    spacing: 4
    Repeater {
      model: Model.anchors.slice(0, 9)
      delegate: Ui.Button {
        required property string modelData
        required property int index
        width: 62
        height: 40
        focusable: true
        text: ['↖', '↑', '↗', '←', '•', '→', '↙', '↓', '↘'][index]
        tooltipText: strings.t('anchor.' + modelData)
        selected: Placement.anchorFor(root.monitorName) === modelData
        onClicked: Placement.selectAnchor(root.monitorName, modelData)
      }
    }
  }
  Ui.Button {
    text: strings.t('anchor.free')
    focusable: true
    selected: Placement.anchorFor(root.monitorName) === 'free'
    onClicked: Placement.selectAnchor(root.monitorName, 'free')
  }
}
