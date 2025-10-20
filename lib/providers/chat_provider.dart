import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okara/models/ai_provider.dart';
import 'package:okara/models/ai_request.dart';
import 'package:okara/models/comparison_message.dart';
import 'package:okara/models/message.dart';
import 'package:okara/models/usage_stats.dart';
import 'package:okara/providers/analytics_provider.dart';
import 'package:okara/providers/chat_session_provider.dart';
import 'package:okara/services/ai_service_factory.dart';
import 'package:okara/services/database_service.dart';
import 'package:uuid/uuid.dart';

final selectedProviderProvider =
    NotifierProvider<SelectedProviderNotifier, AIProvider>(
      SelectedProviderNotifier.new,
    );

class SelectedProviderNotifier extends Notifier<AIProvider> {
  @override
  AIProvider build() {
    return AIProvider.openai;
  }

  void setProvider(AIProvider provider) {
    state = provider;
  }
}

final messagesProvider = NotifierProvider<MessagesNotifier, List<Message>>(
  MessagesNotifier.new,
);

final comparisonMessagesProvider =
    NotifierProvider<ComparisonMessagesNotifier, List<ComparisonMessage>>(
      ComparisonMessagesNotifier.new,
    );

class MessagesNotifier extends Notifier<List<Message>> {
  final _uuid = const Uuid();
  final _db = DatabaseService.instance;
  String? _lastLoadedSessionId;

  @override
  List<Message> build() {
    // Watch current session and trigger load when it changes
    final currentSession = ref.watch(currentSessionProvider);

    // Only load if session actually changed
    if (currentSession != null && currentSession.id != _lastLoadedSessionId) {
      _lastLoadedSessionId = currentSession.id;
      Future.microtask(() => _loadMessages(currentSession.id));
    } else if (currentSession == null && _lastLoadedSessionId != null) {
      _lastLoadedSessionId = null;
      state = [];
    }

    return [];
  }

  Future<void> _loadMessages(String sessionId) async {
    final messages = await _db.getMessages(sessionId);
    state = messages;
  }

  Future<void> reloadMessages() async {
    final currentSession = ref.read(currentSessionProvider);
    if (currentSession != null) {
      await _loadMessages(currentSession.id);
    }
  }

  Future<void> addMessage(
    String content,
    MessageRole role, {
    AIProvider? provider,
    UsageStats? usage,
  }) async {
    final currentSession = ref.read(currentSessionProvider);
    if (currentSession == null) return;

    final message = Message(
      id: _uuid.v4(),
      content: content,
      role: role,
      timestamp: DateTime.now(),
      provider: provider,
      usage: usage,
    );

    state = [...state, message];

    // Save to database
    await _db.saveMessage(message, currentSession.id);

    // Auto-rename chat if this is the first user message and chat has default name
    if (role == MessageRole.user &&
        _isFirstUserMessage() &&
        _hasDefaultName(currentSession.title)) {
      final newTitle = _generateTitleFromMessage(content);
      await ref
          .read(chatSessionsProvider.notifier)
          .updateSessionTitle(currentSession.id, newTitle);
      // Update current session to reflect the new title
      ref
          .read(currentSessionProvider.notifier)
          .setSession(currentSession.copyWith(title: newTitle));
    }

    // Update session list to reflect updated timestamp
    await ref.read(chatSessionsProvider.notifier).refreshSessions();
  }

  bool _isFirstUserMessage() {
    return state.where((msg) => msg.role == MessageRole.user).length == 1;
  }

  bool _hasDefaultName(String title) {
    // Check if title is "New Chat" or "New Chat 1", "New Chat 2", etc.
    return title == 'New Chat' || RegExp(r'^New Chat \d+$').hasMatch(title);
  }

  String _generateTitleFromMessage(String message) {
    // Get first sentence or first 30 characters
    String title = message.trim();

    // Try to find first sentence
    final sentenceEnd = RegExp(r'[.!?]').firstMatch(title);
    if (sentenceEnd != null && sentenceEnd.start < 30) {
      title = title.substring(0, sentenceEnd.start);
    }

    // Limit to 30 characters
    if (title.length > 30) {
      title = title.substring(0, 30).trim();
      // Remove trailing incomplete word if cut off
      final lastSpace = title.lastIndexOf(' ');
      if (lastSpace > 15) {
        title = title.substring(0, lastSpace);
      }
      title = '$title...';
    }

    return title;
  }

