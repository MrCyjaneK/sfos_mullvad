TARGET = harbour-mullvad

CONFIG += sailfishapp c++11

HEADERS += src/vpn.h
SOURCES += src/harbour-mullvad.cpp \
    src/vpn.cpp \
    src/curve25519-donna.c

DISTFILES += qml/harbour-mullvad.qml \
    qml/cover/CoverPage.qml \
    qml/pages/LoginPage.qml \
    qml/pages/AccountPage.qml \
    qml/pages/DevicesPage.qml \
    qml/pages/KickDialog.qml \
    qml/pages/RelaysPage.qml \
    qml/pages/TopupPage.qml \
    rpm/harbour-mullvad.spec \
    harbour-mullvad.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
