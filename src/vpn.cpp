#include "vpn.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>

extern "C" int curve25519_donna(unsigned char *mypublic,
                                const unsigned char *secret,
                                const unsigned char *basepoint);

static QString b64(const QByteArray &raw)
{
    return QString::fromLatin1(raw.toBase64());
}

static QByteArray fromB64(const QString &s)
{
    return QByteArray::fromBase64(s.toLatin1());
}

MullvadVpn::MullvadVpn(QObject *parent)
    : QObject(parent)
    , m_connected(false)
{
    load();
    if (m_privateKey.isEmpty())
        generateKeys();
    refreshStatus();
}

QString MullvadVpn::configDir() const
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/.config");
    QString dir = base + QStringLiteral("/harbour-mullvad");
    QDir().mkpath(dir);
    return dir;
}

void MullvadVpn::load()
{
    QSettings s(configDir() + QStringLiteral("/device.ini"), QSettings::IniFormat);
    m_privateKey = s.value(QStringLiteral("privateKey")).toString();
    m_publicKey = s.value(QStringLiteral("publicKey")).toString();
    m_address = s.value(QStringLiteral("address")).toString();
    m_ipv6 = s.value(QStringLiteral("ipv6")).toString();
    m_deviceName = s.value(QStringLiteral("deviceName")).toString();
    m_deviceId = s.value(QStringLiteral("deviceId")).toString();
    m_location = s.value(QStringLiteral("location")).toString();
    m_endpoint = s.value(QStringLiteral("endpoint")).toString();
    m_accountNumber = s.value(QStringLiteral("accountNumber")).toString();
    m_selectedCityName = s.value(QStringLiteral("selectedCity")).toString();
    m_selectedCountry = s.value(QStringLiteral("selectedCountry")).toString();
    m_selectedHost = s.value(QStringLiteral("selectedHost")).toString();
    m_selectedPubkey = s.value(QStringLiteral("selectedPubkey")).toString();
    m_selectedIpv4 = s.value(QStringLiteral("selectedIpv4")).toString();
}

void MullvadVpn::save() const
{
    QSettings s(configDir() + QStringLiteral("/device.ini"), QSettings::IniFormat);
    s.setValue(QStringLiteral("privateKey"), m_privateKey);
    s.setValue(QStringLiteral("publicKey"), m_publicKey);
    s.setValue(QStringLiteral("address"), m_address);
    s.setValue(QStringLiteral("ipv6"), m_ipv6);
    s.setValue(QStringLiteral("deviceName"), m_deviceName);
    s.setValue(QStringLiteral("deviceId"), m_deviceId);
    s.setValue(QStringLiteral("location"), m_location);
    s.setValue(QStringLiteral("endpoint"), m_endpoint);
    s.setValue(QStringLiteral("accountNumber"), m_accountNumber);
    s.setValue(QStringLiteral("selectedCity"), m_selectedCityName);
    s.setValue(QStringLiteral("selectedCountry"), m_selectedCountry);
    s.setValue(QStringLiteral("selectedHost"), m_selectedHost);
    s.setValue(QStringLiteral("selectedPubkey"), m_selectedPubkey);
    s.setValue(QStringLiteral("selectedIpv4"), m_selectedIpv4);
    s.sync();
    QFile::setPermissions(configDir() + QStringLiteral("/device.ini"),
                          QFile::ReadOwner | QFile::WriteOwner);
}

void MullvadVpn::setAccountNumber(const QString &number)
{
    if (m_accountNumber == number)
        return;
    m_accountNumber = number;
    save();
    emit accountNumberChanged();
}

void MullvadVpn::setSelectedCity(const QString &city, const QString &country,
                                 const QString &host, const QString &pubkey,
                                 const QString &ipv4)
{
    if (m_selectedCityName == city && m_selectedCountry == country
            && m_selectedHost == host && m_selectedPubkey == pubkey
            && m_selectedIpv4 == ipv4)
        return;
    m_selectedCityName = city;
    m_selectedCountry = country;
    m_selectedHost = host;
    m_selectedPubkey = pubkey;
    m_selectedIpv4 = ipv4;
    save();
    emit selectedCityChanged();
}

void MullvadVpn::setError(const QString &e)
{
    if (m_error == e)
        return;
    m_error = e;
    emit errorChanged();
}

