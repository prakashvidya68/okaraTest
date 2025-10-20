import 'dart:async';
import 'dart:convert';
import 'package:okara/models/ai_provider.dart';
import 'package:okara/models/ai_request.dart';
import 'package:okara/models/ai_response.dart';
import 'package:okara/models/usage_stats.dart';
import 'package:okara/services/ai_service.dart';
import 'package:http/http.dart' as http;

class XAIService implements AIService {
  final String apiKey;

  static const _baseUrl = 'https://api.x.ai/v1';
  static const _model = 'grok-4';
  static const _inputCostPer1kTokens = 0.005;
  static const _outputCostPer1kTokens = 0.015;

  XAIService({required this.apiKey});

  @override
  Future<AIResponse> sendMessage(AIRequest request) async {
    final startTime = DateTime.now();

    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': request.prompt},
        ],
        'temperature': request.temperature,
        'max_tokens': request.maxTokens,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('XAI API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final usage = data['usage'];
    final promptTokens = usage['prompt_tokens'] as int;
    final completionTokens = usage['completion_tokens'] as int;

    final usageStats = UsageStats(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: promptTokens + completionTokens,
      estimatedCost: _calculateCost(promptTokens, completionTokens),
    );

    return AIResponse(
      id: data['id'],
      content: data['choices'][0]['message']['content'],
      provider: AIProvider.xai,
      usage: usageStats,
      responseTime: DateTime.now().difference(startTime),
      timestamp: DateTime.now(),
    );
  }

  @override
  Stream<String> streamMessage(AIRequest request) async* {
    final client = http.Client();

    try {
      final request0 = http.Request(
        'POST',
        Uri.parse('$_baseUrl/chat/completions'),
      );

      request0.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });

      request0.body = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': request.prompt},
        ],
        'temperature': request.temperature,
        'max_tokens': request.maxTokens,
        'stream': true,
      });

      final response = await client.send(request0);

      await for (var chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (var line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data.trim() == '[DONE]') continue;

            try {
              final json = jsonDecode(data);
              final content = json['choices']?[0]?['delta']?['content'];
              if (content != null) {
                yield content as String;
              }
            } catch (_) {}
          }
        }
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<AIResponse> completeStream({
    required String messageId,
    required String fullContent,
    required AIRequest request,
    required Duration responseTime,
  }) async {
    final promptTokens = _estimateTokens(request.prompt);
    final completionTokens = _estimateTokens(fullContent);

    final usageStats = UsageStats(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: promptTokens + completionTokens,
      estimatedCost: _calculateCost(promptTokens, completionTokens),
    );

    return AIResponse(
      id: messageId,
      content: fullContent,
      provider: AIProvider.xai,
      usage: usageStats,
      responseTime: responseTime,
      timestamp: DateTime.now(),
    );
  }

  double _calculateCost(int promptTokens, int completionTokens) {
    return (promptTokens / 1000 * _inputCostPer1kTokens) +
        (completionTokens / 1000 * _outputCostPer1kTokens);
  }

  int _estimateTokens(String text) {
    return (text.length / 4).ceil();
  }
}
