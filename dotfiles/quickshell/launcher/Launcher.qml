import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "services"
import "components"

PanelWindow {
    id: root

    property bool open: true
    property int mode: 0
    property string query: ""
    property int selectedIndex: 0
    readonly property real screenH: root.screen ? root.screen.height : 1080
    readonly property int tallH: Math.round(Math.min(900, Math.max(560, root.screenH * 0.82)))
    readonly property int panelW: root.mode === 3 ? 1000 : 720
    readonly property int panelH: root.mode === 3 ? root.tallH : 560
    readonly property int wallpaperColumns: 3
    property int typeFilter: 0
    property string colorFilter: ""

    onTypeFilterChanged: root.selectedIndex = 0
    onColorFilterChanged: root.selectedIndex = 0

    readonly property string previewWallpaper: {
        var list =
            root.filteredWallpapers()

        if (
            list.length > 0 &&
            root.selectedIndex >= 0 &&
            root.selectedIndex < list.length
        ) {
            return String(
                list[root.selectedIndex]
            )
        }

        return ""
    }
    property int quitTicks: 0

    property color panelColor: Theme.background
    property color cardColor: Theme.surface
    property color hoverColor: Theme.selected
    property color lineColor: Theme.border
    property color titleColor: Theme.foreground
    property color textColor: Theme.subtext
    property color mutedColor: Theme.muted
    property color accentColor: Theme.accent
    property color infoColor: Theme.blue
    property color warningColor: Theme.yellow
    property color connectedColor: Theme.green
    property string fontName: Theme.fontFamily

    visible: root.open
    focusable: root.open
    aboveWindows: true

    screen:
        Quickshell.screens.length > 0
        ? Quickshell.screens[0]
        : null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer:
        WlrLayer.Overlay

    WlrLayershell.keyboardFocus:
        root.open
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    WlrLayershell.namespace:
        "doiz-launcher"

    AppService {
        id: appService
    }

    RunService {
        id: runService
    }

    WindowService {
        id: windowService
    }

    WallpaperService {
        id: wallpaperService
    }

    Timer {
        id: quitTimer

        interval: 300
        repeat: true

        onTriggered: {
            if (root.open) {
                quitTimer.stop()
                return
            }

            if (
                wallpaperService.busy &&
                root.quitTicks < 50
            ) {
                root.quitTicks++
                return
            }

            Qt.quit()
        }
    }

    onOpenChanged: {
        root.quitTicks = 0

        if (root.open)
            quitTimer.stop()
        else
            quitTimer.restart()
    }

    function tint(c, alpha) {
        return Qt.rgba(
            c.r,
            c.g,
            c.b,
            alpha
        )
    }

    function score(text, q) {
        text = String(
            text || ""
        ).toLowerCase()

        q = String(
            q || ""
        ).toLowerCase()

        if (!q)
            return 0

        var pos = 0
        var gaps = 0

        for (
            var i = 0;
            i < q.length;
            i++
        ) {
            var found =
                text.indexOf(
                    q[i],
                    pos
                )

            if (found < 0)
                return -1

            gaps += found - pos
            pos = found + 1
        }

        var exact =
            text.indexOf(q)

        var prefix =
            exact === 0
            ? 120
            : 0

        return 1000
            - gaps
            - text.length * 0.15
            + prefix
            - (exact < 0 ? 20 : 0)
    }

    function ranked(source, builder) {
        var q =
            root.query
            .trim()
            .toLowerCase()

        var result = []

        if (!source)
            return result

        for (
            var i = 0;
            i < source.length;
            i++
        ) {
            var item =
                source[i]

            var text =
                builder(item)

            var value =
                root.score(
                    text,
                    q
                )

            if (
                !q ||
                value >= 0
            ) {
                result.push({
                    item: item,
                    score: value
                })
            }
        }

        result.sort(
            function(a, b) {
                if (
                    b.score !==
                    a.score
                ) {
                    return (
                        b.score -
                        a.score
                    )
                }

                return builder(
                    a.item
                ).localeCompare(
                    builder(
                        b.item
                    ),
                    undefined,
                    {
                        sensitivity:
                            "base"
                    }
                )
            }
        )

        return result.map(
            function(entry) {
                return entry.item
            }
        )
    }

    function filteredApps() {
        return root.ranked(
            appService.applications || [],
            function(app) {
                return String(
                    app.name || ""
                )
                    + " "
                    + String(
                        app.genericName || ""
                    )
                    + " "
                    + String(
                        app.comment || ""
                    )
                    + " "
                    + String(
                        app.id || ""
                    )
            }
        )
    }

    function filteredRuns() {
        return root.ranked(
            runService.commands || [],
            function(command) {
                return String(
                    command || ""
                )
            }
        )
    }

    function filteredWindows() {
        return root.ranked(
            windowService.windows || [],
            function(item) {
                if (!item)
                    return ""

                return String(
                    item.title || ""
                )
                    + " "
                    + String(
                        item.appId || ""
                    )
            }
        )
    }

    function rankedWallpapers() {
        return root.ranked(
            wallpaperService.wallpapers || [],
            function(item) {
                var path =
                    String(
                        item || ""
                    )

                var parts =
                    path.split("/")

                return String(
                    parts[
                        parts.length - 1
                    ] || ""
                )
                    + " "
                    + path
            }
        )
    }

    function filteredWallpapers() {
        var list =
            root.rankedWallpapers()

        var type =
            root.typeFilter

        var color =
            root.colorFilter

        if (type === 0 && color === "")
            return list

        var colors =
            wallpaperService.wallpaperColors || ({})

        return list.filter(
            function(item) {
                var path =
                    String(item)

                var video =
                    wallpaperService.isVideo(path)

                if (type === 1 && video)
                    return false

                if (type === 2 && !video)
                    return false

                if (color !== "") {
                    var tags =
                        colors[path]

                    if (
                        !tags ||
                        tags.split(",").indexOf(color) < 0
                    ) {
                        return false
                    }
                }

                return true
            }
        )
    }

    function wallpaperStats() {
        var list =
            root.rankedWallpapers()

        var colors =
            wallpaperService.wallpaperColors || ({})

        var stats = {
            all: list.length,
            image: 0,
            video: 0,
            colors: ({})
        }

        for (var i = 0; i < list.length; i++) {
            var path =
                String(list[i])

            var video =
                wallpaperService.isVideo(path)

            if (video)
                stats.video++
            else
                stats.image++

            if (root.typeFilter === 1 && video)
                continue

            if (root.typeFilter === 2 && !video)
                continue

            var tags =
                colors[path]

            if (!tags)
                continue

            var parts =
                tags.split(",")

            for (var j = 0; j < parts.length; j++) {
                stats.colors[parts[j]] =
                    (stats.colors[parts[j]] || 0) + 1
            }
        }

        return stats
    }

    function currentItems() {
        if (root.mode === 0)
            return root.filteredApps()

        if (root.mode === 1)
            return root.filteredRuns()

        if (root.mode === 2)
            return root.filteredWindows()

        if (root.mode === 3)
            return root.filteredWallpapers()

        return []
    }

    function resetSearch() {
        root.query = ""
        root.selectedIndex = 0

        if (
            search &&
            search.input
        ) {
            search.input.text = ""
            search.input.forceActiveFocus()
        }
    }

    function setMode(value) {
        var nextMode =
            Number(value)

        if (!isFinite(nextMode))
            nextMode = 0

        nextMode =
            Math.max(
                0,
                Math.min(
                    3,
                    Math.floor(
                        nextMode
                    )
                )
            )

        root.mode =
            nextMode

        root.resetSearch()

        if (root.mode === 1)
            runService.refresh()

        if (root.mode === 2)
            windowService.refresh()

        if (root.mode === 3)
            wallpaperService.refresh()
    }

    function close() {
        root.open = false
    }

    function show() {
        root.open = true
        root.selectedIndex = 0
        root.query = ""
        root.typeFilter = 0
        root.colorFilter = ""

        if (
            search &&
            search.input
        ) {
            search.input.text = ""
            search.input.forceActiveFocus()
        }

        appService.refresh()
        runService.refresh()
        windowService.refresh()
        wallpaperService.refresh()
    }

    function runCurrent() {
        if (root.mode === 0) {
            var apps =
                root.filteredApps()

            if (
                apps.length <= 0 ||
                root.selectedIndex < 0 ||
                root.selectedIndex >= apps.length
            ) {
                return
            }

            var app =
                apps[
                    root.selectedIndex
                ]

            root.close()

            if (app)
                app.execute()

            return
        }

        if (root.mode === 1) {
            var commands =
                root.filteredRuns()

            if (
                commands.length <= 0 ||
                root.selectedIndex < 0 ||
                root.selectedIndex >= commands.length
            ) {
                return
            }

            var command =
                String(
                    commands[
                        root.selectedIndex
                    ] || ""
                )

            if (
                command.length <= 0
            ) {
                return
            }

            root.close()

            Qt.callLater(
                function() {
                    Quickshell.execDetached(
                        [command]
                    )
                }
            )

            return
        }

        if (root.mode === 2) {
            var windows =
                root.filteredWindows()

            if (
                windows.length <= 0 ||
                root.selectedIndex < 0 ||
                root.selectedIndex >= windows.length
            ) {
                return
            }

            var windowItem =
                windows[
                    root.selectedIndex
                ]

            if (!windowItem)
                return

            root.close()

            Qt.callLater(
                function() {
                    windowItem.activate()
                }
            )

            return
        }

        if (root.mode === 3) {
            var wallpapers =
                root.filteredWallpapers()

            if (
                wallpapers.length <= 0 ||
                root.selectedIndex < 0 ||
                root.selectedIndex >= wallpapers.length
            ) {
                return
            }

            wallpaperService.apply(
                wallpapers[
                    root.selectedIndex
                ]
            )

            root.close()
        }
    }

    function moveSelection(delta) {
        var items =
            root.currentItems()

        var count =
            items.length

        if (count <= 0) {
            root.selectedIndex = 0
            return
        }

        if (
            root.mode === 3 &&
            Math.abs(Number(delta)) > 1
        ) {
            var target =
                root.selectedIndex +
                Number(delta)

            var columns =
                root.wallpaperColumns

            if (target < 0) {
                target =
                    root.selectedIndex
            } else if (target >= count) {
                var lastRow =
                    Math.floor(
                        (count - 1) / columns
                    )

                var currentRow =
                    Math.floor(
                        root.selectedIndex / columns
                    )

                target =
                    currentRow < lastRow
                    ? count - 1
                    : root.selectedIndex
            }

            root.selectedIndex =
                target

            return
        }

        var next =
            root.selectedIndex +
            Number(delta)

        while (next < 0)
            next += count

        while (next >= count)
            next -= count

        root.selectedIndex =
            next
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (root.open)
                root.close()
            else
                root.show()
        }

        function show(): void {
            root.show()
        }

        function hide(): void {
            root.close()
        }

        function apps(): void {
            root.mode = 0
            root.show()
        }

        function run(): void {
            root.mode = 1
            root.show()
        }

        function windows(): void {
            root.mode = 2
            root.show()
        }

        function wallpaper(): void {
            root.mode = 3
            root.show()
        }
    }

    Item {
        id: shortcutHandler

        anchors.fill: parent

        Shortcut {
            sequence: "Escape"
            enabled: root.open

            onActivated: {
                root.close()
            }
        }

        Shortcut {
            sequence: "Down"
            enabled: root.open

            onActivated: {
                root.moveSelection(
                    root.mode === 3
                    ? root.wallpaperColumns
                    : 1
                )
            }
        }

        Shortcut {
            sequence: "Right"
            enabled: root.open && root.mode === 3

            onActivated: {
                root.moveSelection(1)
            }
        }

        Shortcut {
            sequence: "Up"
            enabled: root.open

            onActivated: {
                root.moveSelection(
                    root.mode === 3
                    ? -root.wallpaperColumns
                    : -1
                )
            }
        }

        Shortcut {
            sequence: "Left"
            enabled: root.open && root.mode === 3

            onActivated: {
                root.moveSelection(-1)
            }
        }

        Shortcut {
            sequence: "Tab"
            enabled: root.open

            onActivated: {
                root.setMode(
                    (root.mode + 1) % 4
                )
            }
        }

        Shortcut {
            sequence: "Return"
            enabled: root.open

            onActivated: {
                root.runCurrent()
            }
        }

        Shortcut {
            sequence: "Enter"
            enabled: root.open

            onActivated: {
                root.runCurrent()
            }
        }
    }

    MouseArea {
        id: outsideMouse

        anchors.fill: parent

        visible: root.open

        onClicked: {
            var localX =
                mouse.x - panel.x

            var localY =
                mouse.y - panel.y

            if (
                localX < 0 ||
                localY < 0 ||
                localX > panel.width ||
                localY > panel.height
            ) {
                root.close()
            }
        }
    }

    Rectangle {
        id: panel

        width: root.panelW
        height: root.panelH

        Behavior on width {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        anchors.centerIn: parent

        visible: root.open

        color:
            root.panelColor

        radius: 8

        border.width: 1

        border.color:
            root.tint(
                root.accentColor,
                0.35
            )

        property bool entered: false

        opacity:
            root.open && panel.entered
            ? 1
            : 0

        scale:
            root.open && panel.entered
            ? 1
            : 0.97

        transform: Translate {
            y:
                root.open && panel.entered
                ? 0
                : -6

            Behavior on y {
                NumberAnimation {
                    duration: 220
                    easing.type:
                        Easing.OutCubic
                }
            }
        }

        Timer {
            interval: 16
            running: true
            repeat: false

            onTriggered: {
                panel.entered = true
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type:
                    Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type:
                    Easing.OutBack
                easing.overshoot: 1.6
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                mouse.accepted = true
            }
        }

        Column {
            id: mainColumn

            anchors.fill: parent
            anchors.margins: 12

            spacing: 8

            Item {
                width: parent.width
                height: 40

                Rectangle {
                    id: launcherIcon

                    anchors.left: parent.left
                    anchors.verticalCenter:
                        parent.verticalCenter

                    width: 40
                    height: 40

                    radius: 6

                    color:
                        root.tint(
                            root.accentColor,
                            0.16
                        )

                    Text {
                        anchors.fill: parent

                        horizontalAlignment:
                            Text.AlignHCenter

                        verticalAlignment:
                            Text.AlignVCenter

                        text:
                            root.mode === 0
                            ? "󰀻"
                            : root.mode === 1
                                ? "󰆍"
                                : root.mode === 2
                                    ? "󰖯"
                                    : "󰸉"

                        color:
                            root.accentColor

                        font.family:
                            root.fontName

                        font.pixelSize: 21
                    }
                }

                Column {
                    anchors.left:
                        launcherIcon.right

                    anchors.leftMargin:
                        10

                    anchors.verticalCenter:
                        parent.verticalCenter

                    spacing: 2

                    Text {
                        text: "LAUNCHER"

                        color:
                            root.titleColor

                        font.family:
                            root.fontName

                        font.pixelSize: 13

                        font.weight:
                            Font.Bold
                    }

                    Text {
                        text:
                            root.mode === 0
                            ? "Applications"
                            : root.mode === 1
                                ? "Run command"
                                : root.mode === 2
                                    ? "Windows"
                                    : "Wallpaper"

                        color:
                            root.accentColor

                        font.family:
                            root.fontName

                        font.pixelSize: 9

                        font.weight:
                            Font.DemiBold
                    }
                }

                Rectangle {
                    anchors.right:
                        parent.right

                    anchors.verticalCenter:
                        parent.verticalCenter

                    width: 54
                    height: 40

                    radius: 6

                    color:
                        root.cardColor

                    Text {
                        anchors.fill: parent

                        horizontalAlignment:
                            Text.AlignHCenter

                        verticalAlignment:
                            Text.AlignVCenter

                        text:
                            root.mode === 0
                            ? "APPS"
                            : root.mode === 1
                                ? "RUN"
                                : root.mode === 2
                                    ? "WIN"
                                    : "WALL"

                        color:
                            root.textColor

                        font.family:
                            root.fontName

                        font.pixelSize: 9

                        font.weight:
                            Font.Bold
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1

                color:
                    root.lineColor
            }

            SearchBar {
                id: search

                width: parent.width

                onAccepted: {
                    root.runCurrent()
                }

                onTextChanged: {
                    root.query = text
                    root.selectedIndex = 0
                }
            }

            ModeSwitcher {
                width: parent.width

                currentMode:
                    root.mode

                onModeSelected:
                    function(mode) {
                        root.setMode(mode)
                    }
            }

            Rectangle {
                width: parent.width
                height: 1

                color:
                    root.lineColor
            }

            Item {
                id: contentArea

                width: parent.width

                height:
                    parent.height
                    - search.height
                    - 141

                clip: true

                ListView {
                    id: appsList

                    anchors.fill: parent

                    visible:
                        root.mode === 0

                    clip: true

                    spacing: 5

                    currentIndex:
                        root.selectedIndex

                    model:
                        root.filteredApps()

                    delegate: AppItem {
                        width:
                            appsList.width

                        app:
                            modelData

                        selected:
                            index ===
                            root.selectedIndex

                        onTriggered: {
                            root.selectedIndex =
                                index

                            root.runCurrent()
                        }
                    }

                    ScrollBar.vertical:
                        ScrollBar {
                            policy:
                                ScrollBar.AsNeeded

                            contentItem:
                                Rectangle {
                                    implicitWidth: 3
                                    radius: 2

                                    color:
                                        root.accentColor

                                    opacity: 0.55
                                }
                        }
                }

                ListView {
                    id: runList

                    anchors.fill: parent

                    visible:
                        root.mode === 1

                    clip: true

                    spacing: 5

                    currentIndex:
                        root.selectedIndex

                    model:
                        root.filteredRuns()

                    delegate: RunItem {
                        width:
                            runList.width

                        command:
                            String(modelData)

                        selected:
                            index ===
                            root.selectedIndex

                        onTriggered: {
                            root.selectedIndex =
                                index

                            root.runCurrent()
                        }
                    }

                    ScrollBar.vertical:
                        ScrollBar {
                            policy:
                                ScrollBar.AsNeeded

                            contentItem:
                                Rectangle {
                                    implicitWidth: 3
                                    radius: 2

                                    color:
                                        root.accentColor

                                    opacity: 0.55
                                }
                        }
                }

                ListView {
                    id: windowsList

                    anchors.fill: parent

                    visible:
                        root.mode === 2

                    clip: true

                    spacing: 5

                    currentIndex:
                        root.selectedIndex

                    model:
                        root.filteredWindows()

                    delegate: WindowItem {
                        width:
                            windowsList.width

                        windowItem:
                            modelData

                        selected:
                            index ===
                            root.selectedIndex

                        onTriggered: {
                            root.selectedIndex =
                                index

                            root.runCurrent()
                        }
                    }

                    ScrollBar.vertical:
                        ScrollBar {
                            policy:
                                ScrollBar.AsNeeded

                            contentItem:
                                Rectangle {
                                    implicitWidth: 3
                                    radius: 2

                                    color:
                                        root.accentColor

                                    opacity: 0.55
                                }
                        }
                }

                Column {
                    id: wallpaperContent

                    anchors.fill: parent

                    visible:
                        root.mode === 3

                    spacing: 7

                    clip: true

                    WallpaperSettings {
                        id: wallpaperSettings

                        width:
                            parent.width

                        service:
                            wallpaperService
                    }

                    Item {
                        id: wallpaperHeader

                        width:
                            parent.width

                        height: 20

                        Text {
                            anchors.left:
                                parent.left

                            anchors.verticalCenter:
                                parent.verticalCenter

                            text:
                                root.filteredWallpapers().length > 0
                                ? "WALLPAPERS"
                                : wallpaperService.colorsBusy &&
                                  root.colorFilter.length > 0
                                    ? "ANALYZING COLORS"
                                    : "NO WALLPAPERS MATCH"

                            color:
                                root.mutedColor

                            font.family:
                                root.fontName

                            font.pixelSize: 9

                            font.weight:
                                Font.Bold
                        }

                        Text {
                            anchors.right:
                                parent.right

                            anchors.verticalCenter:
                                parent.verticalCenter

                            text:
                                root.filteredWallpapers().length

                            color:
                                root.accentColor

                            font.family:
                                root.fontName

                            font.pixelSize: 9

                            font.weight:
                                Font.Bold
                        }
                    }

                    Row {
                        id: wallpaperBody

                        width: parent.width

                        height:
                            Math.max(
                                1,
                                parent.height -
                                wallpaperSettings.height -
                                wallpaperHeader.height -
                                14
                            )

                        spacing: 12

                        Column {
                            id: wallpaperSide

                            width: 400
                            height: parent.height

                            spacing: 12

                            WallpaperPreview {
                                id: previewPane

                                width:
                                    parent.width

                                path:
                                    root.previewWallpaper

                                thumbnail:
                                    wallpaperService.videoThumbs[
                                        root.previewWallpaper
                                    ] || ""

                                position:
                                    root.previewWallpaper.length > 0
                                    ? root.selectedIndex + 1
                                    : 0

                                total:
                                    root.filteredWallpapers().length
                            }

                            WallpaperFilters {
                                id: wallpaperFilters

                                width:
                                    parent.width

                                typeFilter:
                                    root.typeFilter

                                colorFilter:
                                    root.colorFilter

                                busy:
                                    wallpaperService.colorsBusy

                                stats:
                                    root.wallpaperStats()

                                onTypeSelected:
                                    function(value) {
                                        root.typeFilter = value
                                    }

                                onColorSelected:
                                    function(value) {
                                        root.colorFilter =
                                            root.colorFilter === value
                                            ? ""
                                            : value
                                    }
                            }
                        }

                        GridView {
                            id: wallpaperList

                            readonly property int columns:
                                root.wallpaperColumns

                            readonly property real thumbWidth:
                                Math.max(
                                    40,
                                    cellWidth - 18
                                )

                            width:
                                parent.width -
                                wallpaperSide.width -
                                parent.spacing

                            height:
                                parent.height

                            clip: true

                            cellWidth:
                                Math.floor(
                                    width / columns
                                )

                            cellHeight:
                                Math.round(
                                    thumbWidth * 0.58
                                ) + 37

                            cacheBuffer:
                                cellHeight * 2

                            boundsBehavior:
                                Flickable.StopAtBounds

                            currentIndex:
                                root.selectedIndex

                            onCurrentIndexChanged: {
                                if (currentIndex >= 0)
                                    positionViewAtIndex(
                                        currentIndex,
                                        GridView.Contain
                                    )
                            }

                            model:
                                root.filteredWallpapers()

                            delegate: Item {
                                width:
                                    wallpaperList.cellWidth

                                height:
                                    wallpaperList.cellHeight

                                WallpaperItem {
                                    anchors.fill: parent
                                    anchors.margins: 3

                                    path:
                                        String(modelData)

                                    thumbnail:
                                        wallpaperService.videoThumbs[
                                            String(modelData)
                                        ] || ""

                                    selected:
                                        index ===
                                        root.selectedIndex

                                    onTriggered: {
                                        root.selectedIndex =
                                            index

                                        root.runCurrent()
                                    }
                                }
                            }

                            ScrollBar.vertical:
                                ScrollBar {
                                    policy:
                                        ScrollBar.AsNeeded

                                    contentItem:
                                        Rectangle {
                                            implicitWidth: 3
                                            radius: 2

                                            color:
                                                root.accentColor

                                            opacity: 0.55
                                        }
                                }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 18

                Text {
                    id: footerHint

                    anchors.right:
                        parent.right

                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        "ENTER SELECT  ·  TAB SWITCH  ·  ESC CLOSE"

                    color:
                        root.mutedColor

                    font.family:
                        root.fontName

                    font.pixelSize: 7

                    font.weight:
                        Font.DemiBold
                }
            }
        }
    }

    Component.onCompleted: {
        root.show()
    }
}