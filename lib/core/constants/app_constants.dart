import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF075E54);
  static const primaryDark = Color(0xFF054640);
  static const accent = Color(0xFF25D366);
  static const chatBackground = Color(0xFFECE5DD);
  static const sentBubble = Color(0xFFDCF8C6);
  static const receivedBubble = Colors.white;
  static const headerBackground = Color(0xFF075E54);
  static const subtitle = Color(0xFF667781);
  static const tickBlue = Color(0xFF53BDEB);
  static const divider = Color(0xFFE9EDEF);
  static const darkBackground = Color(0xFF0B141A);
  static const darkHeader = Color(0xFF1F2C34);
  static const darkSurface = Color(0xFF111B21);
  static const darkInput = Color(0xFF1F2C34);
  static const darkSentBubble = Color(0xFF005C4B);
  static const darkReceivedBubble = Color(0xFF1F2C34);
  static const darkSubtitle = Color(0xFF8696A0);
  static const darkDivider = Color(0xFF222D34);
}

abstract final class AppConstants {
  static const appName = 'BT Messenger';
  static const bleServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const bleTxCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const bleRxCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
  static const maxBlePayload = 512;
  static const deviceNamePrefix = 'BTMsg-';
  static const legacyDeviceNamePrefix = 'BTMsg_';
  static const localPeerPrefix = 'local:';
  static const udpDiscoveryPort = 45678;
  static const tcpDiscoveryPort = 45679;
  static const tcpMessagePort = 45680;
}
