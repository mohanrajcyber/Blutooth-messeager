import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/contact.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  static const _version = 2;

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
      version: _version,
      onCreate: _createAll,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _createAll(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        peer_id TEXT NOT NULL UNIQUE,
        peer_name TEXT NOT NULL,
        last_message TEXT,
        unread_count INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        is_group INTEGER NOT NULL DEFAULT 0,
        wallpaper TEXT,
        bubble_color TEXT
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
        reply_to_id TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        expires_at INTEGER,
        forwarded_from TEXT
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
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        peer_id TEXT,
        avatar_path TEXT,
        last_seen INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE blocked_users (peer_id TEXT PRIMARY KEY)
    ''');
    await db.execute('''
      CREATE TABLE statuses (
        id TEXT PRIMARY KEY,
        body TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'text',
        media_path TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE messages ADD COLUMN reply_to_id TEXT',
      );
      await db.execute(
        'ALTER TABLE messages ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE messages ADD COLUMN expires_at INTEGER');
      await db.execute(
        'ALTER TABLE messages ADD COLUMN forwarded_from TEXT',
      );
      await db.execute(
        'ALTER TABLE conversations ADD COLUMN is_group INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE conversations ADD COLUMN wallpaper TEXT');
      await db.execute(
        'ALTER TABLE conversations ADD COLUMN bubble_color TEXT',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS contacts (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT NOT NULL,
          peer_id TEXT,
          avatar_path TEXT,
          last_seen INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS blocked_users (peer_id TEXT PRIMARY KEY)
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS statuses (
          id TEXT PRIMARY KEY,
          body TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'text',
          media_path TEXT,
          created_at INTEGER NOT NULL,
          expires_at INTEGER NOT NULL
        )
      ''');
    }
  }

  Future<List<Conversation>> getConversations() async {
    final db = await database;
    final rows = await db.query('conversations', orderBy: 'updated_at DESC');
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
      where: 'conversation_id = ? AND is_deleted = 0',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Message.fromMap).toList();
  }

  Future<List<Message>> searchMessages(String conversationId, String query) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ? AND is_deleted = 0 AND body LIKE ?',
      whereArgs: [conversationId, '%$query%'],
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
    await db.update('messages', updates, where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> deleteMessage(String messageId, {bool soft = true}) async {
    final db = await database;
    if (soft) {
      await db.update(
        'messages',
        {'is_deleted': 1, 'body': ''},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } else {
      await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
    }
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

  Future<List<Map<String, dynamic>>> getPendingOutbox() async {
    final db = await database;
    return db.query(
      'outbox',
      where: 'next_retry <= ?',
      whereArgs: [DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<void> removeFromOutbox(String messageId) async {
    final db = await database;
    await db.delete('outbox', where: 'message_id = ?', whereArgs: [messageId]);
  }

  Future<void> bumpOutboxRetry(String messageId) async {
    final db = await database;
    final rows = await db.query(
      'outbox',
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final retry = (rows.first['retry_count'] as int) + 1;
    await db.update(
      'outbox',
      {
        'retry_count': retry,
        'next_retry':
            DateTime.now().add(Duration(seconds: retry * 5)).millisecondsSinceEpoch,
      },
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  // Contacts
  Future<List<SavedContact>> getContacts() async {
    final db = await database;
    final rows = await db.query('contacts', orderBy: 'name ASC');
    return rows.map(SavedContact.fromMap).toList();
  }

  Future<void> saveContact(SavedContact contact) async {
    final db = await database;
    await db.insert(
      'contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteContact(String id) async {
    final db = await database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  // Blocked
  Future<bool> isBlocked(String peerId) async {
    final db = await database;
    final rows = await db.query(
      'blocked_users',
      where: 'peer_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> blockUser(String peerId) async {
    final db = await database;
    await db.insert(
      'blocked_users',
      {'peer_id': peerId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> unblockUser(String peerId) async {
    final db = await database;
    await db.delete('blocked_users', where: 'peer_id = ?', whereArgs: [peerId]);
  }

  // Status stories
  Future<List<StatusStory>> getActiveStatuses() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'statuses',
      where: 'expires_at > ?',
      whereArgs: [now],
      orderBy: 'created_at DESC',
    );
    return rows.map(StatusStory.fromMap).toList();
  }

  Future<void> saveStatus(StatusStory status) async {
    final db = await database;
    await db.insert(
      'statuses',
      status.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> purgeExpiredMessages() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'messages',
      {'is_deleted': 1},
      where: 'expires_at IS NOT NULL AND expires_at <= ?',
      whereArgs: [now],
    );
    await db.delete(
      'statuses',
      where: 'expires_at <= ?',
      whereArgs: [now],
    );
  }

  Future<String> exportBackupJson() async {
    final db = await database;
    final conversations = await db.query('conversations');
    final messages = await db.query('messages');
    final contacts = await db.query('contacts');
    return jsonEncode({
      'version': _version,
      'exported_at': DateTime.now().toIso8601String(),
      'conversations': conversations,
      'messages': messages,
      'contacts': contacts,
    });
  }

  Future<void> importBackupJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final db = await database;
    final batch = db.batch();
    for (final row in (data['conversations'] as List? ?? [])) {
      batch.insert(
        'conversations',
        Map<String, dynamic>.from(row as Map),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final row in (data['messages'] as List? ?? [])) {
      batch.insert(
        'messages',
        Map<String, dynamic>.from(row as Map),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final row in (data['contacts'] as List? ?? [])) {
      batch.insert(
        'contacts',
        Map<String, dynamic>.from(row as Map),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
