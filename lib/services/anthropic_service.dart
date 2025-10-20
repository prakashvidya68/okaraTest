import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:okara/models/ai_provider.dart';
import 'package:okara/models/ai_request.dart';
import 'package:okara/models/ai_response.dart';
import 'package:okara/models/usage_stats.dart';
import 'package:okara/services/ai_service.dart';

class AnthropicService implements AIService {
  final String apiKey;

  static const _baseUrl = 'https://api.anthropic.com/v1';
  static const _model = 'claude-sonnet-4-5';
  static const _inputCostPer1kTokens = 0.003;
  static const _outputCostPer1kTokens = 0.015;

  AnthropicService({required this.apiKey});

  @override
  Future<AIResponse> sendMessage(AIRequest request) async {
    final startTime = DateTime.now();

    final response = await http.post(
      Uri.parse('$_baseUrl/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        "anthropic-version": "2023-06-01",
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
      throw Exception('Anthropic API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final usage = data['usage'];
    final promptTokens = usage['input_tokens'] as int;
    final completionTokens = usage['output_tokens'] as int;

    final usageStats = UsageStats(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: promptTokens + completionTokens,
      estimatedCost: _calculateCost(promptTokens, completionTokens),
    );

    return AIResponse(
      id: data['id'],
      content: data['content'][0]['text'],
      provider: AIProvider.anthropic,
      usage: usageStats,
      responseTime: DateTime.now().difference(startTime),
      timestamp: DateTime.now(),
    );
  }

  @override
  Stream<String> streamMessage(AIRequest request) async* {
    final client = http.Client();

    try {
      final request0 = http.Request('POST', Uri.parse('$_baseUrl/messages'));

      request0.headers.addAll({
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
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

            try {
              final json = jsonDecode(data);
              if (json['type'] == 'content_block_delta') {
                final content = json['delta']?['text'];
                if (content != null) {
                  yield content as String;
                }
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
      provider: AIProvider.anthropic,
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
