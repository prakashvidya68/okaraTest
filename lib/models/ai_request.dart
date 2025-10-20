import 'package:okara/models/ai_provider.dart';

class AIRequest {
  final String prompt;
  final AIProvider provider;
  final double temperature;
  final int maxTokens;

  AIRequest({
    required this.prompt,
    required this.provider,
    this.temperature = 0.7,
    this.maxTokens = 2048,
  });
}
