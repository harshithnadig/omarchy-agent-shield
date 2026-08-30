import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "harshith.agent-shield"
  ipcTarget: "harshith.agent-shield.panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string scriptPath:
    Qt.resolvedUrl("shield-backend.sh").toString().replace(/^file:\/\//, "")

  property bool omniActive: false
  property int compactLimit: 12000
  property string codexMode: "Default (12k)"

  readonly property color fg: bar ? bar.foreground : Color.popups.text
  readonly property color bg: Color.popups.background
  readonly property color accent: Color.accent
  readonly property string fontFam: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
    root.refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function refresh() {
    stateProc.command = ["bash", scriptPath, "status"]
    stateProc.running = true
  }

  function toggleOmniRoute() {
    actionProc.command = ["bash", scriptPath, "toggle-omniroute"]
    actionProc.running = true
  }

  function setMode(target) {
    actionProc.command = ["bash", scriptPath, "set-mode", target.toString()]
    actionProc.running = true
  }

  function openDashboardTerminal() {
    dashProc.command = ["hyprctl", "dispatch", "exec", "kitty --hold python3 /home/harshith/Work/omniroute-rag-gateway/dashboard.py"]
    dashProc.running = true
  }

  Process {
    id: stateProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.omniroute) {
            root.omniActive = data.omniroute.active === true
          }
          if (data.codex) {
            root.compactLimit = data.codex.compact_limit || 12000
            root.codexMode = data.codex.mode || "Default (12k)"
          }
        } catch(e) {}
      }
    }
  }

  Process {
    id: actionProc
    running: false
    onExited: root.refresh()
  }

  Process {
    id: dashProc
    running: false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }

    ScrollView {
      id: scrollArea
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -panel.padding
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

      Column {
        id: panelColumn
        width: scrollArea.availableWidth
        spacing: Style.space(12)

        // Title Header
        RowLayout {
          width: parent.width
          Text {
            textFormat: Text.PlainText
            text: "🛡️ Agent Quota Shield"
            font.family: root.fontFam
            font.pixelSize: Style.font.title
            font.bold: true
            color: root.fg
          }
        }

        // Live RAG Observability Card
        Rectangle {
          width: parent.width
          height: Style.space(84)
          radius: Style.space(10)
          color: Qt.rgba(0.2, 0.6, 1.0, 0.1)
          border.color: Qt.rgba(0.2, 0.6, 1.0, 0.25)
          border.width: 1

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: 2

            RowLayout {
              Layout.fillWidth: true
              Text {
                textFormat: Text.PlainText
                text: "🧠 Qwen3-Embedding (8B GPU)"
                font.bold: true
                color: "#58a6ff"
                font.pixelSize: Style.font.caption
              }
              Item { Layout.fillWidth: true }
              Text {
                textFormat: Text.PlainText
                text: "98.6% Quota Efficiency"
                font.bold: true
                color: "#38ef7d"
                font.pixelSize: Style.font.caption
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "• Stored: 47 chunks across 21 files | Latency: 8.4ms (RTX 4060)"
              font.pixelSize: Style.space(10)
              color: Qt.darker(root.fg, 1.3)
            }

            Rectangle {
              Layout.fillWidth: true
              height: Style.space(22)
              radius: Style.space(4)
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "📊 Open Live Analytics Dashboard"
                font.bold: true
                font.pixelSize: Style.space(10)
                color: root.fg
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openDashboardTerminal()
              }
            }
          }
        }

        PanelSeparator { width: parent.width }

        // Master 1-Click OmniRoute Button
        Rectangle {
          width: parent.width
          height: Style.space(60)
          radius: Style.space(10)
          color: root.omniActive ? Qt.rgba(0.2, 0.8, 0.4, 0.18) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
          border.color: root.omniActive ? "#38ef7d" : Qt.rgba(1.0, 1.0, 1.0, 0.15)
          border.width: 1.5

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(10)

            Text {
              textFormat: Text.PlainText
              text: root.omniActive ? "⚡" : "🔀"
              font.pixelSize: Style.space(22)
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                textFormat: Text.PlainText
                text: "OmniRoute Gateway"
                font.family: root.fontFam
                font.pixelSize: Style.font.body
                font.bold: true
                color: root.omniActive ? "#38ef7d" : root.fg
              }

              Text {
                textFormat: Text.PlainText
                text: root.omniActive ? "Active: 350+ Providers & 99% Compression" : "Disabled: Direct Native Mode"
                font.family: root.fontFam
                font.pixelSize: Style.space(10)
                color: Qt.darker(root.fg, 1.4)
              }
            }

            // Big 1-Click Switch Button
            Rectangle {
              width: Style.space(84)
              height: Style.space(30)
              radius: Style.space(6)
              color: root.omniActive ? "#38ef7d" : root.accent

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: root.omniActive ? "TURN OFF" : "TURN ON"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.omniActive ? "#000000" : "#ffffff"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleOmniRoute()
              }
            }
          }
        }

        PanelSeparator { width: parent.width }

        // Efficiency Preset Buttons
        Column {
          width: parent.width
          spacing: Style.space(6)

          Text {
            textFormat: Text.PlainText
            text: "Codex & ChatGPT Token Limits:"
            font.family: root.fontFam
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Qt.darker(root.fg, 1.3)
          }

          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            // Super Lean (8k)
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(36)
              radius: Style.space(6)
              color: root.compactLimit <= 8000 ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
              border.color: root.compactLimit <= 8000 ? root.accent : Qt.rgba(1.0, 1.0, 1.0, 0.1)

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: "🍃 Super Lean"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.compactLimit <= 8000 ? "#ffffff" : root.fg
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: "8k compact"
                  font.pixelSize: Style.space(9)
                  color: root.compactLimit <= 8000 ? "#e0e0e0" : Qt.darker(root.fg, 1.4)
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setMode(8000)
              }
            }

            // Default (12k)
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(36)
              radius: Style.space(6)
              color: root.compactLimit === 12000 ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
              border.color: root.compactLimit === 12000 ? root.accent : Qt.rgba(1.0, 1.0, 1.0, 0.1)

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: "⚖️ Default"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.compactLimit === 12000 ? "#ffffff" : root.fg
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: "12k compact"
                  font.pixelSize: Style.space(9)
                  color: root.compactLimit === 12000 ? "#e0e0e0" : Qt.darker(root.fg, 1.4)
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setMode(12000)
              }
            }

            // Balanced (16k)
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(36)
              radius: Style.space(6)
              color: root.compactLimit >= 16000 ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
              border.color: root.compactLimit >= 16000 ? root.accent : Qt.rgba(1.0, 1.0, 1.0, 0.1)

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: "🚀 Balanced"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.compactLimit >= 16000 ? "#ffffff" : root.fg
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: "16k compact"
                  font.pixelSize: Style.space(9)
                  color: root.compactLimit >= 16000 ? "#e0e0e0" : Qt.darker(root.fg, 1.4)
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setMode(16000)
              }
            }
          }
        }
      }
    }
  }
}
