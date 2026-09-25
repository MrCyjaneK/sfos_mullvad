/* setgid privileged: vpnd allows Create/Connect/Disconnect only for that group. */
#define _GNU_SOURCE
#include <dbus/dbus.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CONFIG_DIR "/home/defaultuser/.config/harbour-mullvad"
#define PROPS_PATH CONFIG_DIR "/vpn.provider"
#define VPN_NAME "Mullvad"
#define CONN_PREFIX "/net/connman/vpn/connection/"

struct props {
    char *host;
    char *address;
    char *private_key;
    char *public_key;
    char *allowed_ips;
    char *endpoint_port;
    char *keepalive;
    char *dns;
};

static DBusConnection *bus;

static void oom(void)
{
    fprintf(stderr, "out of memory\n");
    exit(1);
}

static char *xstrdup(const char *s)
{
    char *p = strdup(s ? s : "");
    if (!p)
        oom();
    return p;
}

static void set_field(char **dst, const char *val)
{
    free(*dst);
    *dst = xstrdup(val);
}

static void free_props(struct props *p)
{
    free(p->host);
    free(p->address);
    free(p->private_key);
    free(p->public_key);
    free(p->allowed_ips);
    free(p->endpoint_port);
    free(p->keepalive);
    free(p->dns);
    memset(p, 0, sizeof(*p));
}

static void die_dbus(DBusError *err, const char *what)
{
    fprintf(stderr, "%s: %s\n", what, err->message ? err->message : "dbus error");
    exit(1);
}

static DBusMessage *call(DBusMessage *msg, int timeout_ms)
{
    DBusError err;
    DBusMessage *reply;

    dbus_error_init(&err);
    reply = dbus_connection_send_with_reply_and_block(bus, msg, timeout_ms, &err);
    dbus_message_unref(msg);
    if (!reply)
        die_dbus(&err, "connman");
    dbus_error_free(&err);
    return reply;
}

static int load_props(struct props *p)
{
    FILE *f = fopen(PROPS_PATH, "r");
    char *line = NULL;
    size_t cap = 0;

    memset(p, 0, sizeof(*p));
    if (!f) {
        fprintf(stderr, "missing %s\n", PROPS_PATH);
        return -1;
    }
    set_field(&p->endpoint_port, "51820");
    set_field(&p->keepalive, "25");
    set_field(&p->dns, "10.64.0.1");
    set_field(&p->allowed_ips, "0.0.0.0/0");
    while (getline(&line, &cap, f) != -1) {
        char *eq = strchr(line, '=');
        char *nl;
        if (!eq)
            continue;
        *eq++ = 0;
        nl = strchr(eq, '\n');
        if (nl)
            *nl = 0;
        if (!strcmp(line, "host"))
            set_field(&p->host, eq);
        else if (!strcmp(line, "address"))
            set_field(&p->address, eq);
        else if (!strcmp(line, "privateKey"))
            set_field(&p->private_key, eq);
        else if (!strcmp(line, "publicKey"))
            set_field(&p->public_key, eq);
        else if (!strcmp(line, "allowedIPs"))
            set_field(&p->allowed_ips, eq);
        else if (!strcmp(line, "endpointPort"))
            set_field(&p->endpoint_port, eq);
        else if (!strcmp(line, "keepalive"))
            set_field(&p->keepalive, eq);
        else if (!strcmp(line, "dns"))
            set_field(&p->dns, eq);
    }
    free(line);
    fclose(f);
    if (!p->host || !p->host[0] || !p->address || !p->address[0]
            || !p->private_key || !p->private_key[0]
            || !p->public_key || !p->public_key[0]) {
        fprintf(stderr, "incomplete vpn provider\n");
        free_props(p);
        return -1;
    }
    return 0;
}

static void append_entry(DBusMessageIter *dict, const char *key, const char *val)
{
    DBusMessageIter ent, var;
    dbus_message_iter_open_container(dict, DBUS_TYPE_DICT_ENTRY, NULL, &ent);
    dbus_message_iter_append_basic(&ent, DBUS_TYPE_STRING, &key);
    dbus_message_iter_open_container(&ent, DBUS_TYPE_VARIANT, "s", &var);
    dbus_message_iter_append_basic(&var, DBUS_TYPE_STRING, &val);
    dbus_message_iter_close_container(&ent, &var);
    dbus_message_iter_close_container(dict, &ent);
}

