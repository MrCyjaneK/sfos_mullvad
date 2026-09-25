#ifndef MULLVAD_VPN_H
#define MULLVAD_VPN_H

#include <QObject>
#include <QString>

class MullvadVpn : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString publicKey READ publicKey NOTIFY keysChanged)
    Q_PROPERTY(QString address READ address NOTIFY deviceChanged)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY deviceChanged)
    Q_PROPERTY(QString deviceId READ deviceId NOTIFY deviceChanged)
    Q_PROPERTY(bool hasDevice READ hasDevice NOTIFY deviceChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY statusChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString location READ location NOTIFY locationChanged)
    Q_PROPERTY(QString endpoint READ endpoint NOTIFY locationChanged)
    Q_PROPERTY(QString accountNumber READ accountNumber NOTIFY accountNumberChanged)
    Q_PROPERTY(QString selectedCityName READ selectedCityName NOTIFY selectedCityChanged)
    Q_PROPERTY(QString selectedCountry READ selectedCountry NOTIFY selectedCityChanged)
    Q_PROPERTY(QString selectedHost READ selectedHost NOTIFY selectedCityChanged)
    Q_PROPERTY(QString selectedPubkey READ selectedPubkey NOTIFY selectedCityChanged)
    Q_PROPERTY(QString selectedIpv4 READ selectedIpv4 NOTIFY selectedCityChanged)

public:
    explicit MullvadVpn(QObject *parent = 0);

    QString publicKey() const { return m_publicKey; }
    QString address() const { return m_address; }
    QString deviceName() const { return m_deviceName; }
    QString deviceId() const { return m_deviceId; }
    bool hasDevice() const { return !m_deviceId.isEmpty() && !m_address.isEmpty(); }
    bool connected() const { return m_connected; }
    QString error() const { return m_error; }
    QString location() const { return m_location; }
    QString endpoint() const { return m_endpoint; }
    QString accountNumber() const { return m_accountNumber; }
    QString selectedCityName() const { return m_selectedCityName; }
    QString selectedCountry() const { return m_selectedCountry; }
    QString selectedHost() const { return m_selectedHost; }
    QString selectedPubkey() const { return m_selectedPubkey; }
    QString selectedIpv4() const { return m_selectedIpv4; }

    Q_INVOKABLE void setAccountNumber(const QString &number);
    Q_INVOKABLE void setSelectedCity(const QString &city, const QString &country,
                                     const QString &host, const QString &pubkey,
                                     const QString &ipv4);
    Q_INVOKABLE void ensureKeys();
    Q_INVOKABLE void setDevice(const QString &id, const QString &name,
                               const QString &ipv4, const QString &ipv6);
    Q_INVOKABLE void clearDevice();
    Q_INVOKABLE bool prepare(const QString &peerPub, const QString &ipv4,
                             const QString &hostname, const QString &city);
    Q_INVOKABLE void connectTunnel();
    Q_INVOKABLE void disconnectTunnel();
    Q_INVOKABLE void refreshStatus();

signals:
    void keysChanged();
    void deviceChanged();
    void statusChanged();
    void errorChanged();
    void locationChanged();
    void accountNumberChanged();
    void selectedCityChanged();

private:
    QString configDir() const;
    void load();
    void save() const;
    void setError(const QString &e);
    QByteArray runHelper(const QStringList &args, int *code) const;
    bool generateKeys();

    QString m_privateKey;
    QString m_publicKey;
    QString m_address;
    QString m_ipv6;
    QString m_deviceName;
    QString m_deviceId;
    QString m_location;
    QString m_endpoint;
    QString m_accountNumber;
    QString m_selectedCityName;
    QString m_selectedCountry;
    QString m_selectedHost;
    QString m_selectedPubkey;
    QString m_selectedIpv4;
    QString m_error;
    bool m_connected;
};

#endif
