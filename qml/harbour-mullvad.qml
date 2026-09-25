import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"

ApplicationWindow {
    id: app
    allowedOrientations: defaultAllowedOrientations
    initialPage: Component { LoginPage { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")

    property string accountNumber: ""
    property string accessToken: ""
    property bool busy: false
    property string vpnActivity: ""
    property bool checking: false
    property string checkError: ""
    property string error: ""
    property var account: ({})
    property var devices: []
    property var connection: ({})
    property var cities: []
    property bool loggedIn: accessToken.length > 0
    property bool needKick: false
    property bool pendingConnect: false
    property var pendingCity: null
    property var selectedCity: vpn.selectedHost.length > 0 ? {
        "city": vpn.selectedCityName,
        "country": vpn.selectedCountry,
        "host": vpn.selectedHost,
        "pubkey": vpn.selectedPubkey,
        "ipv4": vpn.selectedIpv4
    } : null
    property int maxDevices: (account && account.max_devices) ? account.max_devices : 5
    property bool canAddDevices: {
        if (account && account.can_add_devices === false)
            return false
        return devices.length < maxDevices
    }

    ListModel { id: deviceModel }
    property alias deviceModel: deviceModel

    Timer {
        id: tunnelTimer
        interval: 1
        repeat: false
        property string action: ""
        onTriggered: {
            if (action === "up")
                app.finishConnect()
            else if (action === "down")
                app.finishDisconnect()
        }
    }

    function digitsOnly(s) {
        return String(s || "").replace(/\D/g, "")
    }

    function httpError(what, status) {
        if (!status)
            return qsTr("%1 failed. No network.").arg(what)
        return qsTr("%1 failed (%2).").arg(what).arg(status)
    }

    function formatAccount(s) {
        var d = digitsOnly(s)
        var parts = []
        for (var i = 0; i < d.length; i += 4)
            parts.push(d.substr(i, 4))
        return parts.join(" ")
    }

    function formatExpiry(iso) {
        if (!iso)
            return qsTr("unknown")
        var t = Date.parse(iso)
        if (!t)
            return iso
        return new Date(t).toDateString()
    }

    function daysLeft(iso) {
        var t = Date.parse(iso)
        if (!t)
            return -1
        return Math.max(0, Math.floor((t - Date.now()) / 86400000))
    }

    function cidrHost(s) {
        s = String(s || "")
        var i = s.indexOf("/")
        return i > 0 ? s.substr(0, i) : s
    }

    function shortKey(k) {
        k = String(k || "")
        if (k.length <= 12)
            return k
        return k.substr(0, 8) + "…"
    }

    function parseJson(text) {
        if (!text)
            return null
        var t = String(text).replace(/^\s+/, "")
        try {
            if (t.charAt(0) === "[")
                return JSON.parse('{"x":' + t + "}").x
            return JSON.parse(t)
        } catch (e) {
            return null
        }
    }

    function listFrom(obj) {
        var out = []
        if (obj === null || obj === undefined)
            return out
        for (var i = 0; obj[i] !== undefined && obj[i] !== null; i++)
            out.push(obj[i])
        return out
    }

    function request(method, url, body, cb) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            cb(xhr.status, parseJson(xhr.responseText), xhr.responseText)
        }
        xhr.open(method, url)
        if (app.accessToken.length > 0)
            xhr.setRequestHeader("Authorization", "Bearer " + app.accessToken)
        if (body) {
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.send(JSON.stringify(body))
        } else {
            xhr.send()
        }
    }

    function login(num) {
        var n = digitsOnly(num)
        app.error = ""
        if (n.length !== 16) {
            app.error = qsTr("Account number must be 16 digits.")
            return
        }
        app.busy = true
        app.accountNumber = n
        vpn.setAccountNumber(n)
        request("POST", "https://api.mullvad.net/auth/v1/token",
                { "account_number": n }, function(status, obj) {
            if (status !== 200 || !obj || !obj.access_token) {
                app.busy = false
                app.accessToken = ""
                app.error = (obj && obj.code) ? obj.code : httpError(qsTr("Login"), status)
                return
            }
            app.accessToken = obj.access_token
            vpn.ensureKeys()
            if (vpn.error.length > 0)
                app.error = vpn.error
            refreshAll()
            if (pageStack.currentPage && pageStack.currentPage.objectName !== "AccountPage")
                pageStack.replace(Qt.resolvedUrl("pages/AccountPage.qml"))
        })
    }

    function logout() {
        app.accessToken = ""
        app.accountNumber = ""
        app.account = ({})
        app.devices = []
        deviceModel.clear()
        app.connection = ({})
        app.cities = []
        app.error = ""
        app.busy = false
        app.vpnActivity = ""
        app.checking = false
        app.checkError = ""
        app.needKick = false
        app.pendingConnect = false
        app.pendingCity = null
        vpn.disconnectTunnel()
        if (vpn.error.length > 0)
            app.error = vpn.error
        pageStack.replace(Qt.resolvedUrl("pages/LoginPage.qml"))
    }

    function refreshAll() {
        refreshAccount()
        refreshConnection()
        refreshRelays()
    }

    function refreshAccount() {
        request("GET", "https://api.mullvad.net/accounts/v1/accounts/me", null, function(status, obj) {
            app.busy = false
            if (status === 200 && obj)
                app.account = obj
            else
                app.error = httpError(qsTr("Account lookup"), status)
            refreshDevices()
            refreshConnection()
        })
    }

    function refreshDevices(done) {
        request("GET", "https://api.mullvad.net/accounts/v1/devices", null, function(status, obj) {
            var list = (status === 200) ? listFrom(obj) : []
            app.devices = list
            deviceModel.clear()
            for (var i = 0; i < list.length; i++) {
                var d = list[i]
                var pub = (d && d.pubkey) ? String(d.pubkey) : ""
                var did = (d && d.id) ? String(d.id) : ""
                var thisDev = (pub && pub === vpn.publicKey) || (did && did === vpn.deviceId)
                deviceModel.append({
                    "name": (d && d.name) ? String(d.name) : qsTr("unnamed"),
                    "created": (d && d.created) ? String(d.created) : "",
                    "deviceId": did,
                    "pubkey": pub,
                    "ipv4": (d && d.ipv4_address) ? String(d.ipv4_address) : "",
                    "ipv6": (d && d.ipv6_address) ? String(d.ipv6_address) : "",
                    "thisDevice": thisDev ? 1 : 0
                })
            }
            if (status === 200)
                syncLocalDevice()
            else
                app.error = httpError(qsTr("Device list"), status)
            if (typeof done === "function")
                done()
        })
    }

    function findLocalDevice() {
        var pub = vpn.publicKey
        var i
        for (i = 0; i < app.devices.length; i++) {
            var d = app.devices[i]
            if (!d)
                continue
            if (pub && d.pubkey === pub)
                return d
            if (vpn.deviceId && d.id === vpn.deviceId)
                return d
        }
        return null
    }

    function adoptMatching() {
        var found = findLocalDevice()
        if (!found)
            return false
        vpn.setDevice(found.id || "", found.name || "", found.ipv4_address || "", found.ipv6_address || "")
        return true
    }

    function syncLocalDevice() {
        if (adoptMatching())
            return
        if (vpn.hasDevice) {
            if (vpn.connected)
                vpn.disconnectTunnel()
            vpn.clearDevice()
        }
    }

    function showDevicesPage() {
        if (pageStack.currentPage && pageStack.currentPage.objectName === "DevicesPage")
            return
        pageStack.push(Qt.resolvedUrl("pages/DevicesPage.qml"))
    }

    function isMaxDevicesError(status, obj) {
        var code = (obj && obj.code) ? String(obj.code) : ""
        if (code === "MAX_DEVICES_REACHED" || code === "MAX_DEVICES")
            return true
        if (status === 400 && app.account.can_add_devices === false)
            return true
        if (status === 400 && app.devices.length >= app.maxDevices)
            return true
        return false
    }

    function refreshConnection() {
        app.checking = true
        app.checkError = ""
        request("GET", "https://am.i.mullvad.net/json", null, function(status, obj) {
            app.checking = false
            if (status === 200 && obj) {
                app.connection = obj
                app.checkError = ""
            } else {
                app.checkError = httpError(qsTr("Connection check"), status)
            }
        })
    }

    function refreshRelays() {
        request("GET", "https://api.mullvad.net/public/relays/wireguard/v1/", null, function(status, obj) {
            if (status !== 200 || !obj || !obj.countries) {
                if (app.pendingConnect) {
                    app.pendingConnect = false
                    app.busy = false
                    app.vpnActivity = ""
                }
                app.error = httpError(qsTr("Location list"), status)
                return
            }
            var out = []
            for (var i = 0; i < obj.countries.length; i++) {
                var co = obj.countries[i]
                var cities = co.cities || []
                for (var j = 0; j < cities.length; j++) {
                    var ci = cities[j]
                    var relays = ci.relays || []
                    out.push({
                        "city": ci.name || "",
                        "country": co.name || "",
                        "code": (co.code || "") + "-" + (ci.code || ""),
                        "relays": relays.length,
                        "host": relays.length ? (relays[0].hostname || "") : "",
                        "pubkey": relays.length ? (relays[0].public_key || "") : "",
                        "ipv4": relays.length ? (relays[0].ipv4_addr_in || "") : ""
                    })
                }
            }
            app.cities = out
            if (app.pendingConnect) {
                if (out.length)
                    connectVpn(app.pendingCity)
                else {
                    app.pendingConnect = false
                    app.busy = false
                    app.vpnActivity = ""
                    app.error = qsTr("No WireGuard location loaded yet.")
                }
            }
        })
    }

    function defaultCity() {
        var i
        for (i = 0; i < app.cities.length; i++) {
            if (app.cities[i].country === "Sweden" || app.cities[i].country === "Netherlands")
                return app.cities[i]
        }
        return app.cities.length ? app.cities[0] : null
    }

    function registerDevice(cb) {
        vpn.ensureKeys()
        if (adoptMatching()) {
            if (cb)
                cb()
            return
        }
        if (vpn.hasDevice) {
            if (cb)
                cb()
            return
        }
        app.busy = true
        request("POST", "https://api.mullvad.net/accounts/v1/devices",
                { "pubkey": vpn.publicKey, "hijack_dns": true }, function(status, obj) {
            if ((status === 201 || status === 200) && obj) {
                vpn.setDevice(obj.id || "", obj.name || "", obj.ipv4_address || "", obj.ipv6_address || "")
                app.needKick = false
                refreshDevices(function() {
                    if (cb)
                        cb()
                    else
                        app.busy = false
                })
                return
            }
            if (obj && obj.code === "PUBKEY_IN_USE") {
                refreshDevices(function() {
                    if (adoptMatching() && cb)
                        cb()
                    else {
                        app.busy = false
                        app.vpnActivity = ""
                        app.error = qsTr("This key is already registered.")
                    }
                })
                return
            }
            app.busy = false
            app.vpnActivity = ""
            if (isMaxDevicesError(status, obj)) {
                app.needKick = true
                app.error = qsTr("Account is full. Remove a device to connect this one.")
                showDevicesPage()
                return
            }
            app.error = (obj && obj.code) ? obj.code : httpError(qsTr("Device register"), status)
        })
    }

    function kickDevice(deviceId) {
        if (!deviceId) {
            app.error = qsTr("Missing device id.")
            return
        }
        var mine = (deviceId === vpn.deviceId)
        var i
        for (i = 0; i < app.devices.length; i++) {
            var d = app.devices[i]
            if (d && d.id === deviceId && vpn.publicKey && d.pubkey === vpn.publicKey)
                mine = true
        }
        app.busy = true
        app.error = ""
        request("DELETE", "https://api.mullvad.net/accounts/v1/devices/" + encodeURIComponent(deviceId), null, function(status, obj) {
            if (status !== 204 && status !== 200 && status !== 404) {
                app.busy = false
                app.error = (obj && obj.code) ? obj.code : httpError(qsTr("Remove device"), status)
                return
            }
            if (mine) {
                vpn.disconnectTunnel()
                vpn.clearDevice()
            }
            refreshDevices(function() {
                if (app.pendingCity && (vpn.hasDevice || app.canAddDevices))
                    connectVpn(app.pendingCity)
                else
                    app.busy = false
            })
        })
    }

    function selectCity(city) {
        vpn.setSelectedCity(city.city || "", city.country || "", city.host || "",
                            city.pubkey || "", city.ipv4 || "")
        app.selectedCity = {
            "city": city.city || "",
            "country": city.country || "",
            "host": city.host || "",
            "pubkey": city.pubkey || "",
            "ipv4": city.ipv4 || ""
        }
        if (pageStack.depth > 1)
            pageStack.pop()
    }

    function connectVpn(city) {
        if (city)
            app.pendingCity = city
        else if (app.selectedCity)
            app.pendingCity = app.selectedCity
        var c = app.pendingCity || defaultCity()
        if (!c || !c.pubkey || !c.ipv4) {
            app.pendingConnect = true
            app.vpnActivity = "connect"
            app.busy = true
            app.error = qsTr("Loading locations…")
            refreshRelays()
            return
        }
        app.pendingConnect = false
        app.error = ""
        app.pendingCity = c
        app.vpnActivity = "connect"
        app.busy = true
        registerDevice(function() {
            if (!vpn.prepare(c.pubkey, c.ipv4, c.host, (c.city || "") + ", " + (c.country || ""))) {
                app.busy = false
                app.vpnActivity = ""
                app.error = vpn.error || qsTr("Could not prepare the VPN.")
                return
            }
            tunnelTimer.action = "up"
            tunnelTimer.restart()
        })
    }

    function finishConnect() {
        vpn.connectTunnel()
        app.busy = false
        app.vpnActivity = ""
        if (vpn.error.length > 0) {
            app.error = vpn.error
            return
        }
        app.needKick = false
        app.pendingCity = null
        if (pageStack.currentPage && pageStack.currentPage.objectName === "DevicesPage")
            pageStack.pop()
        refreshConnection()
    }

    function disconnectVpn() {
        app.error = ""
        app.vpnActivity = "disconnect"
        app.busy = true
        tunnelTimer.action = "down"
        tunnelTimer.restart()
    }

    function finishDisconnect() {
        vpn.disconnectTunnel()
        app.busy = false
        app.vpnActivity = ""
        if (vpn.error.length > 0)
            app.error = vpn.error
        refreshConnection()
    }
}
