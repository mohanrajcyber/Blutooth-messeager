import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/chat_repository.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../services/bluetooth/bluetooth_service.dart';
import '../services/local/code_pairing_service.dart';
import '../services/messaging/message_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.watch(appDatabaseProvider));
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.watch(appDatabaseProvider));
});

final bluetoothServiceProvider = Provider<BluetoothService>((ref) {
  final service = BluetoothService();
  ref.onDispose(service.dispose);
  return service;
});

final codePairingServiceProvider = Provider<CodePairingService>((ref) {
  final service = CodePairingService();
  ref.onDispose(service.dispose);
  return service;
});

final messageServiceProvider = FutureProvider<MessageService>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  await db.database;

  final service = MessageService(
    bluetooth: ref.watch(bluetoothServiceProvider),
    codePairing: ref.watch(codePairingServiceProvider),
    messages: ref.watch(messageRepositoryProvider),
    conversations: ref.watch(conversationRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  ref.watch(messageRefreshProvider);
  return ref.watch(conversationRepositoryProvider).getAll();
});

final messageRefreshProvider = StateProvider<int>((ref) => 0);

final messagesProvider =
    FutureProvider.family<List<Message>, String>((ref, conversationId) async {
  ref.watch(messageRefreshProvider);
  return ref.watch(messageRepositoryProvider).getForConversation(conversationId);
});

final nearbyPeersProvider = StreamProvider<List<Peer>>((ref) {
  return ref.watch(bluetoothServiceProvider).peersStream;
});

final connectionStateProvider = StreamProvider<BluetoothConnectionState>((ref) {
  return ref.watch(bluetoothServiceProvider).connectionStream;
});
