import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:okara/models/ai_provider.dart';
import 'package:okara/models/ai_request.dart';
import 'package:okara/models/ai_response.dart';
import 'package:okara/models/usage_stats.dart';
import 'package:okara/services/ai_service.dart';

class OpenAIService implements AIService {
  final String apiKey;

  static const _baseUrl = 'https://api.openai.com/v1';
  static const _model = 'gpt-5';
  static const _inputCostPer1kTokens = 0.0025;
  static const _outputCostPer1kTokens = 0.01;

  // Store usage data from the stream for accurate token counting
  Map<String, dynamic>? _lastStreamUsage;

  OpenAIService({required this.apiKey});

  @override
  Future<AIResponse> sendMessage(AIRequest request) async {
    final startTime = DateTime.now();

    final response = await http.post(
      Uri.parse('$_baseUrl/responses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({'model': _model, 'input': request.prompt}),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI API error: ${response.statusCode}');
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
      provider: AIProvider.openai,
      usage: usageStats,
      responseTime: DateTime.now().difference(startTime),
      timestamp: DateTime.now(),
    );
  }

  @override
  Stream<String> streamMessage(AIRequest request) async* {
    final client = http.Client();
    _lastStreamUsage = null; // Reset usage data for new stream

    try {
      final request0 = http.Request('POST', Uri.parse('$_baseUrl/responses'));

      request0.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });

      request0.body = jsonEncode({
        'model': _model,
        'input': request.prompt,
        'stream': true,
      });

      final response = await client.send(request0);
      await for (var chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (var line in lines) {
          if (line.startsWith('event: ')) {
            // Skip event type line
            continue;
          }
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data.isEmpty) continue;

            try {
              final json = jsonDecode(data);
              final eventType = json['type'];

              // Handle text delta events (new Response API format)
              if (eventType == 'response.output_text.delta') {
                final delta = json['delta'];
                if (delta != null) {
                  yield delta as String;
                }
              }

              // Capture usage data from completed response
              if (eventType == 'response.completed') {
                _lastStreamUsage = json['response']?['usage'];
              }
            } catch (e) {
              // Silently skip malformed JSON
            }
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
    // Use actual usage data from stream if available, otherwise estimate
    int promptTokens;
    int completionTokens;

    if (_lastStreamUsage != null) {
      promptTokens =
          _lastStreamUsage!['input_tokens'] ?? _estimateTokens(request.prompt);
      completionTokens =
          _lastStreamUsage!['output_tokens'] ?? _estimateTokens(fullContent);
    } else {
      promptTokens = _estimateTokens(request.prompt);
      completionTokens = _estimateTokens(fullContent);
    }

    final usageStats = UsageStats(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: promptTokens + completionTokens,
      estimatedCost: _calculateCost(promptTokens, completionTokens),
    );

    return AIResponse(
      id: messageId,
      content: fullContent,
      provider: AIProvider.openai,
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
