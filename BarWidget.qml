import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// The bar pill: mm:ss while a focus/break interval is running, today's
// logged word count when idle. Click opens the panel below it.
BarWidget {
  id: root
  moduleName: "trc.scrible"

  property bool timerRunning: false
  property string timerRemainingLabel: "25:00"
  property int todayWordCount: 0

  readonly property string wordCountLabel: todayWordCount + (todayWordCount === 1 ? " word" : " words")
  readonly property string displayText: timerRunning
    ? timerRemainingLabel
    : (vertical ? String(todayWordCount) : wordCountLabel)

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "trc.scrible"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    fontSize: root.vertical ? Style.font.bodySmall : Style.font.body
    tooltipText: "Scrible"
    horizontalMargin: 8.5

    onPressed: function(b) { root.togglePanel() }
  }
}
