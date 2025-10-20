import 'package:okara/models/ai_provider.dart';
import 'package:okara/models/usage_stats.dart';

enum MessageRole { user, assistant }

class Message {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final AIProvider? provider;
  final bool isStreaming;
  final UsageStats? usage;

  Message({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.provider,
    this.isStreaming = false,
    this.usage,
  });

  Message copyWith({String? content, bool? isStreaming, UsageStats? usage}) {
    return Message(
      id: id,
      content: content ?? this.content,
      role: role,
      timestamp: timestamp,
      provider: provider,
      isStreaming: isStreaming ?? this.isStreaming,
      usage: usage ?? this.usage,
    );
  }
}
