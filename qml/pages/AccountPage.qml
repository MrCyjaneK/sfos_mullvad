import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "AccountPage"
    allowedOrientations: Orientation.All

    function connectionStatus() {
        if (app.busy && app.vpnActivity === "disconnect")
            return qsTr("Disconnecting…")
        if (app.busy && app.vpnActivity === "connect") {
            var city = app.pendingCity && app.pendingCity.city
            if (city)
                return qsTr("Connecting to %1…").arg(city)
            return qsTr("Connecting…")
        }
        if (app.checking)
            return qsTr("Checking…")
        if (vpn.connected) {
            if (vpn.location.length > 0)
                return qsTr("Connected · %1").arg(vpn.location)
            return qsTr("Connected")
        }
        return qsTr("Not connected")
    }

    function checkText() {
        if (app.checking)
            return qsTr("Checking…")
        if (app.checkError.length > 0)
            return app.checkError
        if (app.connection && app.connection.ip) {
            var place = [app.connection.city, app.connection.country].filter(function(x) { return x }).join(", ")
            var via = app.connection.mullvad_exit_ip ? qsTr("Using Mullvad") : qsTr("Not using Mullvad")
            if (place.length > 0)
                return via + " · " + app.connection.ip + " · " + place
            return via + " · " + app.connection.ip
        }
        return qsTr("Not checked yet")
    }

    function devicesSummary() {
        var summary = qsTr("%1 of %2").arg(app.devices.length).arg(app.maxDevices)
        if (vpn.deviceName.length > 0)
            return summary + " · " + vpn.deviceName
        return summary
    }

    function locationsSummary() {
        var city = app.selectedCity
        if (city && city.city)
            return city.city + ", " + (city.country || "")
        return qsTr("Choose a city")
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.height
        pressDelay: 0

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: app.refreshAll()
            }
            MenuItem {
                text: qsTr("Log out")
                onClicked: app.logout()
            }
        }

        Column {
            id: column
            width: page.width

            PageHeader {
                title: qsTr("Mullvad")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                text: app.formatAccount(app.accountNumber)
                color: Theme.primaryColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                text: {
                    var left = app.daysLeft(app.account.expiry)
                    if (left < 0)
                        return qsTr("Expires %1").arg(app.formatExpiry(app.account.expiry))
                    return qsTr("Expires %1 · %2 days left").arg(app.formatExpiry(app.account.expiry)).arg(left)
                }
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                text: page.connectionStatus()
                color: (vpn.connected && !app.busy) ? Theme.highlightColor : Theme.primaryColor
                font.pixelSize: Theme.fontSizeLarge
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                enabled: !app.busy && app.loggedIn
                text: {
                    if (app.busy && app.vpnActivity === "disconnect")
                        return qsTr("Disconnecting…")
                    if (app.busy)
                        return qsTr("Connecting…")
                    return vpn.connected ? qsTr("Disconnect") : qsTr("Connect")
                }
                onClicked: vpn.connected ? app.disconnectVpn() : app.connectVpn()
            }

            ListItem {
                id: checkItem
                width: parent.width
                contentHeight: Math.max(Theme.itemSizeMedium, checkLabel.implicitHeight + Theme.paddingLarge)
                enabled: !app.checking
                onClicked: app.refreshConnection()

                Label {
                    id: checkLabel
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin - (checkBusy.visible ? checkBusy.width + Theme.paddingMedium : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.Wrap
                    text: page.checkText()
                    color: app.checkError.length > 0
                           ? (Theme.errorColor !== undefined ? Theme.errorColor : "#ff6b6b")
                           : (app.checking ? Theme.highlightColor : Theme.primaryColor)
                }

                BusyIndicator {
                    id: checkBusy
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    running: app.checking
                    visible: running
                    size: BusyIndicatorSize.Small
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                visible: app.error.length > 0
                text: app.error
                color: Theme.errorColor !== undefined ? Theme.errorColor : "#ff6b6b"
            }

            ListItem {
                width: parent.width
                contentHeight: Theme.itemSizeLarge
                onClicked: app.showDevicesPage()

                Column {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        width: parent.width
                        text: qsTr("Devices")
                        color: highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                    Label {
                        width: parent.width
                        text: page.devicesSummary()
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            ListItem {
                width: parent.width
                contentHeight: Theme.itemSizeSmall
                onClicked: pageStack.push(Qt.resolvedUrl("TopupPage.qml"))
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Crypto top up")
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
            }

            ListItem {
                width: parent.width
                contentHeight: Theme.itemSizeLarge
                onClicked: pageStack.push(Qt.resolvedUrl("RelaysPage.qml"))

                Column {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        width: parent.width
                        text: qsTr("Locations")
                        color: highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        text: page.locationsSummary()
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator {}
    }
}
