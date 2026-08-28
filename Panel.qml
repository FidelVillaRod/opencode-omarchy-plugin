import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "opencode.core"
  ipcTarget: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string script:
    Qt.resolvedUrl("collector.py").toString().replace(/^file:\/\//, "")
  property bool reachable: true
  property var sessions: []
  property var models: []
  property var availableModels: []
  property string lastModel: ""
  property string selectedModel: ""
  property int todaySessions: 0
  property int todayTokens: 0
  property real todayCost: 0

  readonly property int barContentWidth: Style.bar.iconFont + Style.space(5)
  readonly property int barSlot: barContentWidth + Style.space(10)
  implicitWidth: bar && bar.vertical ? (bar ? bar.barSize : Style.bar.sizeHorizontal) : barSlot
  implicitHeight: bar && bar.vertical ? barSlot : (bar ? bar.barSize : Style.bar.sizeHorizontal)

  IpcHandler {
    target: "opencode.core"
    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function refresh() { root.refreshData() }
  }

  function refreshData() {
    collector.running = true
  }

  Process {
    id: collector
    command: ["python3", root.script]
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(line)
          if (data.ok) {
            root.sessions = data.sessions || []
            root.models = data.models || []
            root.availableModels = data.available_models || []
            root.lastModel = data.last_model ? (data.last_model.full || "") : ""
            var stats = data.stats || {}
            var today = stats.today || {}
            root.todaySessions = today.sessions || 0
            root.todayTokens = today.tokens || 0
            root.todayCost = today.cost || 0
            if (!root.selectedModel && root.lastModel) root.selectedModel = root.lastModel
            root.reachable = true
          }
        } catch (e) {
          root.reachable = false
        }
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: 300000
    running: true
    repeat: true
    onTriggered: root.refreshData()
  }

  Component.onCompleted: refreshData()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰆧"
    tooltipText: root.reachable
      ? (root.todaySessions + " sessions hoy · " + root.formatTokens(root.todayTokens) + " tokens" +
         (root.todayCost > 0 ? " · $" + root.todayCost.toFixed(2) : ""))
      : "OpenCode"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.openNewSession()
      else root.toggle()
    }
  }

  function formatTokens(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
    if (n >= 1000) return (n / 1000).toFixed(1) + "k"
    return String(n)
  }

  function openNewSession() {
    if (!root.bar || !root.bar.run) return
    var cmd = "omarchy-opencode-new"
    if (root.selectedModel) cmd = cmd + " " + Util.shellQuote(root.selectedModel)
    root.bar.run(cmd)
    root.close()
  }

  function resumeSession(id) {
    if (!root.bar || !root.bar.run) return
    root.bar.run("omarchy-opencode-resume " + Util.shellQuote(id))
    root.close()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (t === "r") root.refreshData()
      }

      Column {
        id: content
        anchors.fill: parent
        spacing: Style.space(6)

        PanelSectionHeader {
          width: parent.width
          text: "OpenCode"
          textFormat: Text.PlainText
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Text {
          width: parent.width
          text: root.todaySessions + " sesiones hoy · " + root.formatTokens(root.todayTokens) + " tokens" +
                (root.todayCost > 0 ? " · $" + root.todayCost.toFixed(2) : "")
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          color: Qt.darker(root.foreground, 1.5)
          elide: Text.ElideRight
        }

        Row {
          width: parent.width
          height: modelDropdown.implicitHeight
          spacing: Style.space(6)

          Dropdown {
            id: modelDropdown
            width: parent.width - newButton.width - parent.spacing
            label: "Modelo"
            options: {
              var opts = []
              for (var i = 0; i < root.availableModels.length; i++) {
                opts.push({
                  value: root.availableModels[i].full,
                  label: root.availableModels[i].id
                })
              }
              return opts
            }
            value: root.selectedModel
            onChanged: function(v) { root.selectedModel = v }
            hasCursor: true
          }

          PanelActionButton {
            id: newButton
            iconText: ""
            tooltipText: "Nueva sesión" + (root.selectedModel ? " (" + (root.selectedModel.split("/").pop()) + ")" : "")
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.openNewSession()
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Repeater {
          model: root.sessions
          delegate: Rectangle {
            width: parent.width
            height: sessionCol.implicitHeight + Style.space(8)
            radius: Style.cornerRadius
            color: Color.popups.background

            Column {
              id: sessionCol
              anchors.fill: parent
              anchors.margins: Style.space(4)
              spacing: Style.space(2)

              Text {
                text: modelData.title || "Untitled"
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                color: root.foreground
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: (modelData.model || "") + " · " + root.formatTokens(modelData.total_tokens) + " tokens"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                color: Qt.darker(root.foreground, 1.5)
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.resumeSession(modelData.id)
              }
            }
          }
        }

        Text {
          visible: root.sessions.length === 0
          text: root.reachable ? "No sessions found" : "OpenCode no disponible"
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          color: Qt.darker(root.foreground, 1.5)
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }
    }
  }
}