  Future<void> sendStreamingMessage(String prompt, AIProvider provider) async {
    await addMessage(prompt, MessageRole.user);

    final messageId = _uuid.v4();
    final assistantMessage = Message(
      id: messageId,
      content: '',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      provider: provider,
      isStreaming: true,
    );
    state = [...state, assistantMessage];

    final service = AIServiceFactory.getService(provider);
    final request = AIRequest(prompt: prompt, provider: provider);
    final startTime = DateTime.now();

    String fullContent = '';

    try {
      await for (final chunk in service.streamMessage(request)) {
        fullContent += chunk;
        _updateStreamingMessage(messageId, fullContent);
      }

      final responseTime = DateTime.now().difference(startTime);
      final response = await service.completeStream(
        messageId: messageId,
        fullContent: fullContent,
        request: request,
        responseTime: responseTime,
      );

      await _completeStreamingMessage(
        messageId,
        fullContent,
        response.usage,
        responseTime,
      );
      ref.read(analyticsProvider.notifier).recordResponse(response);
    } catch (e) {
      final responseTime = DateTime.now().difference(startTime);
      await _completeStreamingMessage(
        messageId,
        'Error: Unable to get response. Using demo mode.',
        UsageStats.zero(),
        responseTime,
      );
    }
  }

  void _updateStreamingMessage(String messageId, String content) {
    state = state.map((msg) {
      if (msg.id == messageId) {
        return msg.copyWith(content: content);
      }
      return msg;
    }).toList();
  }

  Future<void> _completeStreamingMessage(
    String messageId,
    String content,
    UsageStats usage,
    Duration responseTime,
  ) async {
    final currentSession = ref.read(currentSessionProvider);

    state = state.map((msg) {
      if (msg.id == messageId) {
        return msg.copyWith(
          content: content,
          isStreaming: false,
          usage: usage,
          responseTime: responseTime,
        );
      }
      return msg;
    }).toList();

    // Save completed message to database
    if (currentSession != null) {
      final completedMessage = state.firstWhere((msg) => msg.id == messageId);
      await _db.saveMessage(completedMessage, currentSession.id);
      await ref.read(chatSessionsProvider.notifier).refreshSessions();
    }
  }

  void clear() {
    state = [];
  }
}

class ComparisonMessagesNotifier extends Notifier<List<ComparisonMessage>> {
  final _uuid = const Uuid();
  final _db = DatabaseService.instance;
  String? _lastLoadedSessionId;

  @override
  List<ComparisonMessage> build() {
    // Watch current session and trigger load when it changes
    final currentSession = ref.watch(currentSessionProvider);

    // Only load if session actually changed
    if (currentSession != null && currentSession.id != _lastLoadedSessionId) {
      _lastLoadedSessionId = currentSession.id;
      Future.microtask(() => _loadComparisonMessages(currentSession.id));
    } else if (currentSession == null && _lastLoadedSessionId != null) {
      _lastLoadedSessionId = null;
      state = [];
    }

    return [];
  }

  Future<void> _loadComparisonMessages(String sessionId) async {
    final comparisons = await _db.getComparisonMessages(sessionId);
    state = comparisons;
  }

  Future<void> reloadMessages() async {
    final currentSession = ref.read(currentSessionProvider);
    if (currentSession != null) {
      await _loadComparisonMessages(currentSession.id);
    }
  }

  Future<void> addComparison(
    String query,
    List<ProviderResponse> responses, {
    String? id,
  }) async {
    final currentSession = ref.read(currentSessionProvider);
    if (currentSession == null) return;

    final comparison = ComparisonMessage(
      id: id ?? _uuid.v4(),
      userQuery: query,
      responses: responses,
      timestamp: DateTime.now(),
    );

    state = [...state, comparison];

    // Auto-rename chat if this is the first comparison and chat has default name
    if (_isFirstComparison() && _hasDefaultName(currentSession.title)) {
      final newTitle = _generateTitleFromMessage(query);
      await ref
          .read(chatSessionsProvider.notifier)
          .updateSessionTitle(currentSession.id, newTitle);
      // Update current session to reflect the new title
      ref
          .read(currentSessionProvider.notifier)
          .setSession(currentSession.copyWith(title: newTitle));
    }

    // Save to database (only if not streaming)
    if (responses.every((r) => !r.isStreaming)) {
      await _db.saveComparisonMessage(comparison, currentSession.id);
      await ref.read(chatSessionsProvider.notifier).refreshSessions();
    }
  }

