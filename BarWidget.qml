import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "harshith.agent-shield"

  readonly property string scriptPath:
    Qt.resolvedUrl("shield-backend.sh").toString().replace(/^file:\/\//, "")

  property bool omniActive: false
  property string codexMode: "Default (12k)"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = shieldPill
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  function refresh() {
    stateProc.command = ["bash", scriptPath, "status"]
    stateProc.running = true
  }

  implicitWidth: shieldPill.width
  implicitHeight: shieldPill.height

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

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
            root.codexMode = data.codex.mode || "Default (12k)"
          }
        } catch(e) {}
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()

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

  // Topbar Pill Widget
  Rectangle {
    id: shieldPill
    height: Style.space(26)
    width: contentRow.implicitWidth + Style.space(16)
    radius: Style.space(6)
    color: root.opened
      ? Color.accent
      : (root.omniActive ? Qt.rgba(0.2, 0.8, 0.4, 0.15) : Qt.rgba(1.0, 1.0, 1.0, 0.05))
    border.color: root.omniActive ? "#38ef7d" : Qt.rgba(1.0, 1.0, 1.0, 0.1)
    border.width: 1

    Behavior on color { ColorAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: 180 } }

    RowLayout {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: "🛡️"
        font.pixelSize: Style.font.caption
      }

      Text {
        textFormat: Text.PlainText
        text: root.omniActive ? "OmniRoute ON" : "Shield"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        color: root.omniActive ? "#38ef7d" : (root.bar ? root.bar.foreground : Color.foreground)
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: root.togglePanel()
    }
  }
}