static void dict_add_wg(DBusMessageIter *dict, const struct props *p)
{
    append_entry(dict, "WireGuard.Address", p->address);
    append_entry(dict, "WireGuard.PrivateKey", p->private_key);
    append_entry(dict, "WireGuard.PublicKey", p->public_key);
    append_entry(dict, "WireGuard.AllowedIPs", p->allowed_ips);
    append_entry(dict, "WireGuard.EndpointPort", p->endpoint_port);
    append_entry(dict, "WireGuard.PersistentKeepalive", p->keepalive);
    append_entry(dict, "WireGuard.DNS", p->dns);
}

static char *create_connection(const struct props *p)
{
    DBusMessage *msg = dbus_message_new_method_call(
        "net.connman.vpn", "/", "net.connman.vpn.Manager", "Create");
    DBusMessage *reply;
    DBusMessageIter iter, dict;
    const char *path = NULL;
    char *out;
    const char *type = "wireguard";
    const char *name = VPN_NAME;

    dbus_message_iter_init_append(msg, &iter);
    dbus_message_iter_open_container(&iter, DBUS_TYPE_ARRAY, "{sv}", &dict);
    append_entry(&dict, "Type", type);
    append_entry(&dict, "Name", name);
    append_entry(&dict, "Host", p->host);
    /* Reloading a provider with no Domain leaves its D-Bus path unset, and the next GetConnections aborts vpnd. */
    append_entry(&dict, "Domain", "mullvad");
    dict_add_wg(&dict, p);
    dbus_message_iter_close_container(&iter, &dict);
    reply = call(msg, 20000);
    if (!dbus_message_get_args(reply, NULL, DBUS_TYPE_OBJECT_PATH, &path, DBUS_TYPE_INVALID)) {
        fprintf(stderr, "Create returned no path\n");
        exit(1);
    }
    out = xstrdup(path);
    dbus_message_unref(reply);
    return out;
}

static void set_property(const char *path, const char *key, const char *val)
{
    DBusMessage *msg = dbus_message_new_method_call(
        "net.connman.vpn", path, "net.connman.vpn.Connection", "SetProperty");
    DBusMessageIter iter, var;
    DBusMessage *reply;

    dbus_message_iter_init_append(msg, &iter);
    dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &key);
    dbus_message_iter_open_container(&iter, DBUS_TYPE_VARIANT, "s", &var);
    dbus_message_iter_append_basic(&var, DBUS_TYPE_STRING, &val);
    dbus_message_iter_close_container(&iter, &var);
    reply = call(msg, 20000);
    dbus_message_unref(reply);
}

static void remove_connection(const char *path)
{
    DBusMessage *msg = dbus_message_new_method_call(
        "net.connman.vpn", "/", "net.connman.vpn.Manager", "Remove");
    DBusMessage *reply;
    dbus_message_append_args(msg, DBUS_TYPE_OBJECT_PATH, &path, DBUS_TYPE_INVALID);
    reply = call(msg, 20000);
    dbus_message_unref(reply);
}

static char *service_path(const char *conn_path)
{
    size_t n = strlen(CONN_PREFIX);
    char *svc;
    if (!conn_path || strncmp(conn_path, CONN_PREFIX, n) != 0) {
        fprintf(stderr, "unexpected connection path\n");
        exit(1);
    }
    if (asprintf(&svc, "/net/connman/service/vpn_%s", conn_path + n) < 0)
        oom();
    return svc;
}

static int error_means_missing(const DBusError *err)
{
    return err->name && (strstr(err->name, "UnknownMethod")
                         || strstr(err->name, "UnknownObject"));
}

/* The service object shows up just after Create; UnknownMethod means wait. */
static DBusMessage *service_call(const char *svc, const char *method, int timeout_ms)
{
    int tries;
    for (tries = 0; tries < 50; tries++) {
        DBusMessage *msg = dbus_message_new_method_call(
            "net.connman", svc, "net.connman.Service", method);
        DBusError err;
        DBusMessage *reply;
        dbus_error_init(&err);
        reply = dbus_connection_send_with_reply_and_block(bus, msg, timeout_ms, &err);
        dbus_message_unref(msg);
        if (reply) {
            dbus_error_free(&err);
            return reply;
        }
        if (!error_means_missing(&err))
            die_dbus(&err, "connman");
        dbus_error_free(&err);
        usleep(100000);
    }
    fprintf(stderr, "connman service %s did not appear\n", svc);
    exit(1);
}

