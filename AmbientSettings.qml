pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
import "AmbientModel.js" as Model
import "ambient"

Column {
  id: root
  property var confirm: null
  property string resolvedText: strings.t('ambient.mode.auto') + ' → ' + strings.t('ambient.mode.'
                                                                                   + Ambient.effect) + ' ('
                                + strings.t('ambient.reason.' + Ambient.reason) + ')'
  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl('i18n')
  }
  spacing: 12
  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: Theme.foreground
    text: Ambient.config.mode === 'auto' ? root.resolvedText : strings.t('ambient.mode.' + (Ambient.enabled
                                                                                            ? Ambient.config.mode :
                                                                                              'none'))
  }
  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: Theme.inkDim
    text: strings.t('ambient.help')
  }
  Text {
    width: parent.width
    visible: Ambient.legacyOwned
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: Theme.foreground
    text: strings.t('ambient.legacy')
  }
  Ui.Button {
    visible: Ambient.legacyOwned
    focusable: true
    text: strings.t('ambient.takeover')
    onClicked: root.confirm(function () {
      Ambient.takeOwnership();
    }, strings.t('ambient.takeoverConfirm'))
  }
  Ui.Button {
    visible: Ambient.legacyOwned
    focusable: true
    text: strings.t('ambient.recheck')
    onClicked: Ambient.checkLegacy()
  }
  Text {
    width: parent.width
    visible: Ambient.error !== ''
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: Theme.accent
    text: strings.t(Ambient.error)
  }
  Repeater {
    model: [
      {
        key: 'enabled',
        kind: 'toggle'
      },
      {
        key: 'mode',
        kind: 'select'
      },
      {
        key: 'density',
        kind: 'slider',
        min: 0,
        max: 1,
        step: 0.01
      },
      {
        key: 'speed',
        kind: 'slider',
        min: 0.1,
        max: 2,
        step: 0.01
      },
      {
        key: 'opacity',
        kind: 'slider',
        min: 0,
        max: 1,
        step: 0.01
      },
      {
        key: 'size',
        kind: 'slider',
        min: 0.25,
        max: 3,
        step: 0.05
      },
      {
        key: 'wind',
        kind: 'slider',
        min: 0,
        max: 3,
        step: 0.05
      },
      {
        key: 'preview',
        kind: 'toggle'
      }
    ]
    delegate: SettingControl {
      required property var modelData
      width: parent.width
      setting: 'ambient.' + modelData.key
      label: strings.t(setting)
      kind: modelData.kind
      minimum: modelData.min === undefined ? 0 : modelData.min
      maximum: modelData.max === undefined ? 1 : modelData.max
      step: modelData.step || 0.01
      current: Ambient.config[modelData.key]
      enabled: modelData.key === 'enabled' || Ambient.enabled
      opacity: enabled ? 1 : 0.45
      options: Model.modes.map(function (mode) {
        return {
          value: mode,
          label: strings.t('ambient.mode.' + mode)
        };
      })
    }
  }
  Rectangle {
    width: parent.width
    height: visible ? 180 : 0
    visible: Ambient.enabled && Ambient.config.preview
    clip: true
    color: Theme.background
    border.color: Theme.inkFaint
    radius: Commons.Style.cornerRadius
    PetalField {
      objectName: 'aioAmbientPreview'
      anchors.fill: parent
      settings: Ambient.settings
      effect: Ambient.effect
      effectsEnabled: Ambient.enabled
      running: root.visible && parent.visible
    }
  }
  Ui.Button {
    text: strings.t('ambient.reset')
    focusable: true
    onClicked: root.confirm(function () {
      Config.resetSection('ambient');
    })
  }
}
