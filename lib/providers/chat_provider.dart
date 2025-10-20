import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okara/models/ai_provider.dart';
import 'package:okara/models/ai_request.dart';
import 'package:okara/models/comparison_message.dart';
import 'package:okara/models/message.dart';
import 'package:okara/models/usage_stats.dart';
import 'package:okara/providers/analytics_provider.dart';
import 'package:okara/services/ai_service_factory.dart';
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

  @override
  List<Message> build() {
    return [];
  }

  void addMessage(
    String content,
    MessageRole role, {
    AIProvider? provider,
    UsageStats? usage,
  }) {
    final message = Message(
      id: _uuid.v4(),
      content: content,
      role: role,
      timestamp: DateTime.now(),
      provider: provider,
      usage: usage,
    );
    state = [...state, message];
  }

  Future<void> sendStreamingMessage(String prompt, AIProvider provider) async {
    addMessage(prompt, MessageRole.user);

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

      _completeStreamingMessage(messageId, fullContent, response.usage);
      ref.read(analyticsProvider.notifier).recordResponse(response);
    } catch (e) {
      _completeStreamingMessage(
        messageId,
        'Error: Unable to get response. Using demo mode.',
        UsageStats.zero(),
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

  void _completeStreamingMessage(
    String messageId,
    String content,
    UsageStats usage,
  ) {
    state = state.map((msg) {
      if (msg.id == messageId) {
        return msg.copyWith(content: content, isStreaming: false, usage: usage);
      }
      return msg;
    }).toList();
  }

  void clear() {
    state = [];
  }
}

class ComparisonMessagesNotifier extends Notifier<List<ComparisonMessage>> {
  final _uuid = const Uuid();

  @override
  List<ComparisonMessage> build() {
    return [];
  }

  void addComparison(
    String query,
    List<ProviderResponse> responses, {
    String? id,
  }) {
    final comparison = ComparisonMessage(
      id: id ?? _uuid.v4(),
      userQuery: query,
      responses: responses,
      timestamp: DateTime.now(),
    );
    state = [...state, comparison];
  }

  void updateProviderResponse(
    String comparisonId,
    AIProvider provider,
    String content,
    bool isStreaming,
  ) {
    state = state.map((comparison) {
      if (comparison.id == comparisonId) {
        final updatedResponses = comparison.responses.map((response) {
          if (response.provider == provider) {
            return response.copyWith(
              content: content,
              isStreaming: isStreaming,
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
    final messageId = _uuid.v4();

    // Create initial comparison with empty streaming responses
    final initialResponses = AIProvider.standardProviders.map((provider) {
      return ProviderResponse(
        provider: provider,
        content: '',
        isStreaming: true,
      );
    }).toList();

    addComparison(prompt, initialResponses, id: messageId);

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

        // Mark as complete
        updateProviderResponse(messageId, provider, fullContent, false);

        ref.read(analyticsProvider.notifier).recordResponse(response);
      } catch (e) {
        updateProviderResponse(
          messageId,
          provider,
          'Error: Unable to get response from ${provider.name}',
          false,
        );
      }
    });

    // Wait for all providers to complete
    await Future.wait(futures);
  }

  void clear() {
    state = [];
  }
}
