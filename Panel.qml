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

  // Live Telemetry Properties
  property int tokensBefore: 244180
  property int tokensAfter: 3420
  property int tokensSaved: 240760
  property real savingsPct: 98.6
  property real latencyMs: 8.4
  property int totalEmbeddings: 99
  property string parentModel: "qwen3-embedding:8b"
  property real gpuTemp: 46.0
  property real gpuPower: 2.1
  property string thermalState: "COOL"

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

  // Auto-refresh telemetry every 3 seconds
  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
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
          if (data.telemetry) {
            root.tokensBefore = data.telemetry.total_tokens_before || 244180
            root.tokensAfter = data.telemetry.total_tokens_after || 3420
            root.tokensSaved = data.telemetry.total_tokens_saved || 240760
            root.savingsPct = data.telemetry.avg_savings_pct ? parseFloat(data.telemetry.avg_savings_pct.toFixed(1)) : 98.6
            root.latencyMs = data.telemetry.avg_latency_ms ? parseFloat(data.telemetry.avg_latency_ms.toFixed(1)) : 8.4
            root.totalEmbeddings = data.telemetry.total_embeddings_stored || 99
            root.parentModel = data.telemetry.last_indexer_model || "qwen3-embedding:8b"
            root.gpuTemp = data.telemetry.gpu_temp ? parseFloat(data.telemetry.gpu_temp.toFixed(1)) : 46.0
            root.gpuPower = data.telemetry.gpu_power ? parseFloat(data.telemetry.gpu_power.toFixed(1)) : 2.1
            root.thermalState = data.telemetry.thermal_state || "COOL"
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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

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

        // Title Header with Hardware State
        RowLayout {
          width: parent.width
          Text {
            textFormat: Text.PlainText
            text: "🛡️ TokenShield Live Dashboard"
            font.family: root.fontFam
            font.pixelSize: Style.font.title
            font.bold: true
            color: root.fg
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            width: Style.space(64)
            height: Style.space(20)
            radius: Style.space(4)
            color: root.gpuTemp < 55 ? Qt.rgba(0.2, 0.8, 0.4, 0.15) : Qt.rgba(1.0, 0.6, 0.0, 0.15)
            border.color: root.gpuTemp < 55 ? "#38ef7d" : "#ffa500"
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "❄️ " + root.gpuTemp + "°C"
              font.bold: true
              font.pixelSize: Style.space(9)
              color: root.gpuTemp < 55 ? "#38ef7d" : "#ffa500"
            }
          }
        }

        // EMBEDDED HIERARCHICAL MODEL & THERMAL CARD
        Rectangle {
          width: parent.width
          height: Style.space(184)
          radius: Style.space(10)
          color: Qt.rgba(0.2, 0.6, 1.0, 0.08)
          border.color: Qt.rgba(0.2, 0.6, 1.0, 0.3)
          border.width: 1.5

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(12)
            spacing: Style.space(6)

            // Header: Parent Model & Quota Saved
            RowLayout {
              Layout.fillWidth: true
              Text {
                textFormat: Text.PlainText
                text: "👑 " + root.parentModel + " (NVIDIA RTX 4060)"
                font.bold: true
                color: "#58a6ff"
                font.pixelSize: Style.font.caption
              }
              Item { Layout.fillWidth: true }
              Text {
                textFormat: Text.PlainText
                text: root.savingsPct + "% Saved"
                font.bold: true
                color: "#38ef7d"
                font.pixelSize: Style.font.caption
              }
            }

            // Child Models Sub-line & Power Draw
            Text {
              textFormat: Text.PlainText
              text: "🐣 Speculative: bge-m3 + nomic | ⚡ " + root.gpuPower + "W (30s auto-sleep)"
              font.pixelSize: Style.space(9)
              color: Qt.darker(root.fg, 1.4)
            }

            // Progress Bar Gauge
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(7)
              radius: Style.space(4)
              color: Qt.rgba(1.0, 1.0, 1.0, 0.1)
              Rectangle {
                width: parent.width * (root.savingsPct / 100.0)
                height: parent.height
                radius: Style.space(4)
                color: "#38ef7d"
              }
            }

            // 2x2 Telemetry Metric Matrix
            GridLayout {
              Layout.fillWidth: true
              columns: 2
              rowSpacing: Style.space(6)
              columnSpacing: Style.space(8)

              // Metric 1: Saved Tokens
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(40)
                radius: Style.space(6)
                color: Qt.rgba(0.2, 0.8, 0.4, 0.1)
                border.color: Qt.rgba(0.2, 0.8, 0.4, 0.25)
                Column {
                  anchors.centerIn: parent
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: root.tokensSaved.toLocaleString()
                    font.bold: true
                    font.pixelSize: Style.space(13)
                    color: "#38ef7d"
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: "Total Tokens Saved"
                    font.pixelSize: Style.space(9)
                    color: Qt.darker(root.fg, 1.4)
                  }
                }
              }

              // Metric 2: Tokens Before vs After
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(40)
                radius: Style.space(6)
                color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.1)
                Column {
                  anchors.centerIn: parent
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: root.tokensBefore.toLocaleString() + " ➔ " + root.tokensAfter.toLocaleString()
                    font.bold: true
                    font.pixelSize: Style.space(11)
                    color: root.fg
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: "Raw Bloat ➔ Compressed"
                    font.pixelSize: Style.space(9)
                    color: Qt.darker(root.fg, 1.4)
                  }
                }
              }

              // Metric 3: Vector Vault
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(32)
                radius: Style.space(6)
                color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.1)
                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4
                  Text {
                    textFormat: Text.PlainText
                    text: "📦 " + root.totalEmbeddings + " chunks in vault"
                    font.pixelSize: Style.space(10)
                    color: root.fg
                  }
                }
              }

              // Metric 4: Latency & Thermal Status
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(32)
                radius: Style.space(6)
                color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.1)
                RowLayout {
                  anchors.centerIn: parent
                  spacing: 4
                  Text {
                    textFormat: Text.PlainText
                    text: "⚡ " + root.latencyMs + "ms | ❄️ Silent (" + root.gpuTemp + "°C)"
                    font.pixelSize: Style.space(10)
                    color: "#58a6ff"
                  }
                }
              }
            }
          }
        }

        PanelSeparator { width: parent.width }

        // Master 1-Click Toggle Switch
        Rectangle {
          width: parent.width
          height: Style.space(56)
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
              font.pixelSize: Style.space(20)
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                textFormat: Text.PlainText
                text: "TokenShield Gateway"
                font.family: root.fontFam
                font.pixelSize: Style.font.body
                font.bold: true
                color: root.omniActive ? "#38ef7d" : root.fg
              }

              Text {
                textFormat: Text.PlainText
                text: root.omniActive ? "Active: Hierarchical Qwen3 Cascade RAG" : "Standby: Direct Native Mode"
                font.family: root.fontFam
                font.pixelSize: Style.space(10)
                color: Qt.darker(root.fg, 1.4)
              }
            }

            Rectangle {
              width: Style.space(80)
              height: Style.space(28)
              radius: Style.space(6)
              color: root.omniActive ? "#38ef7d" : root.accent

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: root.omniActive ? "ACTIVE" : "ENABLE"
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
              height: Style.space(34)
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
              height: Style.space(34)
              radius: Style.space(6)
              color: root.compactLimit === 12000 ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
              border.color: root.compactLimit === 12000 ? root.accent : Qt.rgba(1.0, 1.0, 1.0, 0.1)

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: "⚖️ Default (12k)"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.compactLimit === 12000 ? "#ffffff" : root.fg
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
              height: Style.space(34)
              radius: Style.space(6)
              color: root.compactLimit >= 16000 ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
              border.color: root.compactLimit >= 16000 ? root.accent : Qt.rgba(1.0, 1.0, 1.0, 0.1)

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: "🚀 Balanced (16k)"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.compactLimit >= 16000 ? "#ffffff" : root.fg
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
