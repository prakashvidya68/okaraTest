import 'dart:async';
import 'dart:convert';
import 'package:okara/models/chat_session.dart';
import 'package:okara/models/comparison_message.dart';
import 'package:okara/models/message.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('okara_chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Chat sessions table
    await db.execute('''
      CREATE TABLE chat_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sessionId TEXT NOT NULL,
        content TEXT NOT NULL,
        role TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        provider TEXT,
        promptTokens INTEGER,
        completionTokens INTEGER,
        totalTokens INTEGER,
        estimatedCost REAL,
        responseTimeMs INTEGER,
        FOREIGN KEY (sessionId) REFERENCES chat_sessions (id) ON DELETE CASCADE
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_messages_sessionId ON messages(sessionId)
    ''');

    // Comparison messages table
    await db.execute('''
      CREATE TABLE comparison_messages (
        id TEXT PRIMARY KEY,
        sessionId TEXT NOT NULL,
        userQuery TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        responses TEXT NOT NULL,
        FOREIGN KEY (sessionId) REFERENCES chat_sessions (id) ON DELETE CASCADE
      )
    ''');

    // Create index for comparison messages
    await db.execute('''
      CREATE INDEX idx_comparison_messages_sessionId ON comparison_messages(sessionId)
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add comparison messages table for version 2
      await db.execute('''
        CREATE TABLE comparison_messages (
          id TEXT PRIMARY KEY,
          sessionId TEXT NOT NULL,
          userQuery TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          responses TEXT NOT NULL,
          FOREIGN KEY (sessionId) REFERENCES chat_sessions (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_comparison_messages_sessionId ON comparison_messages(sessionId)
      ''');
    }

    if (oldVersion < 3) {
      // Add responseTimeMs column to messages table for version 3
      await db.execute('''
        ALTER TABLE messages ADD COLUMN responseTimeMs INTEGER
      ''');
    }
  }

  // Chat Session Operations
  Future<ChatSession> createSession(ChatSession session) async {
    final db = await database;
    await db.insert('chat_sessions', session.toMap());
    return session;
  }

  Future<List<ChatSession>> getAllSessions() async {
    final db = await database;
    final result = await db.query('chat_sessions', orderBy: 'updatedAt DESC');
    return result.map((json) => ChatSession.fromMap(json)).toList();
  }

  Future<ChatSession?> getSession(String id) async {
    final db = await database;
    final maps = await db.query(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ChatSession.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateSession(ChatSession session) async {
    final db = await database;
    await db.update(
      'chat_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('chat_sessions', where: 'id = ?', whereArgs: [id]);
  }

  // Message Operations
  Future<void> saveMessage(Message message, String sessionId) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(sessionId: sessionId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update session's updatedAt timestamp
    final session = await getSession(sessionId);
    if (session != null) {
      await updateSession(session.copyWith(updatedAt: DateTime.now()));
    }
  }

  Future<List<Message>> getMessages(String sessionId) async {
    final db = await database;
    final result = await db.query(
      'messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return result.map((json) => Message.fromMap(json)).toList();
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearSessionMessages(String sessionId) async {
    final db = await database;
    await db.delete('messages', where: 'sessionId = ?', whereArgs: [sessionId]);
  }

  // Comparison Message Operations
  Future<void> saveComparisonMessage(
    ComparisonMessage message,
    String sessionId,
  ) async {
    final db = await database;
    final map = message.toMap(sessionId: sessionId);

    // Convert responses list to JSON string for storage
    map['responses'] = jsonEncode(map['responses']);

    await db.insert(
      'comparison_messages',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update session's updatedAt timestamp
    final session = await getSession(sessionId);
    if (session != null) {
      await updateSession(session.copyWith(updatedAt: DateTime.now()));
    }
  }

  Future<List<ComparisonMessage>> getComparisonMessages(
    String sessionId,
  ) async {
    final db = await database;
    final result = await db.query(
      'comparison_messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return result.map((json) {
      // Parse JSON string back to list
      final map = Map<String, dynamic>.from(json);
      map['responses'] = jsonDecode(json['responses'] as String);
      return ComparisonMessage.fromMap(map);
    }).toList();
  }

  Future<void> deleteComparisonMessage(String id) async {
    final db = await database;
    await db.delete('comparison_messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearSessionComparisonMessages(String sessionId) async {
    final db = await database;
    await db.delete(
      'comparison_messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  // Analytics Operations
  Future<Map<String, dynamic>> getAllMessagesStats() async {
    final db = await database;

    // Get stats from regular messages
    final messagesResult = await db.rawQuery('''
      SELECT 
        provider,
        COUNT(*) as totalRequests,
        SUM(totalTokens) as totalTokens,
        SUM(estimatedCost) as totalCost,
        SUM(responseTimeMs) as totalResponseTimeMs
      FROM messages
      WHERE role = 'assistant' AND provider IS NOT NULL AND totalTokens IS NOT NULL
      GROUP BY provider
    ''');

    // Get comparison messages to extract provider data
    final comparisonResult = await db.query('comparison_messages');

    // Parse comparison messages and aggregate by provider
    final Map<String, Map<String, dynamic>> aggregatedStats = {};

    // First, add regular message stats
    for (final row in messagesResult) {
      final provider = row['provider'] as String;
      aggregatedStats[provider] = {
        'provider': provider,
        'totalRequests': row['totalRequests'] as int,
        'totalTokens': row['totalTokens'] as int? ?? 0,
        'totalCost': row['totalCost'] as double? ?? 0.0,
        'totalResponseTimeMs': row['totalResponseTimeMs'] as int? ?? 0,
      };
    }

    // Then, add comparison message stats
    for (final compRow in comparisonResult) {
      final responsesJson = compRow['responses'] as String;
      final List<dynamic> responses = jsonDecode(responsesJson);

      for (final response in responses) {
        final provider = response['provider'] as String;
        final responseTimeMs = response['responseTimeMs'] as int? ?? 0;
        final totalTokens = response['totalTokens'] as int? ?? 0;
        final estimatedCost = response['estimatedCost'] as double? ?? 0.0;

        if (aggregatedStats.containsKey(provider)) {
          aggregatedStats[provider]!['totalRequests'] =
              (aggregatedStats[provider]!['totalRequests'] as int) + 1;
          aggregatedStats[provider]!['totalResponseTimeMs'] =
              (aggregatedStats[provider]!['totalResponseTimeMs'] as int) +
              responseTimeMs;
          aggregatedStats[provider]!['totalTokens'] =
              (aggregatedStats[provider]!['totalTokens'] as int) + totalTokens;
          aggregatedStats[provider]!['totalCost'] =
              (aggregatedStats[provider]!['totalCost'] as double) +
              estimatedCost;
        } else {
          aggregatedStats[provider] = {
            'provider': provider,
            'totalRequests': 1,
            'totalTokens': totalTokens,
            'totalCost': estimatedCost,
            'totalResponseTimeMs': responseTimeMs,
          };
        }
      }
    }

    return {'providers': aggregatedStats.values.toList()};
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
