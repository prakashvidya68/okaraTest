import 'package:okara/models/ai_provider.dart';

class ProviderResponse {
  final AIProvider provider;
  final String content;
  final bool isStreaming;
  final Duration? responseTime;
  final int? totalTokens;
  final double? estimatedCost;

  ProviderResponse({
    required this.provider,
    required this.content,
    this.isStreaming = false,
    this.responseTime,
    this.totalTokens,
    this.estimatedCost,
  });

  ProviderResponse copyWith({
    String? content,
    bool? isStreaming,
    Duration? responseTime,
    int? totalTokens,
    double? estimatedCost,
  }) {
    return ProviderResponse(
      provider: provider,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
      responseTime: responseTime ?? this.responseTime,
      totalTokens: totalTokens ?? this.totalTokens,
      estimatedCost: estimatedCost ?? this.estimatedCost,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'provider': provider.name,
      'content': content,
      'responseTimeMs': responseTime?.inMilliseconds,
      'totalTokens': totalTokens,
      'estimatedCost': estimatedCost,
    };
  }

  factory ProviderResponse.fromMap(Map<String, dynamic> map) {
    Duration? responseTime;
    if (map['responseTimeMs'] != null) {
      responseTime = Duration(milliseconds: map['responseTimeMs'] as int);
    }

    return ProviderResponse(
      provider: AIProvider.values.firstWhere((e) => e.name == map['provider']),
      content: map['content'] as String,
      responseTime: responseTime,
      totalTokens: map['totalTokens'] as int?,
      estimatedCost: map['estimatedCost'] as double?,
    );
  }
}

class ComparisonMessage {
  final String id;
  final String userQuery;
  final List<ProviderResponse> responses;
  final DateTime timestamp;

  ComparisonMessage({
    required this.id,
    required this.userQuery,
    required this.responses,
    required this.timestamp,
  });

  Map<String, dynamic> toMap({required String sessionId}) {
    return {
      'id': id,
      'sessionId': sessionId,
      'userQuery': userQuery,
      'timestamp': timestamp.toIso8601String(),
      'responses': responses.map((r) => r.toMap()).toList(),
    };
  }

  factory ComparisonMessage.fromMap(Map<String, dynamic> map) {
    return ComparisonMessage(
      id: map['id'] as String,
      userQuery: map['userQuery'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      responses: (map['responses'] as List)
          .map((r) => ProviderResponse.fromMap(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
