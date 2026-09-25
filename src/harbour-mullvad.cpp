#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include "vpn.h"

#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <sailfishapp.h>

int main(int argc, char *argv[])
{
    if (!qEnvironmentVariableIsSet("MULLVAD_KEEP_MALIIT")) {
        qputenv("QT_IM_MODULE", QByteArray("compose"));
        qputenv("QT_IM_MODULE_PLUGIN", QByteArray("compose"));
    }

    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    app->setOrganizationName(QStringLiteral("net.mullvad"));
    app->setApplicationName(QStringLiteral("harbour-mullvad"));
    QScopedPointer<QQuickView> view(SailfishApp::createView());
    MullvadVpn vpn;
    view->rootContext()->setContextProperty(QStringLiteral("vpn"), &vpn);
    view->setSource(SailfishApp::pathToMainQml());
    view->show();
    return app->exec();
}