  bool _isFirstComparison() {
    // Check if this is the first comparison in this session
    return state.length == 1;
  }

  bool _hasDefaultName(String title) {
    // Check if title is "New Chat" or "New Chat 1", "New Chat 2", etc.
    return title == 'New Chat' || RegExp(r'^New Chat \d+$').hasMatch(title);
  }

  String _generateTitleFromMessage(String message) {
    // Get first sentence or first 30 characters
    String title = message.trim();

    // Try to find first sentence
    final sentenceEnd = RegExp(r'[.!?]').firstMatch(title);
    if (sentenceEnd != null && sentenceEnd.start < 30) {
      title = title.substring(0, sentenceEnd.start);
    }

    // Limit to 30 characters
    if (title.length > 30) {
      title = title.substring(0, 30).trim();
      // Remove trailing incomplete word if cut off
      final lastSpace = title.lastIndexOf(' ');
      if (lastSpace > 15) {
        title = title.substring(0, lastSpace);
      }
      title = '$title...';
    }

    return title;
  }

  void updateProviderResponse(
    String comparisonId,
    AIProvider provider,
    String content,
    bool isStreaming, {
    Duration? responseTime,
    int? totalTokens,
    double? estimatedCost,
  }) {
    state = state.map((comparison) {
      if (comparison.id == comparisonId) {
        final updatedResponses = comparison.responses.map((response) {
          if (response.provider == provider) {
            return response.copyWith(
              content: content,
              isStreaming: isStreaming,
              responseTime: responseTime,
              totalTokens: totalTokens,
              estimatedCost: estimatedCost,
            );
          }
          return response;
        }).toList();

        return ComparisonMessage(
          id: comparison.id,
          userQuery: comparison.userQuery,
          responses: updatedResponses,
          timestamp: comparison.timestamp,
        );
      }
      return comparison;
    }).toList();
  }

  Future<void> sendComparisonMessage(String prompt) async {
    final currentSession = ref.read(currentSessionProvider);
    if (currentSession == null) return;

    final messageId = _uuid.v4();

    // Create initial comparison with empty streaming responses
    final initialResponses = AIProvider.standardProviders.map((provider) {
      return ProviderResponse(
        provider: provider,
        content: '',
        isStreaming: true,
      );
    }).toList();

    await addComparison(prompt, initialResponses, id: messageId);

    // Stream all providers in parallel
    final futures = AIProvider.standardProviders.map((provider) async {
      final service = AIServiceFactory.getService(provider);
      final request = AIRequest(prompt: prompt, provider: provider);

      String fullContent = '';
      final startTime = DateTime.now();

      try {
        await for (final chunk in service.streamMessage(request)) {
          fullContent += chunk;
          // Update UI with streaming content
          updateProviderResponse(messageId, provider, fullContent, true);
        }

        final responseTime = DateTime.now().difference(startTime);
        final response = await service.completeStream(
          messageId: '$messageId-${provider.name}',
          fullContent: fullContent,
          request: request,
          responseTime: responseTime,
        );

        // Mark as complete with response time and usage stats
        updateProviderResponse(
          messageId,
          provider,
          fullContent,
          false,
          responseTime: responseTime,
          totalTokens: response.usage.totalTokens,
          estimatedCost: response.usage.estimatedCost,
        );

        ref.read(analyticsProvider.notifier).recordResponse(response);
      } catch (e) {
        final responseTime = DateTime.now().difference(startTime);
        updateProviderResponse(
          messageId,
          provider,
          'Error: Unable to get response from ${provider.name}',
          false,
          responseTime: responseTime,
        );
      }
    });

    // Wait for all providers to complete
    await Future.wait(futures);

    // Save the completed comparison message to database
    final ComparisonMessage completedComparison = state.firstWhere(
      (c) => c.id == messageId,
      orElse: () => ComparisonMessage(
        id: messageId,
        userQuery: prompt,
        responses: initialResponses,
        timestamp: DateTime.now(),
      ),
    );
    await _db.saveComparisonMessage(completedComparison, currentSession.id);
    await ref.read(chatSessionsProvider.notifier).refreshSessions();

    // Reload to ensure consistency with database
    await reloadMessages();
  }

  void clear() {
    state = [];
  }
}
