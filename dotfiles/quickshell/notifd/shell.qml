import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    property var items: []
    property var refs: ({})
    property int limit: 30

    function snapshot() {
        return JSON.stringify(root.items)
    }

    function drop(id) {
        var key = String(id)
        var n = root.refs[key]

        if (n) {
            try {
                n.dismiss()
            } catch (e) {
            }
        }

        delete root.refs[key]
        root.items = root.items.filter(function(it) {
            return String(it.id) !== key
        })
    }

    IpcHandler {
        target: "notifd"

        function list(): string {
            return root.snapshot()
        }

        function dismiss(id: string): void {
            root.drop(id)
        }

        function clear(): void {
            var ids = root.items.map(function(it) {
                return it.id
            })

            for (var i = 0; i < ids.length; i++)
                root.drop(ids[i])
        }

        function invoke(id: string): void {
            var n = root.refs[String(id)]

            if (!n)
                return

            var pick = null

            for (var i = 0; i < n.actions.length; i++) {
                if (n.actions[i].identifier === "default") {
                    pick = n.actions[i]
                    break
                }

                if (!pick)
                    pick = n.actions[i]
            }

            if (pick)
                pick.invoke()
            else if (n.desktopEntry && n.desktopEntry.length > 0)
                Quickshell.execDetached(["gtk-launch", n.desktopEntry])
        }
    }

    NotificationServer {
        imageSupported: true
        bodySupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: function(n) {
            n.tracked = true
            root.refs[String(n.id)] = n

            var next = root.items.filter(function(it) {
                return it.id !== n.id
            })

            next.unshift({
                id: n.id,
                app: n.appName || "Notification",
                icon: n.appIcon || "",
                title: n.summary || "Notification",
                body: n.body || "",
                time: Qt.formatTime(new Date(), "hh:mm")
            })

            while (next.length > root.limit) {
                var old = next.pop()
                var o = root.refs[String(old.id)]

                if (o) {
                    try {
                        o.dismiss()
                    } catch (e) {
                    }
                }

                delete root.refs[String(old.id)]
            }

            root.items = next

            n.closed.connect(function() {
                delete root.refs[String(n.id)]
                root.items = root.items.filter(function(it) {
                    return it.id !== n.id
                })
            })
        }
    }
}
