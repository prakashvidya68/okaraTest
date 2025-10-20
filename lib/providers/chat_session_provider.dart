import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okara/models/chat_session.dart';
import 'package:okara/services/database_service.dart';
import 'package:uuid/uuid.dart';

// Provider for the list of all chat sessions
final chatSessionsProvider =
    NotifierProvider<ChatSessionsNotifier, List<ChatSession>>(
      ChatSessionsNotifier.new,
    );

// Provider for the current active session
final currentSessionProvider =
    NotifierProvider<CurrentSessionNotifier, ChatSession?>(
      CurrentSessionNotifier.new,
    );

class ChatSessionsNotifier extends Notifier<List<ChatSession>> {
  final _uuid = const Uuid();
  final _db = DatabaseService.instance;

  @override
  List<ChatSession> build() {
    _loadSessions();
    return [];
  }

  Future<void> _loadSessions() async {
    final sessions = await _db.getAllSessions();
    state = sessions;
  }

  Future<ChatSession> createNewSession({String? title}) async {
    final now = DateTime.now();

    // Generate smart default title if not provided
    String finalTitle;
    if (title != null) {
      finalTitle = title;
    } else {
      finalTitle = _generateDefaultTitle();
    }

    final session = ChatSession(
      id: _uuid.v4(),
      title: finalTitle,
      createdAt: now,
      updatedAt: now,
    );

    await _db.createSession(session);
    state = [session, ...state];
    return session;
  }

  String _generateDefaultTitle() {
    // Check if "New Chat" exists
    if (!state.any((s) => s.title == 'New Chat')) {
      return 'New Chat';
    }

    // Find the next available number
    int maxNumber = 0;
    final pattern = RegExp(r'^New Chat (\d+)$');

    for (final session in state) {
      final match = pattern.firstMatch(session.title);
      if (match != null) {
        final number = int.parse(match.group(1)!);
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    return 'New Chat ${maxNumber + 1}';
  }

  Future<void> updateSessionTitle(String sessionId, String newTitle) async {
    final session = state.firstWhere((s) => s.id == sessionId);
    final updated = session.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );

    await _db.updateSession(updated);
    state = state.map((s) => s.id == sessionId ? updated : s).toList();
  }

  Future<void> deleteSession(String sessionId) async {
    await _db.deleteSession(sessionId);
    state = state.where((s) => s.id != sessionId).toList();
  }

  Future<void> refreshSessions() async {
    await _loadSessions();
  }
}

class CurrentSessionNotifier extends Notifier<ChatSession?> {
  @override
  ChatSession? build() {
    return null;
  }

  void setSession(ChatSession session) {
    state = session;
  }

  void clearSession() {
    state = null;
  }
}
