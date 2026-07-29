# Bluetooth Messenger

Offline peer-to-peer messaging for mobile and desktop over Bluetooth, with a WhatsApp-style interface.

## Features (v0.1)

- WhatsApp-inspired chat list and message bubbles
- Offline-first local SQLite storage
- Bluetooth LE device discovery and messaging
- Optimistic UI for low perceived latency
- Android and Windows desktop support

## Prerequisites

1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (3.16+)
2. Enable **Developer Mode** on Windows (required for symlink support)
3. For Android: enable USB debugging and grant Bluetooth/Location permissions

## Install on Android (GitHub APK)

No Play Store needed. Use GitHub Releases:

1. Open the latest release page:
   `https://github.com/mohanrajcyber/Blutooth-messeager/releases/latest`
2. Download **app-release.apk**
3. Install on Android (enable "Install unknown apps" if asked)

See [docs/INSTALL_ANDROID.md](docs/INSTALL_ANDROID.md) for step-by-step phone setup.

### Publish a new APK (maintainers)

```bash
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions builds the APK and attaches it to the release automatically.

## Quick start (Windows)

1. Install Flutter: https://docs.flutter.dev/get-started/install/windows
2. Open a terminal in this folder and run:

```powershell
.\tool\setup.ps1
```

Or manually:

```bash
flutter create . --project-name bluetooth_messenger --platforms=android,windows
flutter pub get
flutter run -d windows
```

3. For Android, merge permissions from `tool/AndroidManifest.permissions.xml` into `android/app/src/main/AndroidManifest.xml`

## Run

```bash
# Windows desktop
flutter run -d windows

# Android (device or emulator with Bluetooth)
flutter run -d android
```

## Project structure

```
lib/
├── core/           Theme, colors, constants
├── models/         Message, Conversation, Peer
├── data/           SQLite database and repositories
├── services/       Bluetooth transport and messaging
├── providers/      Riverpod state management
├── screens/        Chat list, chat, nearby devices
└── widgets/        Reusable UI components
```

## Bluetooth notes

- **Android**: Requires Bluetooth + Nearby devices permissions (Android 12+)
- **Windows**: Uses BLE via flutter_blue_plus
- **iOS**: Limited in v0.1 — RFCOMM not available; Multipeer planned for later

## Next steps

- End-to-end encryption (Signal protocol)
- Bluetooth Classic RFCOMM for faster throughput on Android
- Media message chunking
- Group chat over mesh topology
