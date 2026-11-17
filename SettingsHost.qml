import QtQuick

// Own each backing window for one open session. Closing destroys transient
// controls/popups; durable configuration remains in the existing singletons.
Item {
  id: root
  property var panel: null
  property string lastCategory: 'general'
  function release(window) {
    if (root.panel !== window)
      return;
    root.lastCategory = window.category;
    root.panel = null;
    window.visible = false;
    window.destroy();
  }
  function openFor(screen) {
    if (panel && panel.visible && panel.backingWindowVisible) {
      panel.openFor(screen);
      return;
    }
    if (panel)
      release(panel);
    var window = factory.createObject(root, {
                                        category: lastCategory
                                      });
    root.panel = window;
    window.visibleChanged.connect(function () {
      if (!window.visible)
        Qt.callLater(function () {
          if (root.panel === window && !window.visible)
            release(window);
        });
    });
    window.closed.connect(function () {
      if (root.panel === window)
        window.visible = false;
    });
    window.openFor(screen);
  }
  Component {
    id: factory
    SettingsPanel {}
  }
}
