#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSocketNotifier>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTimer>

#include <gio/gio.h>
#include <linux/input.h>
#include <xkbcommon/xkbcommon.h>

#include <algorithm>
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <memory>
#include <sys/ioctl.h>
#include <unistd.h>

namespace {
using XkbContext = std::unique_ptr<xkb_context, decltype(&xkb_context_unref)>;
using XkbKeymap = std::unique_ptr<xkb_keymap, decltype(&xkb_keymap_unref)>;
using XkbState = std::unique_ptr<xkb_state, decltype(&xkb_state_unref)>;

bool hasKey(const unsigned long *bits, unsigned int key) {
    constexpr unsigned int wordBits = sizeof(unsigned long) * 8;
    return (bits[key / wordBits] & (1UL << (key % wordBits))) != 0;
}

bool isKeyboard(int fd) {
    unsigned long keys[(KEY_MAX + sizeof(unsigned long) * 8) / (sizeof(unsigned long) * 8)] = {};
    if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keys)), keys) < 0) return false;
    return hasKey(keys, KEY_A) && hasKey(keys, KEY_Z)
        && hasKey(keys, KEY_SPACE) && hasKey(keys, KEY_ENTER);
}

void send(const QJsonObject &event) {
    QByteArray line = QJsonDocument(event).toJson(QJsonDocument::Compact);
    line.append('\n');
    const char *data = line.constData();
    size_t remaining = size_t(line.size());
    while (remaining > 0) {
        const ssize_t written = ::write(STDOUT_FILENO, data, remaining);
        if (written <= 0) return;
        data += written;
        remaining -= size_t(written);
    }
}

struct Device {
    int fd;
    QSocketNotifier *notifier;
};

class Capture : public QObject {
public:
    explicit Capture(QCoreApplication &app, bool testMode = false) : QObject(&app),
        m_app(app), m_testMode(testMode),
        m_settings(g_settings_new("org.gnome.desktop.input-sources")),
        m_context(xkb_context_new(XKB_CONTEXT_NO_FLAGS), xkb_context_unref),
        m_sourcePath(QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation)
            + QStringLiteral("/zhyprbola/input-source")) {
        if (!m_context || !loadLayout()) return;
        if (m_testMode) {
            m_ready = true;
            return;
        }

        auto *parent = new QSocketNotifier(STDIN_FILENO, QSocketNotifier::Read, this);
        connect(parent, &QSocketNotifier::activated, this, [this] {
            char byte;
            if (::read(STDIN_FILENO, &byte, 1) <= 0) m_app.quit();
        });
        connect(&m_scanTimer, &QTimer::timeout, this, [this] { scanDevices(); });
        scanDevices();
        if (m_devices.isEmpty()) return;
        m_scanTimer.start(2000);
        send({{QStringLiteral("type"), QStringLiteral("ready")}});
        m_ready = true;
    }

    ~Capture() override {
        for (const Device &device : m_devices) {
            delete device.notifier;
            ::close(device.fd);
        }
        g_object_unref(m_settings);
    }

    bool ready() const { return m_ready; }

    void selfTest() {
        const auto testKey = [this](quint16 code, qint32 value) {
            input_event event = {};
            event.type = EV_KEY;
            event.code = code;
            event.value = value;
            keyEvent(event);
        };
        testKey(KEY_A, 1);
        testKey(KEY_A, 0);
        testKey(KEY_LEFTCTRL, 1);
        testKey(KEY_A, 1);
        testKey(KEY_A, 0);
        testKey(KEY_LEFTCTRL, 0);
        testKey(KEY_LEFTSHIFT, 1);
        testKey(KEY_A, 1);
        testKey(KEY_A, 0);
        testKey(KEY_LEFTSHIFT, 0);
        m_testLayout = 1;
        testKey(KEY_D, 1);
        testKey(KEY_D, 0);
        testKey(KEY_SPACE, 1);
        testKey(KEY_BACKSPACE, 1);
        testKey(KEY_ENTER, 1);
    }

    void selfTestSourceSwitch() {
        QTemporaryDir directory;
        if (!directory.isValid()) return;
        m_sourcePath = directory.filePath(QStringLiteral("input-source"));
        const auto testSource = [this](const QByteArray &source) {
            QFile file(m_sourcePath);
            if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
            file.write(source);
            file.close();
            input_event event = {};
            event.type = EV_KEY;
            event.code = KEY_D;
            event.value = 1;
            keyEvent(event);
            event.value = 0;
            keyEvent(event);
        };
        testSource("us\n");
        testSource("th\n");
        testSource("us\n");
    }