static void service_method(const char *conn_path, const char *method, int timeout_ms)
{
    char *svc = service_path(conn_path);
    DBusMessage *reply = service_call(svc, method, timeout_ms);
    free(svc);
    dbus_message_unref(reply);
}

/* The top menu disconnects by clearing AutoConnect, and only if it changes. */
static void service_set_autoconnect(const char *conn_path, int enabled)
{
    char *svc = service_path(conn_path);
    DBusMessage *msg;
    DBusMessageIter iter, var;
    dbus_bool_t value = enabled ? TRUE : FALSE;
    const char *key = "AutoConnect";
    DBusMessage *reply;
    msg = dbus_message_new_method_call(
        "net.connman", svc, "net.connman.Service", "SetProperty");
    dbus_message_iter_init_append(msg, &iter);
    dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &key);
    dbus_message_iter_open_container(&iter, DBUS_TYPE_VARIANT, "b", &var);
    dbus_message_iter_append_basic(&var, DBUS_TYPE_BOOLEAN, &value);
    dbus_message_iter_close_container(&iter, &var);
    reply = service_call(svc, "GetProperties", 20000);
    dbus_message_unref(reply);
    reply = call(msg, 20000);
    dbus_message_unref(reply);
    free(svc);
}

static int dict_string(DBusMessageIter *var, const char **out)
{
    if (dbus_message_iter_get_arg_type(var) != DBUS_TYPE_STRING)
        return -1;
    dbus_message_iter_get_basic(var, out);
    return 0;
}

static char *find_mullvad(char **host_out)
{
    DBusMessage *msg = dbus_message_new_method_call(
        "net.connman.vpn", "/", "net.connman.vpn.Manager", "GetConnections");
    DBusMessage *reply = call(msg, 20000);
    DBusMessageIter arr, top;
    char *found = NULL;

    if (host_out)
        *host_out = NULL;
    dbus_message_iter_init(reply, &top);
    if (dbus_message_iter_get_arg_type(&top) != DBUS_TYPE_ARRAY) {
        dbus_message_unref(reply);
        return NULL;
    }
    dbus_message_iter_recurse(&top, &arr);
    while (dbus_message_iter_get_arg_type(&arr) == DBUS_TYPE_STRUCT) {
        DBusMessageIter st, dict;
        const char *path = NULL;
        const char *name = NULL;
        const char *host = NULL;

        dbus_message_iter_recurse(&arr, &st);
        if (dbus_message_iter_get_arg_type(&st) == DBUS_TYPE_OBJECT_PATH)
            dbus_message_iter_get_basic(&st, &path);
        dbus_message_iter_next(&st);
        if (dbus_message_iter_get_arg_type(&st) == DBUS_TYPE_ARRAY) {
            dbus_message_iter_recurse(&st, &dict);
            while (dbus_message_iter_get_arg_type(&dict) == DBUS_TYPE_DICT_ENTRY) {
                DBusMessageIter ent, var;
                const char *key = NULL;
                dbus_message_iter_recurse(&dict, &ent);
                dbus_message_iter_get_basic(&ent, &key);
                dbus_message_iter_next(&ent);
                dbus_message_iter_recurse(&ent, &var);
                if (key && !strcmp(key, "Name"))
                    dict_string(&var, &name);
                else if (key && !strcmp(key, "Host"))
                    dict_string(&var, &host);
                dbus_message_iter_next(&dict);
            }
        }
        if (path && name && !strcmp(name, VPN_NAME)) {
            free(found);
            found = xstrdup(path);
            if (host_out) {
                free(*host_out);
                *host_out = xstrdup(host ? host : "");
            }
        }
        dbus_message_iter_next(&arr);
    }
    dbus_message_unref(reply);
    return found;
}

