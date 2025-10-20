import 'package:okara/models/ai_request.dart';
import 'package:okara/models/ai_response.dart';

abstract class AIService {
  Future<AIResponse> sendMessage(AIRequest request);

  Stream<String> streamMessage(AIRequest request);

  Future<AIResponse> completeStream({
    required String messageId,
    required String fullContent,
    required AIRequest request,
    required Duration responseTime,
  });
}
