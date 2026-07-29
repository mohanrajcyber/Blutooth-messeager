/// Tamil + English UI strings.
class AppStrings {
  AppStrings(this.code);

  final String code;

  static final en = AppStrings('en');
  static final ta = AppStrings('ta');

  String get appName => _t('BT Messenger', 'BT Messenger');
  String get chats => _t('Chats', 'Chats');
  String get settings => _t('Settings', 'அமைப்புகள்');
  String get connectByCode => _t('Connect by code', 'Code மூலம் connect');
  String get bluetoothScan => _t('Bluetooth scan', 'Bluetooth scan');
  String get noInternet => _t('No internet required', 'Internet வேண்டாம்');
  String get typing => _t('typing…', 'typing…');
  String get online => _t('online', 'online');
  String get offline => _t('offline', 'offline');
  String get message => _t('Message', 'Message');
  String get copy => _t('Copy', 'Copy');
  String get reply => _t('Reply', 'Reply');
  String get delete => _t('Delete', 'Delete');
  String get forward => _t('Forward', 'Forward');
  String get search => _t('Search', 'Search');
  String get contacts => _t('Contacts', 'Contacts');
  String get groupChat => _t('Group chat', 'Group chat');
  String get status => _t('Status', 'Status');
  String get backup => _t('Backup & restore', 'Backup & restore');
  String get appLock => _t('App lock', 'App lock');
  String get darkTheme => _t('Dark theme', 'Dark theme');
  String get lightTheme => _t('Light theme', 'Light theme');
  String get language => _t('Language', 'மொழி');
  String get disappearing => _t('Disappearing messages (24h)', '24h messages');
  String get voiceCall => _t('Voice call', 'Voice call');
  String get videoCall => _t('Video call', 'Video call');
  String get scanQr => _t('Scan QR code', 'QR scan');
  String get exitApp => _t('Exit app', 'Exit app');

  String _t(String en, String ta) => code == 'ta' ? ta : en;
}
