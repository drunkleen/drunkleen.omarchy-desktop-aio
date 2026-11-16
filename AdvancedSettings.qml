pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons

Column {
  id: root
  property var confirm: null
  property string imported: ""
  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }
  spacing: 10
  Ui.Button {
    text: strings.t('editConfig')
    focusable: true
    onClicked: Config.edit()
  }
  Ui.Button {
    text: strings.t('advanced.directory')
    focusable: true
    onClicked: Config.openDirectory()
  }
  Ui.Button {
    text: strings.t('advanced.reload')
    focusable: true
    onClicked: Config.reload()
  }
  Ui.TextField {
    id: path
    width: parent.width
    text: Config.directory + '/desktop-aio-export.toml'
    placeholderText: strings.t('advanced.path')
  }
  Ui.Button {
    text: strings.t('advanced.export')
    focusable: true
    onClicked: root.confirm(function () {
      Config.exportTo(path.text);
    })
  }
  Ui.Button {
    text: strings.t('advanced.import')
    focusable: true
    onClicked: {
      try {
        root.imported = Config.readImport(path.text);
        if (Config.error)
          return;
        root.confirm(function () {
          Config.importText(root.imported);
        });
      } catch (e) {
        Config.error = String(e);
      }
    }
  }
  Ui.Button {
    text: strings.t('layout.reset')
    focusable: true
    onClicked: root.confirm(function () {
      Config.resetSection('layout');
    })
  }
  Ui.Button {
    text: strings.t('advanced.reset')
    focusable: true
    onClicked: root.confirm(function () {
      Config.resetAll();
    })
  }
  Ui.Button {
    text: strings.t('advanced.completeReset')
    focusable: true
    onClicked: root.confirm(function () {
      Config.resetAll();
      Placement.resetAll();
    })
  }
  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: Theme.inkDim
    text: strings.t('advanced.help')
  }
}
