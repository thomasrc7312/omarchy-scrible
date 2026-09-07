import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "HistoryStore.js" as HistoryStore

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

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // ---- Chart --------------------------------------------------------
  readonly property string chartView: root.setting("chartView", "day") // day | week | month | year
  function setChartView(view) {
    if (view !== root.chartView) root.persistSettings({ chartView: view })
  }

  readonly property string todayKey: HistoryStore.localDateKey(new Date())

  // Bucketing is real date-math over every recorded day; only worth doing
  // while the panel is actually open.
  readonly property var chartBuckets: {
    if (!root.opened || !root.hostWidget) return []
    var today = new Date()
    var byDate = root.hostWidget.historyByDate
    if (root.chartView === "week") return HistoryStore.weekBuckets(byDate, today, 12)
    if (root.chartView === "month") return HistoryStore.monthBuckets(byDate, today, 12)
    if (root.chartView === "year") return HistoryStore.yearBuckets(byDate, today)
    return HistoryStore.dayBuckets(byDate, today, 30)
  }

  readonly property real chartMaxValue: {
    var max = 0
    for (var i = 0; i < chartBuckets.length; i++) if (chartBuckets[i].value > max) max = chartBuckets[i].value
    return max
  }
  readonly property int chartMaxIndex: {
    if (chartMaxValue <= 0) return -1
    for (var i = 0; i < chartBuckets.length; i++) if (chartBuckets[i].value === chartMaxValue) return i
    return -1
  }

  readonly property int chartHeadlineValue: chartBuckets.length > 0 ? chartBuckets[chartBuckets.length - 1].value : 0
  readonly property string chartHeadlineCaption: chartView === "week" ? "this week"
    : chartView === "month" ? "this month"
    : chartView === "year" ? "this year"
    : "today"

  readonly property real barGap: Style.space(3)
  readonly property real barWidth: chartBuckets.length > 0
    ? Math.max(2, (chartArea.width - (chartBuckets.length - 1) * barGap) / chartBuckets.length)
    : 0

  // ---- Day editing (chart-bar click or date picker) -------------------
  property string editingDate: ""
  property int editingValue: 0
  property bool pickerExpanded: false
  property int pickerViewYear: new Date().getFullYear()
  property int pickerViewMonth: new Date().getMonth()

  readonly property var pickerWeeks: pickerExpanded
    ? Model.monthGrid(pickerViewYear, pickerViewMonth, todayKey) : []

  function pickerMoveMonth(delta) {
    var d = new Date(root.pickerViewYear, root.pickerViewMonth + delta, 1)
    root.pickerViewYear = d.getFullYear()
    root.pickerViewMonth = d.getMonth()
  }

  function openDayEditor(dateKey) {
    var rec = root.hostWidget ? HistoryStore.dayRecord(root.hostWidget.historyByDate, dateKey) : { words: 0 }
    root.editingValue = rec.words
    root.editingDate = dateKey
  }

  function cancelDayEdit() {
    root.editingDate = ""
  }

  function saveDayEdit() {
    if (root.editingDate === "" || !root.hostWidget) return
    root.hostWidget.setWordsForDate(root.editingDate, root.editingValue)
    root.editingDate = ""
  }

  // ---- Quick log --------------------------------------------------------
  property int wordsToAdd: 0

  function submitWordsToAdd() {
    if (root.wordsToAdd > 0 && root.hostWidget) root.hostWidget.addWordsToday(root.wordsToAdd)
    root.wordsToAdd = 0
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

          ButtonGroup {
            options: ["Day", "Week", "Month", "Year"]
            value: root.chartView === "week" ? "Week"
              : root.chartView === "month" ? "Month"
              : root.chartView === "year" ? "Year" : "Day"
            foreground: root.contentForeground
            accent: Color.accent
            fontFamily: root.contentFontFamily
            fontSize: Style.font.bodySmall
            onChanged: function(value) { root.setChartView(value.toLowerCase()) }
          }

          Text {
            text: Model.wordsLabel(root.chartHeadlineValue) + " " + root.chartHeadlineCaption
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.display
            font.bold: true
          }

          // Reserved strip for the one label the chart shows: the tallest
          // bar's value, sitting directly above it. No other bar is labeled,
          // and there is no y-axis or gridline.
          Item {
            width: parent.width
            height: maxValueLabel.implicitHeight

            Text {
              id: maxValueLabel
              visible: root.chartMaxIndex >= 0
              text: root.chartMaxIndex >= 0 ? Model.formatCount(root.chartBuckets[root.chartMaxIndex].value) : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              x: Math.max(0, Math.min(width > 0 ? chartArea.width - width : 0,
                root.chartMaxIndex * (root.barWidth + root.barGap) + root.barWidth / 2 - width / 2))
            }
          }

          Item {
            id: chartArea
            width: parent.width
            height: Style.space(110)

            Row {
              anchors.left: parent.left
              anchors.bottom: parent.bottom
              height: parent.height
              spacing: root.barGap

              Repeater {
                model: root.chartBuckets

                Item {
                  id: barSlot
                  required property var modelData
                  required property int index
                  width: root.barWidth
                  height: chartArea.height
                  property bool appeared: false

                  Component.onCompleted: Qt.callLater(function() { barSlot.appeared = true })

                  Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: barSlot.appeared && root.chartMaxValue > 0
                      ? Math.max(barSlot.modelData.value > 0 ? 2 : 0,
                          Math.round(chartArea.height * (barSlot.modelData.value / root.chartMaxValue)))
                      : 0
                    topLeftRadius: Style.space(2)
                    topRightRadius: Style.space(2)
                    color: barSlot.modelData.isCurrent
                      ? Color.accent
                      : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)

                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                  }

                  MouseArea {
                    id: barMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.chartView === "day" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (root.chartView === "day") root.openDayEditor(barSlot.modelData.key)

                    PanelToolTip {
                      visible: barMouse.containsMouse
                      text: Model.wordsLabel(barSlot.modelData.value) + " · " + barSlot.modelData.rangeLabel
                      fontFamily: root.contentFontFamily
                    }
                  }
                }
              }
            }
          }

          Row {
            spacing: Style.space(8)

            NumberField {
              value: root.wordsToAdd
              from: 0
              to: 200000
              stepSize: 25
              foreground: root.contentForeground
              accent: Color.accent
              fontFamily: root.contentFontFamily
              onModified: function(v) { root.wordsToAdd = v }
            }

            Button {
              text: "Add words"
              selected: true
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              onClicked: root.submitWordsToAdd()
            }
          }

          Text {
            text: root.pickerExpanded ? "Hide date picker" : "Edit a different day…"
            color: Style.selectedStateColor(root.contentForeground, Color.accent)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.pickerExpanded = !root.pickerExpanded
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: root.pickerExpanded

            Item {
              width: parent.width
              height: Style.space(22)

              PanelActionButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅁"
                tooltipText: "Previous month"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.pickerMoveMonth(-1)
              }

              Text {
                id: monthNavLabel
                anchors.centerIn: parent
                text: Qt.formatDate(new Date(root.pickerViewYear, root.pickerViewMonth, 1), "MMMM yyyy").toUpperCase()
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
              }

              PanelActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅂"
                tooltipText: "Next month"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.pickerMoveMonth(1)
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(2)

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(2)

                Repeater {
                  model: ["M", "T", "W", "T", "F", "S", "S"]

                  Text {
                    required property string modelData
                    width: Style.space(38)
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              Repeater {
                model: root.pickerWeeks

                Row {
                  required property var modelData
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(2)

                  Repeater {
                    model: parent.modelData

                    Rectangle {
                      id: dayCell
                      required property var modelData
                      width: Style.space(38)
                      height: Style.space(26)
                      radius: Style.cornerRadius
                      color: dayMouse.containsMouse && !modelData.isFuture
                        ? Style.hoverFillFor(root.contentForeground, Color.accent)
                        : "transparent"
                      border.width: modelData.isToday ? Style.spacing.hairline : 0
                      border.color: Style.normalBorderFor(root.contentForeground, Color.accent)

                      Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day
                        color: !dayCell.modelData.inMonth || dayCell.modelData.isFuture
                          ? Qt.darker(root.contentForeground, 2.2)
                          : root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.bodySmall
                      }

                      MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !dayCell.modelData.isFuture
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openDayEditor(dayCell.modelData.key)
                      }
                    }
                  }
                }
              }
            }
          }

          Row {
            visible: root.editingDate !== ""
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Editing " + root.editingDate + ":"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            NumberField {
              value: root.editingValue
              from: 0
              to: 200000
              stepSize: 10
              foreground: root.contentForeground
              accent: Color.accent
              fontFamily: root.contentFontFamily
              onModified: function(v) { root.editingValue = v }
            }

            Button {
              text: "Save"
              selected: true
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              onClicked: root.saveDayEdit()
            }

            Button {
              text: "Cancel"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              onClicked: root.cancelDayEdit()
            }
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
