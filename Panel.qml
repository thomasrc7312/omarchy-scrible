import QtQuick
import qs.Commons
import qs.Ui

// The panel that drops from the Scrible bar pill: timer controls at top,
// word entry + stats + chart in the middle, Scriby at the bottom.
Panel {
  id: root
  moduleName: "trc.scrible"
  ipcTarget: "trc.scrible"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(sectionsColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: sectionsColumn
        width: parent.width
        spacing: Style.space(16)

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "TIMER"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "WORDS"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "SCRIBY"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }
        }
      }
    }
  }
}