static int state_is_up(const char *conn_path)
{
    char *svc = service_path(conn_path);
    DBusMessage *msg;
    DBusMessage *reply;
    DBusMessageIter top, dict;
    int up = 0;
    msg = dbus_message_new_method_call(
        "net.connman", svc, "net.connman.Service", "GetProperties");
    reply = call(msg, 20000);
    dbus_message_iter_init(reply, &top);
    if (dbus_message_iter_get_arg_type(&top) == DBUS_TYPE_ARRAY) {
        dbus_message_iter_recurse(&top, &dict);
        while (dbus_message_iter_get_arg_type(&dict) == DBUS_TYPE_DICT_ENTRY) {
            DBusMessageIter ent, var;
            const char *key = NULL;
            const char *state = NULL;
            dbus_message_iter_recurse(&dict, &ent);
            dbus_message_iter_get_basic(&ent, &key);
            dbus_message_iter_next(&ent);
            dbus_message_iter_recurse(&ent, &var);
            if (key && !strcmp(key, "State") && dict_string(&var, &state) == 0) {
                if (!strcmp(state, "ready") || !strcmp(state, "online"))
                    up = 1;
            }
            dbus_message_iter_next(&dict);
        }
    }
    dbus_message_unref(reply);
    free(svc);
    return up;
}

static int cmd_up(void)
{
    struct props p;
    char *existing_host = NULL;
    char *path;

    memset(&p, 0, sizeof(p));
    if (load_props(&p) != 0)
        return 1;
    path = find_mullvad(&existing_host);
    if (path && strcmp(existing_host ? existing_host : "", p.host) != 0) {
        remove_connection(path);
        free(path);
        path = NULL;
    }
    if (!path) {
        path = create_connection(&p);
    } else {
        set_property(path, "WireGuard.Address", p.address);
        set_property(path, "WireGuard.PrivateKey", p.private_key);
        set_property(path, "WireGuard.PublicKey", p.public_key);
        set_property(path, "WireGuard.AllowedIPs", p.allowed_ips);
        set_property(path, "WireGuard.EndpointPort", p.endpoint_port);
        set_property(path, "WireGuard.PersistentKeepalive", p.keepalive);
        set_property(path, "WireGuard.DNS", p.dns);
        set_property(path, "Domain", "mullvad");
    }
    service_method(path, "Connect", 90000);
    service_set_autoconnect(path, 1);
    printf("up %s via %s\n", p.address, p.host);
    free(path);
    free(existing_host);
    free_props(&p);
    return 0;
}

static int cmd_down(void)
{
    char *svc;
    char *path = find_mullvad(NULL);
    DBusMessage *msg;
    DBusError err;
    DBusMessage *reply;

    if (!path)
        return 0;
    service_set_autoconnect(path, 0);
    svc = service_path(path);
    msg = dbus_message_new_method_call("net.connman", svc, "net.connman.Service", "Disconnect");
    dbus_error_init(&err);
    reply = dbus_connection_send_with_reply_and_block(bus, msg, 30000, &err);
    dbus_message_unref(msg);
    free(svc);
    free(path);
    if (reply) {
        dbus_message_unref(reply);
        dbus_error_free(&err);
        return 0;
    }
    /* Idle profiles answer with AlreadyDisabled. That is not a failure. */
    if (dbus_error_is_set(&err) && err.name && strstr(err.name, "Already")) {
        dbus_error_free(&err);
        return 0;
    }
    fprintf(stderr, "connman: %s\n",
            (dbus_error_is_set(&err) && err.message) ? err.message : "disconnect failed");
    dbus_error_free(&err);
    return 1;
}

static int cmd_status(void)
{
    char *path = find_mullvad(NULL);
    if (!path || !state_is_up(path)) {
        printf("down\n");
        free(path);
        return 1;
    }
    printf("up\n");
    free(path);
    return 0;
}

int main(int argc, char **argv)
{
    DBusError err;

    if (argc < 2) {
        fprintf(stderr, "usage: harbour-mullvad-vpn up|down|status\n");
        return 1;
    }
    dbus_error_init(&err);
    bus = dbus_bus_get(DBUS_BUS_SYSTEM, &err);
    if (!bus)
        die_dbus(&err, "system bus");
    if (!strcmp(argv[1], "up"))
        return cmd_up();
    if (!strcmp(argv[1], "down"))
        return cmd_down();
    if (!strcmp(argv[1], "status"))
        return cmd_status();
    fprintf(stderr, "unknown command\n");
    return 1;
}
