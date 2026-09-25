import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "RelaysPage"
    allowedOrientations: Orientation.All

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: app.cities
        header: Column {
            width: listView.width
            PageHeader {
                title: qsTr("WireGuard locations")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                visible: app.error.length > 0
                text: app.error
                color: Theme.errorColor !== undefined ? Theme.errorColor : "#ff6b6b"
            }
        }
        ViewPlaceholder {
            enabled: app.cities.length === 0
            text: app.busy ? qsTr("Loading…") : qsTr("No locations loaded.")
        }
        delegate: BackgroundItem {
            id: delegate
            width: listView.width
            height: Theme.itemSizeMedium
            onClicked: app.selectCity(modelData)
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                truncationMode: TruncationMode.Fade
                text: modelData.city + ", " + modelData.country
                      + (modelData.host ? "  ·  " + modelData.host : "")
                color: {
                    var chosen = app.selectedCity
                    var selected = chosen && chosen.host === modelData.host && chosen.city === modelData.city
                    if (delegate.highlighted || selected)
                        return Theme.highlightColor
                    return Theme.primaryColor
                }
            }
        }
        VerticalScrollDecorator {}
    }
}