bool MullvadVpn::generateKeys()
{
    QFile urandom(QStringLiteral("/dev/urandom"));
    if (!urandom.open(QIODevice::ReadOnly))
        return false;
    const QByteArray priv = urandom.read(32);
    urandom.close();
    if (priv.size() != 32)
        return false;

    static const unsigned char basepoint[32] = { 9 };
    unsigned char pub[32];
    curve25519_donna(pub,
                     reinterpret_cast<const unsigned char *>(priv.constData()),
                     basepoint);

    m_privateKey = b64(priv);
    m_publicKey = b64(QByteArray(reinterpret_cast<const char *>(pub), 32));
    save();
    emit keysChanged();
    return true;
}

void MullvadVpn::ensureKeys()
{
    if (m_privateKey.isEmpty() || m_publicKey.isEmpty()) {
        if (!generateKeys())
            setError(QStringLiteral("Could not generate WireGuard keys."));
    }
}

void MullvadVpn::setDevice(const QString &id, const QString &name,
                           const QString &ipv4, const QString &ipv6)
{
    m_deviceId = id;
    m_deviceName = name;
    m_address = ipv4;
    m_ipv6 = ipv6;
    save();
    emit deviceChanged();
}

void MullvadVpn::clearDevice()
{
    m_deviceId.clear();
    m_deviceName.clear();
    m_address.clear();
    m_ipv6.clear();
    save();
    emit deviceChanged();
}

bool MullvadVpn::prepare(const QString &peerPub, const QString &ipv4,
                         const QString &hostname, const QString &city)
{
    setError(QString());
    ensureKeys();
    if (!m_error.isEmpty())
        return false;
    if (m_privateKey.isEmpty() || m_address.isEmpty()) {
        setError(QStringLiteral("Device is not registered yet."));
        return false;
    }
    QByteArray priv = fromB64(m_privateKey);
    QByteArray peer = fromB64(peerPub);
    if (priv.size() != 32 || peer.size() != 32) {
        setError(QStringLiteral("Invalid WireGuard keys."));
        return false;
    }

    QString addresses = m_address;
    QString allowed = QStringLiteral("0.0.0.0/0");
    if (!m_ipv6.isEmpty()) {
        addresses += QStringLiteral(", ") + m_ipv6;
        allowed += QStringLiteral(", ::/0");
    }

    const QString dir = configDir();
    QFile provider(dir + QStringLiteral("/vpn.provider"));
    if (!provider.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        setError(QStringLiteral("Cannot write tunnel config."));
        return false;
    }
    QTextStream ps(&provider);
    ps << "host=" << ipv4 << "\n"
       << "address=" << addresses << "\n"
       << "privateKey=" << m_privateKey << "\n"
       << "publicKey=" << peerPub << "\n"
       << "allowedIPs=" << allowed << "\n"
       << "endpointPort=51820\n"
       << "keepalive=25\n"
       << "dns=10.64.0.1\n";
    provider.close();
    provider.setPermissions(QFile::ReadOwner | QFile::WriteOwner);

    m_location = city.isEmpty() ? hostname : (city + QStringLiteral(" · ") + hostname);
    m_endpoint = ipv4 + QStringLiteral(":51820");
    save();
    emit locationChanged();
    return true;
}

QByteArray MullvadVpn::runHelper(const QStringList &args, int *code) const
{
    QProcess p;
    p.start(QStringLiteral("/usr/libexec/harbour-mullvad-vpn"), args);
    if (!p.waitForStarted(5000)) {
        if (code)
            *code = -1;
        return QByteArray("Could not start the VPN helper.");
    }
    if (!p.waitForFinished(100000)) {
        p.kill();
        if (code)
            *code = -1;
        return QByteArray("VPN helper timed out.");
    }
    if (code)
        *code = p.exitCode();
    return p.readAllStandardOutput() + p.readAllStandardError();
}

void MullvadVpn::connectTunnel()
{
    int code = 0;
    QByteArray out = runHelper(QStringList() << QStringLiteral("up"), &code);
    if (code != 0) {
        QString err = QString::fromUtf8(out).trimmed();
        setError(err.isEmpty() ? QStringLiteral("Connect failed.") : err);
        m_connected = false;
        emit statusChanged();
        return;
    }
    setError(QString());
    m_connected = true;
    emit statusChanged();
}

void MullvadVpn::disconnectTunnel()
{
    int code = 0;
    QByteArray out = runHelper(QStringList() << QStringLiteral("down"), &code);
    if (code != 0) {
        QString err = QString::fromUtf8(out).trimmed();
        setError(err.isEmpty() ? QStringLiteral("Disconnect failed.") : err);
    } else {
        setError(QString());
    }
    m_connected = false;
    emit statusChanged();
}

void MullvadVpn::refreshStatus()
{
    int code = 0;
    QByteArray out = runHelper(QStringList() << QStringLiteral("status"), &code);
    m_connected = (code == 0 && out.contains("up"));
    emit statusChanged();
}
