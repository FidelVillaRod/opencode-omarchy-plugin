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
  property string pendingDeleteId: ""
  property string pendingDeleteTitle: ""
  property bool deleteDialogOpen: false
  property string deleteDialogMessage: ""
  property bool deleteDialogChecked: false
  property bool deleteDialogOpenMessage: false

  property bool cursorActive: false
  property int selectedIndex: -1
  property int actionColumn: 0
  property int headerSubIndex: 0
  property int mouseActionHoverIndex: -1
  property bool keyboardNavigation: false
  property string deletingId: ""

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

  Process {
    id: checker
    command: ["omarchy-opencode-check", root.pendingDeleteId]
    stdout: SplitParser {
      onRead: function(line) {
        var state = String(line || "").trim()
        var title = root.pendingDeleteTitle || "Untitled"
        if (state === "open") {
          root.deleteDialogOpenMessage = true
          root.deleteDialogMessage = "La sesión \"" + title + "\" está en uso." +
            " ¿Seguro que quieres cerrarla y eliminarla?"
        } else {
          root.deleteDialogOpenMessage = false
          root.deleteDialogMessage = "¿Eliminar la sesión \"" + title + "\"?"
        }
        root.deleteDialogChecked = true
      }
    }
  }

  Process {
    id: deleteProc
    command: ["true"]
    onExited: {
      root.deletingId = ""
      root.refreshData()
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

  function confirmDelete(id, title) {
    root.pendingDeleteId = id
    root.pendingDeleteTitle = title || "Untitled"
    root.deleteDialogOpen = true
    root.deleteDialogChecked = false
    root.deleteDialogOpenMessage = false
    root.deleteDialogMessage = "Comprobando estado de la sesión..."
    checker.running = true
  }

  function cancelDelete() {
    root.pendingDeleteId = ""
    root.deleteDialogOpen = false
  }

  function runDelete() {
    root.deleteDialogOpen = false
    root.deletingId = root.pendingDeleteId
    deleteProc.command = ["omarchy-opencode-delete", root.pendingDeleteId]
    root.pendingDeleteId = ""
    deleteProc.running = true
  }

  function exportSession(id) {
    if (root.bar && root.bar.run) {
      root.bar.run("omarchy-opencode-export " + Util.shellQuote(id))
    }
  }

  function sessionCount() {
    return root.sessions ? root.sessions.length : 0
  }

  function clampIndex(i) {
    var max = sessionCount() - 1
    if (max < 0) return -1
    return Math.max(0, Math.min(i, max))
  }

  function moveCursor(delta) {
    root.keyboardNavigation = true
    if (!root.cursorActive) {
      root.cursorActive = true
      root.selectedIndex = sessionCount() > 0 ? 0 : -1
      root.headerSubIndex = 0
      root.actionColumn = 0
      return
    }
    // Cabecera: subir/bajar a la primera sesión (o quedarse).
    if (root.selectedIndex === -1) {
      if (delta > 0) {
        root.selectedIndex = sessionCount() > 0 ? 0 : -1
        root.actionColumn = 0
      }
      return
    }
    // Última sesión hacia arriba → cabecera.
    if (delta < 0 && root.selectedIndex === 0) {
      root.selectedIndex = -1
      root.headerSubIndex = 0
      root.actionColumn = 0
      return
    }
    if (root.actionColumn !== 0) { root.actionColumn = 0; return }
    if (sessionCount() === 0) return
    root.selectedIndex = clampIndex(root.selectedIndex + delta)
  }

  function moveCursorH(delta) {
    if (!root.cursorActive || root.selectedIndex < 0) return
    if (root.selectedIndex === -1) {
      // En la cabecera, izquierda/derecha alterna dropdown <-> botón "+".
      root.headerSubIndex = delta > 0 ? 1 : 0
      return
    }
    root.keyboardNavigation = true
    root.actionColumn = delta > 0
      ? (root.actionColumn === 2 ? 2 : root.actionColumn + 1)
      : (root.actionColumn === 0 ? 0 : root.actionColumn - 1)
  }

  function activateCursor() {
    if (!root.cursorActive || root.selectedIndex < 0) return
    root.keyboardNavigation = true
    if (root.selectedIndex === -1) {
      if (root.headerSubIndex === 1) {
        root.openNewSession()
      } else {
        modelDropdown.forceActiveFocus()
        modelDropdown.open()
      }
      return
    }
    var row = root.sessions[root.selectedIndex]
    if (!row) return
    if (root.actionColumn === 1) {
      root.exportSession(row.id)
    } else if (root.actionColumn === 2) {
      root.confirmDelete(row.id, row.title)
    } else {
      root.resumeSession(row.id)
    }
  }

  function deleteSelected() {
    if (!root.cursorActive || root.selectedIndex < 0) return
    var row = root.sessions[root.selectedIndex]
    if (row) root.confirmDelete(row.id, row.title)
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

    Item {
      id: keyCatcher
      anchors.fill: parent
      z: root.deleteDialogOpen ? 20 : 0
      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        // Si el popup del dropdown está abierto, deja que ese popup maneje las teclas.
        if (modelDropdown.popupOpen) return

        if (root.deleteDialogOpen) {
          if (deleteConfirm.handleKey(event)) event.accepted = true
          return
        }

        if (event.key === Qt.Key_Escape) {
          root.close(); event.accepted = true
        } else if (event.key === Qt.Key_Down || event.text === "j") {
          root.moveCursor(1); event.accepted = true
        } else if (event.key === Qt.Key_Up || event.text === "k") {
          root.moveCursor(-1); event.accepted = true
        } else if (event.key === Qt.Key_Right || event.text === "l") {
          root.moveCursorH(1); event.accepted = true
        } else if (event.key === Qt.Key_Left || event.text === "h") {
          root.moveCursorH(-1); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.activateCursor(); event.accepted = true
        } else if (event.key === Qt.Key_Delete || event.text === "d") {
          root.deleteSelected(); event.accepted = true
        } else if (event.text === "r") {
          root.refreshData(); event.accepted = true
        }
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
            hasCursor: root.selectedIndex === -1 && root.headerSubIndex === 0
            onHovered: function(on) {
              if (on) {
                root.keyboardNavigation = false
                root.cursorActive = true
                root.selectedIndex = -1
                root.headerSubIndex = 0
                root.actionColumn = 0
              }
            }
          }

          PanelActionButton {
            id: newButton
            iconText: ""
            tooltipText: "Nueva sesión" + (root.selectedModel ? " (" + (root.selectedModel.split("/").pop()) + ")" : "")
            foreground: root.foreground
            hoverColor: Color.urgent
            fontFamily: root.fontFamily
            hasCursor: root.selectedIndex === -1 && root.headerSubIndex === 1
            onHovered: function(on) {
              if (on) {
                root.keyboardNavigation = false
                root.cursorActive = true
                root.selectedIndex = -1
                root.headerSubIndex = 1
                root.actionColumn = 0
              }
            }
            onClicked: root.openNewSession()
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Repeater {
          model: root.sessions
          delegate: CursorSurface {
            id: row
            required property var modelData
            required property int index

            width: parent.width
            implicitHeight: rowContent.implicitHeight + Style.space(8)
            radius: Style.cornerRadius
            foreground: root.foreground
            fill: root.cursorActive
              ? Style.hoverFillFor(root.foreground, Color.accent)
              : Color.popups.background
            currentFill: Style.selectedFillFor(root.foreground, Color.accent)
            hasCursor: root.cursorActive && root.selectedIndex === index &&
              (root.keyboardNavigation || rowMouse.containsMouse || root.mouseActionHoverIndex === index) &&
              root.actionColumn === 0

            readonly property bool showActions: rowMouse.containsMouse ||
              root.mouseActionHoverIndex === index ||
              (root.keyboardNavigation && root.cursorActive && root.selectedIndex === index)

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: function(on) {
                if (on) {
                  root.keyboardNavigation = false
                  root.cursorActive = true
                  root.selectedIndex = index
                  root.actionColumn = 0
                } else {
                  root.mouseActionHoverIndex = -1
                }
              }
              onClicked: {
                root.resumeSession(modelData.id)
              }
            }

            Row {
              id: rowContent
              z: 1
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(4)
              anchors.rightMargin: Style.space(4)
              spacing: Style.space(2)

              Column {
                id: infoCol
                width: parent.width - actionRow.width - parent.spacing
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: modelData.title || "Untitled"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  color: root.foreground
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: modelData.id === root.deletingId
                    ? "Eliminando…"
                    : (modelData.model || "") + " · " + root.formatTokens(modelData.total_tokens) + " tokens"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: Qt.darker(root.foreground, 1.5)
                  elide: Text.ElideRight
                }
              }

              Row {
                id: actionRow
                spacing: Style.space(1)
                enabled: row.showActions
                opacity: row.showActions ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }

                PanelActionButton {
                  iconText: "\uf019"
                  tooltipText: "Exportar conversación"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  size: Style.space(24)
                  hasCursor: root.cursorActive && root.selectedIndex === index && root.actionColumn === 1
                  onHovered: function(on) {
                    root.mouseActionHoverIndex = on ? index : -1
                    if (on) { root.keyboardNavigation = false; root.cursorActive = true; root.selectedIndex = index; root.actionColumn = 1 }
                    else if (rowMouse.containsMouse) root.actionColumn = 0
                  }
                  onClicked: root.exportSession(modelData.id)
                }

                PanelActionButton {
                  iconText: "\uf1f8"
                  tooltipText: "Eliminar sesión"
                  foreground: root.foreground
                  hoverColor: Color.urgent
                  fontFamily: root.fontFamily
                  size: Style.space(24)
                  hasCursor: root.cursorActive && root.selectedIndex === index && root.actionColumn === 2
                  onHovered: function(on) {
                    root.mouseActionHoverIndex = on ? index : -1
                    if (on) { root.keyboardNavigation = false; root.cursorActive = true; root.selectedIndex = index; root.actionColumn = 2 }
                    else if (rowMouse.containsMouse) root.actionColumn = 0
                  }
                  onClicked: root.confirmDelete(modelData.id, modelData.title)
                }
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

    ConfirmDialog {
      id: deleteConfirm
      anchors.fill: parent
      opened: root.deleteDialogOpen
      z: 10
      message: root.deleteDialogMessage
      confirmText: root.deleteDialogChecked
        ? (root.deleteDialogOpenMessage ? "Cerrar y eliminar" : "Eliminar")
        : "Eliminar"
      cancelText: "Cancelar"
      foreground: root.foreground
      background: Color.popups.background
      scrim: Util.alpha(Color.background, 0.82)
      selectedBackground: Util.alpha(root.foreground, 0.16)
      selectedText: Color.accent
      fontFamily: root.fontFamily
      onCanceled: root.cancelDelete()
      onConfirmed: root.runDelete()
    }
  }
}