private:
    bool loadLayout() {
        QStringList layouts;
        QStringList variants;
        if (m_testMode) {
            layouts = {QStringLiteral("us"), QStringLiteral("th")};
            m_sourceIds = layouts;
        } else {
            GVariant *sources = g_settings_get_value(m_settings, "sources");
            GVariantIter iter;
            g_variant_iter_init(&iter, sources);
            const char *type;
            const char *id;
            while (g_variant_iter_loop(&iter, "(&s&s)", &type, &id)) {
                if (strcmp(type, "xkb") != 0) continue;
                const QStringList parts = QString::fromUtf8(id).split(QLatin1Char('+'));
                layouts.append(parts.value(0));
                variants.append(parts.value(1));
                m_sourceIds.append(QString::fromUtf8(id));
            }
            g_variant_unref(sources);
        }
        if (layouts.isEmpty()) {
            layouts.append(QStringLiteral("us"));
            m_sourceIds.append(QStringLiteral("us"));
        }
        while (variants.size() < layouts.size()) variants.append(QString());

        const QByteArray layout = layouts.join(QLatin1Char(',')).toUtf8();
        const QByteArray variant = variants.join(QLatin1Char(',')).toUtf8();
        const xkb_rule_names names = {"evdev", "pc105", layout.constData(),
            variant.constData(), nullptr};
        m_keymap = XkbKeymap(xkb_keymap_new_from_names(m_context.get(), &names,
            XKB_KEYMAP_COMPILE_NO_FLAGS), xkb_keymap_unref);
        if (!m_keymap) return false;
        m_state = XkbState(xkb_state_new(m_keymap.get()), xkb_state_unref);
        return bool(m_state);
    }

    void syncLayout() {
        while (g_main_context_iteration(nullptr, false)) {}
        const xkb_layout_index_t count = xkb_keymap_num_layouts(m_keymap.get());
        if (!count) return;
        xkb_layout_index_t selected = std::min(m_testMode ? m_testLayout
            : g_settings_get_uint(m_settings, "current"), count - 1);
        QFile sourceFile(m_sourcePath);
        if (sourceFile.open(QIODevice::ReadOnly)) {
            const int index = m_sourceIds.indexOf(
                QString::fromUtf8(sourceFile.readAll().trimmed()));
            if (index >= 0 && xkb_layout_index_t(index) < count)
                selected = xkb_layout_index_t(index);
        }
        if (selected == m_layout) return;
        m_layout = selected;
        xkb_state_update_mask(m_state.get(),
            xkb_state_serialize_mods(m_state.get(), XKB_STATE_MODS_DEPRESSED),
            xkb_state_serialize_mods(m_state.get(), XKB_STATE_MODS_LATCHED),
            xkb_state_serialize_mods(m_state.get(), XKB_STATE_MODS_LOCKED),
            0, 0, selected);
    }

    void keyEvent(const input_event &event) {
        if (event.type != EV_KEY || event.value == 2 || event.code > KEY_MAX) return;
        syncLayout();
        const xkb_keycode_t code = event.code + 8;
        if (event.value == 1)
            xkb_state_update_key(m_state.get(), code, XKB_KEY_DOWN);

        const xkb_keysym_t sym = xkb_state_key_get_one_sym(m_state.get(), code);
        char name[128] = {};
        xkb_keysym_get_name(sym, name, sizeof(name));
        if (event.value == 0) {
            send({{QStringLiteral("type"), QStringLiteral("release")},
                {QStringLiteral("name"), QString::fromLatin1(name)}});
            xkb_state_update_key(m_state.get(), code, XKB_KEY_UP);
            return;
        }
        if (event.value != 1) return;

        const int size = xkb_state_key_get_utf8(m_state.get(), code, nullptr, 0);
        QByteArray utf8(size + 1, '\0');
        if (size > 0)
            xkb_state_key_get_utf8(m_state.get(), code, utf8.data(), size_t(utf8.size()));
        const auto active = [this](const char *modifier) {
            return xkb_state_mod_name_is_active(m_state.get(), modifier,
                XKB_STATE_MODS_EFFECTIVE) > 0;
        };
        send({{QStringLiteral("type"), QStringLiteral("press")},
            {QStringLiteral("name"), QString::fromLatin1(name)},
            {QStringLiteral("text"), QString::fromUtf8(utf8.constData())},
            {QStringLiteral("shift"), active(XKB_MOD_NAME_SHIFT)},
            {QStringLiteral("ctrl"), active(XKB_MOD_NAME_CTRL)},
            {QStringLiteral("alt"), active(XKB_MOD_NAME_ALT)},
            {QStringLiteral("super"), active(XKB_MOD_NAME_LOGO)}});
    }

    void scanDevices() {
        const QStringList entries = QDir(QStringLiteral("/dev/input")).entryList(
            {QStringLiteral("event*")}, QDir::System | QDir::Files);
        for (const QString &entry : entries) {
            const QString path = QStringLiteral("/dev/input/") + entry;
            if (m_devices.contains(path)) continue;
            const int fd = ::open(QFile::encodeName(path).constData(),
                O_RDONLY | O_NONBLOCK | O_CLOEXEC);
            if (fd < 0) continue;
            if (!isKeyboard(fd)) {
                ::close(fd);
                continue;
            }
            auto *notifier = new QSocketNotifier(fd, QSocketNotifier::Read, this);
            connect(notifier, &QSocketNotifier::activated, this, [this, path, fd] {
                input_event event;
                ssize_t bytes;
                while ((bytes = ::read(fd, &event, sizeof(event))) == sizeof(event))
                    keyEvent(event);
                if (bytes == 0 || (bytes < 0 && errno != EAGAIN && errno != EINTR)) {
                    auto device = m_devices.take(path);
                    device.notifier->deleteLater();
                    ::close(device.fd);
                }
            });
            m_devices.insert(path, {fd, notifier});
        }
    }

    QCoreApplication &m_app;
    bool m_testMode;
    unsigned int m_testLayout = 0;
    GSettings *m_settings;
    XkbContext m_context;
    XkbKeymap m_keymap{nullptr, xkb_keymap_unref};
    XkbState m_state{nullptr, xkb_state_unref};
    QStringList m_sourceIds;
    QString m_sourcePath;
    xkb_layout_index_t m_layout = XKB_LAYOUT_INVALID;
    QHash<QString, Device> m_devices;
    QTimer m_scanTimer;
    bool m_ready = false;
};
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    const bool sourceSwitchTest = app.arguments().contains(
        QStringLiteral("--self-test-source-switch"));
    const bool testMode = sourceSwitchTest || app.arguments().contains(
        QStringLiteral("--self-test"));
    Capture capture(app, testMode);
    if (!capture.ready()) {
        qWarning("No readable keyboard devices or XKB layout for key capture");
        return 1;
    }
    if (testMode) {
        if (sourceSwitchTest) capture.selfTestSourceSwitch();
        else capture.selfTest();
        return 0;
    }
    return app.exec();
}
