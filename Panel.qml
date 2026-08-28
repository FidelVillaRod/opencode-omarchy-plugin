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
  property string searchText: ""

  readonly property real maxVisibleRowsHeight: Style.space(34) * 7

  readonly property var visibleSessions: root.filterVerified(root.sessions || [], root.searchText)

  function filterVerified(sessions, q) {
    var out = []
    for (var i = 0; i < sessions.length; i++) {
      var s = sessions[i]
      var query = (q || "").trim().toLowerCase()
      var hit = !query
      if (!hit) {
        hit = (s.title || "").toLowerCase().indexOf(query) >= 0 ||
              (s.model || "").toLowerCase().indexOf(query) >= 0 ||
              (s.provider || "").toLowerCase().indexOf(query) >= 0
      }
      if (hit) out.push(s)
    }
    return out
  }

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

  onOpenedChanged: if (opened) root.refreshData()

  onSelectedIndexChanged: {
    if (root.selectedIndex >= 0 && typeof sessionList !== 'undefined' && sessionList.count > 0) {
      sessionList.positionViewAtIndex(root.selectedIndex, ListView.Center)
    }
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
            // "Deleting…" is kept until the session actually disappears
            // from the list.
            if (root.deletingId) {
              var stillThere = false
              var list = root.sessions
              for (var s = 0; s < list.length; s++) {
                if (list[s].id === root.deletingId) { stillThere = true; break }
              }
              if (!stillThere) root.deletingId = ""
            }
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
          root.deleteDialogMessage = "The session \"" + title + "\" is in use." +
            " Are you sure you want to close and delete it?"
        } else {
          root.deleteDialogOpenMessage = false
          root.deleteDialogMessage = "Delete the session \"" + title + "\"?"
        }
        root.deleteDialogChecked = true
      }
    }
  }

  Process {
    id: deleteProc
    command: ["true"]
    onExited: root.refreshData()
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

  function openExportsFolder() {
    if (!root.bar || !root.bar.run) return
    root.bar.run("omarchy-opencode-exports")
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
    root.deleteDialogMessage = "Checking session state..."
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
    return root.visibleSessions ? root.visibleSessions.length : 0
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
      // Header: 2 = exports folder button (top), 1 = "+" button, 0 = model dropdown.
      root.headerSubIndex = 1
      root.selectedIndex = -1
      root.actionColumn = 0
      return
    }
    // Header (folder button on top, then "+", then model dropdown at the bottom).
    if (root.selectedIndex === -1) {
      if (delta < 0) {
        // Move up: dropdown → "+" → folder.
        if (root.headerSubIndex === 0) root.headerSubIndex = 1
        else if (root.headerSubIndex === 1) root.headerSubIndex = 2
      } else {
        // Move down: folder → "+" → dropdown → first session.
        if (root.headerSubIndex === 2) root.headerSubIndex = 1
        else if (root.headerSubIndex === 1) root.headerSubIndex = 0
        else { root.selectedIndex = sessionCount() > 0 ? 0 : -1; root.actionColumn = 0; root.headerSubIndex = 0 }
      }
      return
    }
    // First session moving up → model dropdown.
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
    if (root.selectedIndex === -1) return
    root.keyboardNavigation = true
    root.actionColumn = delta > 0
      ? (root.actionColumn === 2 ? 2 : root.actionColumn + 1)
      : (root.actionColumn === 0 ? 0 : root.actionColumn - 1)
  }

  function activateCursor() {
    if (!root.cursorActive) return
    root.keyboardNavigation = true
    if (root.selectedIndex === -1) {
      if (root.headerSubIndex === 2) {
        root.openExportsFolder()
      } else if (root.headerSubIndex === 1) {
        root.openNewSession()
      } else {
        modelDropdown.forceActiveFocus()
        modelDropdown.open()
      }
      return
    }
    var row = root.visibleSessions[root.selectedIndex]
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
    var row = root.visibleSessions[root.selectedIndex]
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
        // Let the search field handle typing without the panel cursor hijacking keys.
        if (searchField.activeFocus) return

        // If the model dropdown popup is open, let that popup handle the keys.
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
        } else if (event.text === "/") {
          searchField.forceActiveFocus(); searchField.selectAll(); event.accepted = true
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
          text: root.todaySessions + " sessions today · " + root.formatTokens(root.todayTokens) + " tokens" +
                (root.todayCost > 0 ? " · $" + root.todayCost.toFixed(2) : "")
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          color: Qt.darker(root.foreground, 1.5)
          elide: Text.ElideRight
        }

        TextField {
          id: searchField
          width: parent.width
          placeholderText: "Search session title or model…"
          accent: Color.accent
          foreground: root.foreground
          onTextChanged: root.searchText = text
          horizontalPadding: Style.space(4)
          verticalPadding: Style.space(3)

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.searchText = text = ""
              keyCatcher.forceActiveFocus()
              event.accepted = true
            }
          }
        }

        Item {
          width: parent.width
          height: Style.space(2)
        }

        Row {
          width: parent.width
          spacing: Style.space(6)
          height: Style.space(24)

          PanelActionButton {
            id: folderButton
            iconText: "\uf07b"
            tooltipText: "Open exports folder"
            foreground: root.foreground
            hoverColor: Color.urgent
            fontFamily: root.fontFamily
            hasCursor: root.selectedIndex === -1 && root.headerSubIndex === 2
            onHovered: function(on) {
              if (on) {
                root.keyboardNavigation = false
                root.cursorActive = true
                root.selectedIndex = -1
                root.headerSubIndex = 2
                root.actionColumn = 0
              }
            }
            onClicked: root.openExportsFolder()
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Exports"
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            color: Qt.darker(root.foreground, 1.5)
          }
        }

        Row {
          width: parent.width
          height: modelDropdown.implicitHeight
          spacing: Style.space(6)

          Dropdown {
            id: modelDropdown
            width: parent.width - newButton.width - parent.spacing
            label: "Model"
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
            onPopupOpenChanged: if (!popupOpen) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
            onChanged: function(v) {
              root.selectedModel = v
              // Returning focus to the catcher after picking from the keyboard
              // keeps the panel cursor navigating.
              Qt.callLater(function() { keyCatcher.forceActiveFocus() })
            }
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
            tooltipText: "New session" + (root.selectedModel ? " (" + (root.selectedModel.split("/").pop()) + ")" : "")
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

        ListView {
          id: sessionList
          width: parent.width
          height: Math.min(sessionList.contentHeight, root.maxVisibleRowsHeight)
          clip: true
          model: root.visibleSessions
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: Style.space(4)
          }

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
              (root.keyboardNavigation || rowHover.hovered) &&
              root.actionColumn === 0

            readonly property bool showActions: rowHover.hovered ||
              (root.keyboardNavigation && root.cursorActive && root.selectedIndex === index)

            // Space always reserved by the action icons (export + delete).
            readonly property real actionWidth: Style.space(24) * 2 + Style.space(1)

            // Tracks the pointer over the WHOLE row (text + icons) in a stable
            // way, coexisting with the buttons' child MouseAreas.
            HoverHandler {
              id: rowHover
              target: row
            }

            // Resume-only: excludes the icon zone so a click on a button can
            // never reach the row and resume the conversation.
            MouseArea {
              id: rowMouse
              anchors.fill: parent
              anchors.rightMargin: row.actionWidth + Style.space(4)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: function(on) {
                if (on) {
                  root.keyboardNavigation = false
                  root.cursorActive = true
                  root.selectedIndex = index
                  root.actionColumn = 0
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
                width: parent.width - row.actionWidth - parent.spacing
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
                    ? "Deleting…"
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
                visible: row.showActions
                opacity: row.showActions ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 80 } }

                PanelActionButton {
                  iconText: "\uf019"
                  tooltipText: "Export conversation"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  size: Style.space(24)
                  hasCursor: root.cursorActive && root.selectedIndex === index && root.actionColumn === 1
                  onHovered: function(on) {
                    if (on) { root.keyboardNavigation = false; root.cursorActive = true; root.selectedIndex = index; root.actionColumn = 1 }
                    else if (rowMouse.containsMouse) root.actionColumn = 0
                  }
                  onClicked: root.exportSession(modelData.id)
                }

                PanelActionButton {
                  iconText: "\uf1f8"
                  tooltipText: "Delete session"
                  foreground: root.foreground
                  hoverColor: Color.urgent
                  fontFamily: root.fontFamily
                  size: Style.space(24)
                  hasCursor: root.cursorActive && root.selectedIndex === index && root.actionColumn === 2
                  onHovered: function(on) {
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
          text: root.reachable ? "No sessions found" : "OpenCode unavailable"
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
      z: 30
      message: root.deleteDialogMessage
      confirmText: root.deleteDialogChecked
        ? (root.deleteDialogOpenMessage ? "Close and delete" : "Delete")
        : "Delete"
      cancelText: "Cancel"
      foreground: root.foreground
      background: Color.popups.background
      scrim: Qt.rgba(0, 0, 0, 0.55)
      selectedBackground: Util.alpha(root.foreground, 0.16)
      selectedText: Color.accent
      fontFamily: root.fontFamily
      onCanceled: root.cancelDelete()
      onConfirmed: root.runDelete()
    }
  }
}
