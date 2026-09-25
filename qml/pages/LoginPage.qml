import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "LoginPage"
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height
        pressDelay: 0

        Column {
            id: column
            width: page.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Mullvad")
            }

            TextField {
                id: accountField
                objectName: "accountField"
                width: parent.width
                label: qsTr("Account number")
                placeholderText: "0000 0000 0000 0000"
                inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                validator: RegExpValidator { regExp: /[0-9 ]*/ }
                focus: true
                EnterKey.enabled: app.digitsOnly(text).length === 16 && !app.busy
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: app.login(text)
            }

            Button {
                id: loginButton
                objectName: "loginButton"
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: app.busy ? qsTr("Signing in…") : qsTr("Log in")
                enabled: app.digitsOnly(accountField.text).length === 16 && !app.busy
                onClicked: app.login(accountField.text)
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: app.busy
                size: BusyIndicatorSize.Medium
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                visible: app.error.length > 0
                text: app.error
                color: Theme.errorColor !== undefined ? Theme.errorColor : "#ff6b6b"
            }
        }
    }

    Component.onCompleted: {
        if (vpn.accountNumber.length === 16)
            accountField.text = app.formatAccount(vpn.accountNumber)
        page.forceActiveFocus()
    }
}
