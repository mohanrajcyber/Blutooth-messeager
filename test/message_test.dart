import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_messenger/models/message.dart';

void main() {
  test('Message serializes to and from map', () {
    final now = DateTime(2026, 1, 15, 10, 30);
    final message = Message(
      id: 'abc-123',
      conversationId: 'peer-1',
      body: 'Hello over Bluetooth',
      isOutgoing: true,
      status: MessageStatus.sent,
      createdAt: now,
      sentAt: now,
    );

    final restored = Message.fromMap(message.toMap());

    expect(restored.id, message.id);
    expect(restored.body, message.body);
    expect(restored.status, MessageStatus.sent);
    expect(restored.isOutgoing, isTrue);
  });
}
