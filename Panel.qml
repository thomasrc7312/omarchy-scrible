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

          Item {
            width: parent.width
            height: phaseLabel.implicitHeight

            Text {
              id: phaseLabel
              anchors.left: parent.left
              text: root.hostWidget ? root.hostWidget.phaseLabel.toUpperCase() : "IDLE"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            Text {
              anchors.right: parent.right
              text: root.hostWidget
                ? (root.hostWidget.focusSessionsSinceLongBreak + " of " + root.hostWidget.sessionsUntilLongBreak + " to long break")
                : ""
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.hostWidget ? root.hostWidget.timerReadoutLabel : "25:00"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
          }

          Text {
            width: parent.width
            visible: root.hostWidget ? root.hostWidget.pendingBreakType !== "" : false
            text: "Focus session complete. Ready for your "
              + (root.hostWidget && root.hostWidget.pendingBreakType === "long" ? "long" : "short") + " break?"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            Button {
              visible: root.hostWidget ? (root.hostWidget.phase === "idle" && root.hostWidget.pendingBreakType === "") : false
              selected: true
              text: "Start focus"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              onClicked: if (root.hostWidget) root.hostWidget.startFocus()
            }

            Button {
              visible: root.hostWidget ? (root.hostWidget.phase === "idle" && root.hostWidget.pendingBreakType !== "") : false
              selected: true
              text: root.hostWidget && root.hostWidget.pendingBreakType === "long" ? "Start long break" : "Start short break"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              onClicked: if (root.hostWidget) root.hostWidget.startBreak(root.hostWidget.pendingBreakType)
            }

            Button {
              visible: root.hostWidget ? (root.hostWidget.phase === "idle" && root.hostWidget.pendingBreakType !== "") : false
              text: "Skip"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              onClicked: if (root.hostWidget) root.hostWidget.dismissPendingBreak()
            }

            Button {
              visible: root.hostWidget ? root.hostWidget.phase === "focus" : false
              text: "Cancel"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              onClicked: if (root.hostWidget) root.hostWidget.cancelCurrent()
            }

            Button {
              visible: root.hostWidget ? (root.hostWidget.phase === "shortBreak" || root.hostWidget.phase === "longBreak") : false
              text: "Skip break"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              onClicked: if (root.hostWidget) root.hostWidget.cancelCurrent()
            }
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
