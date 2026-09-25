import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "DevicesPage"
    allowedOrientations: Orientation.All

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: app.deviceModel

        header: Column {
            width: listView.width

            PageHeader {
                title: qsTr("Devices (%1 / %2)").arg(app.devices.length).arg(app.maxDevices)
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                visible: app.needKick || !app.canAddDevices
                text: qsTr("Account is full. Remove a device so this one can connect.")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                visible: app.error.length > 0
                text: app.error
                color: Theme.errorColor !== undefined ? Theme.errorColor : "#ff6b6b"
                font.pixelSize: Theme.fontSizeSmall
            }

            Item {
                width: 1
                height: Theme.paddingMedium
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: app.refreshDevices()
            }
        }

        delegate: ListItem {
            id: item
            objectName: "deviceRow"
            width: listView.width
            contentHeight: details.height + Theme.paddingMedium
            onClicked: pageStack.push(Qt.resolvedUrl("KickDialog.qml"), {
                "deviceId": deviceId,
                "deviceName": name
            })

            Column {
                id: details
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: name + (thisDevice ? " · " + qsTr("this device") : "")
                    color: thisDevice ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: ipv4.length > 0 || created.length > 0
                    text: {
                        var bits = []
                        if (ipv4.length)
                            bits.push(app.cidrHost(ipv4))
                        if (created.length)
                            bits.push(app.formatExpiry(created))
                        return bits.join(" · ")
                    }
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: pubkey.length > 0
                    text: app.shortKey(pubkey)
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }
        }

        ViewPlaceholder {
            enabled: app.devices.length === 0 && !app.busy
            text: qsTr("No devices registered.")
        }

        VerticalScrollDecorator {}
    }
}
