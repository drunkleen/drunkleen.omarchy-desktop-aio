pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons

Column {
  id: root
  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }
  spacing: 8
  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: Theme.foreground
    text: strings.t('weather.current') + ' ' + (Config.weatherSec.label || Config.city)
  }
  Ui.TextField {
    width: parent.width
    placeholderText: strings.t('weather.search')
    onTextEdited: Weather.search(text)
    onAccepted: Weather.search(text)
  }
  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: Theme.inkDim
    text: strings.t('weather.' + Weather.searchStatus)
  }
  Repeater {
    model: Weather.suggestions
    delegate: Ui.Button {
      required property var modelData
      width: parent.width
      leftAlign: true
      focusable: true
      // Omarchy Button uses PlainText for labels.
      text: modelData.label
      onClicked: Weather.choose(modelData)
    }
  }
  Ui.Button {
    text: strings.t('weather.refresh')
    focusable: true
    enabled: Config.showWeather
    onClicked: Weather.retry()
  }
  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: Theme.foreground
    text: strings.t('weather.' + Weather.status) + (Weather.errorText ? ' — ' + strings.t(Weather.errorText) :
                                                                        '')
  }
}
