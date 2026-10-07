#include <QCoreApplication>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSocketNotifier>
#include <QSet>
#include <QVector>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTimer>

#include <gio/gio.h>
#include <linux/input.h>
#include <xkbcommon/xkbcommon.h>

#include <algorithm>
#include <cerrno>
#include <chrono>
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

qint64 monotonicMilliseconds() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

struct PendingEvent {
    QString path;
    input_event event;
};

struct Device {
    int fd;
    QSocketNotifier *notifier;
    QSet<quint16> pressed;
    bool dropped = false;
};

class Capture : public QObject {
public:
    explicit Capture(QCoreApplication &app, bool testMode = false) : QObject(&app),
        m_app(app), m_testMode(testMode),
        m_settings(g_settings_new("org.gnome.desktop.input-sources")),
        m_keyboardSettings(g_settings_new("org.gnome.desktop.peripherals.keyboard")),
        m_context(xkb_context_new(XKB_CONTEXT_NO_FLAGS), xkb_context_unref),
        m_sourcePath(QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation)
            + QStringLiteral("/zhyprbola/input-source")) {
        if (!m_context || !loadLayout()) return;
        m_repeatTimer.setSingleShot(true);
        m_repeatTimer.setTimerType(Qt::PreciseTimer);
        connect(&m_repeatTimer, &QTimer::timeout, this, [this] { repeatHeldKey(); });
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
        g_object_unref(m_keyboardSettings);
    }

    bool ready() const { return m_ready; }

    void selfTest() {
        m_sourcePath.clear();
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

    void selfTestStateRecovery() {
        m_sourcePath.clear();
        Device first{-1, nullptr, {}, false};
        Device second{-1, nullptr, {}, false};
        const auto key = [this](Device &device, quint16 code, qint32 value) {
            input_event event = {};
            event.type = EV_KEY;
            event.code = code;
            event.value = value;
            if (value == 2) keyEvent(event, &device.pressed); // Synthetic repeat.
            else deviceEvent(device, event);
        };
        const auto scenario = [](const char *name) {
            send({{QStringLiteral("type"), QStringLiteral("scenario")},
                {QStringLiteral("name"), QString::fromLatin1(name)}});
        };
        const auto letter = [&key, &first] {
            key(first, KEY_A, 1);
            key(first, KEY_A, 0);
        };
        scenario("duplicate-super");
        key(first, KEY_LEFTMETA, 1);
        key(first, KEY_LEFTMETA, 1);
        key(first, KEY_LEFTMETA, 0);
        letter();
        scenario("two-keyboards");
        key(first, KEY_LEFTMETA, 1);
        key(second, KEY_LEFTMETA, 1);
        key(first, KEY_LEFTMETA, 0);
        letter();
        key(second, KEY_LEFTMETA, 0);
        letter();
        scenario("layout-switch-with-shift");
        key(first, KEY_LEFTSHIFT, 1);
        letter();
        m_testLayout = 1;
        letter();
        m_testLayout = 0;
        key(first, KEY_LEFTSHIFT, 0);
        letter();
        scenario("missed-release");
        key(first, KEY_LEFTCTRL, 1);
        key(first, KEY_LEFTSHIFT, 1);
        reconcilePressed(first, {});
        letter();
        scenario("disconnect");
        key(second, KEY_LEFTMETA, 1);
        reconcilePressed(second, {});
        letter();
        scenario("startup-held-key");
        reconcilePressed(first, {KEY_LEFTSHIFT});
        letter();
        key(first, KEY_LEFTSHIFT, 0);
        letter();
        scenario("caps-led");
        input_event led = {};
        led.type = EV_LED;
        led.code = LED_CAPSL;
        led.value = 1;
        deviceEvent(first, led);
        letter();
        led.value = 0;
        deviceEvent(first, led);
        letter();
        scenario("held-key-repeat");
        key(first, KEY_A, 1);
        key(first, KEY_A, 2);
        key(first, KEY_A, 2);
        key(first, KEY_A, 0);
        key(first, KEY_A, 2); // Ignore stray repeats after release.
        key(first, KEY_LEFTSHIFT, 1);
        key(first, KEY_A, 1);
        key(first, KEY_A, 2);
        key(first, KEY_A, 0);
        key(first, KEY_LEFTSHIFT, 2); // Modifiers must not repeat in XKB.
        key(first, KEY_LEFTSHIFT, 0);
        letter();
        key(first, KEY_BACKSPACE, 1);
        key(first, KEY_BACKSPACE, 2);
        key(first, KEY_BACKSPACE, 0);
        scenario("dropped-events");
        input_event sync = {};
        sync.type = EV_SYN;
        sync.code = SYN_DROPPED;
        deviceEvent(first, sync);
        key(first, KEY_LEFTMETA, 1);
        key(first, KEY_CAPSLOCK, 1);
        key(first, KEY_A, 1);
        sync.code = SYN_REPORT;
        deviceEvent(first, sync);
        letter();
    }

    void selfTestEventOrder() {
        m_sourcePath.clear();
        int first[2], second[2];
        if (pipe2(first, O_NONBLOCK | O_CLOEXEC) < 0) return;
        if (pipe2(second, O_NONBLOCK | O_CLOEXEC) < 0) {
            ::close(first[0]);
            ::close(first[1]);
            return;
        }
        m_devices.insert(QStringLiteral("first"), {first[0], nullptr, {}, false});
        m_devices.insert(QStringLiteral("second"), {second[0], nullptr, {}, false});
        qint64 timestamp = 0;
        const auto enqueue = [&timestamp](int fd, quint16 code, int value) {
            input_event event = {};
            event.type = EV_KEY;
            event.code = code;
            event.value = value;
            event.input_event_sec = 1;
            event.input_event_usec = timestamp++;
            if (::write(fd, &event, sizeof(event)) != sizeof(event))
                qFatal("Could not queue a keyboard event for the ordering test");
        };
        const QString alphabet = QStringLiteral("abcdefghijklmnopqrstuvwxyz");
        const quint16 codes[] = {KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F,
            KEY_G, KEY_H, KEY_I, KEY_J, KEY_K, KEY_L, KEY_M, KEY_N, KEY_O,
            KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T, KEY_U, KEY_V, KEY_W, KEY_X,
            KEY_Y, KEY_Z};
        const QString text = QStringLiteral("develop become at the word");
        for (int i = 0; i < text.size(); ++i) {
            const quint16 code = text[i] == QLatin1Char(' ') ? KEY_SPACE
                : codes[alphabet.indexOf(text[i])];
            const int fd = i % 2 ? second[1] : first[1];
            enqueue(fd, code, 1);
            enqueue(fd, code, 2); // Kernel repeats are not compositor repeats.
            enqueue(fd, code, 0);
        }
        readDevices();
        enqueue(first[1], KEY_LEFTSHIFT, 1);
        enqueue(second[1], KEY_A, 1);
        enqueue(second[1], KEY_A, 0);
        enqueue(first[1], KEY_LEFTSHIFT, 0);
        readDevices();
        // A mirrored key-down must produce one character, but two genuine
        // consecutive taps of the same letter must both appear.
        enqueue(first[1], KEY_A, 1);
        enqueue(second[1], KEY_A, 1);
        enqueue(first[1], KEY_A, 0);
        enqueue(second[1], KEY_A, 0);
        enqueue(first[1], KEY_A, 1);
        enqueue(first[1], KEY_A, 0);
        readDevices();
        reconcileSnapshot(m_devices[QStringLiteral("first")], {KEY_B}, false);
        enqueue(first[1], KEY_B, 1);
        enqueue(first[1], KEY_B, 0);
        readDevices();
        ::close(first[1]);
        ::close(second[1]);
        readDevices();
    }

    void selfTestRepeatTiming() {
        m_sourcePath.clear();
        g_settings_set_uint(m_keyboardSettings, "delay", 20);
        g_settings_set_uint(m_keyboardSettings, "repeat-interval", 5);
        g_settings_set_boolean(m_keyboardSettings, "repeat", true);
        m_testMode = false;
        input_event event = {};
        event.type = EV_KEY;
        event.code = KEY_A;
        event.value = 1;
        keyEvent(event);
        QEventLoop loop;
        const auto wait = [&loop](int milliseconds) {
            QTimer::singleShot(milliseconds, &loop, &QEventLoop::quit);
            loop.exec();
        };
        wait(50);
        event.code = KEY_B;
        keyEvent(event); // Only the latest repeatable key may repeat.
        wait(50);
        event.value = 0;
        keyEvent(event);
        wait(25); // Releasing B must not resume A, which is still held.
        event.code = KEY_A;
        keyEvent(event);
        g_settings_set_boolean(m_keyboardSettings, "repeat", false);
        event.code = KEY_C;
        event.value = 1;
        keyEvent(event);
        wait(30);
        event.value = 0;
        keyEvent(event);
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
        m_textState = XkbState(xkb_state_new(m_keymap.get()), xkb_state_unref);
        return bool(m_state) && bool(m_textState);
    }

    void syncLayout() {
        while (g_main_context_iteration(nullptr, false)) {}
        const xkb_layout_index_t count = xkb_keymap_num_layouts(m_keymap.get());
        if (!count) return;
        xkb_layout_index_t selected = std::min(m_testMode ? m_testLayout
            : g_settings_get_uint(m_settings, "current"), count - 1);
        QFile sourceFile(m_sourcePath);
        if (!m_sourcePath.isEmpty() && sourceFile.open(QIODevice::ReadOnly)) {
            const int index = m_sourceIds.indexOf(
                QString::fromUtf8(sourceFile.readAll().trimmed()));
            if (index >= 0 && xkb_layout_index_t(index) < count)
                selected = xkb_layout_index_t(index);
        }
        xkb_state_update_mask(m_textState.get(),
            xkb_state_serialize_mods(m_state.get(), XKB_STATE_MODS_DEPRESSED),
            xkb_state_serialize_mods(m_state.get(), XKB_STATE_MODS_LATCHED),
            lockedModifiers(),
            0, 0, selected);
    }

    xkb_mod_mask_t lockedModifiers() const {
        xkb_mod_mask_t locked = xkb_state_serialize_mods(m_state.get(), XKB_STATE_MODS_LOCKED);
        const auto applyLed = [this, &locked](const char *name, int value) {
            const auto index = xkb_keymap_mod_get_index(m_keymap.get(), name);
            if (value < 0 || index == XKB_MOD_INVALID) return;
            const xkb_mod_mask_t mask = xkb_mod_mask_t(1) << index;
            locked = value ? locked | mask : locked & ~mask;
        };
        applyLed(XKB_MOD_NAME_CAPS, m_capsLock);
        applyLed(XKB_MOD_NAME_NUM, m_numLock);
        return locked;
    }

    // Each physical device owns its pressed keys. XKB sees only the first
    // press and last release of a key shared by multiple devices.
    bool updatePressed(QSet<quint16> &pressed, quint16 key, bool down) {
        if (pressed.contains(key) == down) return false;
        if (down) {
            pressed.insert(key);
            if (++m_keyCounts[key] == 1)
                xkb_state_update_key(m_state.get(), key + 8, XKB_KEY_DOWN);
        } else {
            pressed.remove(key);
            if (--m_keyCounts[key] == 0) {
                m_keyCounts.remove(key);
                xkb_state_update_key(m_state.get(), key + 8, XKB_KEY_UP);
                if (m_repeatKey == key) {
                    m_repeatKey = -1;
                    m_repeatTimer.stop();
                }
            }
        }
        return true;
    }

    void keyEvent(const input_event &event, QSet<quint16> *devicePressed = nullptr) {
        if (event.type != EV_KEY || event.code > KEY_MAX
            || event.value < 0 || event.value > 2) return;
        auto &pressed = devicePressed ? *devicePressed : m_testPressed;
        if (event.value == 2) {
            // Repeats produce display events without another XKB key-down:
            // the physical key is already held and must only be released once.
            if (!m_keyCounts.contains(event.code)
                || !xkb_keymap_key_repeats(m_keymap.get(), event.code + 8)) return;
        } else {
            const bool wasDown = m_keyCounts.contains(event.code);
            if (!updatePressed(pressed, event.code, event.value == 1)) return;
            // Mirrored interfaces represent a single logical key-down.
            if (event.value == 1 && wasDown) return;
            if (event.value == 1 && xkb_keymap_key_repeats(m_keymap.get(), event.code + 8)) {
                m_repeatKey = event.code;
                m_repeatDeadline = monotonicMilliseconds()
                    + std::max(1u, g_settings_get_uint(m_keyboardSettings, "delay"));
                if (!m_testMode && g_settings_get_boolean(m_keyboardSettings, "repeat"))
                    m_repeatTimer.start(int(std::max(1u,
                        g_settings_get_uint(m_keyboardSettings, "delay"))));
            }
        }
        syncLayout();
        const xkb_keycode_t code = event.code + 8;
        const xkb_keysym_t sym = xkb_state_key_get_one_sym(m_textState.get(), code);
        char name[128] = {};
        xkb_keysym_get_name(sym, name, sizeof(name));
        if (event.value == 0) {
            send({{QStringLiteral("type"), QStringLiteral("release")},
                {QStringLiteral("name"), QString::fromLatin1(name)}});
            return;
        }
        const int size = xkb_state_key_get_utf8(m_textState.get(), code, nullptr, 0);
        QByteArray utf8(size + 1, '\0');
        if (size > 0)
            xkb_state_key_get_utf8(m_textState.get(), code, utf8.data(), size_t(utf8.size()));
        const auto active = [this](const char *modifier) {
            return xkb_state_mod_name_is_active(m_textState.get(), modifier,
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

    void syncLeds(int fd) {
        unsigned long leds[(LED_MAX + sizeof(unsigned long) * 8)
            / (sizeof(unsigned long) * 8)] = {};
        unsigned long supported[(LED_MAX + sizeof(unsigned long) * 8)
            / (sizeof(unsigned long) * 8)] = {};
        if (ioctl(fd, EVIOCGBIT(EV_LED, sizeof(supported)), supported) < 0
            || ioctl(fd, EVIOCGLED(sizeof(leds)), leds) < 0) return;
        if (hasKey(supported, LED_CAPSL)) m_capsLock = hasKey(leds, LED_CAPSL);
        if (hasKey(supported, LED_NUML)) m_numLock = hasKey(leds, LED_NUML);
    }

    void reconcilePressed(Device &device, const QSet<quint16> &current) {
        const auto previous = device.pressed;
        for (quint16 key : previous)
            if (!current.contains(key)) updatePressed(device.pressed, key, false);
        for (quint16 key : current)
            if (!previous.contains(key)) updatePressed(device.pressed, key, true);
    }

    void reconcileSnapshot(Device &device, QSet<quint16> current, bool includePresses) {
        // A live snapshot can include a new press whose event is still queued.
        // During routine repair, only remove released keys; inserting new ones
        // here would make the queued press look like a duplicate and lose text.
        if (!includePresses) current.intersect(device.pressed);
        reconcilePressed(device, current);
    }

    void syncDevice(Device &device, bool includePresses = true) {
        unsigned long keys[(KEY_MAX + sizeof(unsigned long) * 8)
            / (sizeof(unsigned long) * 8)] = {};
        if (ioctl(device.fd, EVIOCGKEY(sizeof(keys)), keys) < 0) return;
        QSet<quint16> current;
        for (quint16 key = 0; key <= KEY_MAX; ++key)
            if (hasKey(keys, key)) current.insert(key);
        reconcileSnapshot(device, current, includePresses);
        syncLeds(device.fd);
    }

    void deviceEvent(Device &device, const input_event &event) {
        if (event.type == EV_SYN && event.code == SYN_DROPPED) {
            device.dropped = true;
            return;
        }
        if (device.dropped) {
            if (event.type == EV_SYN && event.code == SYN_REPORT) {
                syncDevice(device);
                device.dropped = false;
            }
            return;
        }
        if (event.type == EV_LED) {
            if (event.code == LED_CAPSL) m_capsLock = event.value != 0;
            if (event.code == LED_NUML) m_numLock = event.value != 0;
        }
        // Wayland clients repeat using the compositor settings, not the
        // independent EV_KEY value=2 repeat stream supplied by the kernel.
        if (event.type == EV_KEY && event.value == 2) return;
        keyEvent(event, &device.pressed);
    }

    void processPending(QVector<PendingEvent> &pending) {
        std::stable_sort(pending.begin(), pending.end(), [](const auto &a, const auto &b) {
            if (a.event.input_event_sec != b.event.input_event_sec)
                return a.event.input_event_sec < b.event.input_event_sec;
            return a.event.input_event_usec < b.event.input_event_usec;
        });
        for (const auto &item : pending) {
            auto device = m_devices.find(item.path);
            if (device != m_devices.end()) deviceEvent(device.value(), item.event);
        }
    }

    void readDevices(bool repair = false) {
        QVector<PendingEvent> pending;
        QStringList disconnected;
        // All streams must be drained before any event is translated or any
        // snapshot is taken. Notifier activation order is not keypress order.
        for (auto it = m_devices.begin(); it != m_devices.end(); ++it) {
            input_event event;
            ssize_t bytes;
            do {
                bytes = ::read(it->fd, &event, sizeof(event));
                if (bytes == sizeof(event)) pending.append({it.key(), event});
            } while (bytes == sizeof(event) || (bytes < 0 && errno == EINTR));
            if (bytes == 0 || (bytes < 0 && errno != EAGAIN))
                disconnected.append(it.key());
        }
        processPending(pending);
        for (const QString &path : disconnected) {
            auto device = m_devices.take(path);
            reconcilePressed(device, {});
            if (device.notifier) device.notifier->deleteLater();
            ::close(device.fd);
        }
        if (repair) {
            for (auto &device : m_devices)
                if (!device.dropped) syncDevice(device, false);
        }
    }

    void repeatHeldKey() {
        // A release or another press may already be queued when the timer fires.
        readDevices();
        if (m_repeatKey < 0 || !g_settings_get_boolean(m_keyboardSettings, "repeat")) return;
        const qint64 remaining = m_repeatDeadline - monotonicMilliseconds();
        if (remaining > 0) {
            m_repeatTimer.start(int(remaining));
            return;
        }
        input_event event = {};
        event.type = EV_KEY;
        event.code = quint16(m_repeatKey);
        event.value = 2;
        keyEvent(event);
        const int interval = int(std::max(1u,
            g_settings_get_uint(m_keyboardSettings, "repeat-interval")));
        m_repeatDeadline = monotonicMilliseconds() + interval;
        m_repeatTimer.start(interval);
    }

    void scanDevices() {
        readDevices(true);
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
            connect(notifier, &QSocketNotifier::activated, this, [this] {
                readDevices();
            });
            m_devices.insert(path, {fd, notifier, {}, false});
            syncDevice(m_devices[path]);
        }
    }

    QCoreApplication &m_app;
    bool m_testMode;
    unsigned int m_testLayout = 0;
    GSettings *m_settings;
    GSettings *m_keyboardSettings;
    XkbContext m_context;
    XkbKeymap m_keymap{nullptr, xkb_keymap_unref};
    XkbState m_state{nullptr, xkb_state_unref};
    XkbState m_textState{nullptr, xkb_state_unref};
    QHash<quint16, int> m_keyCounts;
    QSet<quint16> m_testPressed;
    int m_capsLock = -1;
    int m_numLock = -1;
    QStringList m_sourceIds;
    QString m_sourcePath;
    QHash<QString, Device> m_devices;
    QTimer m_scanTimer;
    QTimer m_repeatTimer;
    int m_repeatKey = -1;
    qint64 m_repeatDeadline = 0;
    bool m_ready = false;
};
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    const bool sourceSwitchTest = app.arguments().contains(
        QStringLiteral("--self-test-source-switch"));
    const bool stateRecoveryTest = app.arguments().contains(
        QStringLiteral("--self-test-state-recovery"));
    const bool eventOrderTest = app.arguments().contains(QStringLiteral("--self-test-event-order"));
    const bool repeatTimingTest = app.arguments().contains(QStringLiteral("--self-test-repeat-timing"));
    const bool testMode = sourceSwitchTest || stateRecoveryTest || eventOrderTest
        || repeatTimingTest || app.arguments().contains(
        QStringLiteral("--self-test"));
    if (testMode) qputenv("GSETTINGS_BACKEND", "memory");
    Capture capture(app, testMode);
    if (!capture.ready()) {
        qWarning("No readable keyboard devices or XKB layout for key capture");
        return 1;
    }
    if (testMode) {
        if (eventOrderTest) capture.selfTestEventOrder();
        else if (repeatTimingTest) capture.selfTestRepeatTiming();
        else if (stateRecoveryTest) capture.selfTestStateRecovery();
        else if (sourceSwitchTest) capture.selfTestSourceSwitch();
        else capture.selfTest();
        return 0;
    }
    return app.exec();
}
