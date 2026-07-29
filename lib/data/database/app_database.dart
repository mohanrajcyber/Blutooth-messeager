import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/conversation.dart';
import '../../models/message.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'bt_messenger.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            peer_id TEXT NOT NULL UNIQUE,
            peer_name TEXT NOT NULL,
            last_message TEXT,
            unread_count INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            body TEXT NOT NULL,
            is_outgoing INTEGER NOT NULL,
            status INTEGER NOT NULL,
            type INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            sent_at INTEGER,
            delivered_at INTEGER,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at)',
        );
        await db.execute('''
          CREATE TABLE outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message_id TEXT NOT NULL UNIQUE,
            peer_id TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            next_retry INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<List<Conversation>> getConversations() async {
    final db = await database;
    final rows = await db.query(
      'conversations',
      orderBy: 'updated_at DESC',
    );
    return rows.map(Conversation.fromMap).toList();
  }

  Future<Conversation?> getConversationByPeerId(String peerId) async {
    final db = await database;
    final rows = await db.query(
      'conversations',
      where: 'peer_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Conversation.fromMap(rows.first);
  }

  Future<void> upsertConversation(Conversation conversation) async {
    final db = await database;
    await db.insert(
      'conversations',
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Message.fromMap).toList();
  }

  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status, {
    DateTime? sentAt,
    DateTime? deliveredAt,
  }) async {
    final db = await database;
    final updates = <String, Object?>{'status': status.index};
    if (sentAt != null) updates['sent_at'] = sentAt.millisecondsSinceEpoch;
    if (deliveredAt != null) {
      updates['delivered_at'] = deliveredAt.millisecondsSinceEpoch;
    }
    await db.update(
      'messages',
      updates,
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markConversationRead(String conversationId) async {
    final db = await database;
    await db.update(
      'conversations',
      {'unread_count': 0},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> enqueueOutbox(String messageId, String peerId) async {
    final db = await database;
    await db.insert('outbox', {
      'message_id': messageId,
      'peer_id': peerId,
      'retry_count': 0,
      'next_retry': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> removeFromOutbox(String messageId) async {
    final db = await database;
    await db.delete(
      'outbox',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }
}
