import 'package:okara/models/ai_provider.dart';
import 'package:okara/models/usage_stats.dart';

class AIResponse {
  final String id;
  final String content;
  final AIProvider provider;
  final UsageStats usage;
  final Duration responseTime;
  final DateTime timestamp;

  AIResponse({
    required this.id,
    required this.content,
    required this.provider,
    required this.usage,
    required this.responseTime,
    required this.timestamp,
  });
}
