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
  final Duration? responseTime;

  Message({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.provider,
    this.isStreaming = false,
    this.usage,
    this.responseTime,
  });

  Message copyWith({
    String? content,
    bool? isStreaming,
    UsageStats? usage,
    Duration? responseTime,
  }) {
    return Message(
      id: id,
      content: content ?? this.content,
      role: role,
      timestamp: timestamp,
      provider: provider,
      isStreaming: isStreaming ?? this.isStreaming,
      usage: usage ?? this.usage,
      responseTime: responseTime ?? this.responseTime,
    );
  }

  Map<String, dynamic> toMap({required String sessionId}) {
    return {
      'id': id,
      'sessionId': sessionId,
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
      'provider': provider?.name,
      'promptTokens': usage?.promptTokens,
      'completionTokens': usage?.completionTokens,
      'totalTokens': usage?.totalTokens,
      'estimatedCost': usage?.estimatedCost,
      'responseTimeMs': responseTime?.inMilliseconds,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    UsageStats? usage;
    if (map['totalTokens'] != null) {
      usage = UsageStats(
        promptTokens: map['promptTokens'] as int? ?? 0,
        completionTokens: map['completionTokens'] as int? ?? 0,
        totalTokens: map['totalTokens'] as int,
        estimatedCost: map['estimatedCost'] as double? ?? 0.0,
      );
    }

    Duration? responseTime;
    if (map['responseTimeMs'] != null) {
      responseTime = Duration(milliseconds: map['responseTimeMs'] as int);
    }

    return Message(
      id: map['id'] as String,
      content: map['content'] as String,
      role: MessageRole.values.firstWhere((e) => e.name == map['role']),
      timestamp: DateTime.parse(map['timestamp'] as String),
      provider: map['provider'] != null
          ? AIProvider.values.firstWhere((e) => e.name == map['provider'])
          : null,
      usage: usage,
      responseTime: responseTime,
    );
  }
}
