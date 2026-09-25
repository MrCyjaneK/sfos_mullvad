import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingMedium
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Mullvad")
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeLarge
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: {
                if (vpn && vpn.connected)
                    return qsTr("VPN on")
                if (!app.loggedIn)
                    return qsTr("Not signed in")
                if (app.connection.mullvad_exit_ip)
                    return qsTr("Using Mullvad")
                return qsTr("Signed in")
            }
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeMedium
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: app.loggedIn
            text: app.formatExpiry(app.account.expiry)
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
