import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog
    objectName: "KickDialog"
    property string deviceId: ""
    property string deviceName: ""
    allowedOrientations: Orientation.All
    canAccept: deviceId.length > 0 && !app.busy

    DialogHeader {
        id: header
        objectName: "kickHeader"
        title: qsTr("Remove device")
        acceptText: qsTr("Remove")
    }

    Column {
        anchors.top: header.bottom
        width: parent.width
        spacing: Theme.paddingLarge

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.Wrap
            text: qsTr("Remove “%1” from this account?").arg(deviceName)
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeLarge
        }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.Wrap
            text: qsTr("That device loses VPN access immediately. This cannot be undone from here.")
            color: Theme.secondaryColor
        }
    }

    onAccepted: app.kickDevice(deviceId)
}
