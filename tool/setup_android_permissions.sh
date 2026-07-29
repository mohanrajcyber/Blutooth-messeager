#!/usr/bin/env bash
# Run after `flutter create .` to add Bluetooth permissions on Android.

MANIFEST="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST" ]; then
  echo "Run 'flutter create .' first to generate platform folders."
  exit 1
fi

echo "Add these permissions to AndroidManifest.xml before <application>:"
cat << 'EOF'

    <!-- Bluetooth (Android 12+) -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />

EOF
