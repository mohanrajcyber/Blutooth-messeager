# Install BT Messenger on Android (GitHub APK)

## Download link

After a release is published, open:

```
https://github.com/YOUR_USERNAME/bluetooth-messenger/releases/latest
```

Download **app-release.apk** and install it on your phone.

## Phone setup

1. Open the APK download link in Chrome on your Android phone.
2. Tap **Download**.
3. Open the downloaded file.
4. If Android asks, allow **Install unknown apps** for Chrome/Files.
5. Tap **Install**.

## App permissions

When the app opens, allow:

- Bluetooth
- Nearby devices
- Location (required for Bluetooth scan on Android 12+)

## Bluetooth name (important)

For two devices to find each other:

1. Open app menu → **Set display name** (example: `Ravi`).
2. On Android, the phone should be discoverable as `BTMsg_Ravi`.
3. Both phones must have BT Messenger installed.
4. Open **Nearby devices** on both phones at the same time.

## Troubleshooting

| Problem | Fix |
|---|---|
| No devices found | Use 2 different phones, Bluetooth ON, stay on Nearby screen |
| Install blocked | Enable unknown sources for your browser |
| Scan empty | Grant Location + Bluetooth permissions |
