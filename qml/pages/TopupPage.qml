import QtQuick 2.0
import Sailfish.Silica 1.0
import Amber.Barcode 1.0

Page {
    id: page
    objectName: "TopupPage"
    allowedOrientations: Orientation.All

    property int coinIndex: 2
    property var coins: [
        { "id": "bitcoin", "unit": "BTC", "amountKey": "amount" },
        { "id": "bitcoincash", "unit": "BCH", "amountKey": "amount" },
        { "id": "monero", "unit": "XMR", "amountKey": "tx_amount" }
    ]
    property string address
    property string amount
    property string payUri
    property string loadError
    property bool loading: true

    function post(url, body, cb) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                cb(xhr)
        }
        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.setRequestHeader("Origin", "https://mullvad.net")
        xhr.send(body)
    }

    function fail(xhr, what) {
        loading = false
        var body = String(xhr.responseText || "").replace(/^\s+|\s+$/g, "")
        loadError = what + " (" + xhr.status + ")" + (body ? "\n" + body.substring(0, 300) : "")
    }

    function load() {
        var account = app.accountNumber || vpn.accountNumber
        var coin = coins[coinIndex]
        loading = true
        loadError = address = amount = payUri = ""
        if (!account) {
            loading = false
            loadError = qsTr("Log in first.")
            return
        }
        post("https://mullvad.net/en/account/login", "account_number=" + account, function(login) {
            if (login.status !== 200) {
                fail(login, qsTr("Could not open the payment page."))
                return
            }
            post("https://mullvad.net/en/account/payment/" + coin.id,
                 "understood=on&months=1", function(pay) {
                loading = false
                var obj = app.parseJson(pay.responseText)
                if (!obj || obj.type !== "success" || !obj.data) {
                    fail(pay, qsTr("Could not create a payment address."))
                    return
                }
                var arr = JSON.parse(obj.data)
                var map = arr[0]
                var value = Number(arr[map.monthly_price]).toFixed(8).replace(/0+$/, "").replace(/\.$/, "")
                address = arr[map.address] || ""
                amount = value + " " + coin.unit
                payUri = coin.id + ":" + address + "?" + coin.amountKey + "=" + value
            })
        })
    }

    Component.onCompleted: load()

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader { title: qsTr("Crypto top up") }

            ComboBox {
                width: parent.width
                currentIndex: page.coinIndex
                menu: ContextMenu {
                    MenuItem { text: "Bitcoin" }
                    MenuItem { text: "Bitcoin Cash" }
                    MenuItem { text: "Monero" }
                }
                onCurrentIndexChanged: {
                    if (currentIndex === page.coinIndex)
                        return
                    page.coinIndex = currentIndex
                    page.load()
                }
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: page.loading
                visible: running
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                visible: page.loadError.length > 0
                text: page.loadError
                color: Theme.errorColor !== undefined ? Theme.errorColor : "#ff6b6b"
            }

            BarcodeImage {
                visible: page.payUri.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 2 * Theme.horizontalPageMargin, Theme.itemSizeHuge * 4)
                height: width
                format: BarcodeImage.QRCode
                sourceText: page.payUri
            }

            Repeater {
                model: [page.amount, page.address]
                BackgroundItem {
                    width: column.width
                    visible: modelData.length > 0
                    height: visible ? lab.height + Theme.paddingMedium : 0
                    onClicked: Clipboard.text = modelData
                    Label {
                        id: lab
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.Wrap
                        text: index ? modelData : modelData + " · " + qsTr("1 month")
                        font.pixelSize: index ? Theme.fontSizeSmall : Theme.fontSizeMedium
                        color: highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                }
            }
        }
    }
}
