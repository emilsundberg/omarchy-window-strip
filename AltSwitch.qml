// Window Strip for Omarchy.
//
// This is the display half only. All key handling and all state live in
// altswitch.lua next to this file, loaded from the Hyprland config. It owns the
// frozen window list and the cursor, and drives this panel over IPC:
//
//   omarchy-shell emil.altswitch show '{"windows":[...],"index":1}'
//   omarchy-shell emil.altswitch select 2
//   omarchy-shell emil.altswitch hide
//
// This panel never takes keyboard focus; Hyprland handles Ctrl+Tab.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "AppIdentity.js" as AppIdentity

Item {
  id: root

  // Injected by Omarchy's panel loader.
  property var shell: null
  property var manifest: null
  property bool opened: false
  property var windows: []
  property int selectedIndex: 0

  readonly property int tileWidth: Style.space(104)
  readonly property int tileHeight: Style.space(112)
  readonly property var selectedWindow: windows[selectedIndex] || ({})

  function appEntry(appClass) {
    const raw = String(appClass || "").trim()
    if (!raw) return null
    const entry = AppIdentity.findEntry(raw, DesktopEntries.applications.values || [])
    // Browser heuristics may resolve an unmatched web app to the browser itself.
    return entry || (AppIdentity.webApp(raw) ? null : DesktopEntries.heuristicLookup(raw))
  }

  function friendlyAppName(appClass) {
    const entry = root.appEntry(appClass)
    return entry && entry.name ? String(entry.name) : AppIdentity.fallbackName(appClass)
  }

  // Use Omarchy's disk index fallback when Qt cannot resolve themed icons.
  property var iconIndex: ({})
  property var pendingIconIndex: ({})

  function iconIndexScanCommand() {
    // List app/device icons across the XDG icon dirs and /usr/share/pixmaps as
    // "<path>" lines. Some desktop entries, such as Print Settings, use device
    // icons like "printer" instead of app icons. SVGs are emitted before PNGs
    // so the parser, which keeps the first hit per name, prefers scalable icons.
    return [
      'dirs="$HOME/.icons $HOME/.local/share/icons";',
      'IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;',
      'for ext in svg png; do',
      '  for base in $dirs; do',
      '    [[ -d $base ]] && find "$base" \\( -path "*/apps/*" -o -path "*/devices/*" \\) -name "*.$ext" 2>/dev/null;',
      '  done;',
      '  find /usr/share/pixmaps -maxdepth 1 -name "*.$ext" 2>/dev/null;',
      'done'
    ].join(' ')
  }

  function indexIconLine(path) {
    var value = String(path || "").trim()
    if (value.length === 0) return
    var slash = value.lastIndexOf("/")
    var file = slash >= 0 ? value.slice(slash + 1) : value
    var dot = file.lastIndexOf(".")
    var name = dot > 0 ? file.slice(0, dot) : file
    if (name.length > 0 && root.pendingIconIndex[name] === undefined)
      root.pendingIconIndex[name] = value
  }

  Process {
    id: iconIndexScan
    command: ["bash", "-c", root.iconIndexScanCommand()]
    running: true
    stdout: SplitParser { onRead: function(line) { root.indexIconLine(line) } }
    onStarted: root.pendingIconIndex = ({})
    onExited: root.iconIndex = root.pendingIconIndex
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { if (!iconIndexScan.running) iconIndexScan.running = true }
  }

  function appIcon(appClass) {
    const raw = String(appClass || "").trim()
    const entry = root.appEntry(raw)
    const icon = entry ? String(entry.icon || "") : ""

    if (icon.indexOf("file://") === 0 || icon.indexOf("image://") === 0) return icon
    if (icon.charAt(0) === "/") return Util.fileUrl(icon)
    const name = icon || raw || "application-x-executable"
    const found = root.iconIndex[name]
    if (found) return Util.fileUrl(found)
    return Quickshell.iconPath(name, true)
  }

  function show(payloadJson) {
    // Armed before anything that can throw, so a payload this panel cannot read
    // can never strand it on screen.
    watchdog.restart()

    let payload
    try {
      payload = JSON.parse(payloadJson)
    } catch (error) {
      console.warn("altswitch: unreadable payload:", error)
      root.hide()
      return
    }

    root.windows = payload.windows || []
    root.selectedIndex = payload.index || 0
    root.opened = root.windows.length > 0
  }

  function select(index) {
    root.selectedIndex = index
    watchdog.restart()
  }

  function hide() {
    watchdog.stop()
    root.opened = false
  }

  // A switch ends when Ctrl is released, detected by the Hyprland
  // config. If that release is ever missed the panel would sit on screen for
  // good, so it also gives up on its own and tells the config to reset.
  Timer {
    id: watchdog
    interval: 10000
    onTriggered: {
      root.hide()
      Quickshell.execDetached(["hyprctl", "eval", "__emil_altswitch_cancel()"])
    }
  }

  IpcHandler {
    target: "emil.altswitch"

    function show(payloadJson: string): string {
      root.show(payloadJson)
      return "ok"
    }

    function select(index: int): string {
      root.select(index)
      return "ok"
    }

    function hide(): string {
      root.hide()
      return "ok"
    }

    function state(): string {
      return root.opened ? "open" : "closed"
    }

  }

  PanelWindow {
    id: panel

    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "emil-altswitch"
    WlrLayershell.layer: WlrLayer.Overlay
    // Never grab the keyboard. A grab here can outlive the switch and leave the
    // desktop with no way to dismiss it; a purely visual surface cannot.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    BorderSurface {
      id: card

      width: Math.min(
        Math.max(root.tileWidth * Math.min(root.windows.length, 7), Style.space(280))
          + card.contentLeftInset + card.contentRightInset,
        panel.width - Style.gapsOut * 2
      )
      height: Math.min(root.tileHeight + Style.space(44)
        + card.contentTopInset + card.contentBottomInset,
        panel.height - Style.gapsOut * 2)
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        spacing: Style.spacing.md

        ListView {
          id: list

          Layout.fillWidth: true
          Layout.preferredHeight: root.tileHeight
          clip: true
          interactive: false
          orientation: ListView.Horizontal
          model: root.windows
          currentIndex: root.selectedIndex
          highlightMoveDuration: 0
          preferredHighlightBegin: 0
          preferredHighlightEnd: width
          highlightRangeMode: ListView.ApplyRange
          onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

          delegate: Rectangle {
            required property int index
            required property var modelData
            readonly property bool selected: index === root.selectedIndex

            width: root.tileWidth
            height: root.tileHeight
            radius: Style.cornerRadius
            color: selected ? Color.menu.selectedBackground : "transparent"
            border.width: selected ? Math.max(1, Style.space(2)) : 0
            border.color: Color.menu.selectedText
            Accessible.name: root.friendlyAppName(modelData.appClass) + ": " + modelData.title

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Style.space(64)
                Layout.preferredHeight: Style.space(64)

                Image {
                  id: appImage
                  anchors.fill: parent
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: width * Screen.devicePixelRatio
                  sourceSize.height: height * Screen.devicePixelRatio
                  source: root.appIcon(modelData.appClass)
                  asynchronous: false
                }

                Text {
                  anchors.centerIn: parent
                  visible: appImage.status !== Image.Ready
                  text: root.friendlyAppName(modelData.appClass).charAt(0)
                  color: selected ? Color.menu.selectedText : Color.menu.text
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.space(36)
                }
              }

              Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.friendlyAppName(modelData.appClass)
                color: selected ? Color.menu.selectedText : Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideMiddle
          textFormat: Text.PlainText
          text: root.selectedWindow.title || root.friendlyAppName(root.selectedWindow.appClass)
          color: Color.menu.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }

      }
    }
  }
}
